import Foundation
import Testing
@testable import MusixCore

@Suite struct SongManifestTests {
    @Test func decodesSongJSON() throws {
        let json = """
        {
          "title": "Demo", "artist": "Band", "bpm": 120, "timeSignature": "4/4", "key": "C",
          "tracks": [
            {"name": "Click", "file": "click.m4a", "role": "click"},
            {"name": "Guia", "file": "guide.m4a", "role": "guide"},
            {"name": "Baixo", "file": "bass.m4a", "role": "band"}
          ],
          "markers": [{"name": "Intro", "time": 2.0}, {"name": "Verso", "time": 10.0}]
        }
        """
        let song = try SongManifest.decode(Data(json.utf8))
        #expect(song.title == "Demo")
        #expect(song.bpm == 120)
        #expect(song.tracks.map(\.role) == [.click, .guide, .band])
        #expect(song.tracks[2].file == "bass.m4a")
        #expect(song.markers == [Marker(name: "Intro", time: 2), Marker(name: "Verso", time: 10)])
    }

    @Test func optionalFieldsMayBeMissing() throws {
        let json = #"{"title": "X", "tracks": [{"name": "A", "file": "a.wav"}]}"#
        let song = try SongManifest.decode(Data(json.utf8))
        #expect(song.bpm == nil)
        #expect(song.markers.isEmpty)
        #expect(song.tracks[0].role == .band)
    }

    @Test func infersManifestFromFolderFileNames() {
        let song = SongManifest.infer(
            folderName: "Grande É o Senhor",
            fileNames: ["Baixo.wav", "Click.wav", "GUIA.wav", "notes.txt", "Bateria.WAV", ".DS_Store", "Pad.m4a"]
        )
        #expect(song.title == "Grande É o Senhor")
        // click and guide first, then band tracks alphabetically; non-audio ignored
        #expect(song.tracks.map(\.file) == ["Click.wav", "GUIA.wav", "Baixo.wav", "Bateria.WAV", "Pad.m4a"])
        #expect(song.tracks.map(\.role) == [.click, .guide, .band, .band, .band])
        #expect(song.tracks.map(\.name) == ["Click", "GUIA", "Baixo", "Bateria", "Pad"])
    }

    @Test(arguments: [
        ("Click.wav", TrackRole.click), ("clique.wav", .click), ("Metronomo.wav", .click),
        ("Metrônomo.mp3", .click), ("CLK.wav", .click),
        ("Guide.wav", .guide), ("Guia.wav", .guide), ("Cues.wav", .guide), ("Voz Guia.wav", .guide),
        ("Guitarra.wav", .band), ("Vocals.wav", .band), ("Backing.wav", .band),
    ])
    func infersRoleFromName(file: String, role: TrackRole) {
        #expect(TrackRole.infer(fromFileName: file) == role)
    }
}
