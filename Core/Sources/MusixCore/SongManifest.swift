import Foundation

public enum TrackRole: String, Codable, CaseIterable, Sendable {
    case click, guide, band

    private static let clickKeywords = ["click", "clique", "clik", "clk", "metronomo", "metronome"]
    private static let guideKeywords = ["guide", "guia", "cue", "cues"]

    /// Guesses the role of a stem from its file name ("Click.wav" -> .click, "Guia.wav" -> .guide).
    public static func infer(fromFileName fileName: String) -> TrackRole {
        let base = (fileName as NSString).deletingPathExtension
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let words = base.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        if words.contains(where: clickKeywords.contains) { return .click }
        if words.contains(where: guideKeywords.contains) { return .guide }
        return .band
    }
}

public struct Marker: Codable, Equatable, Sendable {
    public var name: String
    public var time: Double

    public init(name: String, time: Double) {
        self.name = name
        self.time = time
    }
}

public struct TrackInfo: Codable, Equatable, Sendable {
    public var name: String
    public var file: String
    public var role: TrackRole

    public init(name: String, file: String, role: TrackRole) {
        self.name = name
        self.file = file
        self.role = role
    }

    private enum CodingKeys: String, CodingKey { case name, file, role }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        file = try c.decode(String.self, forKey: .file)
        role = try c.decodeIfPresent(TrackRole.self, forKey: .role) ?? .band
    }
}

public struct SongManifest: Codable, Equatable, Sendable {
    public var title: String
    public var artist: String?
    public var bpm: Double?
    public var timeSignature: String?
    public var key: String?
    public var tracks: [TrackInfo]
    public var markers: [Marker]

    public static let fileName = "song.json"
    public static let audioExtensions: Set<String> = ["wav", "aif", "aiff", "m4a", "mp3", "caf", "flac"]

    public init(title: String, artist: String? = nil, bpm: Double? = nil, timeSignature: String? = nil,
                key: String? = nil, tracks: [TrackInfo], markers: [Marker] = []) {
        self.title = title
        self.artist = artist
        self.bpm = bpm
        self.timeSignature = timeSignature
        self.key = key
        self.tracks = tracks
        self.markers = markers
    }

    private enum CodingKeys: String, CodingKey { case title, artist, bpm, timeSignature, key, tracks, markers }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        artist = try c.decodeIfPresent(String.self, forKey: .artist)
        bpm = try c.decodeIfPresent(Double.self, forKey: .bpm)
        timeSignature = try c.decodeIfPresent(String.self, forKey: .timeSignature)
        key = try c.decodeIfPresent(String.self, forKey: .key)
        tracks = try c.decode([TrackInfo].self, forKey: .tracks)
        markers = try c.decodeIfPresent([Marker].self, forKey: .markers) ?? []
    }

    public static func decode(_ data: Data) throws -> SongManifest {
        try JSONDecoder().decode(SongManifest.self, from: data)
    }

    /// Builds a manifest for a folder of stems that has no song.json.
    /// Click and guide tracks come first, then band tracks sorted by name.
    public static func infer(folderName: String, fileNames: [String]) -> SongManifest {
        let order: [TrackRole: Int] = [.click: 0, .guide: 1, .band: 2]
        let tracks = fileNames
            .filter { !$0.hasPrefix(".") && audioExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
            .map { TrackInfo(name: ($0 as NSString).deletingPathExtension, file: $0, role: .infer(fromFileName: $0)) }
            .sorted {
                let (a, b) = (order[$0.role]!, order[$1.role]!)
                return a != b ? a < b : $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        return SongManifest(title: folderName, tracks: tracks)
    }
}
