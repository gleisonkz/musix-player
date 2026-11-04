import AVFoundation
import Foundation
import MusixCore

/// Multitrack player built on AVAudioEngine.
///
/// Graph per stem: `AVAudioPlayerNode` -> strip `AVAudioMixerNode` -> main mixer.
/// In split mode the strip -> main mixer connection is mono, so every stem is summed to mono
/// and the strip pan sends it hard left (click/guide) or hard right (band).
/// All players are started at the same host time, so stems stay sample aligned.
/// Files are streamed from disk (`scheduleSegment`), never fully loaded into memory.
///
/// Not thread safe: use from a single thread (the main thread in the app).
public final class PlaybackEngine {
    public enum RenderMode {
        case realtime
        /// Manual offline rendering, used by tests to inspect the output samples.
        case offline(sampleRate: Double, maximumFrameCount: AVAudioFrameCount)
    }

    public enum EngineError: Error {
        case notOfflineMode
        case renderFailed
    }

    private struct Channel {
        let info: TrackInfo
        let file: AVAudioFile
        let player = AVAudioPlayerNode()
        let strip = AVAudioMixerNode()
        var sampleRate: Double { file.processingFormat.sampleRate }
    }

    /// Small lead time so every player receives the same future start time.
    public var startDelay: TimeInterval = 0.05

    public var outputMode: OutputMode = .split {
        didSet { if oldValue != outputMode { reconnect() } }
    }

    public private(set) var manifest: SongManifest?
    public private(set) var isPlaying = false
    public private(set) var duration: Double = 0

    /// Called on the main queue after the engine recovered from an audio route/config change.
    public var onConfigurationRecovered: (() -> Void)?

    private let engine = AVAudioEngine()
    private let renderMode: RenderMode
    private var channels: [Channel] = []
    private var gains: [Float] = []
    private var sideOverrides: [Int: OutputSide] = [:]
    private var startOffset: Double = 0
    private var stoppedTime: Double = 0
    private var configObserver: NSObjectProtocol?

