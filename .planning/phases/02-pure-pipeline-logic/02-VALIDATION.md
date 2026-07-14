---
phase: 2
slug: pure-pipeline-logic
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-14
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Derived from `02-RESEARCH.md` §"Validation Architecture".

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | swift-testing (built into Swift 6+ toolchain) |
| **Config file** | none — swift-testing uses macros, no config file |
| **Quick run command** | `swift test --filter <TestSuiteName>` |
| **Full suite command** | `swift test` |
| **Estimated runtime** | ~10-20 seconds (pure-logic tests on Linux) |

---

## Sampling Rate

- **After every task commit:** Run `swift test --filter <modified module>` (~5-10s)
- **After every plan wave:** Run `swift test` (full Linux-runnable suite)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | WRITE-02 | T-2-04 / — | FrontmatterSchema fields validate; snake_case round-trip via Yams | unit | `swift test --filter FrontmatterSchemaTests` | ✅ (Phase 1) / extend | ⬜ pending |
| 02-01-02 | 01 | 1 | WRITE-01, WRITE-03 | — | N/A (pure transformation) | unit | `swift test --filter NoteNormalizerTests` | ❌ Wave 0 | ⬜ pending |
| 02-02-01 | 02 | 1 | WRITE-04 | T-2-02 | Atomic write protocol defined; no partial writes | integration | `swift test --filter NoteWriterTests` | ❌ Wave 0 | ⬜ pending |
| 02-02-02 | 02 | 1 | WRITE-05 | T-2-02 | `.icloud` placeholder hard-fail; never silently skip | unit | `swift test --filter NoteWriterTests/iCloud` | ❌ Wave 0 | ⬜ pending |
| 02-02-03 | 02 | 1 | WRITE-06 | T-2-05 | Structured `NoteWriterError` surfaces; no swallow | unit | `swift test --filter NoteWriterTests/Error` | ❌ Wave 0 | ⬜ pending |
| 02-03-01 | 03 | 1 | (C-01..05) | T-2-01 | Path-traversal strips via FolderNameSanitizer | unit | `swift test --filter FolderNameSanitizerTests` | ❌ Wave 0 | ⬜ pending |
| 02-03-02 | 03 | 1 | (C-01..04) | — | N/A (pure date arithmetic) | unit | `swift test --filter CourseClassifierTests` | ❌ Wave 0 | ⬜ pending |
| 02-04-01 | 04 | 2 | (O-01..05) | — | Concurrent-run rejection enforced by actor isolation | unit | `swift test --filter PipelineOrchestratorTests` | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Tests/UnibrainCoreTests/NormalizationTests/NoteNormalizerTests.swift` — stubs for WRITE-01, WRITE-03, N-01..04 (paragraph grouping, wiki-link emission, H1 title format)
- [ ] `Tests/UnibrainCoreTests/ClassificationTests/CourseClassifierTests.swift` — stubs for C-01..04 (±30min overlap, single/multiple/none match)
- [ ] `Tests/UnibrainCoreTests/ClassificationTests/FolderNameSanitizerTests.swift` — stubs for C-05 (strip `/`, `:`, leading dots; max 100 chars; path-traversal vectors)
- [ ] `Tests/UnibrainCoreTests/WritingTests/NoteWriterTests.swift` — stubs for WRITE-04, WRITE-05, WRITE-06, A-01..05 (atomic write round-trip; `.icloud` detection; structured errors)
- [ ] `Tests/UnibrainCoreTests/PipelineTests/PipelineOrchestratorTests.swift` — stubs for O-01..05 (8-state transitions; concurrent-run rejection; cooperative cancellation)
- [ ] Framework install: swift-testing is built into Swift 6 toolchain — no installation needed

*Existing infrastructure from Phase 1 covers FrontmatterSchema round-trip (WRITE-02). All other test files are Wave 0 gaps.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `NSFileCoordinator` coordination on real macOS with iCloud Drive sync | WRITE-04 | Requires macOS + iCloud account + real sync conflict; Phase 3 ships the macOS conformance | Phase 3 manual test: trigger write during iCloud sync, verify no corruption |
| `EKEvent` → `CalendarEvent` mapping produces correct overlap matches on real schedule | (C-01..04) | Requires real Apple Calendar data; Phase 4 ships the adapter | Phase 4 manual test: record during a scheduled lecture, verify correct course match |

*All Phase 2-scope behaviors have automated verification. Manual items are forward references for Phases 3/4.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
