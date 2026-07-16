# Phase 6: Gated Summarization + Cloud Providers + MVP Polish - Research

**Researched:** 2026-07-16
**Domain:** Multi-provider LLM summarization, cloud REST API integration, Keychain security, SwiftUI Settings
**Confidence:** HIGH

## Summary

Phase 6 completes the unibrain MVP by layering gated local/cloud summarization, four cloud provider integrations (OpenAI/Anthropic/Grok/Z.ai), Keychain-backed API key storage, per-modality consent gates, audit trails, and a polished macOS Settings UI on top of the Phase 1-5 local-first capture loop.

**Primary recommendation:** Use Swift 6's native URLSession + Codable for all five HTTP provider clients (Ollama + 4 cloud). No external AI SDKs needed. Each provider implements the existing `LLMSummarizer` protocol with associated Request/Response types. Keychain APIs handle API key storage. SwiftUI `Settings` scene provides the macOS UI. Actor isolation ensures thread-safe consent state and retry tracking.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Local LLM inference (Ollama) | API / Backend (local process) | — | Ollama runs as separate app at localhost:11434; unibrain is HTTP client |
| Cloud LLM inference | API / Backend (external) | — | REST API calls over HTTPS; no server-side components in unibrain |
| API key storage | OS (macOS Keychain / iOS Secure Enclave) | — | System-provided secure storage; never touches app filesystem |
| Consent state persistence | Database / Storage (local JSON) | — | `.unibrain/consent.json` in vault; iCloud syncs between devices |
| Settings UI | Frontend (SwiftUI macOS Settings) | — | Native macOS Settings window; state reads from Keychain/consent.json |
| Network reachability | OS (Network framework) | — | NWConnection for TCP pre-checks before cloud calls |
| Audit trail | Database / Storage (frontmatter) | — | Per-note YAML fields; no separate audit database |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **Swift 6.0+** | Xcode 16+ | Language, concurrency, Sendable | Swift 6 strict concurrency essential for thread-safe cloud clients and consent state [VERIFIED: Apple Developer] |
| **SwiftUI** | iOS 17+ / macOS 14+ | UI framework (Settings window) | Native Settings scene on macOS; TabView for 5-tab layout [VERIFIED: Apple Developer] |
| **URLSession** | Foundation built-in | HTTP client for all 5 providers | Native async/await support; Codable integration; no external dependencies needed [VERIFIED: Apple Developer] |
| **Yams** | 6.2.2 | YAML frontmatter (schema_version 2) | Already in Phase 1 stack; extends with `*_provider` fields [VERIFIED: Swift Package Index] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **Keychain Services** | Security framework built-in | API key storage (kSecClassGenericPassword) | All cloud providers require API keys; never use UserDefaults [VERIFIED: Apple Developer] |
| **Network framework** | macOS 10.14+ / iOS 12+ | NWConnection for TCP reachability checks | Pre-flight network checks before cloud calls (CF-02) [VERIFIED: Apple Developer] |
| **ModelLoadGate** | Phase 1 code | Enforce one-heavy-local-model-at-a-time | Ollama summarization blocked while ASR loaded (SUMM-07) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| URLSession | Alamofire networking | Alamofire is popular but unnecessary dependency — URLSession async/await is sufficient [CITED: avanderlee.com] |
| Native Keychain | KeychainAccess wrapper | Wrapper reduces verbosity but adds dependency; native APIs are straightforward for this use case [CITED: keychain-swift GitHub] |
| OpenAI Swift SDK | URLSession direct | SDK is OpenAI-specific only; doesn't abstract Anthropic/Grok/Z.ai; would still need custom code [ASSUMED] |
| SwiftUI Settings | WindowGroup + custom window | Settings scene is Apple's standard pattern; custom window breaks HIG expectations [VERIFIED: Apple Developer] |

**Installation:** No new SPM dependencies needed for Phase 6. All providers use URLSession (built-in) and Keychain (built-in). Yams already in Package.swift from Phase 1.

**Version verification:** 
- Swift 6.0 confirmed via Xcode 16 requirement (Phase 1 FOUND-01)
- Yams 6.2.2 confirmed in Phase 1 package.swift
- All Apple frameworks are system-provided at specified OS versions

## Package Legitimacy Audit

> **Required** — This phase installs no new external packages. All dependencies are either:
> (a) System frameworks (URLSession, Keychain, Network, SwiftUI)
> (b) Already in Phase 1-5 stack (Yams)

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| **(none new)** | — | — | — | — | — | N/A — no new packages in Phase 6 |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

*Note: Phase 6 uses only system frameworks and existing SPM dependencies. No package legitimacy audit failures.*

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Interaction Layer                   │
├─────────────────────────────────────────────────────────────────┤
│  macOS: Settings Window (5 tabs)   iOS: Read-only Settings tab   │
│  ├─ General (Ollama setup)         ├─ Providers (read-only)     │
│  ├─ Providers (API keys)           ├─ Courses (read-only)       │
│  ├─ Courses (mappings)             ├─ Permissions (actionable)  │
│  ├─ Permissions (system)           └─ Audit (read-only)         │
│  └─ Audit (per-note trail)                                         │
├─────────────────────────────────────────────────────────────────┤
│                      Consent + Configuration Layer                │
├─────────────────────────────────────────────────────────────────┤
│  ConsentStore actor ──────► .unibrain/consent.json (iCloud)   │
│  APIKeyStore (Keychain) ────► macOS Keychain / iOS Secure Enclave│
│  ProviderSettings ─────────► Per-modality provider selection     │
├─────────────────────────────────────────────────────────────────┤
│                         Provider Protocol Layer                   │
├─────────────────────────────────────────────────────────────────┤
│  LLMSummarizer Protocol (from Phase 1)                          │
│  ├─ OllamaLLMSummarizer (localhost:11434)                       │
│  ├─ OpenAILLMSummarizer (api.openai.com)                        │
│  ├─ AnthropicLLMSummarizer (api.anthropic.com)                  │
│  ├─ GrokLLMSummarizer (docs.x.ai)                               │
│  └─ ZaiLLMSummarizer (api.z.ai)                                 │
├─────────────────────────────────────────────────────────────────┤
│                          HTTP Client Layer                        │
├─────────────────────────────────────────────────────────────────┤
│  URLSession.shared (Foundation)                                  │
│  ├─ TCPReachability (Network framework) ──► Pre-flight checks    │
│  ├─ Retry logic (3x exp backoff: 2s/8s/30s)                     │
│  ├─ Error translation (URLError → ProviderError)               │
│  └─ Request/Response Codable DTOs                               │
├─────────────────────────────────────────────────────────────────┤
│                          Pipeline Layer                           │
├─────────────────────────────────────────────────────────────────┤
│  PipelineOrchestrator (Phase 2)                                  │
│  ├─ ModelLoadGate ─────────► Blocks Ollama if ASR loaded        │
│  ├─ ConsentGate ──────────► Blocks cloud if no consent record   │
│  ├─ LLMRouter ─────────────► Dispatches to selected provider    │
│  └─ NoteWriter ─────────────► Writes summary + frontmatter v2    │
└─────────────────────────────────────────────────────────────────┘
```

**Data flow:** User enables summarization in Settings → PipelineOrchestrator calls LLMRouter → LLMRouter checks consent + network → Provider client makes HTTP call → Response written as `## Summary` section + `llm_provider` field.

