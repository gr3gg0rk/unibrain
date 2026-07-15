import Foundation

#if canImport(AVFoundation)
import AVFoundation
import AVFAudio

/// AVAudioRecorder wrapper producing 16kHz mono AAC .m4a files with
/// pause/resume support and live mic-level metering.
///
/// Per CAPT-01: start/stop provides one-tap recording capability.
/// Per CAPT-02: pause/resume maintains a single contiguous .m4a file.
/// Per CAPT-05: currentLevel drives the mic-level meter in the UI.
/// Per CAPT-06: output is .m4a (AAC) at 16kHz mono.
///
/// Per P-D2: The caller (RecordingSession) handles temp-then-move by
/// passing a temp URL, then calling FileManager.moveItem after stop.
/// AudioRecorder itself records to whatever URL it is given.
///
/// Per Pitfall 3: isMeteringEnabled is set to true BEFORE calling
/// record() — otherwise averagePower returns -160 (silence).
public final class AudioRecorder: @unchecked Sendable {

    /// The underlying AVAudioRecorder instance, or nil when not recording.
    private var recorder: AVAudioRecorder?

    /// Whether recording is currently active.
    public var isRecording: Bool {
        recorder?.isRecording ?? false
    }

    /// Whether recording is currently paused.
    public var isPaused: Bool {
        guard let recorder else { return false }
        return !recorder.isRecording && recorder.currentTime > 0
    }

    /// Whether metering is enabled on the recorder.
    public var isMeteringEnabled: Bool {
        recorder?.isMeteringEnabled ?? false
    }

    /// Current mic level in dB (-160.0 to 0.0).
    ///
    /// Per CAPT-05: returns a meaningful dB value when recording is active.
    /// Returns -160.0 (silence floor) when not recording.
    public var currentLevel: Float {
        guard let recorder else { return -160.0 }
        recorder.updateMeters()
        return recorder.averagePower(forChannel: 0)
    }

    /// Audio settings dictionary for 16kHz mono AAC per CLAUDE.md.
    ///
    /// Per CAPT-06 and CLAUDE.md audio config:
    /// - Format: MPEG4AAC (M4A container)
    /// - Sample rate: 16000 Hz (whisper.cpp native rate)
    /// - Channels: 1 (mono — lectures are single-source)
    /// - Quality: high
    public nonisolated(unsafe) static let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 16000.0,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]

    /// Creates a new AudioRecorder with no active recording.
    public init() {}

    /// Starts recording to the given URL.
    ///
    /// Per CAPT-01: produces a .m4a file at the given URL.
    ///
    /// Per Pitfall 3: isMeteringEnabled is set to true BEFORE calling
    /// record() — otherwise averagePower returns -160 (silence).
    ///
    /// - Parameter url: The file URL to record to.
    /// - Throws: An error if the audio session cannot be configured
    ///   or the recorder cannot be created.
    public func start(to url: URL) throws {
        // Configure audio session
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)

        // Create recorder with URL + settings
        let recorder = try AVAudioRecorder(url: url, settings: Self.audioSettings)

        // Per Pitfall 3: enable metering BEFORE calling record()
        recorder.isMeteringEnabled = true

        // Start recording
        recorder.record()

        self.recorder = recorder
    }

    /// Pauses recording without finalizing the file.
    ///
    /// Per CAPT-02: pause() pauses recording; resume() continues
    /// without creating a new file — maintaining a single contiguous file.
    public func pause() {
        recorder?.pause()
    }

    /// Resumes recording after a pause.
    ///
    /// Per CAPT-02: continues writing to the same file.
    /// AVAudioRecorder.record() resumes from where it left off.
    public func resume() {
        recorder?.record()
    }

    /// Stops recording and finalizes the .m4a file.
    ///
    /// Per CAPT-01: finalizes the recording file.
    /// After stop(), the recorder is released (set to nil).
    public func stop() {
        recorder?.stop()
        recorder = nil
    }
}

#endif // canImport(AVFoundation)
