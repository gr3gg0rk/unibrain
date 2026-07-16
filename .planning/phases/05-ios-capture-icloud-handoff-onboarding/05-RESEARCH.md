# Phase 5: iOS Capture + iCloud Handoff + Onboarding - Research

**Researched:** 2026-07-15
**Domain:** iOS background audio recording, iCloud Drive file handoff, SwiftUI onboarding wizard, NSMetadataQuery file watching
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **IC-01: Picker-only — no iCloud container entitlement.** The app does NOT use `NSUbiquitousContainers` or iCloud Documents capability. The onboarding vault picker lets Angelica pick any folder, defaulting to iCloud Drive root. Security-scoped bookmark persists the choice per-device in Keychain.
- **IC-02: Sandbox-first recording, move on Stop.** iPhone's `AVAudioRecorder` writes to its own sandbox `tmp/recordings/{uuid}.m4a` during active recording. On Stop, the app performs an atomic move into the picked iCloud Drive folder's `_inbox/` subfolder.
- **IC-03: Timestamp + source-prefix filenames.** `_inbox/` audio files are named `{source}-{YYYYMMDDTHHMMSS}-{shortUUID}.m4a`.
- **IC-04: Active download + wait for `.icloud` placeholders.** When macOS detects an `_inbox/` file that is a `.icloud` placeholder, the pipeline calls `URL.startDownloadingUbiquitousItem()` to force iCloud to fetch the file, polls `URLResourceKey.ubiquitousItemDownloadingStatusKey` until `.current`, then proceeds.
- **IOS-01: TabView with Record / Recent / Settings.** iOS app shell is a three-tab `TabView` at the bottom.
- **IOS-02: Now Playing + remote commands only.** `MPNowPlayingInfoCenter` pushes recording state to lock screen. `MPRemoteCommandCenter` handles Stop/Pause from lock screen. Live Activity / Dynamic Island deferred to Phase 6.
- **IOS-03: Pause + auto-resume on interruption.** When iOS interrupts the audio session, pause recording. On interruption end, automatically resume.
- **IOS-04: Expanded Phase 3 layout for Record tab.** iOS gets Phase 3 macOS popover components scaled up to full-screen.
- **TRIG-01: NSMetadataQuery + launch scan (hybrid).** While macOS app runs, `NSMetadataQuery` watches `{vault}/_inbox/`. On app launch, a one-shot scan catches missed files.
- **TRIG-02: Serial FIFO queue.** Discovered files enqueue; queue processor pops one file at a time, FIFO.
- **TRIG-03: Move audio to final course folder on success.** After pipeline writes the note, source audio moves from `_inbox/` to `{vault}/{term}/{course-code}/`.
- **TRIG-04: Retry-with-backoff + dead-letter on failure.** Queue retries 3 times (30s, 2min, 10min). On final failure, moves to `_inbox/_failed/` with error-log sidecar.
- **ONB-01: macOS-first, iOS inherits.** macOS onboarding runs first. iOS detects `.unibrain/courses.json` inside picked iCloud Drive folder and inherits `currentTerm` + course mapping.
- **ONB-02: PageTabView + progress dots.** Onboarding UI is a SwiftUI `TabView` with `.tabViewStyle(.page)`.
- **ONB-03: Folder picker with iCloud default.** SwiftUI `.fileImporter` with `.folder` content type. Security-scoped bookmark persisted in Keychain.
- **ONB-04: Dedicated Permissions sheet (ONBD-05).** Phase 5 ships minimal but complete Permissions UI.

### Claude's Discretion

- iOS sandbox `tmp/recordings/` path
- `shortUUID` format (4-char hex suffix)
- AVAudioSession category specifics (likely `.playAndRecord` with `.defaultToSpeaker` and `.allowBluetoothA2DP`)
- `Info.plist` keys — exact strings for `NSMicrophoneUsageDescription`, `NSCalendarsUsageDescription`, `UIBackgroundModes`
- `MPNowPlayingInfoCenter` artwork / metadata
- Queue processor persistence (in-memory vs disk)
- Backoff schedule (30s/2min/10min suggested)
- Dead-letter sidecar JSON schema
- Welcome page content / copy
- Term input UI (TextField + DatePicker)
- macOS onboarding surface (full window vs sheet)
- iOS onboarding detection via `UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")`
- Security-scoped bookmark lifecycle on iOS (stale bookmark re-prompt flow)

### Deferred Ideas (OUT OF SCOPE)

- Full Settings UI (per-modality provider selectors) -> Phase 6
- iCloud container (`NSUbiquitousContainers`) -> Phase 6 or later
- Live Activity / Dynamic Island -> Phase 6 polish
- iPad-optimized sidebar layout -> v2
- iPhone transcription (SpeechAnalyzer on-device) -> v2
- Cloud ASR providers -> Phase 6
- Background-task upload via `BGProcessingTask` -> Phase 5 uses foreground move-on-Stop
- AirDrop fallback -> Phase 6 or v2
- Multi-iPhone support -> v2
- iCloud Drive sync conflict UI -> relies on Phase 2 atomic writes
- Apple Watch companion app -> v2
- Action Button / Lock Screen widget (CAPT-07) -> v2
- Hands-free bookmark (CAPT-08) -> v2
- Audio-transcript playback sync (CAPT-09) -> v2

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CAPT-03 | Background recording on iOS using `AVAudioSession` background audio mode with lock-screen recording indicator | AVAudioSession `.playAndRecord` + `UIBackgroundModes: ["audio"]` + `MPNowPlayingInfoCenter` for lock-screen display |
| ONBD-01 | First-run flow: welcome -> vault folder picker -> mic permission -> calendar permission -> current-term label -> ready | SwiftUI `TabView` with `.page` style, 6 pages on macOS / 5 on iOS (term inherited) |
| ONBD-04 | Vault folder picker suggests iCloud Drive location; any user-chosen folder works | `.fileImporter` with `UTType.folder`; default to iCloud Drive root; security-scoped bookmark persistence |
| ONBD-05 | Permissions screen accessible post-onboarding for re-grant or audit | Dedicated SwiftUI PermissionsSheet with live status + "Open System Settings" deep-link |
| DISC-04 | App survives iOS backgrounding during an active recording | `UIBackgroundModes: audio` keeps app alive while `AVAudioSession` is active; interruption handler auto-resumes |
</phase_requirements>

## Summary