### Recommended Project Structure

```
Sources/
├── UnibrainCore/
│   ├── Protocols/
│   │   ├── LLMSummarizer.swift           # Existing: Phase 1 protocol
│   │   ├── AudioTranscriber.swift        # Existing: Phase 1 protocol
│   │   ├── VisionDescriber.swift         # Existing: Phase 1 protocol
│   │   └── AudioSynthesizer.swift        # Existing: Phase 1 protocol
│   ├── Errors/
│   │   └── ProviderError.swift           # Existing: Extend with cloud cases
│   ├── ModelLoadGate/
│   │   ├── ModelLoadGate.swift           # Existing: Unchanged for Phase 6
│   │   └── HeavyModelKind.swift         # Existing: .asr + .llm sufficient
│   ├── Schemas/
│   │   └── FrontmatterSchema.swift       # EXTEND: Add *_provider fields, bump schema_version 1→2
│   └── Prompts/
│       └── summary-default.md            # NEW: SUMM-04 prompt template
├── UnibrainProviders/
│   ├── Ollama/
│   │   ├── OllamaLLMSummarizer.swift     # NEW: POST /api/generate with keep_alive: 0
│   │   ├── OllamaHealthCheck.swift       # NEW: GET /api/tags for OLL-01 detection
│   │   └── OllamaModelPull.swift         # NEW: Process shell-out for OLL-03 "Pull model"
│   ├── OpenAI/
│   │   ├── OpenAILLMSummarizer.swift     # NEW: POST /v1/chat/completions
│   │   ├── OpenAITranscriber.swift       # NEW: POST /v1/audio/transcriptions (whisper-1)
│   │   └── OpenAIVisionDescriber.swift   # NEW: POST /v1/chat/completions (vision)
│   ├── Anthropic/
│   │   ├── AnthropicLLMSummarizer.swift  # NEW: POST /v1/messages with x-api-key + anthropic-version
│   │   └── AnthropicVisionDescriber.swift # NEW: POST /v1/messages (image input)
│   ├── Grok/
│   │   └── GrokLLMSummarizer.swift       # NEW: POST /v1/chat/completions (OpenAI-compatible)
│   ├── Zai/
│   │   └── ZaiLLMSummarizer.swift        # NEW: POST /api/paas/v4/chat/completions
│   ├── Consent/
│   │   ├── ConsentStore.swift            # NEW: Actor managing .unibrain/consent.json
│   │   └── ConsentModels.swift           # NEW: ConsentRecord, ConsentState structs
│   ├── Keychain/
│   │   ├── APIKeyStore.swift             # NEW: Security framework wrapper (macOS/iOS)
│   │   └── MockAPIKeyStore.swift         # NEW: Linux test double (in-memory)
│   └── Reachability/
│       └── TCPReachability.swift         # NEW: NWConnection wrapper for CF-02 pre-check
└── UnibrainApp/
    ├── Settings/
    │   ├── SettingsScene.swift           # NEW: macOS Settings window (5 tabs)
    │   ├── GeneralTab.swift              # NEW: Ollama setup, summarization toggle
    │   ├── ProvidersTab.swift            # NEW: Per-modality provider pickers + API key entry
    │   ├── CoursesTab.swift              # NEW: Fold Phase 4 Manage Courses sheet
    │   ├── PermissionsTab.swift          # NEW: Fold Phase 5 Permissions sheet
    │   ├── AuditTab.swift                # NEW: Per-note audit trail viewer
    │   ├── ConsentSheet.swift            # NEW: CON-01 first-use dialog
    │   ├── CloudFailureSheet.swift       # NEW: CF-01 failure recovery sheet
    │   ├── OllamaSetupCallout.swift       # NEW: OLL-01 detection UI
    │   └── ModelPullCallout.swift        # NEW: OLL-03 "Pull model" UI
    └── iOS/
        └── iOSSettingsTab.swift          # EXTEND: Fill Phase 5 placeholder (read-only)
```

### Pattern 1: Actor-Isolated Cloud Provider Client

**What:** Swift 6 actor with internal state (retry counters, rate limit tracking) that conforms to `LLMSummarizer` protocol.

**When to use:** All five HTTP provider clients (Ollama, OpenAI, Anthropic, Grok, Z.ai).

**Example (Anthropic):**

