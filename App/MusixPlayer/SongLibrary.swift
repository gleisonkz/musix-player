import Foundation
import MusixAudio
import MusixCore
import Observation

struct SongEntry: Identifiable, Hashable {
    let folder: URL
    let manifest: SongManifest
    var id: URL { folder }
    var title: String { manifest.title }

    static func == (a: SongEntry, b: SongEntry) -> Bool { a.folder == b.folder }
    func hash(into hasher: inout Hasher) { hasher.combine(folder) }
}

/// Songs live as folders in the app's Documents directory (visible in the Files app as "Musix").
@Observable
final class SongLibrary {
    private(set) var songs: [SongEntry] = []
    var lastError: String?

    let root: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    init() { refresh() }

    func refresh() {
        let fm = FileManager.default
        let folders = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey],
                                                   options: [.skipsHiddenFiles])) ?? []
        songs = folders
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .filter { $0.lastPathComponent != "Inbox" }
            .compactMap { folder in
                guard let manifest = try? PlaybackEngine.manifest(forFolder: folder), !manifest.tracks.isEmpty
                else { return nil }
                return SongEntry(folder: folder, manifest: manifest)
            }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func installDemoIfNeeded() {
        let key = "demoInstalled"
        guard !UserDefaults.standard.bool(forKey: key),
              let demo = Bundle.main.url(forResource: "DemoMusix", withExtension: nil)
        else { return }
        let destination = root.appendingPathComponent("Demo Musix")
        if !FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.copyItem(at: demo, to: destination)
        }
        UserDefaults.standard.set(true, forKey: key)
        refresh()
    }

    /// Copies song folders picked in the Files app (iCloud, Google Drive, USB...) into the library.
    func importFolders(_ urls: [URL]) {
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            var coordinatorError: NSError?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatorError) { source in
                let destination = uniqueDestination(for: source.lastPathComponent)
                do {
                    try FileManager.default.copyItem(at: source, to: destination)
                } catch {
                    lastError = "Falha ao importar \(source.lastPathComponent): \(error.localizedDescription)"
                }
            }
            if let coordinatorError { lastError = coordinatorError.localizedDescription }
        }
        refresh()
    }

    func delete(_ song: SongEntry) {
        try? FileManager.default.removeItem(at: song.folder)
        refresh()
    }

    private func uniqueDestination(for name: String) -> URL {
        var candidate = root.appendingPathComponent(name)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = root.appendingPathComponent("\(name) \(n)")
            n += 1
        }
        return candidate
    }
}