Phase 5 is the most platform-diverse phase yet: it adds a full iOS app surface, an iCloud Drive file-handoff pipeline, and a first-run onboarding wizard. The technical risk is concentrated in three areas: (1) iOS background audio recording that survives 30+ minutes of locked-screen time — this depends on correct `AVAudioSession` configuration, `UIBackgroundModes` declaration, and interruption handling; (2) iCloud Drive file monitoring via `NSMetadataQuery` on macOS, which must detect new files, trigger downloads for `.icloud` placeholders, and feed them into the existing pipeline; (3) the security-scoped bookmark lifecycle for persisting user-picked folder access across app launches on both platforms.

The existing codebase is well-positioned for Phase 5. The `AudioRecorder` and `RecordingSession` from Phase 3 already compile with `#if os(iOS)` guards for `AVAudioSession`. The `EventKitCalendarAdapter` from Phase 4 already works cross-platform. The `PipelineOrchestrator` is platform-agnostic. Phase 5's work is primarily in the `UnibrainApp` target (new iOS views, onboarding flow, permissions sheet) and a new `InboxWatcher` component in `UnibrainProviders` (macOS-only `NSMetadataQuery` wrapper + serial queue processor).

No new external packages are needed. Everything uses Apple built-in frameworks: `AVFoundation`, `MediaPlayer`, `Foundation` (`NSMetadataQuery`, `URL.startDownloadingUbiquitousItem`), `SwiftUI`, `EventKit`, `UniformTypeIdentizers`, and `Security` (Keychain).

**Primary recommendation:** Build in three waves — (1) iOS capture surface (TabView + background recording + Now Playing), (2) macOS inbox watcher pipeline (NSMetadataQuery + serial queue + retry/dead-letter), (3) cross-platform onboarding flow (PageTabView wizard + folder picker + permissions sheet). The inbox watcher is the riskiest component; the onboarding is the most code but lowest risk.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| iOS audio recording (CAPT-03) | Client (iOS app) | — | AVAudioRecorder runs on-device; iPhone is capture-only |
| Background survival (DISC-04) | Client (iOS app) | — | `UIBackgroundModes: audio` is an iOS app-level configuration |
| Lock-screen Now Playing (IOS-02) | Client (iOS app) | — | `MPNowPlayingInfoCenter` is iOS system framework; macOS uses menu bar |
| iCloud file handoff | Client (both) | macOS Backend | iPhone writes to iCloud folder; macOS watches + processes |
| Inbox file watching (TRIG-01) | macOS Backend | — | `NSMetadataQuery` runs on macOS where transcription happens |
| Serial queue processing (TRIG-02) | macOS Backend | — | Queue invokes `PipelineOrchestrator` per file; macOS-only |
| Onboarding wizard (ONBD-01) | Client (both platforms) | — | SwiftUI views per platform; macOS gets 6 pages, iOS gets 5 |
| Folder picker (ONBD-04) | Client (both platforms) | — | `.fileImporter` on both; bookmark persistence per-device |
| Permissions sheet (ONBD-05) | Client (both platforms) | — | SwiftUI sheet; platform-specific deep-links |
| Config inheritance (ONB-01) | Client (iOS app) | Storage (iCloud Drive) | iOS reads `.unibrain/courses.json` from iCloud-synced folder |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AVFoundation | iOS 17+ / macOS 14+ | Audio recording (`AVAudioRecorder`, `AVAudioSession`) | Apple's standard audio API. Already used in Phase 3. `[CITED: developer.apple.com/documentation/avfaudio]` |
| MediaPlayer | iOS 17+ | Lock-screen Now Playing (`MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`) | Apple's only API for lock-screen media metadata and remote commands. `[CITED: developer.apple.com/documentation/mediaplayer]` |
| Foundation | iOS 17+ / macOS 14+ | iCloud file watching (`NSMetadataQuery`), ubiquitous downloads (`FileManager.startDownloadingUbiquitousItem`), security-scoped bookmarks | Built-in framework; no alternative. `[CITED: developer.apple.com/documentation/foundation/nsmetadataquery]` |
| SwiftUI | iOS 17+ / macOS 14+ | Onboarding wizard (`TabView` + `.page` style), iOS TabView shell, Permissions sheet | Apple's declarative UI framework; already used. `[CITED: developer.apple.com/documentation/swiftui/tabview]` |
| EventKit | iOS 17+ / macOS 14+ | Calendar permission flow on iOS | Already integrated in Phase 4; `requestFullAccessToEvents` works cross-platform. `[CITED: developer.apple.com/documentation/eventkit]` |
| UniformTypeIdentifiers | iOS 14+ / macOS 11+ | `UTType.folder` for `.fileImporter` content type | Apple standard for type identifiers. `[CITED: developer.apple.com/documentation/uniformtypeidentifiers]` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Security (Keychain) | Built-in | Persist security-scoped bookmarks across launches | Storing folder access bookmark data per-device. `[ASSUMED]` — standard pattern but exact Keychain API not verified in this session |
| UserNotifications | iOS 17+ / macOS 14+ | Local notifications for queue events | Already used in Phase 3 for transcription-complete alerts; extend for inbox-arrived/failed notifications. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `MPNowPlayingInfoCenter` | `ActivityKit` Live Activity | Live Activity gives Dynamic Island widget; but IOS-02 defers this to Phase 6 — more code, custom widget extension, marginal MVP gain |
| `NSMetadataQuery` | `DispatchSource` (filesystem events) | `DispatchSource` watches local filesystem but is NOT iCloud-aware (cannot detect `.icloud` -> real-file transitions); `NSMetadataQuery` is Apple's standard for iCloud file watching |
| Security-scoped bookmarks | iCloud container entitlement | Entitlement requires Apple Developer Program membership ($99/yr); IC-01 picker-only path avoids this dependency. Bookmarks are more work but unblock Phase 5. |
| `.fileImporter` | `NSOpenPanel` (macOS) / `UIDocumentPickerViewController` (iOS) | `.fileImporter` is the SwiftUI cross-platform wrapper; `NSOpenPanel` works only on macOS. Use `.fileImporter` for shared code, fall back to `NSOpenPanel` for macOS-specific features if needed. |

**Installation:**
No new packages to install. All frameworks are Apple built-ins already linked via the Xcode app target.

## Package Legitimacy Audit

Not applicable — Phase 5 installs zero external packages. All frameworks are Apple built-in (AVFoundation, MediaPlayer, Foundation, SwiftUI, EventKit, UniformTypeIdentifiers, Security, UserNotifications).

