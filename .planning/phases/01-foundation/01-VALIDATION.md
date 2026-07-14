---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-13
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (built into Swift 6 toolchain — `import Testing`, `@Test`, `@Suite`) |
| **Config file** | `Package.swift` (test targets declared in manifest) |
| **Quick run command** | `swift test --test-product UnibrainCoreTests` |
| **Full suite command** | `swift test` (runs all test targets — Linux: core only; macOS: core + providers) |
| **Estimated runtime** | ~5 seconds (quick, core-only) / ~30 seconds (full suite on macOS CI) |

---

## Sampling Rate

- **After every task commit:** Run `swift test --test-product UnibrainCoreTests` (core tests only, ~5s)
- **After every plan wave:** Run `swift test` (full suite — runs on macOS CI, ~30s)
- **Before `/gsd-verify-work`:** Full suite must be green on both Linux (WSL2) and macOS CI
- **Max feedback latency:** ~5 seconds (local quick run) / ~5 minutes (macOS CI run)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 0 | FOUND-01 | — | N/A — manifest is data | smoke | `swift build --target UnibrainCore` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 0 | FOUND-02 | T-1-03 | Protocols compile, no Apple-framework imports in core | unit | `swift build --target UnibrainCore` on Linux | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 0 | FOUND-03 | — | CI runs on every push to main | smoke | GitHub Actions (automatic on push) | ❌ W0 | ⬜ pending |
| 01-04-01 | 04 | 1 | FOUND-04 / DISC-01 | T-1-02 | ModelLoadGate denies conflicting model load (data-race-safe) | unit | `swift test --filter ModelLoadGateTests` | ❌ W0 | ⬜ pending |
| 01-05-01 | 05 | 1 | FOUND-05 | — | Yams encodes/decodes frontmatter round-trip | unit | `swift test --filter FrontmatterSchemaTests` | ❌ W0 | ⬜ pending |
| 01-06-01 | 06 | 2 | FOUND-06 | — | N/A — documentation only | manual | Verify PROJECT.md has the decision | N/A | ⬜ pending |
| 01-02-02 | 02 | 0 | DISC-02 | — | UnibrainCore has zero Apple-framework imports | smoke | `swift build` on Linux succeeds | ❌ W0 | ⬜ pending |
| 01-03-02 | 03 | 0 | DISC-03 | — | Pure-logic tests run on WSL2 Linux | smoke | `swift test --test-product UnibrainCoreTests` on Linux | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Note: Task IDs are provisional — the planner will assign final IDs in PLAN.md. Wave 0 is mandatory: Swift 6.0.x toolchain install + Package.swift + test scaffolding before any other task can verify.*

---

## Wave 0 Requirements

- [ ] **Swift 6.0.x toolchain install on WSL2** — `swift`, `swiftc`, `swift package` must be on PATH (pin to 6.0.x; Swift 6.2 has a known SwiftPM hang on Ubuntu 24.04)
- [ ] **Git repository initialized** — `git init`, initial commit, branch `main` (currently NOT a git repo per environment)
- [ ] `Package.swift` — three-target manifest (`UnibrainCore`, `UnibrainProviders`, `UnibrainCoreTests`) with `.swiftLanguageMode(.v6)` and Yams 6.2.2 dependency on `UnibrainCore`
- [ ] `Tests/UnibrainCoreTests/ModelLoadGateTests.swift` — stubs for FOUND-04 / DISC-01 (deny-on-conflict)
- [ ] `Tests/UnibrainCoreTests/FrontmatterSchemaTests.swift` — stubs for FOUND-05 (Yams round-trip)
- [ ] `.github/workflows/ci.yml` — matrix workflow (Linux + macOS), SPM cache + DerivedData cache

*If none: "Existing infrastructure covers all phase requirements."* — N/A, this is greenfield.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Apple Developer Program decision documented in PROJECT.md Key Decisions | FOUND-06 | Decision is a documentation deliverable, not executable code | Open `.planning/PROJECT.md`, verify Key Decisions table contains a row for "Apple Developer Program" with the chosen rationale (deferred-to-Phase-3 per D-01) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (quick) / < 6 min (CI)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
