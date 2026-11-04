import Testing
@testable import MusixCore

@Suite struct MarkerNavigatorTests {
    let nav = MarkerNavigator(markers: [
        Marker(name: "Verso", time: 10),
        Marker(name: "Intro", time: 2),
        Marker(name: "Refrão", time: 26),
    ])

    @Test func sortsMarkersByTime() {
        #expect(nav.markers.map(\.name) == ["Intro", "Verso", "Refrão"])
    }

    @Test func currentSection() {
        #expect(nav.current(at: 0) == nil)
        #expect(nav.current(at: 2)?.name == "Intro")
        #expect(nav.current(at: 9.99)?.name == "Intro")
        #expect(nav.current(at: 10)?.name == "Verso")
        #expect(nav.current(at: 100)?.name == "Refrão")
    }

    @Test func nextMarker() {
        #expect(nav.next(after: 0)?.name == "Intro")
        #expect(nav.next(after: 2)?.name == "Verso")
        #expect(nav.next(after: 26) == nil)
    }

    @Test func previousRestartsCurrentSectionUnlessNearItsStart() {
        // more than threshold into section -> restart this section
        #expect(nav.previous(before: 15)?.name == "Verso")
        // within threshold of section start -> go to the one before
        #expect(nav.previous(before: 10.5)?.name == "Intro")
        // before first marker -> nil (caller seeks to 0)
        #expect(nav.previous(before: 1) == nil)
    }
}
