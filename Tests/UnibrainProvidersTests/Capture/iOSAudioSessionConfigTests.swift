import Testing
import Foundation
@testable import UnibrainProviders

@Suite("iOSAudioSessionConfig")
struct iOSAudioSessionConfigTests {

    // MARK: - Test 4: Category and options match IOS-03 / RESEARCH Pattern 1

    @Test("lectureRecording config uses playAndRecord with correct options")
    func lectureRecordingConfigIsCorrect() throws {
        let config = iOSAudioSessionConfig.lectureRecording

        // Per IOS-03 and RESEARCH.md Pattern 1: category .playAndRecord
        #expect(config.categoryRawValue == "playAndRecord")

        // Per RESEARCH.md Pattern 1: mode .default
        #expect(config.modeRawValue == "default")

        // Per IOS-03 CONTEXT discretion: .defaultToSpeaker for AirPods support
        #expect(config.containsOption("defaultToSpeaker"))

        // Per IOS-03 CONTEXT discretion: .allowBluetoothA2DP for AirPods support
        #expect(config.containsOption("allowBluetoothA2DP"))
    }

    // MARK: - Test: Config is Sendable and Equatable

    @Test("iOSAudioSessionConfig is Equatable")
    func configIsEquatable() throws {
        let config1 = iOSAudioSessionConfig.lectureRecording
        let config2 = iOSAudioSessionConfig.lectureRecording
        #expect(config1 == config2)
    }
}