## Architecture Patterns

### System Architecture Diagram

```
iPhone (Capture Surface)                      macOS (Processing Surface)
┌─────────────────────────────┐               ┌──────────────────────────────────┐
│  iOS App (TabView)          │               │  macOS App (MenuBarExtra)        │
│                             │               │                                  │
│  Record Tab                 │               │  ┌─────────────────────────┐     │
│  ┌───────────────────┐      │               │  │ InboxWatcher            │     │
│  │ AVAudioRecorder   │      │               │  │ (NSMetadataQuery)       │     │
│  │ -> sandbox tmp/   │      │               │  │  watches _inbox/       │     │
│  └───────┬───────────┘      │               │  └────────┬────────────────┘     │
│          │ On Stop          │               │           │ new file detected    │
│          v                  │               │           v                      │
│  ┌───────────────────┐      │               │  ┌─────────────────────────┐     │
│  │ Atomic move to    │      │   iCloud      │  │ Serial FIFO Queue       │     │
│  │ iCloud Drive      │──────│──────────────│──>│  IC-04: download .icloud│     │
│  │ _inbox/           │      │   Drive       │  │  TRIG-02: pop one file  │     │
│  │ {source}-{ts}.m4a │      │   Sync        │  └────────┬────────────────┘     │
│  └───────────────────┘      │               │           │                      │
│                             │               │           v                      │
│  Now Playing (lock screen)  │               │  ┌─────────────────────────┐     │
│  MPNowPlayingInfoCenter     │               │  │ PipelineOrchestrator    │     │
│  MPRemoteCommandCenter      │               │  │  transcribe -> classify │     │
│                             │               │  │  -> normalize -> write  │     │
│  Onboarding (5 pages)       │               │  └────────┬────────────────┘     │
│  Welcome -> Vault -> Mic    │               │           │ success              │
│  -> Calendar -> Ready       │               │           v                      │
│  (inherits courses.json)    │               │  ┌─────────────────────────┐     │
│                             │               │  │ TRIG-03: Move audio to  │     │
│  Permissions Sheet          │               │  │ {term}/{course}/        │     │
│  (ONBD-05)                  │               │  └─────────────────────────┘     │
└─────────────────────────────┘               │                                  │
                                               │  Onboarding (6 pages)            │
                                               │  Welcome -> Vault -> Mic ->      │
                                               │  Calendar -> Term -> Ready       │
                                               │                                  │
                                               │  Permissions Sheet (ONBD-05)     │
                                               └──────────────────────────────────┘
```

### Recommended Project Structure
```
UnibrainApp/
├── UnibrainApp.swift           # MODIFIED: add iOS TabView, onboarding entry
├── ContentView.swift           # MODIFIED: conditional onboarding vs main view
├── MenuBarPopover.swift        # MODIFIED: add inbox progress + Permissions button
├── Info.plist                  # MODIFIED: add UIBackgroundModes, NSMicrophoneUsageDescription
├── iOS/
│   ├── iOSTabView.swift        # NEW: Record/Recent/Settings TabView shell
│   ├── RecordTab.swift         # NEW: iOS full-screen recording UI
│   ├── RecentTab.swift         # NEW: read-only notes list from vault scan
│   ├── SettingsTab.swift       # NEW: minimal placeholder with Permissions entry
│   └── NowPlayingManager.swift # NEW: MPNowPlayingInfoCenter + MPRemoteCommandCenter
├── Onboarding/
│   ├── OnboardingFlow.swift    # NEW: TabView(.page) wizard controller
│   ├── WelcomePage.swift       # NEW: app icon + value prop
│   ├── VaultPickerPage.swift   # NEW: fileImporter + iCloud default
│   ├── PermissionPage.swift    # NEW: mic/calendar permission requests
│   ├── TermLabelPage.swift     # NEW: macOS-only term input (iOS skips)
│   └── ReadyPage.swift         # NEW: completion + dismiss
├── Views/
│   ├── PermissionsSheet.swift  # NEW: ONBD-05 live status + Settings deep-link
│   └── ... (existing Phase 4 views)
└── ViewModels/
    ├── MenuBarViewModel.swift  # MODIFIED: add inbox queue state + Permissions
    ├── OnboardingViewModel.swift # NEW: drives onboarding state machine
    └── ... (existing)

Sources/UnibrainProviders/
├── Inbox/
│   ├── InboxWatcher.swift      # NEW: NSMetadataQuery wrapper (macOS-only)
│   ├── InboxQueue.swift        # NEW: serial FIFO queue processor actor
│   ├── InboxFileDownloader.swift # NEW: IC-04 .icloud download + poll
│   └── DeadLetterHandler.swift  # NEW: TRIG-04 retry + dead-letter
├── Security/
│   └── BookmarkStore.swift     # NEW: security-scoped bookmark persistence
├── Capture/
│   ├── AudioRecorder.swift     # MODIFIED: add iOS interruption handling
│   └── RecordingSession.swift  # (unchanged — already cross-platform)
└── ... (existing)

Sources/UnibrainCore/
├── Errors/
│   └── NoteWriterError.swift   # MODIFIED: add .iCloudDownloadTimedOut case
└── ... (existing)
```

### Pattern 1: iOS Background Audio Session Configuration
**What:** Configure `AVAudioSession` for background recording that survives lock screen.
**When to use:** Every time iOS recording starts.
**Example:**
```swift
// Source: [CITED: developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record]
// and [CITED: developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes]
#if os(iOS)
let session = AVAudioSession.sharedInstance()
try session.setCategory(
    .playAndRecord,
    mode: .default,
    options: [.defaultToSpeaker, .allowBluetoothA2DP]
)
try session.setActive(true)
#endif
```
The critical requirement: `UIBackgroundModes` must contain `audio` in Info.plist. Without it, iOS will suspend the app within ~30 seconds of backgrounding. With it, the active audio session is the app's "reason to stay alive" in the background. `[CITED: developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record]`

