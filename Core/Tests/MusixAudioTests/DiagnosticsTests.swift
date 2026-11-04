import AVFoundation
import MusixCore
import Testing
@testable import MusixAudio

/// Temporary: prints channel levels for routing scenarios to investigate pan leakage.
@Suite struct DiagnosticsTests {
    let h = PlaybackEngineTests()

    func run(_ name: String, files: [(String, TrackRole, Int)], setup: (PlaybackEngine) -> Void) throws {
        let dir = try h.tempFolder()
        for (file, _, ch) in files {
            try h.writeWav(dir.appendingPathComponent(file), channels: ch, frames: 44_100) { _, _ in 0.5 }
        }
        let engine = try h.makeEngine()
        try engine.load(manifest: h.song(dir, files.map { ($0.0, $0.1) }), folder: dir)
        engine.outputMode = .split
        setup(engine)
        try engine.play(from: 0)
        let out = try h.render(engine, frames: 8192)
        print("DIAG \(name): L=\(h.level(out.l)) R=\(h.level(out.r))")
    }

    @Test func diagnostics() throws {
        try run("single mono click", files: [("c.wav", .click, 1)]) { _ in }
        try run("single mono band", files: [("b.wav", .band, 1)]) { _ in }
        try run("single stereo click", files: [("c.wav", .click, 2)]) { _ in }
        try run("click+band both on", files: [("c.wav", .click, 1), ("b.wav", .band, 1)]) { _ in }
        try run("click+band, band muted", files: [("c.wav", .click, 1), ("b.wav", .band, 1)]) { e in
            var m = MixerState(roles: [.click, .band]); m.toggleMute(at: 1); e.apply(mixer: m)
        }
        try run("click+band, click muted", files: [("c.wav", .click, 1), ("b.wav", .band, 1)]) { e in
            var m = MixerState(roles: [.click, .band]); m.toggleMute(at: 0); e.apply(mixer: m)
        }
    }
}
