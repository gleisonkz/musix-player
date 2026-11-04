import MusixCore
import SwiftUI

struct MixerView: View {
    @Environment(PlayerModel.self) private var player

    var body: some View {
        let tracks = player.song?.manifest.tracks ?? []
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                    ChannelStrip(index: index, track: track)
                }
                Divider()
                MasterStrip()
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: .infinity)
    }
}

private struct ChannelStrip: View {
    @Environment(PlayerModel.self) private var player
    let index: Int
    let track: TrackInfo

    var body: some View {
        let channel = player.mixer.channels.indices.contains(index) ? player.mixer.channels[index] : nil
        VStack(spacing: 8) {
            Text(track.name).font(.subheadline.bold()).lineLimit(1).frame(width: 84)
            Text(roleLabel).font(.caption2).foregroundStyle(roleColor)

            if player.outputMode == .split {
                Button(player.side(at: index) == .left ? "L" : "R") { player.flipSide(at: index) }
                    .font(.headline)
                    .buttonStyle(.bordered)
                    .tint(player.side(at: index) == .left ? .cyan : .pink)
            }

            VerticalFader(value: Binding(get: { channel?.volume ?? 1 },
                                         set: { player.setVolume($0, at: index) }),
                          tint: roleColor)

            Text("\(Int((channel?.volume ?? 1) * 100))").font(.caption.monospacedDigit())

            HStack(spacing: 6) {
                toggle("M", on: channel?.muted == true, color: .red) { player.toggleMute(at: index) }
                toggle("S", on: channel?.soloed == true, color: .yellow) { player.toggleSolo(at: index) }
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private var roleLabel: String {
        switch track.role {
        case .click: "CLICK"
        case .guide: "GUIA"
        case .band: "BANDA"
        }
    }

    private var roleColor: Color {
        switch track.role {
        case .click: .cyan
        case .guide: .purple
        case .band: .green
        }
    }

    private func toggle(_ title: String, on: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).frame(width: 34, height: 34)
                .background(on ? color : Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(on ? .black : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct MasterStrip: View {
    @Environment(PlayerModel.self) private var player

    var body: some View {
        VStack(spacing: 8) {
            Text("Master").font(.subheadline.bold()).frame(width: 84)
            Text(" ").font(.caption2)
            VerticalFader(value: Binding(get: { player.mixer.master }, set: { player.setMaster($0) }), tint: .white)
            Text("\(Int(player.mixer.master * 100))").font(.caption.monospacedDigit())
        }
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Drag up/down fader (0...1). Double tap resets to 100%.
struct VerticalFader: View {
    @Binding var value: Float
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.25))
                RoundedRectangle(cornerRadius: 6).fill(tint.opacity(0.7))
                    .frame(height: height * CGFloat(value))
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                value = Float(min(max(1 - drag.location.y / height, 0), 1))
            })
            .onTapGesture(count: 2) { value = 1 }
        }
        .frame(width: 44)
        .frame(minHeight: 140)
    }
}
