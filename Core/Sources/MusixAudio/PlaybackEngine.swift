import AVFoundation
import Foundation
import MusixCore

/// Multitrack player built on AVAudioEngine. (stub — implementation pending)
public final class PlaybackEngine {
    public enum RenderMode {
        case realtime
        case offline(sampleRate: Double, maximumFrameCount: AVAudioFrameCount)
    }

    public var outputMode: OutputMode = .split
    public private(set) var manifest: SongManifest?
    public private(set) var isPlaying = false
    public var currentTime: Double { 0 }
    public var duration: Double { 0 }

    public init(renderMode: RenderMode = .realtime) throws {}

    @discardableResult
    public func load(folder: URL) throws -> SongManifest {
        SongManifest(title: "", tracks: [])
    }

    public func load(manifest: SongManifest, folder: URL) throws {}
    public func apply(mixer: MixerState) {}
    public func play(from time: Double) throws {}
    public func stop() {}

    public func renderOffline(frameCount: AVAudioFrameCount) throws -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        return buffer
    }
}
