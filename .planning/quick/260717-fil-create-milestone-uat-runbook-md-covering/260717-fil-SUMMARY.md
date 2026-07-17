---
quick_id: 260717-fil
slug: create-milestone-uat-runbook-md-covering
status: complete
description: Create .planning/MILESTONE-UAT-RUNBOOK.md consolidating 15 device-deferred UAT scenarios from phases 3/4/5/6 into an ordered, command-level runbook
date: 2026-07-17
---

# Quick Task 260717-fil — Summary

## Outcome

Authored `.planning/MILESTONE-UAT-RUNBOOK.md` — the canonical end-to-end validation runbook for v1.0 milestone closure. Single file, ~470 lines.

## Structure delivered

- **Frontmatter** with 9 source documents cross-referenced.
- **3 critical pre-conditions** table (no `.xcodeproj` in repo, stale CI, Phase 4 wiring never device-verified).
- **Pre-flight checklist** (Apple ID, MacBook Neo, iPhone, API keys, disk, calendar access).
- **16 stages (0-15)** with command-level steps:
  - Stage 0: WSL2 pre-flight (`swift test` + push + `gh run watch`)
  - Stage 1: MacBook first-boot (Xcode, Homebrew, gh, Obsidian, Ollama, mitmproxy)
  - Stage 2: Apple Developer Program activation
  - Stage 3: Repo + Xcode project bootstrap (includes detailed Project Creation Procedure — 11 numbered sub-steps for the missing `.xcodeproj`)
  - Stage 4: iOS target setup (multiplatform)
  - Stage 5: Local infrastructure (Ollama + model, vault, iCloud Drive)
  - Stage 6: Test calendar setup (events overlapping "now" for live UAT)
  - Stage 7: First-run onboarding UAT (Phase 5)
  - Stage 8: macOS capture + transcribe UAT (Phase 3, 9 scenarios)
  - Stage 9: Course classification smart routing UAT (Phase 4, 10 sub-scenarios)
  - Stage 10: iOS capture + iCloud handoff UAT (Phase 5, 4 scenarios)
  - Stage 11: Gated summarization + cloud providers UAT (Phase 6, 8 scenarios)
  - Stage 12: iOS Settings + iCloud consent sync (Phase 6, 2 scenarios)
  - Stage 13: Zero-telemetry mitmproxy audit (CLOUD-12)
  - Stage 14: Local-first offline test (DISC-05)
  - Stage 15: Milestone sign-off (12 sub-tasks including `/gsd-complete-milestone`)
- **Rollback / failure handling** protocol.
- **Known risks** ranked: Xcode project creation, Phase 4 wiring, whisper.cpp SPM, iOS background recording, ModelLoadGate flakes, plus 3 documented non-blocking UI stubs.
- **Time estimates** table: ~15-22 hours active work spread over 1-3 weeks.

## Critical findings flagged for the user

1. **No `.xcodeproj` in the repo.** This is the single highest-risk item. The Phase 1 plan that mentioned "Xcode app shell" (01-04-PLAN) never produced a committed `.xcodeproj`. Stage 3.4 includes a detailed Project Creation Procedure.
2. **whisper.cpp SPM integration was deferred** (Phase 3 plan 03-02). `WhisperCppTranscriber.swift:81` has a `// TODO: Wire whisper.cpp SPM API once macOS CI validates the import.` Stage 8.5 may fail; SpeechAnalyzer fallback at `SpeechAnalyzerTranscriber.swift:60` has the same TODO pattern.
3. **Phase 4 integration wiring was source-closed by 04-06** but never device-verified. Stage 9 is the first end-to-end test of smart routing.

## Files created

- `.planning/MILESTONE-UAT-RUNBOOK.md` (~470 lines)
- `.planning/quick/260717-fil-create-milestone-uat-runbook-md-covering/260717-fil-PLAN.md`
- `.planning/quick/260717-fil-create-milestone-uat-runbook-md-covering/260717-fil-SUMMARY.md`

## Follow-ups

- User should read the full runbook before Stage 0.
- The 3 critical findings above likely warrant a follow-up `/gsd-quick` or `/gsd-debug` session BEFORE Stage 0 push to resolve or pre-empt:
  - **whisper.cpp SPM wire-up** — may block Stage 8 entirely. Should be addressed in code before the Mac session.
  - **Xcode project creation** — could be partially automated by adding a `project.yml` for XcodeGen, OR by committing an initial `.xcodeproj` from the first Mac session.
- After milestone sign-off, run `/gsd-complete-milestone` per Stage 15.10.
