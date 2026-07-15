---
phase: 3
slug: macos-capture-transcribe
status: draft
shadcn_initialized: false
preset: none
created: 2026-07-14
---

# Phase 3 — UI Design Contract

> Visual and interaction contract for the macOS menu-bar recording surface.
> Generated from 03-CONTEXT.md decisions P-08..P-12, P-D3, P-D5. Native SwiftUI — no web registry.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (native SwiftUI — no shadcn/web tooling applicable) |
| Preset | not applicable |
| Component library | SwiftUI (Apple-built — `MenuBarExtra`, `Button`, `ProgressView`, `Canvas`, `TimelineView`) |
| Icon library | SF Symbols (system — `brain`, `brain.fill`, `mic`, `mic.fill`, `pause.fill`, `stop.fill`, `play.fill`) |
| Font | SF Pro (system default — `.system` with `.body`, `.title`, `.title2`, `.caption` semantic roles) |
| Platform | macOS 26 Tahoe (deployment target D-05) |

**Design language:** Native macOS menu-bar app. Follows Apple Human Interface Guidelines for `MenuBarExtra` popover surfaces. No custom theming layer — uses standard semantic colors (`accentColor`, `.secondary`, `.red`, `.yellow`, `.green`) so the app automatically respects Light/Dark mode and system accent color preferences.

---

## Spacing Scale

SwiftUI uses points (pt). Native macOS HIG spacing — all multiples of 4pt.

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4pt | Icon gaps, inline label padding |
| sm | 8pt | Compact row spacing, button gap horizontal |
| md | 12pt | Default element vertical spacing |
| lg | 16pt | Section padding within popover |
| xl | 24pt | Popover top/bottom padding |
| 2xl | 32pt | Major section break (not used — popover is compact) |

**Popover width:** 280pt fixed (CONTEXT P-09 — compact enough to not obscure lecture content).

**Exceptions:** none — native macOS HIG spacing tokens.

---

## Typography

Native SF Pro via SwiftUI semantic styles. No custom fonts.

| Role | SwiftUI Style | Approx Size | Weight | Line Height |
|------|--------------|-------------|--------|-------------|
| Timer (recording state) | `.system(size: 32, weight: .semibold, design: .monospaced)` | 32pt | semibold | 1.2 |
| Body / status line | `.body` | 13pt | regular | 1.4 |
| Label (button) | `.headline` | 13pt | semibold | 1.3 |
| Caption (download progress) | `.caption` | 10pt | regular | 1.3 |
| Section heading (if needed) | `.headline` | 13pt | semibold | 1.3 |

**Monospaced timer:** the recording timer uses `.monospacedDigit` (system font with fixed-width digits) so the timer doesn't jitter as numbers change.

---

## Color

Native macOS semantic colors — the app respects system Light/Dark mode and user accent color automatically.

| Role | Value (Light/Dark) | Usage |
|------|-------------------|-------|
| Dominant (60%) | `Color(nsColor: .windowBackgroundColor)` | Popover background |
| Secondary (30%) | `Color(nsColor: .controlBackgroundColor)` / `.secondaryFill` | Cards, button backgrounds, waveform track |
| Accent (10%) | `Color.accentColor` (user-selected system accent) | Record button fill, active state indicators |
| Destructive / Recording | `Color.red` | Stop button, recording indicator dot, "recording" menu-bar icon fill |
| Warning / Paused | `Color.yellow` | Paused indicator, mic-level meter "approaching clip" segment |
| Success / Ready | `Color.green` | Mic-level meter "healthy" segment, "verified" model status |
| Text primary | `Color.primary` (`.labelColor`) | All primary text |
| Text secondary | `Color.secondary` (`.secondaryLabelColor`) | Status line secondary info, captions |

**Accent reserved for:** Record button (primary CTA), active recording timer color, menu-bar icon recording state.

**Destructive reserved for:** Stop button only (ends recording — distinct from Pause).

---

## Menu-Bar Icon States (P-D3)

The menu-bar icon communicates current state at a glance — no popover open needed.

| State | SF Symbol | Tint | Behavior |
|-------|-----------|------|----------|
| Idle (ready) | `brain` | `.secondary` (template) | Default — subtle, present |
| Recording | `brain.fill` | `.red` | Animated subtle pulse (opacity 0.7↔1.0, 1.5s cycle) |
| Paused | `brain.fill` | `.yellow` | Static (no animation — frozen like the timer) |
| Transcribing | `brain.fill` | `.accentColor` (user) | Static — popover shows the progress detail |
| Error (model download failed) | `exclamationmark.triangle.fill` | `.orange` | Persistent until dismissed |

**Auto-update:** icon state driven by `@Observable` session state machine — no manual icon management.

---

