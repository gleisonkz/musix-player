import AVFoundation

enum AudioSession {
    /// Playback category keeps audio running with the screen locked / app in background
    /// (together with UIBackgroundModes=audio) and ignores the silent switch.
    static func configure() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            // ~23 ms buffer: latency does not matter for playback (all stems shift together),
            // a larger buffer means fewer dropouts.
            try session.setPreferredIOBufferDuration(0.023)
            try session.setPreferredSampleRate(48_000)
            try session.setActive(true)
        } catch {
            print("AudioSession error: \(error)")
        }
    }

    static var currentOutputName: String {
        AVAudioSession.sharedInstance().currentRoute.outputs.first?.portName ?? "—"
    }
}
