import Foundation

#if canImport(AVFoundation)
import AVFoundation
import AVFAudio

#if os(iOS)

/// Manages the iOS AVAudioSession for background-capable lecture recording.
///
/// Per IOS-03 and RESEARCH.md Pattern 1: Configures `.playAndRecord` category
/// with `.defaultToSpeaker` and `.allowBluetoothA2DP` options (CONTEXT discretion
/// for AirPods support).
///
/// Per RESEARCH.md Pattern 2: Observes `AVAudioSession.interruptionNotification`
/// to auto-pause on `.began` (phone call, Siri) and auto-resume on `.ended`
/// when `.shouldResume` is set.
///
/// Per Pitfall 1: `configure()` MUST be called BEFORE `AudioRecorder.start()`.
/// Without the session active, iOS kills the app within ~30 seconds of
/// backgrounding.
///
/// Per DISC-04: the combination of `UIBackgroundModes: ["audio"]` (from Plan 01
/// Info.plist) + active AVAudioSession is what keeps iOS from suspending the app.
/// The audio session being active IS the background survival lease.
///
/// Per T-05-05 (mitigate): interruption observation prevents recording loss;
/// `mediaServicesWereResetNotification` triggers full re-configure.
final class iOSAudioSessionManager: @unchecked Sendable {

    /// Shared singleton — iOS has one audio session per app.
    static let shared = iOSAudioSessionManager()

    /// Closure called when an interruption begins (recording should pause).
    private var onPause: (() -> Void)?

    /// Closure called when an interruption ends and shouldResume is set.
    private var onResume: (() -> Void)?

    /// Whether the session has been configured.
    private var isConfigured = false

    /// Notification observers for cleanup.
    private var observers: [NSObjectProtocol] = []

    private init() {}

    // MARK: - Configuration

    /// Configures the AVAudioSession for background lecture recording.
    ///
    /// Per RESEARCH.md Pattern 1: Sets category `.playAndRecord` with
    /// `.defaultToSpeaker` and `.allowBluetoothA2DP` options, mode `.default`.
    /// Then calls `setActive(true)`.
    ///
    /// Per Pitfall 1: MUST be called before `AudioRecorder.start()`.
    ///
    /// - Parameters:
    ///   - onPause: Called when an audio interruption begins.
    ///   - onResume: Called when an audio interruption ends with shouldResume.
    /// - Throws: An error if the session cannot be configured.
    func configure(
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void
    ) throws {
        self.onPause = onPause
        self.onResume = onResume

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetoothA2DP]
        )
        try session.setActive(true)

        if !isConfigured {
            registerObservers()
            isConfigured = true
        }
    }

    /// Deactivates the audio session (call after recording stops).
    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
    }

    // MARK: - Interruption Handling (RESEARCH.md Pattern 2, IOS-03)

    /// Registers notification observers for audio session interruptions
    /// and media services reset.
    ///
    /// Per T-05-05: auto-pause prevents recording loss on interruption.
    private func registerObservers() {
        let center = NotificationCenter.default

        // Per RESEARCH.md Pattern 2: interruption notification
        let interruptionObserver = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }
        observers.append(interruptionObserver)

        // Per T-05-05: media services reset — full re-configure required
        let resetObserver = center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleMediaServicesReset()
        }
        observers.append(resetObserver)
    }

    /// Handles an audio session interruption notification.
    ///
    /// Per IOS-03: on `.began`, calls `onPause` to pause recording.
    /// On `.ended` with `.shouldResume`, calls `onResume` to auto-resume.
    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Another app claimed the audio session — pause recording.
            onPause?()

        case .ended:
            // Per IOS-03: auto-resume if the system says we should.
            let options = AVAudioSession.InterruptionOptions(
                rawValue: info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            )
            if options.contains(.shouldResume) {
                // Re-activate the session before resuming.
                try? AVAudioSession.sharedInstance().setActive(true)
                onResume?()
            }

        @unknown default:
            break
        }
    }

    /// Handles media services reset by re-configuring the audio session.
    ///
    /// Per T-05-05: a rare system-level event that requires full re-configure.
    private func handleMediaServicesReset() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothA2DP]
            )
            try session.setActive(true)
        } catch {
            // Re-configuration failed — the onPause/onResume closures
            // remain registered; next configure() call will retry.
        }
    }

    /// Removes all notification observers (call on deinit or teardown).
    func teardown() {
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
        isConfigured = false
        onPause = nil
        onResume = nil
    }
}

#endif // os(iOS)

#endif // canImport(AVFoundation)