```swift
// Source: [CITED: Anthropic Messages API docs] + [CITED: Swift URLSession async/await]
actor AnthropicLLMSummarizer: LLMSummarizer {
    struct Request: Codable, Sendable {
        let model: String
        let max_tokens: Int
        let messages: [Message]
        let temperature: Double
        let system: String

        struct Message: Codable, Sendable {
            let role: String  // "user" or "assistant"
            let content: String
        }
    }

    struct Response: Codable, Sendable {
        let content: [ContentBlock]
        let id: String
        let model: String

        struct ContentBlock: Codable, Sendable {
            let type: String  // "text"
            let text: String
        }
    }

    private let apiKeyStore: APIKeyStore
    private let consentStore: ConsentStore
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private var session: URLSession = .shared

    func summarize(_ request: Request) async throws -> Response {
        // 1. Check consent (CON-02)
        let hasConsent = await consentStore.hasConsent(provider: .anthropic, modality: .llm)
        guard hasConsent else {
            throw ProviderError.consentDenied(provider: .anthropic, modality: .llm)
        }

        // 2. Check network reachability (CF-02)
        try await TCPReachability().check(host: "api.anthropic.com", port: 443, timeout: 2.0)

        // 3. Fetch API key from Keychain (CLOUD-07)
        guard let apiKey = try? await apiKeyStore.fetch(provider: .anthropic) else {
            throw ProviderError.apiKeyMissing(provider: .anthropic)
        }

        // 4. Send request with retries (CF-03)
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.networkFailure(urlRequest, URLError(.badServerResponse))
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }
}
```

**Key insight:** Actor isolation ensures thread-safe mutable state (retry tracking, rate limit windows). Associated types let each provider define its own Request/Response shapes without protocol-level generics bloat.

### Pattern 2: Keychain API Key Storage

**What:** Security framework wrapper using `SecItemAdd` (write) and `SecItemCopyMatching` (read) for secure API key persistence.

**When to use:** All four cloud providers (OpenAI, Anthropic, Grok, Z.ai). Ollama has no API key (localhost).

**Example:**

```swift
// Source: [CITED: Apple Keychain Services docs] + [CITED: Swift Keychain tutorials]
actor APIKeyStore {
    enum KeychainError: Error {
        case writeFailed(OSStatus)
        case readFailed(OSStatus)
        case deleteFailed(OSStatus)
    }

    private let service = "app.unibrain.provider-keys"

    func store(key: String, for provider: CloudProvider) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount,
            kSecValueData as String: key.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.writeFailed(status)
        }
    }

    func fetch(provider: CloudProvider) async throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.readFailed(status)
        }

        return String(data: data, encoding: .utf8)
    }
}
```

**Key insight:** Keychain storage is platform-specific (macOS Keychain vs iOS Secure Enclave). Use `#if os(macOS)` / `#if os(iOS)` guards for platform differences. Linux tests use `MockAPIKeyStore` (in-memory dictionary).

### Pattern 3: Frontmatter Schema Version Migration

**What:** Extend `FrontmatterSchema` with optional `*_provider` fields and bump `schema_version` from 1 to 2.

**When to use:** Every note write that uses cloud providers (records `llm_provider`, `asr_provider`, `vision_provider`).

**Example:**

```swift
// Source: Phase 2 FrontmatterSchema + Phase 6 CON-04 audit trail
public struct FrontmatterSchema: Codable, Sendable {
    /// Schema version for forward compatibility.
    public var schemaVersion: Int  // Bump: 1 → 2

    // ... existing Phase 1-5 fields ...

    /// ASR provider used (ollama, whisper-cpp, openai, anthropic, grok, zai)
    public var asrProvider: String?  // NEW: schema_version 2
    /// LLM provider used for summarization
    public var llmProvider: String?  // NEW: schema_version 2
    /// Vision provider used for image description
    public var visionProvider: String?  // NEW: schema_version 2

    enum CodingKeys: String, CodingKey {
        // ... existing keys ...
        case asrProvider = "asr_provider"
        case llmProvider = "llm_provider"
        case visionProvider = "vision_provider"
    }

    public init(
        schemaVersion: Int,
        // ... existing params ...
        asrProvider: String? = nil,  // NEW: optional, default nil
        llmProvider: String? = nil,  // NEW: optional, default nil
        visionProvider: String? = nil  // NEW: optional, default nil
    ) {
        self.schemaVersion = schemaVersion
        // ... existing assignments ...
        self.asrProvider = asrProvider
        self.llmProvider = llmProvider
        self.visionProvider = visionProvider
    }
}
```

**Key insight:** Additive change is backward-compatible. Decoder treats missing fields as `nil` for schema_version 1 notes. Encoder always writes current schema_version 2. No on-disk migration needed.

### Pattern 4: Consent State Persistence

**What:** Actor-isolated JSON store in `.unibrain/consent.json` for iCloud-synced consent records.

**When to use:** Before every cloud provider call (check consent) and after user grants/revokes consent (persist).

**Example:**

```swift
// Source: Phase 6 CON-03 + Phase 4 courses.json pattern
actor ConsentStore {
    struct ConsentRecord: Codable, Sendable {
        let alwaysAllow: Bool
        let firstConsentedAt: Date
    }

    struct ConsentState: Codable, Sendable {
        var schemaVersion: Int = 1
        var consents: [String: ConsentRecord]  // Key: "provider.modality"
    }

    private var state = ConsentState()
    private let vaultPath: URL

    func hasConsent(provider: CloudProvider, modality: Modality) async -> Bool {
        let key = "\(provider.rawValue).\(modality.rawValue)"
        return state.consents[key]?.alwaysAllow ?? false
    }

    func grantConsent(provider: CloudProvider, modality: Modality, alwaysAllow: Bool) async throws {
        let key = "\(provider.rawValue).\(modality.rawValue)"
        state.consents[key] = ConsentRecord(
            alwaysAllow: alwaysAllow,
            firstConsentedAt: Date()
        )
        try await save()
    }

    private func save() async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        let path = vaultPath.appendingPathComponent(".unibrain/consent.json")
        try data.write(to: path, options: .atomic)
    }
}
```

**Key insight:** iCloud Drive syncs consent state between MacBook and iPhone. Atomic writes prevent corruption. Schema version field enables future migration.

### Anti-Patterns to Avoid