### Pattern 2: AVAudioSession Interruption Handling
**What:** Pause recording on interruption (phone call, Siri), auto-resume when interruption ends.
**When to use:** During iOS recording, observe interruption notifications.
**Example:**
```swift
// Source: [CITED: developer.apple.com/documentation/avfaudio/handling-audio-interruptions]
NotificationCenter.default.addObserver(
    forName: AVAudioSession.interruptionNotification,
    object: nil,
    queue: nil
) { notification in
    guard let info = notification.userInfo,
          let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
        return
    }

    switch type {
    case .began:
        // Pause recording — another app stole the audio session
        Task { try? await session.pause() }
    case .ended:
        // Per IOS-03: auto-resume
        let options = AVAudioSession.InterruptionOptions(
            rawValue: info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        )
        if options.contains(.shouldResume) {
            Task {
                try? AVAudioSession.sharedInstance().setActive(true)
                try? await session.resume()
            }
        }
    @unknown default:
        break
    }
}
```
**Pitfall:** iOS may kill the app during a long interruption. The queue processor's failure path (TRIG-04) catches this — the sandbox temp file persists and can be recovered on next launch. `[CITED: developer.apple.com/documentation/avfaudio/handling-audio-interruptions]`

### Pattern 3: MPNowPlayingInfoCenter for Recording State
**What:** Push recording metadata to the iOS lock screen.
**When to use:** While iOS recording is active.
**Example:**
```swift
// Source: [CITED: developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter]
import MediaPlayer

func updateNowPlaying(elapsed: TimeInterval) {
    var info: [String: Any] = [:]
    info[MPMediaItemPropertyTitle] = "Recording"
    info[MPMediaItemPropertyArtist] = "unibrain"
    info[MPMediaItemPropertyPlaybackDuration] = elapsed
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
    info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
}

// Source: [CITED: developer.apple.com/documentation/mediaplayer/mpremotecommandcenter]
let commandCenter = MPRemoteCommandCenter.shared()
commandCenter.pauseCommand.addTarget { _ in
    Task { try? await recordingSession.pause() }
    return .success
}
commandCenter.togglePlayPauseCommand.addTarget { event in
    // Handle Stop from lock screen
    return .success
}
```
The lock screen shows "Recording — {elapsed}" and provides pause/stop controls. `[CITED: developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter]`

### Pattern 4: NSMetadataQuery for iCloud File Watching
**What:** Watch `_inbox/` for new files arriving via iCloud Drive sync.
**When to use:** On macOS app launch + while app is running.
**Example:**
```swift
// Source: [CITED: developer.apple.com/documentation/foundation/nsmetadataquery]
// and [CITED: developer.apple.com/documentation/uikit/synchronizing-documents-in-the-icloud-environment]
let metadataQuery = NSMetadataQuery()
metadataQuery.searchScopes = [
    NSMetadataQueryUbiquitousDocumentsScope
]
// Predicate scoped to _inbox folder
metadataQuery.predicate = NSPredicate(
    format: "%K BEGINSWITH %@",
    NSMetadataItemPathKey,
    inboxURL.path
)
metadataQuery.sortDescriptors = [
    NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: true)
]

// Listen for new files
NotificationCenter.default.addObserver(
    forName: .NSMetadataQueryDidUpdate,
    object: metadataQuery,
    queue: .main
) { notification in
    // Extract new files from notification
    if let added = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] {
        for item in added {
            let url = item.value(forAttribute: NSMetadataItemURLKey) as! URL
            // Enqueue for processing
        }
    }
}

metadataQuery.start()
```
**Key insight:** `NSMetadataQuery` is iCloud-aware — it detects when `.icloud` placeholder files transition to real downloaded files. This pairs naturally with IC-04's active download logic. `[CITED: developer.apple.com/documentation/foundation/nsmetadataquery]`

### Pattern 5: Security-Scoped Bookmark Persistence
**What:** Persist folder access across app launches using security-scoped bookmarks.
**When to use:** After user picks a vault folder in onboarding.
**Example:**
```swift
// Source: [CITED: developer.apple.com/documentation/foundation/url#2870281]
// and [CITED: avanderlee.com/swift/security-scoped-bookmarks-for-url-access]

// Save bookmark after folder pick
func saveBookmark(for url: URL) throws {
    let bookmarkData = try url.bookmark(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )
    // Store in Keychain (not UserDefaults — bookmarks are sensitive)
    try KeychainHelper.save(bookmarkData, forKey: "vault_bookmark")
}

// Resolve bookmark on app launch
func resolveBookmark() -> URL? {
    guard let data = KeychainHelper.load(forKey: "vault_bookmark") else {
        return nil
    }
    var isStale = false
    do {
        let url = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale {
            // Bookmark expired — user must re-pick folder
            return nil
        }
        _ = url.startAccessingSecurityScopedResource()
        return url
    } catch {
        return nil
    }
}
```
**Critical:** Call `url.startAccessingSecurityScopedResource()` before using the URL and `url.stopAccessingSecurityScopedResource()` when done. On iOS, bookmarks can become stale if the user renames/moves the folder in the Files app — the app must catch the stale-bookmark case and re-prompt. `[CITED: developer.apple.com/documentation/foundation/url#2870281]`

### Pattern 6: SwiftUI Onboarding with TabView Page Style
**What:** Swipeable onboarding wizard with progress dots.
**When to use:** First app launch.
**Example:**
```swift
// Source: [CITED: developer.apple.com/documentation/swiftui/tabviewstyle/page(indexdisplaymode:)]
struct OnboardingFlow: View {
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        TabView {
            WelcomePage()
            VaultPickerPage()
            PermissionPage()
            #if os(macOS)
            TermLabelPage()
            #endif
            ReadyPage(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}
```
On macOS, the same `TabView(.page)` renders as a paged view (typically in a sheet or window). iOS gets swipeable pages with progress dots. `[CITED: developer.apple.com/documentation/swiftui/tabviewstyle/page(indexdisplaymode:)]`

### Pattern 7: .fileImporter for Folder Picking
**What:** SwiftUI cross-platform folder picker.
**When to use:** Onboarding vault picker step.
**Example:**
```swift
// Source: [CITED: developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncancel:)]
import UniformTypeIdentifiers

.fileImporter(
    isPresented: $showingPicker,
    allowedContentTypes: [.folder],
    allowsMultipleSelection: false
) { result in
    switch result {
    case .success(let urls):
        guard let url = urls.first else { return }
        // Gain security-scoped access
        _ = url.startAccessingSecurityScopedResource()
        // Persist bookmark for future launches
        try? saveBookmark(for: url)
        selectedVaultURL = url
    case .failure:
        // User cancelled or error
        break
    }
}
```
`[CITED: developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncancel:)]`

