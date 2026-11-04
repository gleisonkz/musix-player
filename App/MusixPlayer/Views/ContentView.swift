import SwiftUI

struct ContentView: View {
    @Environment(SongLibrary.self) private var library
    @Environment(PlayerModel.self) private var player
    @State private var selection: SongEntry?

    var body: some View {
        NavigationSplitView {
            LibraryView(selection: $selection)
        } detail: {
            if player.song != nil {
                PlayerView()
            } else {
                ContentUnavailableView("Escolha uma música", systemImage: "music.note.list",
                                       description: Text("Importe pastas de multitracks pelo botão + ou pelo app Arquivos (pasta Musix)."))
            }
        }
        .onChange(of: selection) { _, song in
            if let song { player.load(song) }
        }
        .alert("Erro", isPresented: .init(get: { player.errorMessage != nil },
                                          set: { if !$0 { player.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(player.errorMessage ?? "")
        }
    }
}
