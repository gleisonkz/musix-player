public enum OutputMode: String, Codable, CaseIterable, Sendable {
    /// Headphone jack split: click + guide on the left channel, band (mono) on the right.
    case split
    /// Regular stereo mix, everything centered.
    case stereo
}

public enum OutputSide: String, Codable, Sendable {
    case left, right
}

public struct OutputRouting: Equatable, Sendable {
    public var mode: OutputMode

    public init(mode: OutputMode) {
        self.mode = mode
    }

    /// In split mode each stem is summed to mono so a hard pan puts all of it on one side.
    public var downmixToMono: Bool { mode == .split }

    /// Pan in -1 (left) ... 1 (right).
    public func pan(for role: TrackRole, override: OutputSide? = nil) -> Float {
        guard mode == .split else { return 0 }
        let side = override ?? (role == .band ? .right : .left)
        return side == .left ? -1 : 1
    }
}