### Anti-Patterns to Avoid
- **Direct-to-iCloud recording:** Writing `AVAudioRecorder` output directly to an iCloud Drive folder is unreliable — iCloud may refuse writes under storage pressure, partial-file uploads corrupt iCloud state, and crash mid-recording leaves iCloud in a bad state. Use IC-02 sandbox-first-then-move instead. `[ASSUMED]`
- **Ignoring `AVAudioSession` interruptions:** If the app doesn't observe `interruptionNotification`, a phone call will silently stop the recording. IOS-03 mandates auto-resume. `[CITED: developer.apple.com/documentation/avfaudio/handling-audio-interruptions]`
- **Using `FileManager` directory listing instead of `NSMetadataQuery`:** Plain `FileManager.enumerator` does NOT detect iCloud placeholder-to-real-file transitions. `NSMetadataQuery` is the only iCloud-aware file watcher. `[CITED: developer.apple.com/documentation/foundation/nsmetadataquery]`
- **Treating `.icloud` placeholders as errors on the iCloud-handoff path:** Phase 2 A-03's hard-error-on-placeholder contract is correct for non-iCloud destinations but wrong for the Phase 5 `_inbox/` path where placeholders are expected. IC-04 amends this — the planner must make the distinction explicit. `[VERIFIED: codebase — NSFileCoordinatorNoteWriter.swift throws `iCloudPlaceholder` on detection]`
- **Forgetting `UIBackgroundModes: ["audio"]` in Info.plist:** Without this key, iOS kills the background audio session within ~30 seconds. This is the #1 cause of "recording stops on lock screen" bugs. `[CITED: developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record]`
- **Storing bookmarks in UserDefaults:** Security-scoped bookmarks grant filesystem access. Store them in Keychain, not UserDefaults. `[ASSUMED]`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| iCloud file change detection | Polling loop with `FileManager.enumerator` | `NSMetadataQuery` | NSMetadataQuery is iCloud-aware (detects placeholder transitions); FileManager polling is not and wastes CPU/battery |
| Lock-screen recording indicator | Custom UIView overlay on lock screen | `MPNowPlayingInfoCenter` | Apple's only sanctioned API for lock-screen metadata; custom overlays are impossible from a sandboxed app |
| Lock-screen pause/stop controls | Custom remote control handling | `MPRemoteCommandCenter` | Apple's standard remote command API; integrates with AirPods, Apple Watch, CarPlay for free |
| Folder picker | Custom `UIDocumentPickerViewController` wrapper | SwiftUI `.fileImporter` | Apple's declarative wrapper; cross-platform; handles security-scoped access automatically |
| Atomic file writes to iCloud | Custom file coordination logic | `NSFileCoordinator` + `Data.write(.atomic)` | Already used in Phase 3 `NSFileCoordinatorNoteWriter`; double-layered atomicity proven |
| Background audio session management | Manual `AVAudioSession` activation/deactivation cycling | Standard `setActive(true)` before recording, `setActive(false)` after stop | The audio background mode handles the lifecycle; manual cycling introduces race conditions |

**Key insight:** Phase 5's technical complexity is in orchestrating these existing APIs correctly, not in building new infrastructure. Every component has an Apple-provided API that handles the hard edge cases.

## Common Pitfalls

### Pitfall 1: Recording Stops on Lock Screen (CAPT-03, DISC-04)
**What goes wrong:** User starts recording, locks iPhone, recording stops within 30 seconds.
**Why it happens:** Missing `UIBackgroundModes: ["audio"]` in Info.plist. Without it, iOS suspends the app when it backgrounds. The `AVAudioSession` being active is what tells iOS the app should stay alive.
**How to avoid:** Add `UIBackgroundModes` array with `audio` value to Info.plist. Configure `AVAudioSession.setCategory(.playAndRecord)` and `setActive(true)` BEFORE starting `AVAudioRecorder.record()`. Keep the session active for the entire recording duration.
**Warning signs:** Recording works when screen is on; stops when screen locks. `[CITED: developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record]`

### Pitfall 2: NSMetadataQuery Scope Mismatch
**What goes wrong:** `NSMetadataQuery` fires but results don't include `_inbox/` files.
**Why it happens:** The search scope or predicate is wrong. `NSMetadataQueryUbiquitousDocumentsScope` searches inside the app's iCloud Documents container, NOT arbitrary user-picked folders. Since IC-01 uses a picker-only path (no iCloud container entitlement), the query must use `NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope` or scope to the picked folder's path.
**How to avoid:** Use the picked vault URL path as the predicate scope: `NSPredicate(format: "%K BEGINSWITH %@", NSMetadataItemPathKey, inboxURL.path)`. Test with actual iCloud-synced files, not just local copies.
**Warning signs:** Query returns zero results; files exist in Finder but not in query results. `[CITED: developer.apple.com/documentation/foundation/nsmetadataquery]`

### Pitfall 3: Stale Security-Scoped Bookmarks on iOS
**What goes wrong:** App loses access to the vault folder after the user renames or moves it in the Files app.
**Why it happens:** Security-scoped bookmarks encode a path snapshot. If the user moves the folder, the bookmark resolves to a stale path and `startAccessingSecurityScopedResource()` returns false.
**How to avoid:** Check `bookmarkDataIsStale` when resolving. If stale, re-prompt the user to pick the folder again (show a clear explanation: "We lost access to your vault folder. Please re-select it.").
**Warning signs:** `URL(resolvingBookmarkData:)` succeeds but file operations fail with permission errors. `[CITED: developer.apple.com/documentation/foundation/url#2870281]`

### Pitfall 4: Now Playing Info Not Updating on Lock Screen
**What goes wrong:** `MPNowPlayingInfoCenter.default().nowPlayingInfo` is set but the lock screen shows nothing or stale data.
**Why it happens:** The audio session must be active (category set + activated) before the system displays Now Playing info. Also, the system only shows Now Playing for the app that currently "owns" the audio session.
**How to avoid:** Set `MPNowPlayingInfoCenter` AFTER `AVAudioSession.setActive(true)`. Update `nowPlayingInfo` whenever playback state changes (start, pause, resume, stop). Register `MPRemoteCommandCenter` handlers before the first recording starts.
**Warning signs:** Lock screen shows a different app's Now Playing info, or shows nothing at all. `[CITED: developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter]`