    public init(renderMode: RenderMode = .realtime) throws {
        self.renderMode = renderMode
        if case let .offline(sampleRate, maximumFrameCount) = renderMode {
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
            try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: maximumFrameCount)
        } else {
            configObserver = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
            ) { [weak self] _ in self?.recoverFromConfigurationChange() }
        }
        _ = engine.mainMixerNode
    }

    deinit {
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        engine.stop()
    }

    // MARK: loading

    /// Loads a song folder: uses song.json when present, otherwise infers tracks from file names.
    @discardableResult
    public func load(folder: URL) throws -> SongManifest {
        let manifest = try Self.manifest(forFolder: folder)
        try load(manifest: manifest, folder: folder)
        return manifest
    }

    public static func manifest(forFolder folder: URL) throws -> SongManifest {
        let jsonURL = folder.appendingPathComponent(SongManifest.fileName)
        if FileManager.default.fileExists(atPath: jsonURL.path) {
            return try SongManifest.decode(Data(contentsOf: jsonURL))
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        return SongManifest.infer(folderName: folder.lastPathComponent, fileNames: names)
    }

    public func load(manifest: SongManifest, folder: URL) throws {
        stop()
        let files = try manifest.tracks.map { try AVAudioFile(forReading: folder.appendingPathComponent($0.file)) }

        for channel in channels {
            engine.detach(channel.player)
            engine.detach(channel.strip)
        }
        channels = zip(manifest.tracks, files).map { Channel(info: $0, file: $1) }
        for channel in channels {
            engine.attach(channel.player)
            engine.attach(channel.strip)
            engine.connect(channel.player, to: channel.strip, format: channel.file.processingFormat)
        }
        connectStrips()

        self.manifest = manifest
        duration = channels.map { Double($0.file.length) / $0.sampleRate }.max() ?? 0
        gains = Array(repeating: 1, count: channels.count)
        sideOverrides = [:]
        stoppedTime = 0
        applyMixing()
        try startEngineIfNeeded()
    }

    // MARK: mixing

    public func apply(mixer: MixerState) {
        gains = mixer.effectiveGains()
        applyMixing()
    }

    /// Forces a track to one side in split mode (nil = default for its role).
    public func setSide(_ side: OutputSide?, forTrackAt index: Int) {
        sideOverrides[index] = side
        applyMixing()
    }

    public func side(forTrackAt index: Int) -> OutputSide? { sideOverrides[index] }

    private func applyMixing() {
        let routing = OutputRouting(mode: outputMode)
        for (i, channel) in channels.enumerated() {
            channel.strip.outputVolume = i < gains.count ? gains[i] : 1
            channel.strip.pan = routing.pan(for: channel.info.role, override: sideOverrides[i])
        }
    }

    private func connectStrips() {
        let downmix = OutputRouting(mode: outputMode).downmixToMono
        for channel in channels {
            let format = downmix
                ? AVAudioFormat(standardFormatWithSampleRate: channel.sampleRate, channels: 1)!
                : channel.file.processingFormat
            engine.connect(channel.strip, to: engine.mainMixerNode, format: format)
        }
    }

    private func reconnect() {
        let wasPlaying = isPlaying
        let time = currentTime
        stop()
        for channel in channels { engine.disconnectNodeOutput(channel.strip) }
        connectStrips()
        applyMixing()
        if wasPlaying { try? play(from: time) }
    }

    // MARK: transport

    public var currentTime: Double {
        guard isPlaying else { return stoppedTime }
        guard let player = channels.first?.player,
              let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime)
        else { return startOffset }
        let elapsed = max(0, Double(playerTime.sampleTime) / playerTime.sampleRate)
        return min(duration, startOffset + elapsed)
    }

    /// True once playback reached the end of the longest stem.
    public var reachedEnd: Bool { isPlaying && currentTime >= duration - 0.01 }

    public func play(from time: Double) throws {
        guard !channels.isEmpty else { return }
        for channel in channels { channel.player.stop() }
        try startEngineIfNeeded()

        let start = min(max(0, time), duration)
        for channel in channels {
            let startFrame = AVAudioFramePosition(start * channel.sampleRate)
            let remaining = channel.file.length - startFrame
            guard remaining > 0 else { continue }
            channel.player.scheduleSegment(channel.file, startingFrame: startFrame,
                                           frameCount: AVAudioFrameCount(remaining), at: nil)
            channel.player.prepare(withFrameCount: 8192)
        }

        let when: AVAudioTime?
        switch renderMode {
        case .realtime:
            when = AVAudioTime(hostTime: mach_absolute_time() + AVAudioTime.hostTime(forSeconds: startDelay))
        case .offline:
            when = nil // every player starts on the next rendered block
        }
        for channel in channels { channel.player.play(at: when) }
        startOffset = start
        isPlaying = true
    }

    public func stop() {
        stoppedTime = currentTime
        for channel in channels { channel.player.stop() }
        isPlaying = false
    }

    /// Moves the playhead; keeps playing if it was playing.
    public func seek(to time: Double) throws {
        if isPlaying {
            try play(from: time)
        } else {
            stoppedTime = min(max(0, time), duration)
        }
    }

    // MARK: engine

    private func startEngineIfNeeded() throws {
        guard !engine.isRunning else { return }
        engine.prepare()
        try engine.start()
    }

    private func recoverFromConfigurationChange() {
        let wasPlaying = isPlaying
        let time = currentTime
        stop()
        for channel in channels { engine.disconnectNodeOutput(channel.strip) }
        connectStrips()
        applyMixing()
        try? startEngineIfNeeded()
        if wasPlaying { try? play(from: time) }
        onConfigurationRecovered?()
    }

    /// Offline mode only: renders the next block of output.
    public func renderOffline(frameCount: AVAudioFrameCount) throws -> AVAudioPCMBuffer {
        guard case .offline = renderMode else { throw EngineError.notOfflineMode }
        let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: frameCount)!
        switch try engine.renderOffline(frameCount, to: buffer) {
        case .success, .insufficientDataFromInputNode:
            return buffer
        case .cannotDoInCurrentContext, .error:
            throw EngineError.renderFailed
        @unknown default:
            throw EngineError.renderFailed
        }
    }
}
