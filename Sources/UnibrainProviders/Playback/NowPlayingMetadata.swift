import Foundation

/// Cross-platform builder for iOS Now Playing metadata dictionaries.
///
/// Per IOS-02 and RESEARCH.md Pattern 3: The lock screen displays
/// "Recording" as the title, "unibrain" as the artist, with the current
/// elapsed time and a playback rate of 1.0.
///
/// Per T-05-06 (mitigate): Lock screen shows ONLY elapsed time — no course
/// names, no transcript fragments, no audio content.
///
/// This pure function uses string literals for MP* keys (instead of importing
/// MediaPlayer) so it compiles on Linux and is testable without an iOS Simulator.
/// The actual `MPNowPlayingInfoCenter` application happens in `NowPlayingManager`
/// behind `#if os(iOS)`.
public enum NowPlayingMetadata: Sendable {

    /// String key for `MPMediaItemPropertyTitle` (avoids MediaPlayer import).
    public static let titleKey = "MPMediaItemPropertyTitle"

    /// String key for `MPMediaItemPropertyArtist`.
    public static let artistKey = "MPMediaItemPropertyArtist"

    /// String key for `MPNowPlayingInfoPropertyElapsedPlaybackTime`.
    public static let elapsedKey = "MPNowPlayingInfoPropertyElapsedPlaybackTime"

    /// String key for `MPNowPlayingInfoPropertyPlaybackRate`.
    public static let playbackRateKey = "MPNowPlayingInfoPropertyPlaybackRate"

    /// Builds the Now Playing info dictionary for a recording session.
    ///
    /// Per IOS-02: title "Recording", artist "unibrain",
    /// elapsed time, playback rate 1.0.
    ///
    /// - Parameters:
    ///   - title: The media item title (default: "Recording").
    ///   - artist: The media item artist (default: "unibrain").
    ///   - elapsed: The elapsed playback time in seconds.
    /// - Returns: A dictionary suitable for `MPNowPlayingInfoCenter.nowPlayingInfo`.
    public static func buildInfo(
        title: String = "Recording",
        artist: String = "unibrain",
        elapsed: TimeInterval
    ) -> [String: Any] {
        return [
            titleKey: title,
            artistKey: artist,
            elapsedKey: elapsed,
            playbackRateKey: 1.0,
        ]
    }
}