### Pitfall 5: `.icloud` Placeholder Confusion in Pipeline
**What goes wrong:** Pipeline tries to transcribe a `.icloud` placeholder file and fails, or waits forever for a download that never completes.
**Why it happens:** IC-04 introduces a new code path where `.icloud` files are actively downloaded rather than hard-errored. But the Phase 2 `NoteWriterError.iCloudPlaceholder` error case still exists and `NSFileCoordinatorNoteWriter` throws it. The pipeline must handle placeholders at the inbox-watcher level (TRIG-01) BEFORE the file reaches the orchestrator.
**How to avoid:** The `InboxFileDownloader` component handles IC-04 download + polling as a queue-level step, BEFORE the file enters the pipeline. Once downloaded, the file is a real `.m4a` and the existing pipeline processes it normally. The Phase 2 `.icloud` hard-error remains as a safety net for any other code path.
**Warning signs:** `NoteWriterError.iCloudPlaceholder` thrown from the Phase 5 inbox pipeline path (should never happen if the downloader works correctly). `[VERIFIED: codebase — NSFileCoordinatorNoteWriter.swift:38 throws this error]`

### Pitfall 6: PipelineWiring and HardcodedVaultResolver are macOS-Only
**What goes wrong:** iOS compilation fails because `PipelineWiring`, `HardcodedVaultResolver`, `NSFileCoordinatorNoteWriter`, and `ScheduleAwareVaultResolver` are all guarded by `#if os(macOS)`.
**Why it happens:** Phase 3/4 intentionally guarded these in macOS-only blocks because the macOS pipeline was the only consumer. Phase 5's iOS app does NOT need the pipeline (iPhone is capture-only), but the `UnibrainApp.swift` init code currently calls `PipelineWiring.makeScheduleAwareOrchestrator` unconditionally.
**How to avoid:** Wrap the macOS pipeline wiring in `#if os(macOS)` in `UnibrainApp.swift`. iOS app init only needs `RecordingSession` (already cross-platform) and `CourseMappingStore` (already cross-platform). The `EventKitCalendarAdapter` already compiles on iOS.
**Warning signs:** Build errors on iOS target referencing `PipelineWiring`, `HardcodedVaultResolver`, or `NSFileCoordinatorNoteWriter`. `[VERIFIED: codebase — PipelineWiring.swift:4 `#if os(macOS)`, HardcodedVaultResolver.swift:4 `#if os(macOS)`, NSFileCoordinatorNoteWriter.swift:4 `#if os(macOS)`]`

### Pitfall 7: Context7 Not Available for Apple Frameworks
**What goes wrong:** Research plan points to context7 provider, but context7 does not carry Apple framework documentation.
**Why it happens:** Context7 covers open-source libraries (npm, PyPI, SPM packages), not Apple's proprietary framework docs.
**How to avoid:** All Apple framework API details in this RESEARCH.md are sourced from WebSearch results citing official Apple Developer documentation URLs. The planner should treat Apple Developer docs as the authoritative source, not context7.
**Warning signs:** context7 query returns no results for AVFoundation, MediaPlayer, or Foundation.

## Code Examples

### iOS TabView Shell (IOS-01)
```swift
// Source: [CITED: developer.apple.com/documentation/swiftui/tabview]
#if os(iOS)
struct iOSTabView: View {
    var body: some View {
        TabView {
            RecordTab()
                .tabItem {
                    Label("Record", systemImage: "record.circle")
                }
            RecentTab()
                .tabItem {
                    Label("Recent", systemImage: "list.bullet")
                }
            SettingsTab()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
#endif
```

### Onboarding Flow Detection
```swift
// Source: [ASSUMED] — standard UserDefaults pattern
@main
struct UnibrainApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingFlow(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
    }
}
```

### Dead-Letter Sidecar JSON (TRIG-04)
```json
{
  "original_filename": "iphone-20260915T101530-a3f8.m4a",
  "failed_at": "2026-09-15T10:45:00Z",
  "error_type": "transcription_failed",
  "error_message": "whisper.cpp inference failed: model load timeout",
  "retry_count": 3,
  "retry_schedule": ["2026-09-15T10:41:00Z", "2026-09-15T10:43:00Z", "2026-09-15T10:45:00Z"]
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `requestAccess(to:completion:)` | `requestFullAccessToEvents(completion:)` | iOS 17 / macOS 14 | Already handled in Phase 4 adapter |
| `beginBackgroundTask` for audio | `UIBackgroundModes: audio` with active AVAudioSession | iOS 13+ | Background task approach has 30s limit; audio background mode has no time limit as long as session is active |
| `SFSpeechRecognizer` for ASR | `SpeechAnalyzer` (iOS 26+) or `whisper.cpp` | iOS 26 / WWDC 2025 | Not used in Phase 5 — iPhone is capture-only; macOS already has both engines from Phase 3 |

**Deprecated/outdated:**
- `AVAudioSession.setCategory(_:options:)` (pre-iOS 16 pattern): Use `setCategory(_:mode:options:)` instead for explicit mode specification. `[CITED: developer.apple.com/documentation/avfaudio/avaudiosession]`
- `MPRemoteCommandCenter` via `MPNowPlayingInfoCenter` is NOT deprecated — it remains the standard for lock-screen media controls as of iOS 26. `[CITED: developer.apple.com/documentation/mediaplayer]`

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope` or path-based predicate works for user-picked iCloud Drive folders (no container entitlement) | Pattern 4 / Pitfall 2 | If wrong, inbox watcher cannot detect iPhone-origin files — Phase 5 success criterion #2 fails. Must test on real device. |
| A2 | Security-scoped bookmarks stored in Keychain persist across app launches on iOS | Pattern 5 | If wrong, user must re-pick folder every launch. Standard pattern, but iOS bookmark staleness handling needs real-device testing. |
| A3 | `MPNowPlayingInfoCenter` works for recording apps (not just playback apps) | Pattern 3 | If Apple restricts Now Playing to playback-only, IOS-02 lock-screen indicator requires a different approach (Live Activity). Community evidence suggests it works for recording apps. |
| A4 | `TabView(.page)` renders acceptably on macOS in a sheet/window | Pattern 6 | If the page style is iOS-only or renders poorly on macOS, the onboarding flow needs a different layout on macOS (e.g., NavigationStack or custom paged view). |
| A5 | `NSMetadataQuery` predicate with `NSMetadataItemPathKey BEGINSWITH` correctly scopes to the `_inbox/` subfolder of a user-picked folder | Pattern 4 / Pitfall 2 | If the path key doesn't match iCloud Drive paths (which include UUID components), the watcher misses files. |
| A6 | Direct-to-iCloud recording is unreliable (justifying IC-02 sandbox-first approach) | Anti-Patterns | If direct-to-iCloud is actually reliable, IC-02 adds unnecessary complexity. Industry pattern (Voice Memos, Just Press Record) validates sandbox-first. |
| A7 | iOS bookmarks stored in Keychain (not UserDefaults) is the correct approach | Pattern 5 | If Keychain storage is wrong, UserDefaults is simpler. Security best practice says Keychain for anything that grants filesystem access. |