- **Don't bundle analytics SDKs:** Phase 6 has zero-telemetry mandate (CLOUD-12). No Mixpanel, Segment, Firebase Analytics. [VERIFIED: CLAUDE.md privacy requirements]
- **Don't use ephemeral URLSession per call:** Use `URLSession.shared` for connection pooling and HTTP/2 multiplexing. Creating sessions per call wastes resources. [CITED: avanderlee.com URLSession best practices]
- **Don't put API keys in query strings:** All four providers support header-based auth (`Authorization: Bearer` or `x-api-key`). Query params leak in logs and proxy servers. [VERIFIED: OpenAI/Anthropic API docs]
- **Don't forget `keep_alive: 0` for Ollama:** Default `keep_alive` is 5 minutes. On 8GB RAM, leaving a 4-5GB LLM loaded prevents whisper.cpp from running. [VERIFIED: Ollama API docs]
- **Don't assume cloud providers respect system proxy:** URLSession respects macOS/iOS system proxy by default, but test on actual macOS hardware. WSL2 Linux proxy settings may not propagate. [ASSUMED]
- **Don't skip consent checks:** Every cloud call must check `{provider}×{modality}` consent before firing. Missing consent = silent privacy violation. [VERIFIED: CLOUD-08 requirement]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP client layer | Custom URL loading logic | URLSession.asyncUpdata(for:) | Built-in async/await, connection pooling, HTTP/2 support, ATS enforcement [CITED: avanderlee.com] |
| JSON encoding/decoding | Manual string parsing | Codable protocol + JSONEncoder/Decoder | Type-safe, compiler-checked, handles edge cases (escaping, nesting) |
| Secure storage | UserDefaults, plist files | Keychain Services (Security framework) | Encrypted at rest, hardware-backed on macOS/iOS, never leaves device [CITED: Apple Keychain docs] |
| Network reachability | Raw socket(), getaddrinfo | NWConnection (Network framework) | Modern Swift-native API, handles IPv4/IPv6, async-compatible [CITED: Apple NWConnection docs] |
| YAML encoding | Manual string concatenation | Yams library (already in stack) | Handles escaping, indentation, nested structures, type safety [VERIFIED: Phase 1 Yams integration] |
| Retry logic | Manual timers, DispatchQueue | Swift async/await with exponential backoff | Clean async syntax, proper error propagation, testable with mocks |
| Consent persistence | UserDefaults, SQLite | JSON file in vault with atomic writes | Human-debuggable, iCloud-synced, no database overhead |

**Key insight:** Phase 6 uses only system frameworks and one existing library (Yams). Every problem has a battle-tested solution in the stack. Hand-rolling any of these adds risk without benefit.

## Runtime State Inventory

> **Skip this section** — Phase 6 is NOT a rename/refactor/migration phase. This is greenfield feature development on top of existing Phase 1-5 infrastructure.

**Step 2.5: SKIPPED (no rename/refactor scope)**

## Common Pitfalls

### Pitfall 1: Cloud Provider Rate Limiting Without Backoff

**What goes wrong:** 429 HTTP errors crash the pipeline or cause infinite retry loops.

**Why it happens:** Cloud providers (OpenAI, Anthropic) enforce rate limits (RPM/TPM). Naive retry without exponential backoff exacerbates the problem.

**How to avoid:** Implement 3-retry exponential backoff (2s → 8s → 30s) in every provider client. Extract `retry-after` header from 429 responses if present.

**Warning signs:** Pipeline failures with "rate limited" errors in logs, provider dashboard showing burst traffic patterns.

### Pitfall 2: Missing `keep_alive: 0` for Ollama

**What goes wrong:** Ollama model stays loaded in RAM after summarization, preventing ASR from running (SUMM-07 violation).

**Why it happens:** Ollama's default `keep_alive` is 5 minutes. Forgetting to set `0` means model persists.

**How to avoid:** Always set `keep_alive: 0` in OllamaLLMSummarizer requests. Add unit test verifying request encoding includes this parameter.

**Warning signs:** "ModelLoadGate busy" errors when trying to transcribe after summarizing, Activity Monitor showing 4-5GB RAM usage for llama3.2 process.

### Pitfall 3: Keychain Data Loss on App Reinstall

**What goes wrong:** User deletes app and reinstalls — API keys disappear from Keychain (expected), but user doesn't realize and cloud calls fail with confusing errors.

**Why it happens:** macOS Keychain app-specific items are deleted when app bundle is removed. This is correct security behavior but poor UX if unexplained.

**How to avoid:** Surface clear error message: "API key for {Provider} missing. Re-enter key in Settings → Providers." Don't silently fall back to local.

**Warning signs:** Bug reports about "cloud providers stopped working after reinstall," support requests for "where did my API keys go?"

### Pitfall 4: iCloud Drive Sync Conflicts on consent.json

**What goes wrong:** User grants consent on MacBook, iPhone has stale consent.json, cloud call fires without consent on iPhone (privacy violation).

**Why it happens:** iCloud Drive sync is asynchronous. Device edits may conflict. Last-write-wins can overwrite consent grants.

**How to avoid:** Atomic writes with `.atomic` option. Schema version field in consent.json for future merge logic. Log consent state on every cloud check for debugging.

**Warning signs:** Audit log showing cloud calls without corresponding consent records, user reports of "consent dialog didn't appear on iPhone."

### Pitfall 5: Network Reachability Check Blocking Main Thread

**What goes wrong:** 2-second TCP timeout on main thread freezes UI during Settings interaction.

**Why it happens:** NWConnection synchronous usage or calling actor-isolated TCPReachability from @MainActor without proper async dispatch.

**How to avoid:** TCPReachability.check() is async throws. Call from Task.detached or background actor. Never await on @MainActor path.

**Warning signs:** UI freezes when opening Settings or enabling cloud providers, spinning beachball during network checks.

### Pitfall 6: Frontmatter Schema Version Mismatch

**What goes wrong:** Phase 1-5 notes (schema_version 1) fail to decode after Phase 6 adds schema_version 2 fields.

**Why it happens:** Decoder isn't backward-compatible. Missing required fields (if new fields aren't optional) cause decode failure.

**How to avoid:** All new `*_provider` fields are `String?` (optional). Decoder treats missing as `nil`. Encoder always writes `schema_version: 2`. Add unit test for round-trip both schemas.

**Warning signs:** "Unable to read existing notes" errors after Phase 6 upgrade, empty vault in Settings, user reports of "all my notes disappeared."

### Pitfall 7: Ollama Health Check Timeout During Startup

**What goes wrong:** Settings window takes 10+ seconds to open because Ollama health check (`localhost:11434/api/tags`) blocks on network timeout.

**Why it happens:** Ollama isn't running, and health check uses default 60s URLSession timeout.

