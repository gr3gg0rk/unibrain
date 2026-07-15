---
phase: 4
slug: course-classification-smart-routing
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-15
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | swift-testing (`@Test`, `#expect`) — Phase 1/2 standard |
| **Config file** | `Package.swift` (SPM) |
| **Quick run command** | `swift test --filter UnibrainCoreTests` |
| **Full suite command** | `swift test` (Linux) + macOS CI for `UnibrainProvidersTests` |
| **Estimated runtime** | ~15-30 seconds (Linux) ; macOS job ~5-8 min via CI |

---

## Sampling Rate

- **After every task commit:** Run `swift test --filter UnibrainCoreTests`
- **After every plan wave:** Run full `swift test` locally + push for macOS CI
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds (Linux quick path)

---

## Per-Task Verification Map

To be filled by planner per task. Each task MUST have `<verify>` block with one of:
- `swift test --filter <TestName>` (unit/integration)
- `swift build` (compile-only check)
- `grep -q "<pattern>" <file>` (source assertion)
- macOS CI run (device-only tests)

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|--------|
| 04-01-* | 01 | 1 | CLAS-02 | courses.json atomic write | unit | `swift test --filter CoursesMappingStoreTests` | ⬜ pending |
| 04-02-* | 02 | 1 | CLAS-01, CLAS-06 | EventKit predicate + term filter | unit (mocked) | `swift test --filter EventKitCalendarAdapterTests` | ⬜ pending |
| 04-03-* | 03 | 1 | CLAS-04 | Manual picker MVVM | unit | `swift test --filter CoursePickerViewModelTests` | ⬜ pending |
| 04-04-* | 04 | 2 | ONBD-02, ONBD-03 | Permission degradation UX | unit + manual | `swift test --filter PermissionStateTests` | ⬜ pending |
| 04-05-* | 05 | 2 | MP-04 | `.awaitingUserChoice` state | unit | `swift test --filter PipelineOrchestratorPauseTests` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Tests/UnibrainCoreTests/CoursesMappingStoreTests.swift` — stubs for CLAS-02 mapping store
- [ ] `Tests/UnibrainProvidersTests/EventKitCalendarAdapterTests.swift` — stubs for EventKit adapter (macOS-only)
- [ ] `Tests/UnibrainCoreTests/CoursePickerViewModelTests.swift` — stubs for picker logic

*Existing Phase 1-3 test infrastructure covers framework setup.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| First-time permission sheet appears on denied calendar | ONBD-02 | Requires real macOS device + System Settings | 1. Fresh install 2. Deny calendar 3. Start recording 4. Verify sheet appears with deep-link |
| `.sheet` UI anchoring on MenuBarExtra popover | MP-01 | SwiftUI visual check | Record → trigger `.multiple` classification → visually confirm picker appears over popover |
| Auto-created folder appears in Finder/Obsidian | CLAS-03 | File system visual check | Record during unmapped calendar event → confirm `{vault}/{term}/{sanitized-title}/` exists |

---

## Validation Sign-Off

- [ ] All tasks have `<verify>` block with automated command or manual instructions
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s on Linux quick path
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
