import Foundation

/// Cross-platform value type holding the iOS audio session configuration.
///
/// Per RESEARCH.md Pattern 1 and IOS-03: The session uses category
/// `.playAndRecord` with options `.defaultToSpeaker` and `.allowBluetoothA2DP`.
///
/// This struct extracts the CONFIG VALUES into a pure Swift value type
/// that compiles on Linux (where `AVAudioSession` is unavailable). The
/// actual AVAudioSession application happens only inside the
/// `iOSAudioSessionManager.configure()` method behind `#if os(iOS)`.
///
/// Per T-05-05: the config is validated by tests to verify the correct
/// category and options are used per IOS-03.
public struct iOSAudioSessionConfig: Sendable, Equatable {

    /// The raw category string value.
    /// Maps to `AVAudioSession.Category.playAndRecord` on iOS.
    public let categoryRawValue: String

    /// The raw mode string value.
    /// Maps to `AVAudioSession.Mode.default` on iOS.
    public let modeRawValue: String

    /// The raw option values.
    /// Maps to `[.defaultToSpeaker, .allowBluetoothA2DP]` on iOS.
    public let optionRawValues: [String]

    /// The canonical config for iOS lecture recording.
    /// Per RESEARCH.md Pattern 1 and IOS-03.
    public static let lectureRecording = iOSAudioSessionConfig(
        categoryRawValue: "playAndRecord",
        modeRawValue: "default",
        optionRawValues: ["defaultToSpeaker", "allowBluetoothA2DP"]
    )

    /// Whether the config includes a given option (by raw string).
    public func containsOption(_ option: String) -> Bool {
        optionRawValues.contains(option)
    }
}