**How to avoid:** Health check uses 2s timeout. Run in background Task.detached. Show cached "last known status" immediately, update asynchronously when result ready.

**Warning signs:** Settings UI lag, delayed startup, user reports of "app feels slow when opening Settings."

### Pitfall 8: API Key Leakage in Console Logs

**What goes wrong:** API keys appear in Xcode console or system logs during debugging.

**Why it happens:** `print()` statements or os_log calls include request/response bodies containing keys.

**How to avoid:** Never log request bodies. Mask API keys in error messages (show `sk-...•••` instead of full key). Use SwiftLint rule to flag `print()` in production code.

**Warning signs:** Visible API keys in crash logs, user screenshots of console output, git history containing keys.

## Code Examples

### Ollama Summarization with ModelLoadGate

```swift
// Source: [CITED: Ollama API docs] + Phase 1 ModelLoadGate
actor OllamaLLMSummarizer: LLMSummarizer {
    struct Request: Codable, Sendable {
        let model: String
        let prompt: String
        let stream: Bool
        let keep_alive: Int  // 0 = unload immediately
    }

    struct Response: Codable, Sendable {
        let response: String
        let done: Bool
    }

    func summarize(_ transcript: String, courseContext: CourseContext) async throws -> String {
        // SUMM-07: Refuse to run while ASR is loaded
        let lease = try await ModelLoadGate.shared.acquire(.llm)

        defer {
            // Release gate immediately (keep_alive: 0 unloads Ollama model)
            Task.detached { ModelLoadGate.shared.release(.llm) }
        }

        let request = Request(
            model: "llama-3.2:3b",
            prompt: summarizePrompt(transcript: transcript, courseContext: courseContext),
            stream: false,
            keep_alive: 0  // CRITICAL for 8GB RAM discipline
        )

        let url = URL(string: "http://localhost:11434/api/generate")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 30.0  // 30s timeout for local inference

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ProviderError.networkFailure(urlRequest, URLError(.badServerResponse))
        }

        let decoder = JSONDecoder()
        let ollamaResponse = try decoder.decode(Response.self, from: data)

        return ollamaResponse.response
    }
}
```

**Verified pattern:** Ollama API specifies `keep_alive` and `stream` parameters. `keep_alive: 0` unloads model immediately. [CITED: Ollama API documentation]

### OpenAI Chat Completions with Bearer Auth

```swift
// Source: [CITED: OpenAI API Overview] + [CITED: Swift URLSession patterns]
actor OpenAILLMSummarizer: LLMSummarizer {
    struct Request: Codable, Sendable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int

        struct Message: Codable, Sendable {
            let role: String
            let content: String
        }
    }

    struct Response: Codable, Sendable {
        let choices: [Choice]
        let id: String
        let model: String

        struct Choice: Codable, Sendable {
            let message: Message
        }
    }

    func summarize(_ transcript: String, courseContext: CourseContext) async throws -> String {
        let request = Request(
            model: "gpt-4o",
            messages: [
                .init(role: "system", content: loadSystemPrompt()),
                .init(role: "user", content: summarizePrompt(transcript: transcript, courseContext: courseContext))
            ],
            temperature: 0.7,
            max_tokens: 512
        )

        var urlRequest = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ProviderError.networkFailure(urlRequest, URLError(.badServerResponse))
        }

        let openaiResponse = try JSONDecoder().decode(Response.self, from: data)
        return openaiResponse.choices.first?.message.content ?? ""
    }
}
```

**Verified pattern:** OpenAI uses `Authorization: Bearer` header. `gpt-4o` model for best quality, `gpt-4o-mini` for cost savings. [CITED: OpenAI API Reference]

### Anthropic Messages with Version Header

```swift
// Source: [CITED: Anthropic versioning docs] + [CITED: Swift URLSession]
actor AnthropicLLMSummarizer: LLMSummarizer {
    func summarize(_ transcript: String, courseContext: CourseContext) async throws -> String {
        let request = Request(
            model: "claude-sonnet-4-20250514",
            max_tokens: 512,
            messages: [
                .init(role: "user", content: summarizePrompt(transcript: transcript, courseContext: courseContext))
            ],
            temperature: 0.7,
            system: loadSystemPrompt()
        )

        var urlRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")  // REQUIRED
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ProviderError.networkFailure(urlRequest, URLError(.badServerResponse))
        }

        let anthropicResponse = try JSONDecoder().decode(Response.self, from: data)
        return anthropicResponse.content.first?.text ?? ""
    }
}
```

**Verified pattern:** Anthropic requires `anthropic-version: 2023-06-01` header. Missing this header causes 400 errors. [CITED: Anthropic versioning documentation]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Custom HTTP clients | URLSession async/await | Swift 5.5 (2021) | Modern concurrency, cleaner code, no callback hell |
| Manual JSON parsing | Codable protocol | Swift 4 (2017) | Type-safe, compiler-checked, less boilerplate |
| UserDefaults for keys | Keychain Services | iOS 2.0 (2008) | Encrypted storage, hardware-backed, never leaves device |
| Legacy Settings window | SwiftUI Settings scene | macOS 13 / iOS 16 (2022) | Native patterns, state restoration, automatic deep-linking |
| Synchronous networking | Async/await URLSession | Swift 5.5+ | Linear code flow, proper error propagation, testable |

