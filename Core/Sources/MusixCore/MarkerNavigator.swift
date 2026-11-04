public struct MarkerNavigator: Sendable {
    public let markers: [Marker]
    /// Pressing "previous" this close to a section start jumps to the section before it.
    public var restartThreshold: Double = 1.0

    public init(markers: [Marker]) {
        self.markers = markers.sorted { $0.time < $1.time }
    }

    public func current(at time: Double) -> Marker? {
        markers.last { $0.time <= time }
    }

    public func next(after time: Double) -> Marker? {
        markers.first { $0.time > time }
    }

    public func previous(before time: Double) -> Marker? {
        guard let index = markers.lastIndex(where: { $0.time <= time }) else { return nil }
        if time - markers[index].time >= restartThreshold { return markers[index] }
        return index > 0 ? markers[index - 1] : nil
    }
}
