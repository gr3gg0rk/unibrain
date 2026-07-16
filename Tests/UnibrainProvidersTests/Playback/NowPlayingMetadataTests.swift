import Testing
import Foundation
@testable import UnibrainProviders

@Suite("NowPlayingMetadata")
struct NowPlayingMetadataTests {

    // MARK: - Test 5: Metadata dictionary has correct keys and values (IOS-02)

    @Test("buildInfo produces dictionary with correct title, artist, and playback rate")
    func buildInfoProducesCorrectMetadata() throws {
        let info = NowPlayingMetadata.buildInfo(
            title: "Recording",
            artist: "unibrain",
            elapsed: 300
        )

        // Per IOS-02: title = "Recording"
        #expect(info[NowPlayingMetadata.titleKey] as? String == "Recording")

        // Per IOS-02: artist = "unibrain"
        #expect(info[NowPlayingMetadata.artistKey] as? String == "unibrain")

        // Per IOS-02: playback rate = 1.0
        #expect(info[NowPlayingMetadata.playbackRateKey] as? Double == 1.0)

        // Per IOS-02: elapsed time is set
        #expect(info[NowPlayingMetadata.elapsedKey] as? Double == 300.0)
    }

    // MARK: - Test: Default values match IOS-02 spec

    @Test("buildInfo defaults to 'Recording' and 'unibrain'")
    func buildInfoUsesDefaults() throws {
        let info = NowPlayingMetadata.buildInfo(elapsed: 0)

        #expect(info[NowPlayingMetadata.titleKey] as? String == "Recording")
        #expect(info[NowPlayingMetadata.artistKey] as? String == "unibrain")
    }

    // MARK: - Test: T-05-06 — no course names or transcript fragments leaked

    @Test("buildInfo contains no course or transcript data (T-05-06)")
    func buildInfoContainsNoSensitiveData() throws {
        let info = NowPlayingMetadata.buildInfo(elapsed: 600)

        // Per T-05-06: Lock screen shows ONLY elapsed time, title, artist.
        // No course names, no transcript fragments.
        // The dictionary should have exactly 4 keys.
        #expect(info.count == 4)
        #expect(info[NowPlayingMetadata.titleKey] as? String == "Recording")
        #expect(info[NowPlayingMetadata.artistKey] as? String == "unibrain")
    }
}
