import MusixCore
import SwiftUI

struct PlayerView: View {
    @Environment(PlayerModel.self) private var player
    @State private var scrubbing: Double?

    var body: some View {
        @Bindable var player = player
        VStack(spacing: 16) {
            header
            timeline
            markers
            transport
            Picker("Saída", selection: $player.outputMode) {
                Text("Split  ·  L: click/guia  ·  R: banda").tag(OutputMode.split)
                Text("Estéreo").tag(OutputMode.stereo)
            }
            .pickerStyle(.segmented)
            .disabled(player.isPlaying)
            MixerView()
        }
        .padding()
        .navigationTitle(player.song?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        let manifest = player.song?.manifest
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading) {
                Text(manifest?.title ?? "").font(.largeTitle.bold())
                if let artist = manifest?.artist { Text(artist).foregroundStyle(.secondary) }
            }
            Spacer()
            HStack(spacing: 16) {
                if let bpm = manifest?.bpm { tag("\(Int(bpm)) BPM") }
                if let key = manifest?.key { tag("Tom \(key)") }
                if let sig = manifest?.timeSignature { tag(sig) }
            }
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text).font(.headline.monospacedDigit())
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
    }

    private var timeline: some View {
        VStack(spacing: 4) {
            Slider(value: Binding(get: { scrubbing ?? player.currentTime }, set: { scrubbing = $0 }),
                   in: 0...max(player.duration, 0.1)) { editing in
                if !editing, let target = scrubbing {
                    player.seek(to: target)
                    scrubbing = nil
                }
            }
            HStack {
                Text(format(scrubbing ?? player.currentTime))
                Spacer()
                if let marker = player.currentMarker { Text(marker.name).foregroundStyle(.tint) }
                Spacer()
                Text("-" + format(player.duration - (scrubbing ?? player.currentTime)))
            }
            .font(.title3.monospacedDigit())
        }
    }

    private var markers: some View {
        let list = player.navigator.markers
        let current = player.currentMarker
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(list.enumerated()), id: \.offset) { _, marker in
                    Button(marker.name) { player.jump(to: marker) }
                        .buttonStyle(.bordered)
                        .tint(marker == current ? .accentColor : .gray)
                        .controlSize(.large)
                }
            }
        }
        .opacity(list.isEmpty ? 0 : 1)
    }

    private var transport: some View {
        HStack(spacing: 28) {
            transportButton("backward.end.fill") { player.previousSection() }
            transportButton("stop.fill") { player.stop() }
            Button { player.togglePlay() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 44))
                    .frame(width: 110, height: 80)
            }
            .buttonStyle(.borderedProminent)
            .tint(player.isPlaying ? .orange : .green)
            transportButton("forward.end.fill") { player.nextSection() }
        }
    }

    private func transportButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title).frame(width: 64, height: 56)
        }
        .buttonStyle(.bordered)
    }

    private func format(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
