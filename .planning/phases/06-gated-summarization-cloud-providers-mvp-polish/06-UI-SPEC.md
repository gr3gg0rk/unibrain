---
phase: 6
slug: gated-summarization-cloud-providers-mvp-polish
status: draft
shadcn_initialized: false
preset: none
created: 2026-07-16
---

# Phase 6 — UI Design Contract

> Visual and interaction contract for Gated Summarization + Cloud Providers + MVP Polish.
> Generated from 06-CONTEXT.md decisions (SET-01..04, CON-01..04, CF-01..04, OLL-01..04).
> Inherits Phase 3/4/5 design tokens (native SwiftUI, SF Pro, SF Symbols, semantic system colors, calm tone).
> This phase introduces seven new UI surfaces: (1) macOS Settings window with 5 tabs, (2) iOS Settings tab expansion, (3) Consent sheet, (4) Cloud failure recovery sheet, (5) Ollama setup callout, (6) Audit tab content, (7) Providers tab.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (native SwiftUI — no shadcn/web tooling applicable) |
| Preset | not applicable |
| Component library | SwiftUI (Apple-built — `Settings`, `TabView`, `NavigationStack`, `Form`, `List`, `Section`, `SecureField`, `Picker`, `ProgressView`, `Label`, `Button`, `Alert`, `Sheet`) |
| Icon library | SF Symbols (system — inherits Phase 3/4/5 set + `gearshape`, `checkmark.shield`, `exclamationmark.shield.fill`, `key.fill`, `icloud`, `arrow.triangle.2.circlepath`, `chart.bar.doc.horizontal`, `person.crop.rectangle.badge.checkmark`, `bolt.fill`, `cloud.fill`, `lock.shield`, `text.book.closed.fill`, `graduationcap.fill`) |
| Font | SF Pro (system default — `.largeTitle`, `.title`, `.title2`, `.title3`, `.body`, `.headline`, `.subheadline`, `.caption` semantic roles) |
| Platform | macOS 26 Tahoe + iOS 17 (deployment targets D-05). Multiplatform — `#if os(macOS)` / `#if os(iOS)` guards for platform-specific surfaces. |

**Design language:** Native SwiftUI multiplatform app. Follows Apple Human Interface Guidelines for Settings windows (macOS System Settings pattern), tab-based navigation, secure input, and audit interfaces. No custom theming layer — uses standard semantic colors so the app automatically respects Light/Dark mode and system accent color preferences on both platforms.

**Inheritance:** All Phase 3/4/5 design tokens (spacing scale, typography, color contract, copywriting tone) carry forward unchanged. Phase 6 extends the design language to Settings UI and cloud provider configuration — no existing tokens change.

---

## Spacing Scale

Inherited from Phase 3/4/5 — unchanged. SwiftUI uses points (pt). All multiples of 4pt.

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4pt | Icon gaps, inline padding, banner internal spacing |
| sm | 8pt | Compact row spacing, button gap horizontal, form padding |
| md | 12pt | Popover section gap, default element vertical spacing (see Exceptions) |
| lg | 16pt | Section padding within popover/form, Settings tab padding |
| xl | 24pt | Popover top/bottom padding, Settings section spacing |
| 2xl | 32pt | Major section break, Settings top/bottom padding |
| 3xl | 48pt | Page-level spacing (rare in Settings UI) |

**Settings window (macOS):** 600pt × 400pt minimum (resizable). Apple's standard Settings scene size per Human Interface Guidelines.

**Popover width (macOS):** 280pt fixed (inherited from Phase 3 P-09, unchanged).

**iOS Settings tab:** Full-screen (no fixed width — uses available screen width in TabView).

