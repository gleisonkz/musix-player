import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(SongLibrary.self) private var library
    @Environment(PlayerModel.self) private var player
    @Binding var selection: SongEntry?
    @State private var importing = false

    var body: some View {
        List(selection: $selection) {
            ForEach(library.songs) { song in
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title).font(.headline)
                    HStack(spacing: 8) {
                        if let artist = song.manifest.artist { Text(artist) }
                        if let bpm = song.manifest.bpm { Text("\(Int(bpm)) BPM") }
                        if let key = song.manifest.key { Text("Tom \(key)") }
                        Text("\(song.manifest.tracks.count) faixas")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .tag(song)
                .swipeActions {
                    Button("Apagar", role: .destructive) { library.delete(song) }
                        .disabled(player.song == song && player.isPlaying)
                }
            }
        }
        .navigationTitle("Músicas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { importing = true } label: { Label("Importar", systemImage: "plus") }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button { library.refresh() } label: { Label("Atualizar", systemImage: "arrow.clockwise") }
            }
        }
        .refreshable { library.refresh() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.folder], allowsMultipleSelection: true) { result in
            if case let .success(urls) = result { library.importFolders(urls) }
        }
        .safeAreaInset(edge: .bottom) { SigningBanner() }
    }
}