**Deprecated/outdated:**
- **URLSession.shared per request:** Use single shared session for connection pooling. Creating sessions per request wastes resources.
- **Deprecated Settings APIs:** macOS System Settings Prefs pane format is deprecated. Use SwiftUI Settings scene.
- **OpenAI SDKs for single-provider:** Don't add OpenAI SDK if you also need Anthropic/Grok/Z.ai. Uniform URLSession approach reduces dependency surface.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Grok (X) API uses OpenAI-compatible `/v1/chat/completions` endpoint | Cloud Provider Integration | If Grok uses custom endpoint, integration fails; need separate adapter |
| A2 | Z.ai API uses OpenAI-compatible auth with `Authorization: Bearer` | Cloud Provider Integration | If Z.ai requires custom headers, need separate request builder |
| A3 | llama-3.2:3b model exists in Ollama library with 128K context window | Ollama Integration | If model unavailable, summarization fails; need fallback model (qwen2.5:3b) |
| A4 | iCloud Drive syncs `.unibrain/consent.json` within 30s between devices | Consent State Sync | If sync slower or conflicts, consent violations possible; need merge logic |
| A5 | macOS 26 Tahoe and iOS 17 deployment targets support all required APIs | Platform Compatibility | If APIs missing, need availability checks and fallbacks |
| A6 | 8GB RAM can handle Ollama llama-3.2:3b (~4-5GB) + OS (~3-4GB) with `keep_alive: 0` | Memory Discipline | If RAM tighter, may need smaller model (phi-3.5-mini) or cloud-only |
| A7 | Network reachability check (2s TCP) is sufficient for all cloud providers | Network Pre-flight | If some providers have custom timeouts, may need provider-specific values |
| A8 | Keychain `kSecAttrAccessibleWhenUnlocked` works on macOS and iOS identically | Keychain Cross-Platform | If iOS requires different accessibility, need platform-specific code |

**Validation strategy:** Test A1-A2 on real HTTP calls during implementation. Test A3 via `ollama list` during OLL-03 setup. Test A4 via manual device sync testing during UAT. Test A5 by checking API availability headers. Test A6 via Activity Monitor during summarization. Test A7 via network simulator (Little Snitch). Test A8 via Keychain Access app on both platforms.

## Open Questions

1. **Grok API endpoint uncertainty**
   - What we know: CONTEXT.md assumes Grok uses OpenAI-compatible `/v1/chat/completions`
   - What's unclear: Exact endpoint path, required headers, model naming (grok-2? grok-beta?)
   - Recommendation: Verify against [docs.x.ai] during implementation. If incompatible, build separate GrokRequest/GrokResponse types.

2. **Z.ai API model naming**
   - What we know: CONTEXT.md suggests GLM-4.6 model
   - What's unclear: Exact model ID string for API requests (glm-4.6? glm-4.6-turbo?)
   - Recommendation: Check Z.ai API docs before finalizing ZaiLLMSummarizer. Add model selection tests.

3. **Ollama model pull progress parsing**
   - What we know: OLL-03 requires progress bar during `ollama pull`
   - What's unclear: Exact stdout format for percentage parsing (e.g., "✓ 23% 452MB/1.2GB")
   - Recommendation: Run `ollama pull llama-3.2:3b` manually during OLL-03 implementation. Parse percentage with regex.

4. **iOS Secure Enclave vs Keychain for API keys**
   - What we know: CLOUD-07 specifies iOS Secure Enclave, but Secure Enclave has key-type restrictions (ECDSA, P-256)
   - What's unclear: Whether arbitrary-length API key strings (sk-ant-xxx123) can use Secure Enclave or must use regular Keychain
   - Recommendation: Use iOS Keychain (not Secure Enclave) for API keys. Secure Enclave is for cryptographic keys, not generic secrets. Document decision in PLAN.md.

5. **Network reachability timeout value**
   - What we know: CF-02 specifies 2s TCP timeout
   - What's unclear: Whether 2s is appropriate for all network conditions (e.g., slow university WiFi)
   - Recommendation: Start with 2s. Test on real networks during UAT. Make timeout configurable in Settings if users report false negatives.

## Environment Availability

> **Phase 6 requires no new external tools or runtimes.** All dependencies are system frameworks or already installed.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| **Xcode 16+** | Swift 6 compilation | ✓ (CI: macos-15) | Xcode 16.4+ | — |
| **Swift 6.0+** | Strict concurrency, Sendable | ✓ (CI: Swift 6.0.3) | 6.0.3 | — |
| **macOS 26 / iOS 17** | SwiftUI Settings, @Observable | ✓ (deployment targets) | macOS 26 / iOS 17 | — |
| **URLSession** | HTTP client for all providers | ✓ (Foundation built-in) | System | — |
| **Keychain Services** | API key storage | ✓ (Security framework) | System | — |
| **Network framework** | TCP reachability checks | ✓ (System framework) | macOS 10.14+ / iOS 12+ | — |
| **Yams** | YAML frontmatter encoding | ✓ (Phase 1 SPM) | 6.2.2 | — |

**Missing dependencies with no fallback:** None

**Missing dependencies with fallback:** None

**Note:** Phase 6 development requires macOS hardware for Keychain testing, but all cloud-client unit tests run on Linux CI (mock URLSession). Platform-specific tests marked with `#if os(macOS)` guards.

## Validation Architecture

> **nyquist_validation is enabled** (per .planning/config.json default). This section applies.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (swift test) |
| Config file | Package.swift (no swift-test.config — using default Linux-compatible setup) |
| Quick run command | `swift test --enable-test-discovery --filter "Phase6"` |
| Full suite command | `swift test --enable-code-coverage` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SUMM-01 | Ollama HTTP API integration with health-check | unit | `swift test --filter OllamaHealthCheckTests` | ❌ Wave 0 |
| SUMM-02 | Summary feature OFF by default | unit | `swift test --filter SummarizationToggleTests` | ❌ Wave 0 |
| SUMM-03 | llama-3.2:3b with keep_alive: 0 | unit | `swift test --filter OllamaLLMSummarizerTests` | ❌ Wave 0 |
| SUMM-04 | 5-8 bullet key points generation | integration | Manual UAT (requires real Ollama) | — |
| SUMM-05 | Summary under ## Summary heading | unit | `swift test --filter SummaryWriterTests` | ❌ Wave 0 |
| SUMM-06 | Regenerate Summary replaces only section | integration | Manual UAT (Settings → Audit → Regenerate) | — |
| SUMM-07 | Refuses to run while ASR loaded | unit | `swift test --filter ModelLoadGateConflictTests` | ✅ Phase 1 |
| CLOUD-01 | Per-modality provider selectors | integration | Manual UAT (Settings → Providers) | — |
| CLOUD-02 | Local default on first launch | integration | Manual UAT (fresh install) | — |
| CLOUD-03 | OpenAI provider integration | unit | `swift test --filter OpenAILLMSummarizerTests` | ❌ Wave 0 |
| CLOUD-04 | Anthropic provider integration | unit | `swift test --filter AnthropicLLMSummarizerTests` | ❌ Wave 0 |
| CLOUD-05 | Grok provider integration | unit | `swift test --filter GrokLLMSummarizerTests` | ❌ Wave 0 |
| CLOUD-06 | Z.ai provider integration | unit | `swift test --filter ZaiLLMSummarizerTests` | ❌ Wave 0 |
| CLOUD-07 | API keys in Keychain / Secure Enclave | unit | `swift test --filter APIKeyStoreTests` | ❌ Wave 0 |
| CLOUD-08 | First-use consent gate | integration | Manual UAT (first cloud call triggers sheet) | — |
| CLOUD-09 | Cloud ASR as alternative to local | integration | Manual UAT (select OpenAI ASR → record) | — |
| CLOUD-10 | Cloud failure surfaces clear error | integration | Manual UAT (simulate network failure) | — |
| CLOUD-11 | Network reachability check | unit | `swift test --filter TCPReachabilityTests` | ❌ Wave 0 |
| CLOUD-12 | Zero telemetry verified | manual | Code review + mitmproxy audit pre-release | — |
| CLOUD-13 | Per-document audit trail in frontmatter | unit | `swift test --filter FrontmatterSchemaV2Tests` | ❌ Wave 0 |
| DISC-05 | Local-first path works offline | integration | Manual UAT (airplane mode + capture) | — |
| DISC-06 | iCloud Drive sync doesn't corrupt notes | integration | Manual UAT (concurrent edits on Mac + iPhone) | — |

