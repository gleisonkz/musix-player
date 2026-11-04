public struct MixerState: Equatable, Sendable {
    public struct Channel: Equatable, Sendable {
        public var role: TrackRole
        public var volume: Float = 1
        public var muted = false
        public var soloed = false
    }

    public private(set) var channels: [Channel]
    public var master: Float = 1

    public init(roles: [TrackRole]) {
        channels = roles.map { Channel(role: $0) }
    }

    public mutating func setVolume(_ volume: Float, at index: Int) {
        guard channels.indices.contains(index) else { return }
        channels[index].volume = min(max(volume, 0), 1)
    }

    public mutating func toggleMute(at index: Int) {
        guard channels.indices.contains(index) else { return }
        channels[index].muted.toggle()
    }

    public mutating func toggleSolo(at index: Int) {
        guard channels.indices.contains(index) else { return }
        channels[index].soloed.toggle()
    }

    /// Gain per channel after mute/solo/master. The click is never silenced by a solo
    /// (the band always needs it), and a guide is silenced only when another guide is soloed.
    public func effectiveGains() -> [Float] {
        let anySolo = channels.contains(where: \.soloed)
        return channels.map { ch in
            if ch.muted { return 0 }
            if anySolo && !ch.soloed && !isSoloSafe(ch) { return 0 }
            return ch.volume * master
        }
    }

    private func isSoloSafe(_ ch: Channel) -> Bool {
        switch ch.role {
        case .click: return true
        case .guide: return !channels.contains { $0.soloed && $0.role == .guide }
        case .band: return false
        }
    }
}