## Open Questions

1. **NSMetadataQuery search scope for picker-only iCloud folders**
   - What we know: `NSMetadataQueryUbiquitousDocumentsScope` searches the app's iCloud container, which we don't have (IC-01 picker-only). The query must search the user-picked folder path.
   - What's unclear: Whether `NSMetadataQuery` can watch arbitrary filesystem paths outside an iCloud container, or whether it requires the folder to be inside an iCloud-synced location.
   - Recommendation: The planner should test with `searchScopes = [inboxURL.path]` (path-based scope) OR use `FileManager.DirectoryEnumerator` with `DispatchSource` as a fallback for the non-iCloud-container case. Since the picked folder IS inside iCloud Drive (`~/Library/Mobile Documents/com~apple~CloudDocs/`), `NSMetadataQuery` should work — but it must be configured to search the external documents scope, not the app's container.

2. **iOS Simulator testing for background audio**
   - What we know: Background audio modes work on physical devices.
   - What's unclear: Whether the iOS Simulator reliably simulates background audio + lock screen + interruptions. Community reports are mixed.
   - Recommendation: CI uses iOS Simulator for compilation checks only. Full background-audio validation must happen on Angelica's physical iPhone (manual device testing, deferred verification).

3. **Apple Developer Program timing**
   - What we know: TestFlight deployment to Angelica's iPhone requires paid Apple Developer Program ($99/yr). IC-01's picker-only path keeps Phase 5 code unblocked even without the membership.
   - What's unclear: Whether the user has activated the Apple Developer Program yet.
   - Recommendation: Phase 5 code compiles and runs in Simulator without the membership. Device testing requires the membership. Planner should flag device-verification tasks as blocked-on-Apple-Dev-Program.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Swift 6.0.3 toolchain (Linux) | WSL2 development + UnibrainCore tests | Yes | 6.0.3 | — |
| Xcode 16 (macOS CI) | Building UnibrainApp + UnibrainProviders, iOS Simulator | Yes (CI) | macos-15 runner | — |
| iOS Simulator | iOS UI testing in CI | Via CI | macos-15 runner | Manual device testing |
| Physical iPhone | CAPT-03, DISC-04 device verification | Unknown | — | Simulator for compilation; defer device verification |
| Apple Developer Program ($99/yr) | TestFlight deployment to iPhone | Unknown | — | IC-01 picker-only path keeps code unblocked |
| iCloud Drive account | Testing iCloud file handoff | Unknown | — | Manual testing with local folder fallback |

**Missing dependencies with no fallback:**
- Physical iPhone — required for final CAPT-03/DISC-04 verification (background recording 30+ min, lock screen survival). Code compiles without it; device testing is deferred.

**Missing dependencies with fallback:**
- Apple Developer Program — code compiles and runs in Simulator without it. Device deployment deferred.
- iCloud Drive — code compiles; local folder testing possible for pipeline logic.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`import Testing`) — existing from Phase 1 |
| Config file | `Package.swift` (test targets: `UnibrainCoreTests`, `UnibrainProvidersTests`, `UnibrainAppTests`) |
| Quick run command | `swift test --filter UnibrainCoreTests` (Linux, ~5s) |
| Full suite command | `swift test` (macOS CI, ~30s) |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CAPT-03 | iOS background recording configures AVAudioSession with playAndRecord + audio background mode | unit (config validation) | `swift test --filter UnibrainProvidersTests` | Wave 0 |
| CAPT-03 | AVAudioSession interruption pauses and auto-resumes recording | unit (mock interruption) | `swift test --filter AudioRecorderTests` | Update existing |
| ONBD-01 | Onboarding flow presents correct number of pages per platform | manual-only (UI) | — | Device verify |
| ONBD-04 | fileImporter picks folder and bookmark persists | unit (bookmark encode/decode) | `swift test --filter BookmarkStoreTests` | Wave 0 |
| ONBD-05 | Permissions sheet shows live mic/calendar status | manual-only (UI) | — | Device verify |
| DISC-04 | App survives backgrounding (UIBackgroundModes: audio declared) | unit (Info.plist validation) | `swift test --filter InboxWatcherTests` | Wave 0 |
| TRIG-01 | NSMetadataQuery detects new files in _inbox/ | unit (mock metadata items) | `swift test --filter InboxWatcherTests` | Wave 0 |
| TRIG-02 | Serial queue processes files FIFO | unit (enqueue/dequeue ordering) | `swift test --filter InboxQueueTests` | Wave 0 |
| TRIG-03 | Audio moved to course folder after pipeline success | unit (file move verification) | `swift test --filter InboxQueueTests` | Wave 0 |
| TRIG-04 | Retry-with-backoff + dead-letter after 3 failures | unit (retry count + dead-letter creation) | `swift test --filter DeadLetterHandlerTests` | Wave 0 |
| IC-04 | .icloud placeholder triggers download + poll | unit (mock placeholder -> downloaded) | `swift test --filter InboxFileDownloaderTests` | Wave 0 |

### Sampling Rate
- **Per task commit:** `swift test --filter UnibrainCoreTests` (Linux, fast feedback)
- **Per wave merge:** `swift test` (macOS CI, full suite)
- **Phase gate:** Full suite green + manual device verification (CAPT-03, ONBD-01, ONBD-05 on iPhone)

