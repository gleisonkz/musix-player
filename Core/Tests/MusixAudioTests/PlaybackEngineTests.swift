import AVFoundation
import Foundation
import MusixCore
import Testing
@testable import MusixAudio

/// Renders the real AVAudioEngine graph offline and inspects the output samples.
@Suite struct PlaybackEngineTests {
    static let rate = 44_100.0

    // MARK: helpers

    func tempFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("musix-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func writeWav(_ url: URL, channels: Int = 1, frames: Int, fill: (_ channel: Int, _ frame: Int) -> Float) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: Self.rate, channels: AVAudioChannelCount(channels))!
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: Self.rate,
            AVNumberOfChannelsKey: channels, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings,
                                   commonFormat: .pcmFormatFloat32, interleaved: false)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        for c in 0..<channels {
            for f in 0..<frames { buffer.floatChannelData![c][f] = fill(c, f) }
        }
        try file.write(from: buffer)
    }

    func song(_ folder: URL, _ tracks: [(String, TrackRole)]) -> SongManifest {
        SongManifest(title: "T", tracks: tracks.map { TrackInfo(name: $0.0, file: $0.0, role: $0.1) })
    }

    func makeEngine() throws -> PlaybackEngine {
        try PlaybackEngine(renderMode: .offline(sampleRate: Self.rate, maximumFrameCount: 4096))
    }

    /// Renders `frames` and returns (left, right) samples.
    func render(_ engine: PlaybackEngine, frames: Int) throws -> (l: [Float], r: [Float]) {
        var l: [Float] = [], r: [Float] = []
        while l.count < frames {
            let buffer = try engine.renderOffline(frameCount: AVAudioFrameCount(min(4096, frames - l.count)))
            let n = Int(buffer.frameLength)
            l += UnsafeBufferPointer(start: buffer.floatChannelData![0], count: n)
            r += UnsafeBufferPointer(start: buffer.floatChannelData![1], count: n)
        }
        return (l, r)
    }

    func level(_ x: [Float], from: Int = 1024) -> Float {
        let s = x[from...]
        return s.map(abs).reduce(0, +) / Float(s.count)
    }

    func peakIndex(_ x: [Float]) -> Int {
        x.indices.max { abs(x[$0]) < abs(x[$1]) }!
    }

    // MARK: tests

    @Test func splitModeSendsClickLeftAndBandRight() throws {
        let dir = try tempFolder()
        try writeWav(dir.appendingPathComponent("click.wav"), frames: 44_100) { _, _ in 0.5 }
        try writeWav(dir.appendingPathComponent("band.wav"), frames: 44_100) { _, _ in 0.5 }
        let engine = try makeEngine()
        try engine.load(manifest: song(dir, [("click.wav", .click), ("band.wav", .band)]), folder: dir)
        engine.outputMode = .split

        var mixer = MixerState(roles: [.click, .band])
        mixer.toggleMute(at: 1)
        engine.apply(mixer: mixer)
        try engine.play(from: 0)
        // volume changes are ramped by AVAudioMixer (de-zipper, avoids clicks); measure after the ramp
        _ = try render(engine, frames: 8192)
        let clickOnly = try render(engine, frames: 8192)
        #expect(level(clickOnly.l) > 0.1)
        #expect(level(clickOnly.r) < 0.001)

        mixer.toggleMute(at: 1)
        mixer.toggleMute(at: 0)
        engine.apply(mixer: mixer)
        _ = try render(engine, frames: 8192)
        let bandOnly = try render(engine, frames: 8192)
        #expect(level(bandOnly.l) < 0.001)
        #expect(level(bandOnly.r) > 0.1)
    }

    @Test func splitModeDownmixesStereoStemsToTheirSide() throws {
        let dir = try tempFolder()
        // stereo band stem with content only on its left channel
        try writeWav(dir.appendingPathComponent("band.wav"), channels: 2, frames: 44_100) { c, _ in c == 0 ? 0.5 : 0 }
        let engine = try makeEngine()
        try engine.load(manifest: song(dir, [("band.wav", .band)]), folder: dir)
        engine.outputMode = .split
        try engine.play(from: 0)
        let out = try render(engine, frames: 8192)
        #expect(level(out.l) < 0.001)
        #expect(level(out.r) > 0.1)
    }

    @Test func stereoModeKeepsStereoImage() throws {
        let dir = try tempFolder()
        try writeWav(dir.appendingPathComponent("band.wav"), channels: 2, frames: 44_100) { c, _ in c == 0 ? 0.5 : 0 }
        let engine = try makeEngine()
        try engine.load(manifest: song(dir, [("band.wav", .band)]), folder: dir)
        engine.outputMode = .stereo
        try engine.play(from: 0)
        let out = try render(engine, frames: 8192)
        #expect(level(out.l) > 0.1)
        #expect(level(out.r) < 0.001)
    }

    @Test func tracksStartSampleAligned() throws {
        let dir = try tempFolder()
        try writeWav(dir.appendingPathComponent("click.wav"), frames: 10_000) { _, f in f == 2_000 ? 1 : 0 }
        try writeWav(dir.appendingPathComponent("band.wav"), frames: 10_000) { _, f in f == 2_000 ? 1 : 0 }
        let engine = try makeEngine()
        try engine.load(manifest: song(dir, [("click.wav", .click), ("band.wav", .band)]), folder: dir)
        engine.outputMode = .split
        try engine.play(from: 0)
        let out = try render(engine, frames: 8192)
        #expect(peakIndex(out.l) == peakIndex(out.r))
        #expect(abs(peakIndex(out.l) - 2_000) <= 64)
    }

    @Test func playFromTimeSeeks() throws {
        let dir = try tempFolder()
        try writeWav(dir.appendingPathComponent("band.wav"), frames: 88_200) { _, f in f == 44_100 ? 1 : 0 }
        let engine = try makeEngine()
        try engine.load(manifest: song(dir, [("band.wav", .band)]), folder: dir)
        try engine.play(from: 0.5)
        let out = try render(engine, frames: 32_768)
        #expect(abs(peakIndex(out.r) - 22_050) <= 64)
    }

    @Test func durationIsLongestTrack() throws {
        let dir = try tempFolder()
        try writeWav(dir.appendingPathComponent("a.wav"), frames: 44_100) { _, _ in 0 }
        try writeWav(dir.appendingPathComponent("b.wav"), frames: 88_200) { _, _ in 0 }
        let engine = try makeEngine()
        try engine.load(manifest: song(dir, [("a.wav", .band), ("b.wav", .band)]), folder: dir)
        #expect(abs(engine.duration - 2.0) < 0.001)
    }

    @Test func currentTimeFollowsRendering() throws {
        let dir = try tempFolder()
        try writeWav(dir.appendingPathComponent("band.wav"), frames: 88_200) { _, _ in 0 }
        let engine = try makeEngine()
        try engine.load(manifest: song(dir, [("band.wav", .band)]), folder: dir)
        try engine.play(from: 0.25)
        _ = try render(engine, frames: 44_100)
        #expect(abs(engine.currentTime - 1.25) < 0.1)
        engine.stop()
        #expect(!engine.isPlaying)
        let stoppedAt = engine.currentTime
        #expect(abs(stoppedAt - 1.25) < 0.1)
    }

    @Test func loadFolderInfersManifestWithoutSongJSON() throws {
        let dir = try tempFolder()
        try writeWav(dir.appendingPathComponent("Click.wav"), frames: 100) { _, _ in 0 }
        try writeWav(dir.appendingPathComponent("Baixo.wav"), frames: 100) { _, _ in 0 }
        let engine = try makeEngine()
        let manifest = try engine.load(folder: dir)
        #expect(manifest.tracks.map(\.role) == [.click, .band])
    }

    @Test func loadFolderPrefersSongJSON() throws {
        let dir = try tempFolder()
        try writeWav(dir.appendingPathComponent("x.wav"), frames: 100) { _, _ in 0 }
        let json = #"{"title": "Do JSON", "tracks": [{"name": "X", "file": "x.wav", "role": "guide"}]}"#
        try Data(json.utf8).write(to: dir.appendingPathComponent("song.json"))
        let engine = try makeEngine()
        let manifest = try engine.load(folder: dir)
        #expect(manifest.title == "Do JSON")
        #expect(manifest.tracks.map(\.role) == [.guide])
    }
}