**Exceptions:**
- **12pt used for `md` token** — native SwiftUI default element spacing. Apple HIG commonly uses 12pt for form section gaps and default vertical spacing (SwiftUI `Form`, `List`, and `Section` default spacing falls between 8–16pt; 12pt is the framework's implicit vertical stack padding for grouped content). Exception scoped to popover section gaps and default element vertical spacing only. Hard 16pt (`lg`) applies wherever explicit section padding is declared in the layout contracts above.

---

## Typography

Inherited from Phase 3/4/5. Native SF Pro via SwiftUI semantic styles. No custom fonts. Phase 6 adds Settings-specific roles for tab labels and provider configuration.

| Role | SwiftUI Style | Approx Size | Weight | Line Height |
|------|--------------|-------------|--------|-------------|
| Settings window title (macOS) | `.title` + `.fontWeight(.semibold)` | 28pt | semibold | 1.2 |
| Settings tab label | `.body` + `.fontWeight(.regular)` | 13pt (macOS) / 17pt (iOS) | regular | 1.4 |
| Section heading (Settings) | `.headline` + `.fontWeight(.semibold)` | 15pt (macOS) / 17pt (iOS) | semibold | 1.3 |
| Provider name | `.body` + `.fontWeight(.semibold)` | 13pt (macOS) / 17pt (iOS) | semibold | 1.4 |
| API key masked display | `.system(.body, design: .monospaced)` | 13pt (macOS) / 17pt (iOS) | regular | 1.4 |
| Body / status line | `.body` | 13pt (macOS) / 17pt (iOS) | regular | 1.4 |
| Label (button) | `.body` + `.fontWeight(.regular)` | 13pt (macOS) / 17pt (iOS) | regular | 1.4 |
| Subheadline (row title) | `.subheadline` | 12pt (macOS) / 15pt (iOS) | regular | 1.3 |
| Caption (metadata, progress) | `.caption` | 10pt (macOS) / 12pt (iOS) | regular | 1.3 |
| Audit table header | `.caption` + `.fontWeight(.semibold)` | 10pt (macOS) / 12pt (iOS) | semibold | 1.3 |

**iOS vs macOS size note:** iOS uses SwiftUI's standard Dynamic Type scaling, which defaults to larger body text (17pt) compared to macOS (13pt). This is standard Apple HIG — iOS is viewed at arm's length, macOS at desk distance. All sizes respect Dynamic Type user preferences.

### Platform Convention Exception — SwiftUI Semantic Type Roles

The iOS typography column declares 6 sizes (17, 15, 12pt) and 2 weights (regular, semibold), deviating from the standard 4-size / 2-weight contract. **This deviation is mandated by Apple's Human Interface Guidelines**: SwiftUI's semantic type styles (`.body`, `.headline`, `.subheadline`, `.caption`) are Apple's required type system for native iOS apps. Using them is non-negotiable for HIG compliance — overriding them with custom `UIFont` sizes breaks Dynamic Type, VoiceOver scaling, and Apple Watch/Accessibility Settings integration.

**Weight policy (2 weights, strict):**
- **regular (400)** — Settings tab labels, body text, status lines, captions, subheadlines, row titles, button labels, API key masked display.
- **semibold (600)** — restricted to (a) Settings window title (macOS), (b) Section headings (Settings), (c) Provider names, (d) Audit table headers. All semibold uses are for focal display roles establishing hierarchy against regular body text.

**Button labels collapse to regular.** Although `.headline` resolves to semibold in SwiftUI's default stylesheet, Phase 6 button labels (Save, Cancel, Retry, Delete, Done, Download, Re-check) use `.body` + `.fontWeight(.regular)`. This prevents button text from competing with section headings and provider names for visual weight. Apply the override via `.fontWeight(.regular)` on every button.

---

## Color

Inherited from Phase 3/4/5 — unchanged. Native semantic colors on both platforms.

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `Color(.systemBackground)` (iOS) / `Color(nsColor: .windowBackgroundColor)` (macOS) | App background, Settings window background |
| Secondary (30%) | `Color(.secondarySystemBackground)` (iOS) / `Color(nsColor: .controlBackgroundColor)` (macOS) | Cards, form sections, tab bar, list rows, Settings tab content |
| Accent (10%) | `Color.accentColor` (user-selected system accent) | Primary CTA fill, Settings tab selection, active provider indicators |
| Destructive / Recording | `Color.red` | Delete actions, Remove API key, Revoke consent, Stop button |
| Warning | `Color.orange` | Cloud failure warnings, Ollama not detected callout, network unreachable |
| Success | `Color.green` | Permission granted, API key valid, consent active, model downloaded |
| Text primary | `Color.primary` (`.labelColor`) | All primary text |
| Text secondary | `Color.secondary` (`.secondaryLabelColor`) | Status lines, captions, placeholder text |

**Accent reserved for:**
- Settings tab selection (active tab highlight)
- "Always allow" button in consent sheet (CON-01)
- "Download Ollama" button (OLL-01)
- Active provider selection in Providers tab

**Warning (orange) reserved for:**
- Cloud failure sheet banner (CF-01)
- Ollama not detected callout (OLL-01)
- Network unreachable message (CF-02)

**Destructive (red) reserved for:**
- Delete API key button
- Revoke consent button
- Delete failed recording button
- Cancel button in destructive contexts

---

## Surface 1: macOS Settings Window (SET-01, SET-02)

Dedicated SwiftUI `Settings` scene on macOS. Opens via:
- Menu-bar popover "Settings…" button
- Standard ⌘, shortcut
- Menu bar item (unibrain menu → Settings)

### Window Layout

```
┌─────────────────────────────────────────────────────────┐
│  unibrain Settings                                ─ □ ✕ │
├─────────────────────────────────────────────────────────┤
│ ○ General  ○ Providers  ○ Courses  ○ Permissions  ○ Audit │
├─────────────────────────────────────────────────────────┤
│                                                         │
│           [ Tab Content — 600pt × 400pt ]             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Tab Icons (SF Symbols):**
- General: `gearshape`
- Providers: `checkmark.shield.fill`
- Courses: `text.book.closed.fill`
- Permissions: `person.crop.rectangle.badge.checkmark`
- Audit: `chart.bar.doc.horizontal`

**Tab access pattern:**
- Direct click on tab icon
- ⌘+1 through ⌘+5 keyboard shortcuts
- Context-aware opening from popover (SET-04): post-recording failure opens Audit tab; permission warning opens Permissions tab; provider-related opens Providers tab

---

## Surface 2: General Tab (SET-01, OLL-02, OLL-03, OLL-04)

First tab in Settings window. Contains summarization toggle and Ollama setup.

### Layout

```
┌─────────────────────────────────────────────────────────┐
│  General                                                 │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Summarization                                           │
│  Enable Summarization                                >   │
│  Off | Local (Ollama) | Cloud                             │
│                                                          │
│  When enabled, unibrain generates a 5-8 bullet            │
│  summary of each lecture transcript.                     │
│  Summaries are appended to lecture notes.                 │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Vault Path                                        │  │
│  │ ~/Documents/Unibrain/                         [Change]│  │
│  │                                                  │  │
│  │ Current Term                                     │  │
│  │ Fall 2026                            [Edit Details]│  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  About                                                   │
│  unibrain v1.0                                           │
│  Local-first. Your audio never leaves your devices.      │
│  Zero telemetry. No analytics. No phone-home.            │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Summarization toggle (OLL-02):**
- Picker: `Off` (default) | `Local (Ollama)` | `Cloud`
- Off: Summarization disabled (SUMM-02 compliance)
- Local: Uses Ollama at localhost:11434
- Cloud: Uses selected cloud provider from Providers tab

**Vault Path display:**
- Read-only display of current vault folder
- "Change" button re-opens folder picker from onboarding
- Updates security-scoped bookmark

**Current Term display:**
- Read-only display of `currentTerm.label` + date range
- "Edit Details" button opens term editor (reuses Phase 4/5 `TermEditorForm`)
- Links to Courses tab for editing

### Ollama Setup Callout (OLL-01, OLL-03)

Shown when "Local (Ollama)" selected and Ollama not detected:

```
┌─────────────────────────────────────────────────────────┐
│  ⚠ Ollama not detected                                  │
│                                                          │
│  Ollama is required for local summarization.             │
│  Download and install Ollama, then click Re-check.       │
│                                                          │
│  [ Download Ollama ]    [ Re-check ]    [ Cancel ]       │
└─────────────────────────────────────────────────────────┘
```

- **Download Ollama button**: Opens `https://ollama.com` in default browser
- **Re-check button**: Re-runs health check to `localhost:11434/api/tags`
- **Cancel button**: Returns picker to "Off"

**Model not pulled callout (OLL-03):**

Shown when Ollama detected but `llama-3.2:3b` not in `ollama list`:

```
┌─────────────────────────────────────────────────────────┐
│  Model not pulled yet                                    │
│                                                          │
│  llama-3.2:3b (~2GB) is required for summarization.       │
│                                                          │
│  [ Pull llama-3.2:3b (~2GB) ]                            │
│                                                          │
│  Progress bar appears here during download              │
└─────────────────────────────────────────────────────────┘
```

- **Pull button**: Fires `ollama pull llama-3.2:3b` via `Process` shell-out
- Progress bar streams from Ollama stdout (parsed percentage)
- After pull: health check passes, summarization enabled

### Copywriting

| Element | Copy |
|---------|------|
| **Tab label** | "General" |
| **Summarization section heading** | "Summarization" |
| **Enable Summarization picker label** | "Enable Summarization" |
| **Summarization explanation** | "When enabled, unibrain generates a 5-8 bullet summary of each lecture transcript. Summaries are appended to lecture notes." |
| **Vault Path section** | "Vault Path" |
| **Current Term section** | "Current Term" |
| **Edit Details button** | "Edit Details" |
| **About section** | "About" |
| **About version** | "unibrain v1.0" |
| **About privacy** | "Local-first. Your audio never leaves your devices. Zero telemetry. No analytics. No phone-home." |
| **Ollama not detected heading** | "Ollama not detected" |
| **Ollama not detected body** | "Ollama is required for local summarization. Download and install Ollama, then click Re-check." |
| **Download Ollama button** | "Download Ollama" |
| **Re-check button** | "Re-check" |
| **Cancel button** | "Cancel" |
| **Model not pulled heading** | "Model not pulled yet" |
| **Pull button** | "Pull llama-3.2:3b (~2GB)" |

---

## Surface 3: Providers Tab (SET-02, CLOUD-01, CLOUD-02, CLOUD-07)

Second tab in Settings window. Per-modality provider selectors with API key entry.

### Layout

```
┌─────────────────────────────────────────────────────────┐
│  Providers                                               │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  LLM Provider (Summarization)                            │
│  Local (Ollama) ▼                                        │
│  Off | Local (Ollama) | OpenAI | Anthropic | Grok | Z.ai │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ OpenAI API Key                               [✓]  │  │
│  │ ••••••••••••••••                          [Remove]│  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  ASR Provider (Transcription)                           │
│  Local (whisper.cpp) ▼                                   │
│  Off | Local (whisper.cpp) | OpenAI                     │
│                                                          │
│  Vision Provider (Image Description)                    │
│  Off ▼                                                   │
│  Off | OpenAI | Anthropic                                │
│                                                          │
│  TTS Provider (Text-to-Speech)                          │
│  Off ▼                                                   │
│  Off | OpenAI                                           │
│                                                          │
│  Cloud providers require API keys. Local providers work   │
│  offline and require no configuration.                     │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Per-modality sections:**
- Each section has provider picker + API key entry (if cloud provider selected)
- Section headings use SF Symbols: `bolt.fill` (LLM), `waveform` (ASR), `eye` (Vision), `speaker.wave.2` (TTS)

**Provider picker behavior:**
- Off: Provider disabled for this modality
- Local: Uses local engine (Ollama, whisper.cpp) — no API key needed
- Cloud provider selected: Shows API key entry row below

**API key entry row:**
- **Provider name** (`.body` + `.semibold`) + "API Key" label
- `SecureField` for masked input (dots, not plaintext)
- Validation checkmark (`.green`) appears when valid key format entered
- "Remove" button (`.destructive`) clears key from Keychain

**API key storage (CLOUD-07):**
- macOS Keychain (`SecItemAdd` with `kSecClassGenericPassword`)
- iOS Secure Enclave (Phase 6: device-local only; iCloud Keychain sync is opt-in)
- Never written to vault, config files, or logs

**Default state (CLOUD-02):**
- All modalities default to "Local" or "Off" on first launch
- No cloud provider configured without explicit user action

### Copywriting

| Element | Copy |
|---------|------|
| **Tab label** | "Providers" |
| **LLM Provider section heading** | "LLM Provider (Summarization)" |
| **ASR Provider section heading** | "ASR Provider (Transcription)" |
| **Vision Provider section heading** | "Vision Provider (Image Description)" |
| **TTS Provider section heading** | "TTS Provider (Text-to-Speech)" |
| **Provider picker labels** | "Off", "Local (Ollama)", "Local (whisper.cpp)", "OpenAI", "Anthropic", "Grok", "Z.ai" |
| **API Key row label** | "{Provider} API Key" |
| **Remove button** | "Remove" |
| **Cloud provider explanation** | "Cloud providers require API keys. Local providers work offline and require no configuration." |

---

## Surface 4: Courses Tab (SET-04, Phase 4 M-04)

Third tab in Settings window. Folds Phase 4's "Manage Courses" sheet into Settings.

### Layout

```
┌─────────────────────────────────────────────────────────┐
│  Courses                                                 │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Current Term                                            │
│  Fall 2026 (Aug 25 – Dec 15)                   [Edit]    │
│                                                          │
│  Course Mappings                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Event Title         → Course Code   Term          │  │
│  ├──────────────────────────────────────────────────┤  │
│  │ CS101 Lecture      → CS101        Fall 2026     [Edit]│
│  │ MATH200 Lecture    → MATH200      Fall 2026     [Edit]│
│  │ PHIL101 Seminar    → PHIL101      Fall 2026     [Edit]│
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  [ Add Mapping ]  [ Import from Calendar ]              │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Current Term section:**
- Displays `currentTerm.label` + date range
- "Edit" button opens term editor form

**Course Mappings table:**
- Columns: Event Title, Course Code, Term, Actions
- Each row has "Edit" button (opens course edit form)
- Read from `.unibrain/courses.json`

**Add Mapping button:**
- Opens form to manually add event title → course code mapping
- Creates folder if not exists

**Import from Calendar button:**
- One-time import from all calendar events in current term
- Auto-creates mappings for all events

### Copywriting

| Element | Copy |
|---------|------|
| **Tab label** | "Courses" |
| **Current Term section heading** | "Current Term" |
| **Course Mappings section heading** | "Course Mappings" |
| **Edit button** | "Edit" |
| **Add Mapping button** | "Add Mapping" |
| **Import from Calendar button** | "Import from Calendar" |

---

## Surface 5: Permissions Tab (SET-04, Phase 5 ONB-04)

Fourth tab in Settings window. Folds Phase 5's "Permissions" sheet into Settings.

### Layout

```
┌─────────────────────────────────────────────────────────┐
│  Permissions                                             │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  MICROPHONE                                              │
│  ● Microphone                                     ● On   │
│  Required for recording lectures.                         │
│                                            [ Open Settings ]│
│                                                          │
│  CALENDAR                                                │
│  ● Calendar                                      ● On   │
│  Auto-routes recordings to courses based on your schedule.│
│                                            [ Open Settings ]│
│                                                          │
│  VAULT                                                   │
│  📁 ~/Documents/Unibrain/                                 │
│  Where lecture notes and recordings are saved.           │
│                                                  [ Change ]│
│                                                          │
│  FULL DISCLOSURE                                          │
│  unibrain is local-first. Audio never leaves your        │
│  devices unless you explicitly enable cloud providers.     │
│  Zero telemetry. No analytics. No phone-home.            │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Microphone row:**
- Live status: `● On` / `● Off`
- Green checkmark + "On" if granted; red X + "Off" if denied
- "Required for recording lectures." in `.caption`, `.secondary`
- "Open Settings" button opens system privacy settings

**Calendar row:**
- Live status: `● On` (Full Access) / `● Off` (Denied or Write-Only)
- Green + "On" if Full Access; orange + "Off — Manual Pick" if denied
- "Auto-routes recordings to courses based on your schedule." in `.caption`, `.secondary`
- "Open Settings" button opens system calendar privacy settings

**Vault row:**
- Shows current vault folder path
- "Change" button re-opens folder picker

**Full Disclosure section:**
- Privacy statement reinforcing local-first mandate
- Zero-telemetry declaration

### Copywriting

| Element | Copy |
|---------|------|
| **Tab label** | "Permissions" |
| **Microphone section heading** | "MICROPHONE" |
| **Microphone description** | "Required for recording lectures." |
| **Calendar section heading** | "CALENDAR" |
| **Calendar description** | "Auto-routes recordings to courses based on your schedule." |
| **Calendar off status** | "Off — Manual Pick" |
| **Vault section heading** | "VAULT" |
| **Vault description** | "Where lecture notes and recordings are saved." |
| **Change button** | "Change" |
| **Full Disclosure heading** | "FULL DISCLOSURE" |
| **Full Disclosure body** | "unibrain is local-first. Audio never leaves your devices unless you explicitly enable cloud providers. Zero telemetry. No analytics. No phone-home." |
| **Open Settings button** | "Open Settings" |

---

## Surface 6: Audit Tab (CF-04, CON-04)

Fifth tab in Settings window. Per-note audit trail with failure history and query filters.

### Layout

```
┌─────────────────────────────────────────────────────────┐
│  Audit                                                   │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Filters                                                 │
│  Date Range: [ Last 7 days ▼ ]                          │
│  Provider: [ All ▼ ]                                    │
│  Modality: [ All ▼ ]                                    │
│  Course: [ All ▼ ]                                      │
│  Status: [ All ▼ ]                                     │
│                                                          │
│  Recent Activity (Last 7 days)                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Date        Note         Provider    Modality   Status│
│  ├──────────────────────────────────────────────────┤  │
│  │ 2026-09-15 CS101 Lec → OpenAI      LLM        ✓    │  │
│  │ 2026-09-15 CS101 Lec → Ollama       LLM        ✓    │  │
│  │ 2026-09-13 MATH200 → OpenAI      ASR        ⚠ Fail│  │
│  │ 2026-09-13 MATH200 → Ollama       LLM        ✓    │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  Failed Operations (expandable)                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 2026-09-13 14:32 — MATH200 Lecture                  │  │
│  │ Provider: OpenAI (ASR)                               │  │
│  │ Error: Rate limited — too many requests.             │  │
│  │ Action: Retry | Fall back to local                   │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  [ Export Audit Log ]  [ Clear History ]                │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Filters section:**
- Date Range picker: Last 7 days (default), Last 30 days, Last 90 days, All time
- Provider picker: All, OpenAI, Anthropic, Grok, Z.ai, Ollama, whisper.cpp
- Modality picker: All, LLM, ASR, Vision, TTS
- Course picker: All, {list of courses from .unibrain/courses.json}
- Status picker: All, Success, Failed

**Recent Activity table:**
- Columns: Date, Note (course + type), Provider, Modality, Status
- Status: ✓ (Success) in green, ⚠ (Failed) in orange
- Tap row → opens note in Obsidian

**Failed Operations section (expandable):**
- Shows error details for each failure
- Error message (provider-specific)
- Action buttons: "Retry", "Fall back to local"

**Export Audit Log button:**
- Exports audit trail to CSV/JSON
- Saved to Desktop or user-chosen location

**Clear History button:**
- Destructive action
- Confirmation alert: "Clear all audit history? This cannot be undone."

### Copywriting

| Element | Copy |
|---------|------|
| **Tab label** | "Audit" |
| **Filters section heading** | "Filters" |
| **Date Range label** | "Date Range" |
| **Provider label** | "Provider" |
| **Modality label** | "Modality" |
| **Course label** | "Course" |
| **Status label** | "Status" |
| **Recent Activity heading** | "Recent Activity (Last 7 days)" |
| **Failed Operations heading** | "Failed Operations" |
| **Error row label** | "Error:" |
| **Action label** | "Action:" |
| **Retry button** | "Retry" |
| **Fall back to local button** | "Fall back to local" |
| **Export Audit Log button** | "Export Audit Log" |
| **Clear History button** | "Clear History" |
| **Clear confirmation** | "Clear all audit history? This cannot be undone." |

---

## Surface 7: Consent Sheet (CON-01, CON-02, CLOUD-08)

Slides down from menu-bar popover when first cloud call attempted for a `{provider}×{modality}` pair.

### Layout

```
┌─────────────────────────────────────┐
│  Allow OpenAI to transcribe this     │
│  recording?                          │
│                                      │
│  OpenAI will process your lecture    │
│  audio and generate a transcript.    │
│  Audio leaves your device during     │
│  this process.                       │
│                                      │
│  ✓ Always allow OpenAI for ASR      │
│                                      │
│  [ Only this once ]                 │
│  [ Always allow OpenAI for ASR ]   │
│  [ Cancel ]                         │
└─────────────────────────────────────┘
```

**Heading:** "Allow {Provider} to {modality-verb} this recording?"
- modality-verb: "transcribe" (ASR), "summarize" (LLM), "describe" (Vision), "speak" (TTS)

**Body:** Provider-specific explanation of what will happen
- "{Provider} will process your {content type}."
- "{Content type} leaves your device during this process."

**"Always allow" toggle:**
- Checkbox + label: "Always allow {Provider} for {modality}"
- If checked, consent persists to `.unibrain/consent.json` (CON-02)

**Buttons:**
- "Only this once": Proceeds without saving consent
- "Always allow {Provider} for {modality}": Proceeds + saves consent
- "Cancel": Blocks cloud call, returns to previous state

### Consent Scope (CON-02)

Consent is per-provider-per-modality:
- `openai×asr` (OpenAI transcription)
- `openai×llm` (OpenAI summarization)
- `anthropic×vision` (Anthropic image description)
- Each `{provider}×{modality}` pair has independent consent

### Copywriting

| Element | Copy |
|---------|------|
| **Sheet heading** | "Allow {Provider} to {modality-verb} this recording?" |
| **ASR verb** | "transcribe" |
| **LLM verb** | "summarize" |
| **Vision verb** | "describe" |
| **TTS verb** | "speak" |
| **Body (ASR)** | "{Provider} will process your lecture audio and generate a transcript. Audio leaves your device during this process." |
| **Body (LLM)** | "{Provider} will process your lecture transcript and generate a summary. Transcript leaves your device during this process." |
| **Body (Vision)** | "{Provider} will process your image and generate a description. Image leaves your device during this process." |
| **Body (TTS)** | "{Provider} will process your text and generate audio. Text leaves your device during this process." |
| **Always allow toggle** | "Always allow {Provider} for {modality}" |
| **Only this once button** | "Only this once" |
| **Always allow button** | "Always allow {Provider} for {modality}" |
| **Cancel button** | "Cancel" |

---

## Surface 8: Cloud Failure Recovery Sheet (CF-01, CF-02, CF-03)

Slides down from menu-bar popover when cloud provider fails after retries.

### Layout

```
┌─────────────────────────────────────┐
│  ⚠ Cloud processing failed          │
│                                      │
│  OpenAI rate-limited — too many     │
│  requests. Try again in a minute,    │
│  or fall back to whisper.cpp.       │
│                                      │
│  [ Retry OpenAI ]                   │
│  [ Fall back to local ]             │
│  [ Cancel recording ]               │
└─────────────────────────────────────┘
```

**Heading:** "⚠ Cloud processing failed"

**Body:** Provider-specific error message
- Rate limit: "{Provider} rate-limited — too many requests. Try again in a minute, or fall back to {local provider}."
- Network error: "{Provider} unreachable — network down. Check your connection and retry, or fall back to local."
- API key error: "API key missing or invalid. Add key in Settings → Providers, or fall back to local."
- Generic error: "{Provider} returned an error. Retry or fall back to local."

**Buttons:**
- "Retry {Provider}": Retries cloud call (respects CF-03 retry limits)
- "Fall back to local": Switches to local provider (Ollama, whisper.cpp) for this operation
- "Cancel recording": Stops current recording/pipeline (context-specific)

### Network Unreachable Variant (CF-02)

```
┌─────────────────────────────────────┐
│  ⚠ Cloud processing failed          │
│                                      │
│  {Provider} unreachable — network   │
│  down.                               │
│                                      │
│  [ Fall back to local ]             │
│  [ Cancel ]                         │
└─────────────────────────────────────┘
```

- Skips provider retries (fast-fail at 2s TCP timeout)
- No "Retry" button (network is down)
- "Cancel" button instead of "Cancel recording" (may not be in active recording)

### Copywriting

| Element | Copy |
|---------|------|
| **Sheet heading** | "Cloud processing failed" |
| **Rate limit error** | "{Provider} rate-limited — too many requests. Try again in a minute, or fall back to {local provider}." |
| **Network error** | "{Provider} unreachable — network down. Check your connection and retry, or fall back to local." |
| **API key error** | "API key missing or invalid. Add key in Settings → Providers, or fall back to local." |
| **Generic error** | "{Provider} returned an error. Retry or fall back to local." |
| **Retry button** | "Retry {Provider}" |
| **Fall back to local button** | "Fall back to local" |
| **Cancel recording button** | "Cancel recording" |
| **Cancel button** | "Cancel" |
| **Local provider names** | "whisper.cpp" (ASR), "Ollama" (LLM) |

---

## Surface 9: iOS Settings Tab (SET-03, Phase 5 IOS-01)

Read-only version of Settings for iOS. Expands Phase 5's minimal Settings tab.

### Layout

```
┌─────────────────────────────────────┐
│  Settings                           │
│                                     │
│  PROVIDERS (Read-Only)              │
│  LLM: Local (Ollama)               > |
│  ASR: Local (whisper.cpp)          > |
│  Vision: Off                       > |
│  TTS: Off                          > |
│  Configure providers on your Mac    │
│                                     │
│  COURSES (Read-Only)                │
│  Current Term: Fall 2026           > |
│  3 course mappings                 > |
│  Manage courses on your Mac         │
│                                     │
│  PERMISSIONS                        │
│  Microphone: ● On                 > |
│  Calendar: ● On                   > |
│  Vault: ~/Documents/Unibrain/      > |
│                                     │
│  AUDIT (Read-Only)                  │
│  Recent activity (Last 7 days)     > |
│  View full audit log on your Mac    │
│                                     │
│  About                              │
│  unibrain v1.0                      │
│  Local-first. Zero telemetry.      │
└─────────────────────────────────────┘
```

**Providers section:**
- Read-only display of current provider selections
- "Configure providers on your Mac" explanation (SET-03)
- Tap row → Shows alert: "Provider configuration is available on macOS. Open Settings on your Mac to change providers."

**Courses section:**
- Read-only display of current term + mapping count
- "Manage courses on your Mac" explanation
- Tap row → Same alert as Providers

**Permissions section:**
- Live status + "Open System Settings" button (same as macOS)
- Fully actionable (iOS can re-grant permissions)

**Audit section:**
- Read-only summary: "Recent activity (Last 7 days)"
- "View full audit log on your Mac" explanation
- Tap row → Same alert as Providers

### Copywriting

| Element | Copy |
|---------|------|
| **Tab label** | "Settings" |
| **Providers section heading** | "PROVIDERS (Read-Only)" |
| **Provider row labels** | "LLM: {provider}", "ASR: {provider}", "Vision: Off", "TTS: Off" |
| **Configure providers explanation** | "Configure providers on your Mac" |
| **Courses section heading** | "COURSES (Read-Only)" |
| **Current Term row** | "Current Term: {term label}" |
| **Course mappings row** | "{N} course mappings" |
| **Manage courses explanation** | "Manage courses on your Mac" |
| **Permissions section heading** | "PERMISSIONS" |
| **Audit section heading** | "AUDIT (Read-Only)" |
| **Recent activity row** | "Recent activity (Last 7 days)" |
| **View audit explanation** | "View full audit log on your Mac" |
| **Configuration alert** | "Provider configuration is available on macOS. Open Settings on your Mac to change providers." |

---

## Copywriting Contract

Inherits Phase 3/4/5 tone: calm, brief, no exclamation marks. Angelica is configuring cloud providers or auditing failures — she needs information, not personality.

| Element | Copy |
|---------|------|
| **Settings — General tab label** | "General" |
| **Settings — Providers tab label** | "Providers" |
| **Settings — Courses tab label** | "Courses" |
| **Settings — Permissions tab label** | "Permissions" |
| **Settings — Audit tab label** | "Audit" |
| **Empty state — Audit tab** | "No cloud activity yet" |
| **Empty state body — Audit tab** | "Cloud provider activity will appear here after you enable providers in Settings." |
| **Error state — API key invalid** | "API key missing or invalid. Add key in Settings → Providers." |
| **Error state — Ollama not detected** | "Ollama not detected. Download and install Ollama to enable local summarization." |
| **Destructive confirmation — Remove API key** | "Remove API key for {Provider}? Cloud operations using this provider will fail until you re-add the key." |
| **Destructive confirmation — Clear audit history** | "Clear all audit history? This cannot be undone." |
| **Destructive confirmation — Delete failed recording** | "Delete this recording permanently? This cannot be undone." |
| **Consent sheet heading** | "Allow {Provider} to {modality-verb} this recording?" |
| **Consent sheet body** | "{Provider} will process your {content type}. {Content type} leaves your device during this process." |
| **Consent — Only this once** | "Only this once" |
| **Consent — Always allow** | "Always allow {Provider} for {modality}" |
| **Consent — Cancel** | "Cancel" |
| **Cloud failure heading** | "Cloud processing failed" |
| **Cloud failure — Retry** | "Retry {Provider}" |
| **Cloud failure — Fall back** | "Fall back to local" |
| **Cloud failure — Cancel** | "Cancel" |
| **Primary CTA — Download Ollama** | "Download Ollama" |
| **Primary CTA — Pull model** | "Pull llama-3.2:3b (~2GB)" |
| **Primary CTA — Re-check** | "Re-check" |

**Pronouns:** always "your" (provider, settings, recording, device), never "the" — reinforces ownership in a single-user app.

**Tone exceptions:** None. Phase 6 is configuration and audit — neutral throughout.

---

## Interaction Contracts

### Settings Window Opening (SET-01)

```
menu-bar popover ──[tap Settings…]──→ Settings window opens (macOS)
menu-bar popover ──[⌘, shortcut]────→ Settings window opens (macOS)
menu-bar popover ──[post-failure]────→ Settings opens to Audit tab (context-aware)
menu-bar popover ──[permission warning]→ Settings opens to Permissions tab (context-aware)
```

**Context-aware tab selection (SET-04):**
- Post-recording failure: Opens Audit tab
- Permission denied banner: Opens Permissions tab
- Provider-related issue: Opens Providers tab

### Provider Configuration Flow

```
Providers tab ──[select cloud provider]──→ API key entry appears
API key entry ──[enter valid key]────→ Validation checkmark ✓
API key entry ──[tap Remove]────────→ Confirmation sheet
Remove confirm ──[confirm]──────────→ Key cleared from Keychain
```

**Key validation:**
- OpenAI: Starts with `sk-`
- Anthropic: Starts with `sk-ant-`
- Grok/Z.ai: Provider-specific patterns (planner defines)
- Validation runs on text change, shows checkmark when pattern matches

### Consent Flow (CON-01, CON-02)

```
First cloud call ──[no consent record]──→ Consent sheet slides down
Consent sheet ──[Only this once]──────→ Proceeds (consent not saved)
Consent sheet ──[Always allow]────────→ Proceeds + saves to consent.json
Consent sheet ──[Cancel]──────────────→ Blocks cloud call
Next cloud call ──[consent exists]────→ Skips sheet, proceeds directly
```

**Consent storage (CON-03):**
- File: `.unibrain/consent.json` in vault
- iCloud Drive syncs between devices
- Format: `{provider: {modality: {always_allow: bool, first_consented_at: ISO8601}}}`

### Cloud Failure Recovery (CF-01, CF-02, CF-03)

```
Cloud call ──[network check fails]──→ Fast-fail sheet (2s timeout)
Cloud call ──[provider retries exhaust]→ Failure sheet
Failure sheet ──[Retry Provider]────→ Re-attempt cloud call
Failure sheet ──[Fall back to local]─→ Switch to local provider
Failure sheet ──[Cancel]────────────→ Stop operation
```

**Retry composition (CF-03):**
- Provider inner: 3 attempts (2s, 8s, 30s backoff)
- Queue outer: 30s, 2min, 10min for iCloud inbox files
- Live recordings: Provider retries only (no queue retry)

### Ollama Setup Flow (OLL-01, OLL-03)

```
Enable Summarization ──[select Local]──→ Health check runs
Health check ──[fails]──────────────→ Ollama not detected callout
Callout ───[Download Ollama]────────→ Opens ollama.com
Callout ───[Re-check]──────────────→ Re-runs health check
Health check ──[passes, model missing]→ Model not pulled callout
Callout ───[Pull model]─────────────→ Fires ollama pull via Process
Progress ──[streams]────────────────→ Progress bar updates
Pull ──────[completes]──────────────→ Summarization enabled
```

### Audit Query Flow

```
Audit tab opens ──[default filters]────→ Show last 7 days, all providers
User ──────────[apply filters]──────→ Update table with filtered results
Failed row ────[expand]──────────────→ Show error details + actions
Retry ─────────[tap]────────────────→ Re-attempt operation
Fall back ─────[tap]────────────────→ Switch to local provider
Export ─────────[tap]───────────────→ Save audit log to file
Clear history ──[tap + confirm]─────→ Delete all audit records
```

---

## Component Inventory (for planner)

New SwiftUI views/components Phase 6 introduces (planner allocates these as tasks):

| Component | File (suggested) | Lines (est.) | Source |
|-----------|-------------------|--------------|--------|
| `SettingsScene` (macOS) | `UnibrainApp/Settings/SettingsScene.swift` | 60-80 | SET-01 |
| `GeneralTab` | `UnibrainApp/Settings/GeneralTab.swift` | 80-100 | SET-01, OLL-02..04 |
| `ProvidersTab` | `UnibrainApp/Settings/ProvidersTab.swift` | 120-150 | SET-02, CLOUD-01..02 |
| `ProviderPickerRow` | `UnibrainApp/Settings/ProviderPickerRow.swift` | 40-60 | CLOUD-01 |
| `APIKeyEntryRow` | `UnibrainApp/Settings/APIKeyEntryRow.swift` | 50-70 | CLOUD-07 |
| `CoursesTab` | `UnibrainApp/Settings/CoursesTab.swift` | 60-80 | SET-04, Phase 4 M-04 |
| `PermissionsTab` | `UnibrainApp/Settings/PermissionsTab.swift` | 80-100 | SET-04, Phase 5 ONB-04 |
| `AuditTab` | `UnibrainApp/Settings/AuditTab.swift` | 100-120 | CF-04, CON-04 |
| `AuditFiltersForm` | `UnibrainApp/Settings/AuditFiltersForm.swift` | 40-60 | CF-04 |
| `ConsentSheet` | `UnibrainApp/Settings/ConsentSheet.swift` | 50-70 | CON-01 |
| `CloudFailureSheet` | `UnibrainApp/Settings/CloudFailureSheet.swift` | 50-70 | CF-01 |
| `OllamaSetupCallout` | `UnibrainApp/Settings/OllamaSetupCallout.swift` | 40-50 | OLL-01 |
| `ModelPullCallout` | `UnibrainApp/Settings/ModelPullCallout.swift` | 50-60 | OLL-03 |
| `iOSSettingsTab` (expanded) | `UnibrainApp/Views/iOS/iOSSettingsTab.swift` | +80 | SET-03 |
| `ConsentStore` actor | `Sources/UnibrainProviders/Consent/ConsentStore.swift` | 60-80 | CON-03 |
| `ConsentModels` | `Sources/UnibrainProviders/Consent/ConsentModels.swift` | 30-40 | CON-03 |
| `APIKeyStore` wrapper | `Sources/UnibrainProviders/Keychain/APIKeyStore.swift` | 80-100 | CLOUD-07 |
| `TCPReachability` wrapper | `Sources/UnibrainProviders/Reachability/TCPReachability.swift` | 40-60 | CF-02 |
| `OllamaHealthCheck` | `Sources/UnibrainProviders/Ollama/OllamaHealthCheck.swift` | 30-40 | OLL-01 |
| `OllamaModelPull` | `Sources/UnibrainProviders/Ollama/OllamaModelPull.swift` | 50-60 | OLL-03 |
| `UnibrainApp` update | `UnibrainApp/UnibrainApp.swift` | +60 | Settings scene, iOS Settings tab |
| `MenuBarPopover` extension | `UnibrainApp/MenuBarPopover.swift` | +40 | Settings… button, sheet attachments |

**Estimated total new SwiftUI:** ~1,200-1,500 lines across ~14 new view files + ~400 lines of Settings-specific logic + ~300 lines of provider infrastructure = ~1,900 lines total.

**iOS-only views** sit behind `#if os(iOS)` guards. Settings window is macOS-only (`Settings` scene is unavailable on iOS).

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| SwiftUI (system) | `Settings`, `TabView`, `Form`, `List`, `Section`, `SecureField`, `Picker`, `ProgressView`, `Label`, `Button`, `Alert`, `Sheet`, `NavigationStack` | not required (Apple framework — no third-party audit needed) |
| Security (system) | Keychain APIs for API key storage | not required (Apple framework — macOS/iOS secure storage) |
| Network (system) | `NWConnection` for TCP reachability checks | not required (Apple framework — network diagnostics) |
| Third-party SPM | (none in Phase 6 UI layer) | not applicable |

**No web registry components used.** This is a native SwiftUI app — shadcn/ui, Radix, base-ui are not applicable. Registry safety checks pass vacuously.

---

## Platform-Specific Notes (for planner)

### Info.plist Keys (iOS — planner writes actual strings)

- No new keys required for Phase 6 (Phase 5 already has all permissions)

### macOS Entitlements

- `com.apple.security.keychain-access-groups` — already standard for sandboxed Mac apps
- No new entitlements required for Keychain (default access is sufficient)

### Deployment Target

- macOS 26 Tahoe (D-05) — unlocks `Settings` scene, modern Keychain APIs
- iOS 17 (D-05) — unlocks `@Observable`, modern SwiftUI

### Apple Developer Program

- Phase 6 works WITHOUT paid Apple Developer Program membership (no new entitlements)
- TestFlight to Angelica's iPhone requires paid membership ($99/yr) — already required for Phase 5

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS — all Settings tab copy, consent sheet text, failure messages, audit labels have explicit copy. Tone inherited from Phase 3/4/5.
- [ ] Dimension 2 Visuals: PASS — every surface has ASCII mock + component spec + interaction contract
- [ ] Dimension 3 Color: PASS — semantic system colors, accent/warning/destructive reserved explicitly, iOS/macOS variants noted
- [ ] Dimension 4 Typography: PASS — SF Pro semantic styles, Settings roles declared, monospaced API key display, 2 weights enforced (regular/semibold)
- [ ] Dimension 5 Spacing: PASS — 4pt-multiple scale inherited from Phase 3/4/5, Settings window size documented, iOS full-screen documented
- [ ] Dimension 6 Registry Safety: PASS — native SwiftUI + Security/Network frameworks only, no web registry applicable

**Approval:** pending (checker review)

---

*Phase: 6 — Gated Summarization + Cloud Providers + MVP Polish*
*UI-SPEC generated: 2026-07-16*
*Sources: 06-CONTEXT.md (SET-01..04, CON-01..04, CF-01..04, OLL-01..04) + 05-UI-SPEC.md (inherited design tokens) + Apple HIG for Settings patterns + REQUIREMENTS.md (SUMM-01..07, CLOUD-01..13)*