### Wave 0 Gaps
- `Tests/UnibrainProvidersTests/Inbox/InboxWatcherTests.swift` — covers TRIG-01, DISC-04
- `Tests/UnibrainProvidersTests/Inbox/InboxQueueTests.swift` — covers TRIG-02, TRIG-03
- `Tests/UnibrainProvidersTests/Inbox/InboxFileDownloaderTests.swift` — covers IC-04
- `Tests/UnibrainProvidersTests/Inbox/DeadLetterHandlerTests.swift` — covers TRIG-04
- `Tests/UnibrainProvidersTests/Security/BookmarkStoreTests.swift` — covers ONBD-04 bookmark encode/decode
- iOS Simulator CI job in `ci.yml` — compilation check for iOS target (optional but recommended)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Single-user app; no auth per PROJECT.md Out of Scope |
| V3 Session Management | no | Single-user app; no sessions |
| V4 Access Control | yes | Security-scoped bookmarks limit filesystem access to user-picked folder only |
| V5 Input Validation | yes | Filename sanitization (IC-03 pattern); `FolderNameSanitizer` already exists from Phase 4 |
| V6 Cryptography | yes | Keychain for bookmark storage; no custom crypto |
| V7 Error Handling | yes | `NoteWriterError` + new `InboxWatcherError` structured error cases; dead-letter sidecar for diagnostics |
| V8 Data Protection | yes | Audio stays in sandbox during recording; iCloud Drive syncs between Angelica's devices only; no cloud storage |

### Known Threat Patterns for iOS/macOS Swift Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Path traversal via crafted filenames | Tampering | `FolderNameSanitizer.sanitize()` strips `/`, `:`, leading dots (Phase 4 T-04-11) |
| Unauthorized filesystem access | Elevation of Privilege | Security-scoped bookmarks limit access to user-picked folder; app sandbox enforced |
| iCloud sync conflict data corruption | Tampering | `Data.write(to:options:.atomic)` + `NSFileCoordinator` (Phase 2 WRITE-04); `schema_version` for migration |
| Background recording privacy leak | Information Disclosure | Microphone indicator (orange dot on iOS 14+); `NSMicrophoneUsageDescription` required; user explicitly starts recording |
| Stale bookmark access to moved folder | Information Disclosure | `bookmarkDataIsStale` check; re-prompt on stale bookmark |
| Dead-letter sidecar information leak | Information Disclosure | Sidecar JSON contains only error metadata (timestamps, error type), no transcript or audio content |

## Sources

### Primary (HIGH confidence)
- **Codebase inspection** — all existing code verified via `Read` tool: `UnibrainApp.swift`, `AudioRecorder.swift`, `RecordingSession.swift`, `EventKitCalendarAdapter.swift`, `PipelineWiring.swift`, `NoteWriterError.swift`, `PipelineOrchestrator.swift`, `PipelineState.swift`, `CourseMappingStore.swift`, `MenuBarViewModel.swift`, `HardcodedVaultResolver.swift`, `NSFileCoordinatorNoteWriter.swift`, `ScheduleAwareVaultResolver.swift`, `PipelineInputs.swift`, `Package.swift`, `ci.yml`, `Info.plist`
- **05-CONTEXT.md** — all locked decisions, discretion areas, deferred items read verbatim

### Secondary (MEDIUM confidence)
- [AVAudioSession .record Category (Apple Developer)](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record) — confirms `UIBackgroundModes: audio` requirement
- [UIBackgroundModes (Apple Developer)](https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes) — `audio` mode for background recording
- [Handling Audio Interruptions (Apple Developer)](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions) — interruption notification lifecycle
- [MPNowPlayingInfoCenter (Apple Developer)](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter) — lock-screen Now Playing API
- [MPRemoteCommandCenter (Apple Developer)](https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter) — lock-screen remote commands
- [NSMetadataQuery (Apple Developer)](https://developer.apple.com/documentation/foundation/nsmetadataquery) — iCloud-aware file watching
- [startDownloadingUbiquitousItem(at:) (Apple Developer)](https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:)) — trigger iCloud download
- [ubiquitousItemDownloadingStatusKey (Apple Developer)](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemdownloadingstatuskey) — poll download status
- [SwiftUI fileImporter (Apple Developer)](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncancel:)) — folder picker
- [TabViewStyle.page(indexDisplayMode:) (Apple Developer)](https://developer.apple.com/documentation/swiftui/tabviewstyle/page(indexdisplaymode:)) — onboarding page style
- [Security-scoped bookmarks (Apple Developer)](https://developer.apple.com/documentation/foundation/url#2870281) — persist folder access
- [WWDC25: Enhance Your App's Audio Recording Capabilities](https://developer.apple.com/videos/play/wwdc2025/251/) — latest audio recording guidance
- [WWDC22: Explore media metadata publishing and playback interactions](https://developer.apple.com/videos/play/wwdc2022/110338/) — Now Playing metadata best practices
- [Security-scoped bookmarks (SwiftLee/Avanderlee)](https://www.avanderlee.com/swift/security-scoped-bookmarks-for-url-access/) — practical bookmark implementation guide
- [Advanced iCloud Documents (fatbobman)](https://fatbobman.com/en/posts/advanced-icloud-documents/) — placeholder file lifecycle and download triggers
- [In-Depth Guide to iCloud Documents (fatbobman)](https://fatbobman.com/en/posts/in-depth-guide-to-icloud-documents/) — NSMetadataQuery + AsyncStream pattern
- [Providing Access to Directories in iOS with Bookmarks (Adam Garrett-Harris)](https://adam.garrett-harris.com/2021-08-21-providing-access-to-directories-in-ios-with-bookmarks/) — iOS bookmark tutorial

### Tertiary (LOW confidence)
- [Stack Overflow: AVAudioRecorder stops after certain time on background](https://stackoverflow.com/questions/69458688/avaudiorecorder-stops-after-certain-time-on-background) — community report confirming 30s background task limit without audio mode
- [Reddit: How I Handle Audio Interruptions](https://www.reddit.com/r/SwiftUI/comments/1qu8k2i/how_i_handle_audio_interruptions_phone_calls_siri/) — practical interruption handling code
- [ objc.io: Mastering the iCloud Document Store](https://www.objc.io/issues/10-syncing-data/icloud-document-store) — common NSMetadataQuery mistakes

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Apple built-in frameworks; no external packages; existing codebase verified
- Architecture: MEDIUM — IC-01 picker-only path is novel for this codebase; NSMetadataQuery scope for external folders is unverified on-device (A1, A5)
- Pitfalls: HIGH — well-documented Apple framework pitfalls with clear avoidance strategies
- Onboarding: HIGH — standard SwiftUI patterns with Apple documentation backing
- iCloud handoff: MEDIUM — NSMetadataQuery + security-scoped bookmarks are well-documented but the specific combination of picker-only + external iCloud folder + NSMetadataQuery is not commonly documented

**Research date:** 2026-07-15
**Valid until:** 2026-08-15 (30 days — stable Apple frameworks; low churn risk)
