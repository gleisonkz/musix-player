import Foundation
import MusixAudio
import MusixCore
import Observation

@MainActor
@Observable
final class PlayerModel {
    private(set) var song: SongEntry?
    private(set) var isPlaying = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var mixer = MixerState(roles: [])
    private(set) var sides: [Int: OutputSide] = [:]
    var errorMessage: String?

    var outputMode: OutputMode = .split {
        didSet {
            engine?.outputMode = outputMode
            UserDefaults.standard.set(outputMode.rawValue, forKey: "outputMode")
        }
    }

    var navigator: MarkerNavigator { MarkerNavigator(markers: song?.manifest.markers ?? []) }
    var currentMarker: Marker? { navigator.current(at: currentTime) }

    @ObservationIgnored private var engine: PlaybackEngine?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init() {
        if let raw = UserDefaults.standard.string(forKey: "outputMode"), let mode = OutputMode(rawValue: raw) {
            outputMode = mode
        }
        do {
            let engine = try PlaybackEngine()
            engine.outputMode = outputMode
            self.engine = engine
        } catch {
            errorMessage = "Falha ao iniciar áudio: \(error.localizedDescription)"
        }
        startTicker()
    }

    // MARK: loading

    func load(_ entry: SongEntry) {
        guard let engine, entry != song else { return }
        do {
            try engine.load(manifest: entry.manifest, folder: entry.folder)
            song = entry
            duration = engine.duration
            currentTime = 0
            isPlaying = false
            sides = [:]
            mixer = MixerState(roles: entry.manifest.tracks.map(\.role))
            engine.apply(mixer: mixer)
        } catch {
            errorMessage = "Não consegui abrir \(entry.title): \(error.localizedDescription)"
        }
    }

    // MARK: transport

    func togglePlay() {
        guard let engine, song != nil else { return }
        if engine.isPlaying {
            engine.stop()
        } else {
            let from = currentTime >= duration - 0.05 ? 0 : currentTime
            do { try engine.play(from: from) } catch { errorMessage = error.localizedDescription }
        }
        sync()
    }

    /// Stop and rewind to the start of the song.
    func stop() {
        engine?.stop()
        try? engine?.seek(to: 0)
        sync()
    }

    func seek(to time: Double) {
        try? engine?.seek(to: time)
        sync()
    }

    func jump(to marker: Marker) { seek(to: marker.time) }

    func nextSection() {
        if let marker = navigator.next(after: currentTime) { jump(to: marker) }
    }

    func previousSection() {
        if let marker = navigator.previous(before: currentTime) { jump(to: marker) } else { seek(to: 0) }
    }

    // MARK: mixer

    func setVolume(_ volume: Float, at index: Int) {
        mixer.setVolume(volume, at: index)
        engine?.apply(mixer: mixer)
    }

    func setMaster(_ volume: Float) {
        mixer.master = volume
        engine?.apply(mixer: mixer)
    }

    func toggleMute(at index: Int) {
        mixer.toggleMute(at: index)
        engine?.apply(mixer: mixer)
    }

    func toggleSolo(at index: Int) {
        mixer.toggleSolo(at: index)
        engine?.apply(mixer: mixer)
    }

    /// Effective side of a track in split mode (override or role default).
    func side(at index: Int) -> OutputSide {
        if let side = sides[index] { return side }
        let role = song?.manifest.tracks[index].role ?? .band
        return role == .band ? .right : .left
    }

    func flipSide(at index: Int) {
        let newSide: OutputSide = side(at: index) == .left ? .right : .left
        sides[index] = newSide
        engine?.setSide(newSide, forTrackAt: index)
    }

    // MARK: ticker

    private func startTicker() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let engine else { return }
        if engine.reachedEnd {
            engine.stop()
            try? engine.seek(to: 0)
        }
        sync()
    }

    private func sync() {
        guard let engine else { return }
        isPlaying = engine.isPlaying
        currentTime = engine.currentTime
    }
}
