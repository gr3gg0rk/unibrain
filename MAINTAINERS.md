# unibrain MAINTAINERS Guide

## Zero-Telemetry Verification Checklist

Per CLOUD-12: unibrain ships with zero telemetry, zero analytics, zero phone-home.
This checklist must be completed before every release.

### Pre-Release Code Review

- [ ] **Package.swift audit:** Run `grep -iE "mixpanel|segment|amplitude|sentry|firebase|datadog|newrelic|appcenter" Package.swift` — verify zero matches.
- [ ] **Source code audit:** Run `grep -riE "^\s*(import|from)\s+(Mixpanel|Segment|Amplitude|Sentry|FirebaseAnalytics|Datadog|NewRelic|AppCenter|TelemetryDeck|PostHog)" Sources/ UnibrainApp/` — verify zero matches.
- [ ] **URL audit:** All `URL(string:)` calls in Sources/ must be either:
  - `localhost` / `127.0.0.1` (Ollama local LLM)
  - `api.openai.com` (OpenAI — only when user-configured)
  - `api.anthropic.com` (Anthropic — only when user-configured)
  - `api.x.ai` (Grok — only when user-configured)
  - `api.z.ai` (Z.ai — only when user-configured)
- [ ] **No background telemetry tasks:** Verify no `Timer.scheduledTimer` or `DispatchSourceTimer` sends data on a schedule.

### Network Inspection Audit (mitmproxy / Proxyman)

- [ ] Start mitmproxy or Proxyman with HTTPS interception enabled.
- [ ] Launch unibrain on macOS.
- [ ] Trigger each lifecycle event:
  - [ ] App launch (cold start)
  - [ ] Idle for 60 seconds
  - [ ] Start recording
  - [ ] Stop recording
  - [ ] Transcription (local whisper.cpp)
  - [ ] Cloud summarization (if configured)
- [ ] Verify outbound traffic appears ONLY for:
  - `localhost:11434` (Ollama — local)
  - `api.{provider}.com` (only if user configured a cloud provider)
- [ ] Verify NO traffic to analytics, telemetry, or tracking domains.

### Console.app Log Audit

- [ ] Open Console.app on macOS.
- [ ] Filter by subsystem: `com.griak.unibrain` (or `app.unibrain`).
- [ ] Trigger full pipeline: record → stop → transcribe → write.
- [ ] Verify logs contain:
  - [ ] Provider names (e.g., "ollama", "whisper-cpp", "openai")
  - [ ] Error codes and status messages
  - [ ] Pipeline state transitions
- [ ] Verify logs do NOT contain:
  - [ ] API keys (sk-*, xai-*, sk-ant-*)
  - [ ] Transcript content (user's lecture text)
  - [ ] Personal identifiable information (PII)
  - [ ] Vault file paths (beyond the vault root)

### Keychain Verification

- [ ] Open Keychain Access on macOS.
- [ ] Search for `app.unibrain` items.
- [ ] Verify API keys are stored with `kSecAttrAccessibleWhenUnlocked`.
- [ ] Verify keys are encrypted at rest (Keychain default behavior).

### Local-First Offline Test (DISC-05)

- [ ] Disconnect Mac from network (WiFi off, ethernet unplugged).
- [ ] Launch unibrain.
- [ ] Trigger full pipeline: record (5s) → stop → transcribe → classify → write.
- [ ] Verify all steps complete without network:
  - [ ] Recording: AVAudioRecorder writes WAV to disk.
  - [ ] Transcription: whisper.cpp loads model, transcribes, releases model.
  - [ ] Classification: CourseClassifier maps via EventKit (local calendar).
  - [ ] Write: NoteWriter writes Markdown + YAML frontmatter to vault.
- [ ] Verify note appears in vault with correct frontmatter.
- [ ] Reconnect network.
- [ ] Verify no telemetry was sent retroactively after reconnection.

## CI Workflow Notes

The `.github/workflows/ci.yml` workflow runs `swift test` on Linux and `xcodebuild test` on macOS.
No telemetry SDKs are added to the CI environment. No analytics scripts run in CI steps.

## Adding New Dependencies

Before adding any new SPM dependency to `Package.swift`:

1. Verify the dependency does not include analytics/telemetry/transitive telemetry.
2. Check the dependency's own dependencies for telemetry.
3. Document the dependency in PROJECT.md with rationale.
4. If the dependency makes outbound network calls, document the endpoints.

This policy is enforced by convention (code review) per CLOUD-12 decision.
