import Testing
@testable import MusixCore

@Suite struct OutputRoutingTests {
    @Test func splitModeSendsClickAndGuideLeftAndBandRight() {
        let routing = OutputRouting(mode: .split)
        #expect(routing.pan(for: .click) == -1)
        #expect(routing.pan(for: .guide) == -1)
        #expect(routing.pan(for: .band) == 1)
    }

    @Test func splitModeDownmixesEveryTrackToMono() {
        #expect(OutputRouting(mode: .split).downmixToMono)
        #expect(!OutputRouting(mode: .stereo).downmixToMono)
    }

    @Test func stereoModeCentersEverything() {
        let routing = OutputRouting(mode: .stereo)
        for role in TrackRole.allCases {
            #expect(routing.pan(for: role) == 0)
        }
    }

    @Test func sideOverrideWinsInSplitMode() {
        let routing = OutputRouting(mode: .split)
        #expect(routing.pan(for: .band, override: .left) == -1)
        #expect(routing.pan(for: .click, override: .right) == 1)
    }

    @Test func sideOverrideIgnoredInStereoMode() {
        #expect(OutputRouting(mode: .stereo).pan(for: .band, override: .left) == 0)
    }
}
