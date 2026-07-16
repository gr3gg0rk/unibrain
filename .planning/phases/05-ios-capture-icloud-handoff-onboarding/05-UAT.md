---
status: testing
phase: 05-ios-capture-icloud-handoff-onboarding
source: [05-VERIFICATION.md]
started: 2026-07-16T03:45:00Z
updated: 2026-07-16T03:45:00Z
---

# Phase 5: iOS Capture + iCloud Handoff + Onboarding — UAT

## Current Test

number: 1
name: iOS Background Recording Survival (CAPT-03, DISC-04)
expected: |
  Open unibrain on iPhone Record tab, tap Record, lock screen, wait 30 minutes, unlock.
  Timer shows correct elapsed time. Lock screen displayed "Recording" with Stop/Pause.
  Tap Stop — file saved to _inbox/.
awaiting: Apple Developer Program activation + physical iPhone

## Tests

### 1. iOS Background Recording Survival (CAPT-03, DISC-04)
expected: Record on iPhone → lock screen → 30 min → unlock → recording continued, file saved
result: [pending]
blocked_by: Apple Developer Program membership ($99/yr)

### 2. iOS Interruption Auto-Pause/Resume (IOS-03)
expected: Start recording → receive incoming call → recording auto-pauses → decline call → recording auto-resumes → final .m4a is contiguous
result: [pending]
blocked_by: Apple Developer Program + physical iPhone + secondary phone for incoming call

### 3. iCloud Drive End-to-End Handoff
expected: Record 1-min clip on iPhone → stop → file appears in macOS _inbox/ via iCloud Drive → InboxWatcher detects → pipeline processes → note appears in course folder
result: [pending]
blocked_by: Apple Developer Program + iCloud Drive on both devices + completed onboarding on macOS first

### 4. InboxWatcher Live NSMetadataQuery Path
expected: Place a .m4a file in _inbox/ while app is running → NSMetadataQuery fires → handleQueryUpdate enqueues → pipeline processes
result: [pending]
blocked_by: macOS device (verify the let→var fix compiles and runs on macOS — Linux SPM cannot catch #if os(macOS) issues)

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 4

## Gaps

None — all code-level gaps closed (InboxWatcher let→var fix applied commit 7c396b4).

All remaining items are device-deferred per the project's accepted Apple Developer Program blocker pattern (same as Phase 03 Task 4, Phase 04 04-05 Task 3).
