---
phase: 04-course-classification-smart-routing
plan: 06
subsystem: Integration
tags: [gap-closure, wiring, schedule-aware-resolver, state-observer, picker-data, manage-courses]
requires: [04-04, 04-05]
provides: [schedule-aware-pipeline-wired, state-observer-awaiting-user-choice, picker-real-data, manage-courses-real-data]
affects: [PipelineWiring, UnibrainApp, MenuBarViewModel, CoursePickerView, ManageCoursesView]
tech-stack:
  added: []
  patterns: [per-recording orchestrator construction with fresh mapping snapshot, polling state observer for actor state transitions]
key-files:
  created: []
  modified:
    - Sources/UnibrainProviders/Pipeline/PipelineWiring.swift
    - UnibrainApp/UnibrainApp.swift
    - UnibrainApp/ViewModels/MenuBarViewModel.swift
    - UnibrainApp/Views/CoursePickerView.swift
    - UnibrainApp/Views/ManageCoursesView.swift
decisions:
  - Per-recording orchestrator construction chosen over live resolver refresh (resolver is immutable struct injected at init)
  - State observer uses 100ms polling (actor state has no AsyncStream publisher; polling is simplest correct approach)
  - CourseMatch reconstructed from pendingEvents stored during stopRecording (orchestrator does not expose the match that caused the pause)
  - Empty mapping at init time; real mapping loaded per-recording in stopRecording before orchestrator construction
metrics:
  duration: 3m
  completed: 2026-07-15
  tasks: 3
  files: 5
status: complete
---

# Phase 04 Plan 06: Integration Wiring Summary

Wired all four Phase 4 integration gaps: ScheduleAwareVaultResolver factory in PipelineWiring, state observer detecting .awaitingUserChoice in MenuBarViewModel, CoursePickerView reading real course data, and ManageCoursesView loading/persisting real mappings. All 200 existing tests remain green.

## Tasks Completed

| Task | Name | Commit | Key Files |
| ---- | ---- | ------ | --------- |
| 1 | Wire ScheduleAwareVaultResolver into PipelineWiring + UnibrainApp | e01024d | PipelineWiring.swift, UnibrainApp.swift |
| 2 | Add state observer + resolver refresh + picker data exposure in MenuBarViewModel | 4b33a39 | MenuBarViewModel.swift |
| 3 | Wire CoursePickerView + ManageCoursesView to read real data | e44a3cd | CoursePickerView.swift, ManageCoursesView.swift |

## Gap Closure Mapping

| Verification Gap | Task | What Changed |
| --------------- | ---- | ------------ |
| Gap 1: Resolver not wired | Task 1 + 2 | `makeScheduleAwareOrchestrator` factory added; `stopRecording` constructs fresh orchestrator with latest mapping per recording |
| Gap 2: No state observer for .awaitingUserChoice | Task 2 | `stateObserverTask` polls `orchestrator.currentState` at 100ms; reconstructs CourseMatch from `pendingEvents` |
| Gap 3: CoursePickerView has no data | Task 2 + 3 | `pickerRecentCourses`/`pickerFilteredCourses` exposed on MenuBarViewModel; CoursePickerView reads from them |
| Gap 4: ManageCoursesView has no data | Task 2 + 3 | `loadAllMappings`/`addMapping`/`deleteMapping` delegate to CourseMappingStore; ManageCoursesView calls them |

## Deviations from Plan

None - plan executed exactly as written. The plan's preferred simpler approach (empty mapping at init, refresh per-recording) was followed without modification.

## Threat Model Compliance

| Threat ID | Mitigation | Status |
|-----------|------------|--------|
| T-04-06-01 | State observer polling loop terminates | Observer self-cancels after firing handleClassificationPause; also cancelled in onTranscriptionComplete, onTranscriptionError, dismissCompletion |
| T-04-06-02 | Mapping snapshot staleness | Loaded fresh per-recording in stopRecording before orchestrator construction |
| T-04-06-03 | CoursePickerView data exposure | Single-user app; no cross-user exposure surface |

## Verification Results

- `swift build --target UnibrainProviders` - PASS
- `swift build --target UnibrainCore` - PASS
- `swift test` - 200/200 tests PASS (zero regressions)
- grep confirms `makeScheduleAwareOrchestrator` in PipelineWiring.swift and UnibrainApp.swift
- grep confirms `stateObserverTask`, `startObservingOrchestratorState`, `pickerRecentCourses`, `loadAllMappings`, `currentOrchestrator` in MenuBarViewModel.swift
- grep confirms `viewModel.pickerRecentCourses` in CoursePickerView.swift (no hardcoded `return []`)
- grep confirms `viewModel.loadAllMappings` in ManageCoursesView.swift (no hardcoded `mappings = [:]`)

## Self-Check: PASSED

All 5 modified files exist on disk. All 3 task commits verified in git log. 200/200 tests pass on WSL2 Linux. macOS device verification required for full end-to-end behavioral confirmation (same deferred verification as Phase 04 Plans 04-05).