### Sampling Rate
- **Per task commit:** `swift test --enable-test-discovery --filter "Phase6"` (~30s on Linux CI)
- **Per wave merge:** `swift test --enable-code-coverage` (full suite, ~2-3 min on macOS CI)
- **Phase gate:** Full suite green + manual UAT checklist completed before `/gsd-verify-work`

### Wave 0 Gaps

The following test files need to be created in Wave 0 of Phase 6 planning:

- **`Tests/UnibrainProvidersTests/Ollama/OllamaHealthCheckTests.swift`** — covers SUMM-01 (health check to localhost:11434)
- **`Tests/UnibrainProvidersTests/Ollama/OllamaLLMSummarizerTests.swift`** — covers SUMM-03 (keep_alive: 0 encoding), SUMM-07 (ModelLoadGate conflict)
- **`Tests/UnibrainProvidersTests/OpenAI/OpenAILLMSummarizerTests.swift`** — covers CLOUD-03 (Bearer auth, request encoding)
- **`Tests/UnibrainProvidersTests/Anthropic/AnthropicLLMSummarizerTests.swift`** — covers CLOUD-04 (x-api-key + anthropic-version headers)
- **`Tests/UnibrainProvidersTests/Grok/GrokLLMSummarizerTests.swift`** — covers CLOUD-05 (OpenAI-compatible endpoint)
- **`Tests/UnibrainProvidersTests/Zai/ZaiLLMSummarizerTests.swift`** — covers CLOUD-06 (API integration)
- **`Tests/UnibrainProvidersTests/Keychain/APIKeyStoreTests.swift`** — covers CLOUD-07 (SecItemAdd/SecItemCopyMatching), with `MockAPIKeyStore` for Linux
- **`Tests/UnibrainProvidersTests/Reachability/TCPReachabilityTests.swift`** — covers CLOUD-11 (NWConnection TCP check)
- **`Tests/UnibrainCoreTests/Schemas/FrontmatterSchemaV2Tests.swift`** — extends Phase 1 FrontmatterSchema tests for schema_version 2 round-trip
- **`Tests/UnibrainProvidersTests/Consent/ConsentStoreTests.swift`** — covers CON-02/CON-03 (consent persistence, iCloud sync simulation)

**Framework install:** Swift Testing is already in Package.swift from Phase 1. No new dependencies needed.

**Mocks needed:** `MockURLSession` (injectable for provider client tests), `MockAPIKeyStore` (in-memory for Linux), `MockConsentStore` (in-memory for pipeline tests).

## Security Domain

> **security_enforcement is enabled** (per .planning/config.json default). This section applies.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Keychain-backed API keys; cloud provider tokens never in plaintext |
| V3 Session Management | yes | Consent state persists across app launches (`.unibrain/consent.json`) |
| V4 Access Control | yes | Per-modality provider selection; consent gates before every cloud call |
| V5 Input Validation | yes | Provider request/response DTOs validated via Codable; transcript sanitized before LLM |
| V6 Cryptography | yes | HTTPS-only for cloud providers (ATS enforced); Keychain hardware-backed encryption |
| V7 Data Protection | yes | API keys never in logs/vault; audit trail records provider usage |
| V9 Communication | yes | Network reachability pre-checks; TLS 1.2+ enforced by ATS |

### Known Threat Patterns for Cloud Provider Integration

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| **API key exposure in logs** | Information Disclosure | Never log request bodies; mask API keys in errors (show `sk-...•••`); SwiftLint rule against `print()` |
| **Consent state bypass** | Tampering | Actor-isolated ConsentStore; atomic file writes; iCloud sync conflict resolution via schema_version |
| **Man-in-the-middle on cloud calls** | Spoofing | ATS enforces HTTPS; certificate pinning optional (defer to v2); no HTTP exceptions |
| **Keychain access by other apps** | Information Disclosure | Use `kSecAttrAccessGroup` to restrict to unibrain bundle ID; sandbox isolation protects by default |
| **Plaintext API keys in memory** | Information Disclosure | Swift String is not encrypted in memory; accept risk for MVP (Keychain encrypts at rest). Mitigate: minimize key lifetime in memory, clear ASAP |
| **OAuth token theft** | Spoofing | Not applicable — unibrain uses API keys, not OAuth flow. No token exchange attacks |
| **Rate limit exhaustion** | Denial of Service | Exponential backoff (2s/8s/30s); respect `retry-after` header; queue-level retry limits (3 attempts) |
| **Cloud provider compromise** | Supply Chain | Audit trail per note (`*_provider` fields); user can switch providers; local fallback always available |

**Additional security notes:**

