import Foundation

#if canImport(MediaPlayer)
import MediaPlayer

#if os(iOS)

/// Manages the iOS lock-screen Now Playing metadata and remote commands.
///
/// Per IOS-02 and RESEARCH.md Pattern 3: Pushes "Recording — {elapsed}" to
/// the iOS lock screen, Control Center, AirPods double-tap, and Apple Watch
/// remote via `MPNowPlayingInfoCenter`.
///
/// Per IOS-02: `MPRemoteCommandCenter` handles Stop and Pause commands from
/// the lock screen.
///
/// Per T-05-06 (mitigate): Lock screen shows only "Recording" + elapsed time —
/// no course names, no transcript fragments, no audio content.
///
/// Per Pitfall 4: the audio session must be active BEFORE setting nowPlayingInfo.
/// The caller ensures `iOSAudioSessionManager.configure()` is called before
/// `startRecording()`.
final class NowPlayingManager: @unchecked Sendable {

    /// Shared singleton for the app's Now Playing center.
    static let shared = NowPlayingManager()

    /// Whether Now Playing has been activated for the current recording.
    private var isActive = false

    private init() {}

    // MARK: - Recording Lifecycle

    /// Activates Now Playing for a recording session.
    ///
    /// Per RESEARCH.md Pattern 3: Sets `MPNowPlayingInfoCenter.default().nowPlayingInfo`
    /// with title "Recording", artist "unibrain", playbackRate 1.0.
    ///
    /// Per IOS-02: Registers `MPRemoteCommandCenter` handlers for:
    /// - `pauseCommand` → calls injected onPause
    /// - `togglePlayPauseCommand` → treated as Stop (calls injected onStop)
    ///
    /// - Parameters:
    ///   - onPause: Called when the user taps Pause on the lock screen.
    ///   - onStop: Called when the user taps Stop (toggle play/pause) on the lock screen.
    func startRecording(
        onPause: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = "Recording"
        info[MPMediaItemPropertyArtist] = "unibrain"
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        let commandCenter = MPRemoteCommandCenter.shared()

        // Per IOS-02: Pause command from lock screen
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            onPause()
            return .success
        }

        // Per IOS-02: togglePlayPause treated as Stop from lock screen
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            onStop()
            return .success
        }

        isActive = true
    }

    /// Updates the elapsed time on the lock screen.
    ///
    /// Per RESEARCH.md Pattern 3: Called on each timer tick to keep the
    /// lock-screen elapsed time display in sync.
    ///
    /// - Parameter seconds: The current elapsed recording time in seconds.
    func updateElapsed(_ seconds: TimeInterval) {
        guard isActive else { return }

        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = seconds
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Clears Now Playing state and removes remote command handlers.
    ///
    /// Call this when recording stops to return the lock screen to its
    /// default state.
    func stopRecording() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false

        isActive = false
    }
}

#endif // os(iOS)

#endif // canImport(MediaPlayer)
