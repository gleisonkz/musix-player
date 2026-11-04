import Testing
@testable import MusixCore

@Suite struct MixerStateTests {
    let roles: [TrackRole] = [.click, .guide, .band, .band]

    @Test func defaultsToUnityGain() {
        let mixer = MixerState(roles: roles)
        #expect(mixer.effectiveGains() == [1, 1, 1, 1])
    }

    @Test func volumeIsClampedToZeroOne() {
        var mixer = MixerState(roles: roles)
        mixer.setVolume(1.5, at: 0)
        mixer.setVolume(-0.2, at: 1)
        mixer.setVolume(0.5, at: 2)
        #expect(mixer.effectiveGains() == [1, 0, 0.5, 1])
    }

    @Test func muteSilencesTrack() {
        var mixer = MixerState(roles: roles)
        mixer.setVolume(0.8, at: 2)
        mixer.toggleMute(at: 2)
        #expect(mixer.effectiveGains() == [1, 1, 0, 1])
        mixer.toggleMute(at: 2)
        #expect(mixer.effectiveGains() == [1, 1, 0.8, 1])
    }

    @Test func soloOnBandTrackKeepsClickAndGuide() {
        var mixer = MixerState(roles: roles)
        mixer.toggleSolo(at: 3)
        #expect(mixer.effectiveGains() == [1, 1, 0, 1])
    }

    @Test func soloOnGuideSilencesOtherTracksExceptClick() {
        var mixer = MixerState(roles: roles)
        mixer.toggleSolo(at: 1)
        #expect(mixer.effectiveGains() == [1, 1, 0, 0])
    }

    @Test func muteBeatsSolo() {
        var mixer = MixerState(roles: roles)
        mixer.toggleSolo(at: 2)
        mixer.toggleMute(at: 2)
        #expect(mixer.effectiveGains() == [1, 1, 0, 0])
    }

    @Test func outOfRangeIndexIsIgnored() {
        var mixer = MixerState(roles: roles)
        mixer.setVolume(0, at: 9)
        mixer.toggleMute(at: -1)
        mixer.toggleSolo(at: 4)
        #expect(mixer.effectiveGains() == [1, 1, 1, 1])
    }

    @Test func masterVolumeScalesAll() {
        var mixer = MixerState(roles: roles)
        mixer.setVolume(0.5, at: 2)
        mixer.master = 0.5
        #expect(mixer.effectiveGains() == [0.5, 0.5, 0.25, 0.5])
    }
}