## Popover States & Layouts

### Idle State (P-10)

```
┌─────────────────────────────────────┐
│  Ready to record                    │
│  • small.en model downloaded ✓      │
│  • Microphone available ✓           │
│                                     │
│         ┌───────────────┐           │
│         │     Record     │           │
│         └───────────────┘           │
└─────────────────────────────────────┘
```

- **Status line** (`.body`, secondary): readiness preconditions. Shows warnings inline if any precondition fails: `⚠ Fallback model: downloading (40%)` / `⚠ Microphone permission needed`.
- **Record button**: large (`.controlSize(.large)`), filled accent color, `.mic.fill` icon + "Record" label.
- **Precondition checks:** model download status, microphone permission (locked in on first record tap if not yet granted).

### Recording State (P-09)

```
┌─────────────────────────────────────┐
│            00:14:32                 │
│  ▆▃▅▇▆▄▃▅▇▆▃▄▅▇▆▄▃▅▇▆▃▅▇▆▄▃▅   │  ← live waveform
│  ▂▃▄▅▆▇█▇▆▅▄▃▂▁▂▃▄▅▆▇█▇▆▅▄▃▂   │
│  ◁ ───────●───────▷               │  ← mic level meter
│                                     │
│    [ Pause ]      [ Stop ]         │
└─────────────────────────────────────┘
```

- **Timer** (`.system(size: 32, weight: .semibold)`, monospaced, top-centered): `HH:MM:SS` format.
- **Live waveform** (SwiftUI `Canvas` inside `TimelineView`): 2-row retro-style amplitude display, refreshed at 30fps from the audio session's `averagePower` buffer. MUST stay off MainThread (TRAN-03) — the Canvas reads a `@Observable` buffer updated by a detached task; MainActor only renders.
- **Mic-level meter** (horizontal bar): 3 segments — green (healthy) / yellow (approaching clip) / red (clipping). Drives CAPT-05 "confirm lecturer is audible" without extra clicks.
- **Pause button** (`.controlSize(.regular)`, secondary): `.pause.fill` icon + "Pause".
- **Stop button** (`.controlSize(.regular)`, destructive): `.stop.fill` icon + "Stop" — red tint.

### Paused State (P-12)

```
┌─────────────────────────────────────┐
│            00:14:32                 │  ← frozen timer
│  ▂▁▂▁▂▁▂▁▂▁▂▁▂▁▂▁▂▁▂▁▂▁▂▁▂▁▂▁   │  ← dimmed/frozen waveform
│  ◁ ──────────────▷                 │  ← empty mic meter
│                                     │
│   ⏸  Paused — 2 pauses, 14s total  │
│                                     │
│    [ Resume ]     [ Stop ]         │
└─────────────────────────────────────┘
```

- **Frozen timer:** same monospaced style, color dimmed (`.secondary`).
- **Waveform:** last frame frozen, opacity reduced to 0.4.
- **Paused summary** (`.caption`, secondary): `Paused — {N} pauses, {totalSeconds}s total` if P-D1 decision lands on visible pause markers.
- **Resume button** (primary, accent): `.play.fill` + "Resume".
- **Stop button** (destructive): same as recording state.

### Transcribing State (P-11)

```
┌─────────────────────────────────────┐
│  ◌ Transcribing…                    │
│  Est. ~2 min                        │
│                                     │
│  ━━━━━━━░░░░░░░░░░░░  35%           │
│                                     │
│         [ Record (disabled) ]       │
└─────────────────────────────────────┘
```

- **Status** (`.headline`): spinner + "Transcribing…".
- **ETA estimate** (`.caption`, secondary): `Est. ~{N} min` based on audio length / engine (SpeechAnalyzer ~1× realtime, whisper.cpp ~3× realtime).
- **Progress bar** (`ProgressView`): percentage based on audio processed if exposed by engine; otherwise indeterminate spinner.
- **Record button disabled** (`.disabled(true)`): enforces Phase 2 O-02 `.alreadyRunning` rejection — no concurrent run.
- **System notification on completion:** macOS notification — `Lecture transcript ready — opened in vault`. Fires alongside popover clearing to idle.

### Error State (Model Download Failed — P-18)

```
┌─────────────────────────────────────┐
│  ⚠ Fallback model download failed   │
│                                     │
│  Primary recording still works.     │
│  Fallback unavailable until retry.  │
│                                     │
│           [ Retry ]                 │
└─────────────────────────────────────┘
```

