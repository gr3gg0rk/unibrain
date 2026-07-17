---
quick_id: 260717-fil
slug: create-milestone-uat-runbook-md-covering
description: Create .planning/MILESTONE-UAT-RUNBOOK.md consolidating 15 device-deferred UAT scenarios from phases 3/4/5/6 into an ordered, command-level runbook covering clean MacBook Neo first boot through v1.0 milestone sign-off. Assumes paid Apple Developer Program.
mode: quick
created: 2026-07-17
---

# Quick Task 260717-fil — Plan

## Single Task

**Goal:** Author `.planning/MILESTONE-UAT-RUNBOOK.md` as the canonical end-to-end validation runbook for the v1.0 milestone.

**Action:**
- Synthesize content from PROJECT.md, STATE.md, ROADMAP.md, REQUIREMENTS.md, 03-UAT.md, 04-VERIFICATION.md, 05-UAT.md, 06-UAT.md, 06-VERIFICATION.md.
- Surface the three blockers discovered during planning scan: (1) no `.xcodeproj` in repo, (2) stale CI (last green pre-Phase 6), (3) Phase 4 wiring never device-verified.
- Structure as 16 stages (0-15): WSL2 pre-flight → Mac first-boot → Apple Dev activation → Xcode project bootstrap → iOS target → local infra → calendar setup → onboarding UAT → Phase 3/4/5/6 UAT → mitmproxy audit → offline test → milestone sign-off.
- Include Rollback/Failure Handling section, Known Risks (6 ranked items including documented UI stubs), and Time Estimates table.

**Files:**
- `.planning/MILESTONE-UAT-RUNBOOK.md` (create, ~470 lines)

**Verify:**
- File exists at the planned path.
- All 15 UAT scenarios from source phase docs are represented.
- All 3 blockers surfaced in the planning scan appear in the Critical Pre-Conditions table.
- Stage structure is ordered and checkpointable.

**Done when:** File written + committed, STATE.md updated with quick task entry.