- **Zero telemetry enforcement (CLOUD-12):** Code review checklist before each release. grep Package.swift for analytics SDKs (mixpanel, segment, firebase, amplitude). Network inspection via mitmproxy/Proxyman to verify only provider endpoints are called.

- **Keychain data migration:** If provider is added/removed (e.g., future Phase 7 adds new provider), migration script updates Keychain account names. Schema version field in `.unibrain/consent.json` enables forward-compatible consent storage.

- **iOS Secure Enclave vs Keychain decision:** API key strings (sk-ant-xxx, sk-xxx) are arbitrary-length data, not cryptographic keys. Secure Enclave requires ECDSA/P-256 keys. Use regular iOS Keychain (still encrypted, hardware-backed) for API keys. Document in PLAN.md under CLOUD-07 implementation notes.

## Sources

### Primary (HIGH confidence)

- **[Ollama HTTP API Documentation](https://github.com/ollama/ollama/blob/main/docs/api.md)** — `/api/generate` endpoint, `keep_alive` parameter, `stream` parameter, model list, health check via `/api/tags` [VERIFIED via WebSearch]
- **[OpenAI API Reference](https://platform.openai.com/docs/api-reference/chat-completions)** — Chat Completions endpoint, Authorization Bearer header, gpt-4o model, max_tokens parameter [VERIFIED via WebSearch]
- **[Anthropic Messages API](https://docs.anthropic.com/en/api/messages)** — Messages endpoint, `x-api-key` header, `anthropic-version: 2023-06-01` requirement, Sonnet/Opus models [VERIFIED via WebSearch]
- **[SwiftUI Settings Documentation](https://developer.apple.com/documentation/swiftui/settings)** — Settings scene for macOS, TabView configuration, window management, lifecycle [VERIFIED via WebSearch]
- **[Keychain Services Documentation](https://developer.apple.com/documentation/security/keychain_services)** — `SecItemAdd`, `SecItemCopyMatching`, `kSecClassGenericPassword`, API key storage patterns [VERIFIED via WebSearch]
- **[Network Framework NWConnection](https://developer.apple.com/documentation/network/nwconnection)** — TCP connection establishment, async/await integration, reachability checks [VERIFIED via WebSearch]
- **[Swift URLSession async/await patterns](https://www.avanderlee.com/concurrency/urlsession-async-await-network-requests-in-swift/)** — Modern concurrency, HTTP client implementation, JSON decoding, error handling [VERIFIED via WebSearch]

### Secondary (MEDIUM confidence)

- **[macOS Keychain Swift tutorials](https://oneuptime.com/blog/post/2026-02-02-swift-keychain-secure-storage/view)** — Practical implementation examples, CommonSecItemPatterns, security best practices [CITED via WebSearch]
- **[Keychain Swift package](https://github.com/evanthypoc1/keychain-swift)** — Community wrapper reference for ergonomics patterns (not using wrapper, but learning from implementation) [CITED via WebSearch]
- **[Swift Network framework TCP examples](https://stackoverflow.com/questions/65098702/swift-network-framework-with-tcp)** — StackOverflow practical NWConnection usage patterns, timeout configuration [CITED via WebSearch]
- **[SwiftUI Settings tutorials](https://medium.com/@schopenlaam/how-to-build-macos-system-like-app-settings-in-swiftui-9ee3f8d50e57)** — Step-by-step Settings window implementation, TabView layout patterns [CITED via WebSearch]

### Tertiary (LOW confidence)

- **[Grok (X AI) API Documentation](https://docs.x.ai)** — Assumed OpenAI-compatible endpoint (not verified via WebSearch; flagged in A1) [ASSUMED]
- **[Z.ai API Documentation](https://docs.z.ai)** — Assumed OpenAI-compatible auth and model naming (not verified via WebSearch; flagged in A2) [ASSUMED]
- **[llama-3.2:3b Ollama model page](https://ollama.com/library/llama-3.2)** — Assumed 128K context window and availability (not verified via WebSearch; flagged in A3) [ASSUMED]

### Internal Codebase Sources

- **`Sources/UnibrainCore/Protocols/LLMSummarizer.swift`** — Phase 1 protocol definition, associatedtype pattern, single-shot async throws [VERIFIED via codebase read]
- **`Sources/UnibrainCore/Errors/ProviderError.swift`** — Phase 1 error enum, networkFailure/rateLimited/invalidResponse cases [VERIFIED via codebase read]
- **`Sources/UnibrainCore/ModelLoadGate/ModelLoadGate.swift`** — Phase 1 actor implementation, acquire/release lease pattern, deny-on-conflict [VERIFIED via codebase read]
- **`Sources/UnibrainCore/Schemas/FrontmatterSchema.swift`** — Phase 2 schema, Yams integration, CodingKeys snake_case mapping, validation [VERIFIED via codebase read]
- **`Sources/UnibrainProviders/Transcription/TranscriberRouter.swift`** — Phase 3 router pattern (template for LLM/Vision/TTS routers) [VERIFIED via codebase read]
- **`Sources/UnibrainProviders/Security/BookmarkStore.swift`** — Phase 5 Keychain pattern template for APIKeyStore [VERIFIED via codebase read]

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — All system frameworks verified via Apple documentation. URLSession, Keychain, Network framework are battle-tested.
- Architecture: **HIGH** — Protocol-oriented design from Phase 1 is solid. Actor isolation for concurrent state is correct Swift 6 pattern.
- Pitfalls: **HIGH** — All eight pitfalls identified from verified documentation and common Swift security mistakes.
- Cloud providers: **MEDIUM** — Ollama/OpenAI/Anthropic verified via docs. Grok/Z.ai assumed OpenAI-compatible (flagged in Open Questions).
- Keychain security: **HIGH** — Keychain APIs are standard. Security best practices verified via Apple docs.
- Network reachability: **MEDIUM** — NWConnection documented, but 2s timeout assumption needs UAT validation (flagged in Open Questions).

**Research date:** 2026-07-16
**Valid until:** 2026-08-16 (30 days — cloud provider APIs are stable, but deprecation possible beyond 30 days)

**Next steps:** Planner uses this RESEARCH.md to generate Phase 6 PLAN.md files. Flagged assumptions (A1-A8) and open questions (1-5) must be resolved during planning or Wave 0 implementation.
