---
status: testing
phase: 03-macos-capture-transcribe
source: [03-01-SUMMARY.md, 03-02-SUMMARY.md, 03-03-SUMMARY.md, 03-04-SUMMARY.md]
started: 2026-07-16T16:18:50Z
updated: 2026-07-16T16:20:00Z
mvp_mode: true
goal: "A user can record a lecture on a MacBook NEO via the menu-bar record button, stop it, and within minutes see a transcript written as a Markdown note into a hardcoded vault folder."
note: "MVP-mode UAT. Goal is functionally a user-flow story but does not match the strict 'As a... I want... so that...' regex — run /gsd-mvp-phase 03 later to canonicalize. All tests require macOS hardware (WSL2 dev loop has no Swift toolchain)."
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

number: 2
name: Idle Popover State
expected: |
  Click the brain icon. Popover opens (~280pt wide per P-08). Shows "Ready to record" with model status (download progress or ready) and a Record button. Popover matches UI-SPEC idle mockup.
awaiting: user response

## Tests

### 1. Cold Start Smoke Test — App launch & menu-bar icon
expected: Build and launch unibrain on macOS 26+. Brain icon (gray) appears in menu bar (idle, P-D3). No crash, no beachball. Background model download starts automatically (P-17).
result: pass

### 2. Idle Popover State
expected: Click the brain icon. Popover opens (~280pt wide per P-08). Shows "Ready to record" with model status (download progress or ready) and a Record button. Popover matches UI-SPEC idle mockup.
result: [pending]

### 3. Start Recording — timer, waveform, mic meter
expected: Click Record. Menu-bar icon turns brain.fill red (P-D3). Popover shows: live MM:SS timer advancing in real time, animated waveform Canvas, 3-segment mic-level meter (green/yellow/red based on ambient noise). State = recording.
result: [pending]

### 4. Pause & Resume — contiguous file
expected: Click Pause mid-recording. Icon turns brain.fill yellow. Timer freezes, waveform dims. State = paused. Click Resume — icon returns to red, timer continues from frozen point. After stop, the resulting .m4a is ONE contiguous file (not two) and pause timestamps are preserved in frontmatter.
result: [pending]

### 5. Stop — triggers transcription via Task.detached
expected: Click Stop. Within ~200ms popover transitions to "Transcribing…" state with spinner + ETA. Icon turns brain.fill accent color. Menu bar remains interactive (no beachball) — pipeline runs via Task.detached(priority:.userInitiated) per TRAN-03.
result: [pending]

### 6. Transcription completion notification
expected: When transcription finishes, a macOS user notification fires ("Lecture transcribed" or similar per P-11). Clicking it (if actionable) opens or focuses the vault file. Icon returns to gray brain (idle).
result: [pending]

### 7. Vault file written — Markdown + YAML frontmatter
expected: A file exists at `~/Documents/Unibrain/lectures/YYYY-MM-DD-Lecture.md` within ~5 min of stop (for a 1-min recording on small.en). Contents: YAML frontmatter (title, date, duration, source, etc., snake_case keys) followed by title heading and transcript body paragraphs. No `.icloud` placeholder.
result: [pending]

### 8. State-driven icon transitions across all states (P-D3, D4)
expected: Across the full session, icon transitioned: brain (idle) → brain.fill red (recording) → brain.fill yellow (paused) → brain.fill red (resumed) → brain.fill accent (transcribing) → brain (idle post-complete). No stuck or missing state.
result: [pending]

### 9. UI Responsiveness & RAM discipline (TRAN-03, D5)
expected: Throughout the session — especially during transcription — menu bar stays interactive, no beachball, popover remains responsive. Xcode Time Profiler shows pipeline work off MainActor. Activity Monitor shows transient RAM spike during transcription (model loaded at inference time only), released after completion.
result: [pending]

## Summary

total: 9
passed: 1
issues: 0
pending: 8
skipped: 0
blocked: 0

## Gaps

[none yet]