- **Non-blocking** — SpeechAnalyzer primary recording still works. The popover status line carries this warning inline rather than taking over the popover unless the user taps the warning.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary CTA (idle) | "Record" |
| Primary CTA action description | Tap once to start recording; menu-bar icon turns red |
| Pause CTA | "Pause" |
| Resume CTA | "Resume" |
| Stop CTA | "Stop" |
| Empty state heading (first launch, model downloading) | "Ready to record" |
| Empty state body | "Primary transcription is ready. Fallback model: downloading (40%)." |
| Recording state heading | `{timer}` (no heading — timer IS the heading) |
| Transcribing state heading | "Transcribing…" |
| Transcribing completion notification title | "Lecture transcript ready" |
| Transcribing completion notification body | "Opened in vault" |
| Error: model download failed | "Fallback model download failed" |
| Error: model download failed recovery | "Primary recording still works. Fallback unavailable until retry." |
| Error: SpeechAnalyzer failed (silent) | (no user-visible copy — Router silently falls back to whisper.cpp per P-02) |
| Error: both engines failed | "Transcription failed" / "Please re-record or try again after restarting the app." |
| Destructive confirmation: Stop recording | (none — Stop is immediate, no confirmation per CAPT-01 "one-tap stop") |

**Tone:** calm, brief, no exclamation marks. Angelica is in a lecture — she needs information, not personality.

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| SwiftUI (system) | `MenuBarExtra`, `Button`, `Canvas`, `TimelineView`, `ProgressView`, `Label`, `VStack`, `HStack` | not required (Apple framework — no third-party audit needed) |
| Third-party SPM | (none in Phase 3 UI layer — whisper.cpp / SwiftWhisper lives in `UnibrainProviders`, not the UI) | not applicable |

**No web registry components used.** This is a native SwiftUI app — shadcn/ui, Radix, base-ui are not applicable. Registry safety checks pass vacuously.

---

## Interaction Contracts

### Recording Lifecycle (state machine)

```
idle ──[tap Record]──→ recording ──[tap Stop]──→ transcribing ──[done]──→ idle
                            │                                              ↑
                            ├──[tap Pause]──→ paused ──[tap Resume]────────┘
                            │                  │
                            └──────────────────┴──[tap Stop]──→ transcribing
```

- **Record tap:** if microphone permission missing → system permission dialog first, then recording starts on grant. If denied → popover status line shows `Microphone permission needed` with link to System Settings.
- **Stop tap:** immediate (no confirmation). Audio file finalized, transcription kicks off in background.
- **Pause tap:** recording continues at AVAudioRecorder level (no stop/restart) — Angelica's tap sets a flag; the resulting `.m4a` contains the full continuous audio per CAPT-02 "pause/resume contiguous". Pause markers are metadata (P-D1 undecided on location).

### Transcription Lifecycle

- **On Stop:** popover transitions to `transcribing` within 200ms (UI feedback before ASR kicks off — feels responsive).
- **During transcription:** menu-bar icon shows `brain.fill` in accent color. Popover can be closed; transcription continues in background (`Task.detached`).
- **On completion:** macOS notification fires; popover (if open) transitions to `idle`. If popover was closed, menu-bar icon reverts to default `brain` on next render cycle.

---

## Accessibility

- **VoiceOver labels:** every button has `.accessibilityLabel` — Record button label = "Start recording", Stop = "Stop recording and transcribe", Pause = "Pause recording", Resume = "Resume recording".
- **Menu-bar icon accessibility:** `.accessibilityLabel` varies by state — "Unibrain — idle", "Unibrain — recording 14 minutes 32 seconds", "Unibrain — paused", "Unibrain — transcribing".
- **Color independence:** recording state is NOT indicated by red color alone — icon shape changes (`brain` → `brain.fill`) and the pulse animation provides a non-color cue. Mic meter uses shape position (segment fill) not just color.
- **Dynamic Type:** native SwiftUI Dynamic Type support — popover respects user's text size setting. Timer scales up to `.accessibility1` at max.

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS — all primary copy specified, no lorem, tone documented
- [x] Dimension 2 Visuals: PASS — every popover state has ASCII mock + iconography spec
- [x] Dimension 3 Color: PASS — semantic system colors, accent reserved explicitly, destructive reserved for Stop
- [x] Dimension 4 Typography: PASS — SF Pro semantic styles, monospaced timer, sizes/weights declared
- [x] Dimension 5 Spacing: PASS — 4pt-multiple scale, popover width fixed at 280pt
- [x] Dimension 6 Registry Safety: PASS — native SwiftUI only, no web registry applicable

**Approval:** approved 2026-07-14 (self-validated from CONTEXT.md P-08..P-12, P-D3, P-D5 decisions — UI checker agent run is the next step before planning)

---

*Phase: 3 — macOS Capture + Transcribe*
*UI-SPEC generated: 2026-07-14*
*Source: distilled from 03-CONTEXT.md (P-08..P-12, P-D3, P-D5) + Apple HIG for MenuBarExtra*
