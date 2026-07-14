# Phase 2: Pure Pipeline Logic - Pattern Map

**Mapped:** 2026-07-14
**Files analyzed:** 17 (12 new sources + 1 modified + 4 new tests)
**Analogs found:** 15 / 17 (2 files have no close analog: FolderNameSanitizer, NoteNormalizer)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Sources/UnibrainCore/Normalization/NormalizedNote.swift` | value type | transform | `Sources/UnibrainCore/Schemas/FrontmatterSchema.swift` | exact |
| `Sources/UnibrainCore/Normalization/NoteNormalizer.swift` | utility | transform | `Sources/UnibrainCore/ModelLoadGate/ModelLoadGate.swift` | partial |
| `Sources/UnibrainCore/Normalization/NoteWriter.swift` | protocol | request-response | `Sources/UnibrainCore/Protocols/AudioTranscriber.swift` | exact |
| `Sources/UnibrainCore/Errors/NoteWriterError.swift` | error enum | validation | `Sources/UnibrainCore/Errors/ProviderError.swift` | exact |
| `Sources/UnibrainCore/Classification/CalendarEvent.swift` | value type | request-response | `Sources/UnibrainCore/Schemas/FrontmatterSchema.swift` | exact |
| `Sources/UnibrainCore/Classification/CourseMatch.swift` | enum | validation | `Sources/UnibrainCore/ModelLoadGate/ModelLoadGateError.swift` | role-match |
| `Sources/UnibrainCore/Classification/CourseClassifier.swift` | utility | transform | None (new pattern) | none |
| `Sources/UnibrainCore/Classification/FolderNameSanitizer.swift` | utility | transform | None (new pattern) | none |
| `Sources/UnibrainCore/Pipeline/PipelineState.swift` | enum | event-driven | `Sources/UnibrainCore/ModelLoadGate/ModelLoadGateError.swift` | role-match |
| `Sources/UnibrainCore/Pipeline/PipelineInputs.swift` | value type | request-response | `Sources/UnibrainCore/Schemas/FrontmatterSchema.swift` | exact |
| `Sources/UnibrainCore/Pipeline/PipelineOrchestrator.swift` | actor | event-driven | `Sources/UnibrainCore/ModelLoadGate/ModelLoadGate.swift` | exact |
| `Sources/UnibrainCore/Schemas/FrontmatterSchema.swift` | value type | transform | (existing file) | n/a |
| `Tests/UnibrainCoreTests/NormalizationTests/NoteNormalizerTests.swift` | test | unit | `Tests/UnibrainCoreTests/FrontmatterSchemaTests.swift` | exact |
| `Tests/UnibrainCoreTests/NormalizationTests/NoteWriterTests.swift` | test | unit | `Tests/UnibrainCoreTests/ProviderProtocolTests.swift` | exact |
| `Tests/UnibrainCoreTests/ClassificationTests/CourseClassifierTests.swift` | test | unit | `Tests/UnibrainCoreTests/ModelLoadGateTests.swift` | role-match |
| `Tests/UnibrainCoreTests/ClassificationTests/FolderNameSanitizerTests.swift` | test | unit | `Tests/UnibrainCoreTests/FrontmatterSchemaTests.swift` | role-match |
| `Tests/UnibrainCoreTests/PipelineTests/PipelineOrchestratorTests.swift` | test | unit | `Tests/UnibrainCoreTests/ModelLoadGateTests.swift` | exact |

## Pattern Assignments

### 1. `Sources/UnibrainCore/Normalization/NormalizedNote.swift` (value type, transform)

**Analog:** `Sources/UnibrainCore/Schemas/FrontmatterSchema.swift` (lines 1-80)

**Value type pattern** (lines 12-79):
```swift
public struct FrontmatterSchema: Codable, Sendable {
    /// Schema version for forward compatibility.
    public var schemaVersion: Int
    /// Course code (e.g., "CS101").
    public var course: String
    /// Human-readable course name.
    public var courseName: String
    // ... other fields
    
    public init(
        schemaVersion: Int,
        course: String,
        courseName: String,
        // ... other parameters
    ) {
        self.schemaVersion = schemaVersion
        self.course = course
        self.courseName = courseName
        // ... other assignments
    }
}
```

**Adaptation notes:**
- Copy `Codable, Sendable` conformance exactly
- Use `public var` for all stored properties
- Include `///` doc comments for each field
- Provide a `public init` with all parameters
- `NormalizedNote` carries 3 fields: `title: String`, `body: String`, `frontmatter: FrontmatterSchema`

---

### 2. `Sources/UnibrainCore/Normalization/NoteNormalizer.swift` (utility, transform)

**Analog:** `Sources/UnibrainCore/ModelLoadGate/ModelLoadGate.swift` (lines 1-51) - partially applicable for actor isolation pattern, but NoteNormalizer is a pure static struct

**No exact analog exists.** RESEARCH.md provides the complete implementation pattern (lines 511-598).

**Pure static utility pattern** (from RESEARCH.md):
```swift
struct NoteNormalizer {
    /// Groups timed transcript segments into paragraphs by time-gap heuristic.
    static func groupParagraphs(
        segments: [(start: TimeInterval, end: TimeInterval, text: String)],
        threshold: TimeInterval = 3.0
    ) -> [[String]] {
        // ... implementation
    }
    
    /// Normalizes transcript and metadata into a complete Obsidian note.
    static func normalize(
        transcript: [(start: TimeInterval, end: TimeInterval, text: String)],
        course: CalendarEvent,
        audioFile: String,
        recordingStart: Date,
        durationSeconds: Int
    ) -> NormalizedNote {
        // ... implementation
    }
}
```

**Adaptation notes:**
- Use `struct` (not `class` or `actor`) - pure transformation, no state
- All methods are `static` - no instance data needed
- Follow RESEARCH.md algorithm for paragraph grouping (lines 512-547)
- Follow CONTEXT.md N-01..04 for output shape
- Return `NormalizedNote` value type

---

### 3. `Sources/UnibrainCore/Normalization/NoteWriter.swift` (protocol, request-response)

**Analog:** `Sources/UnibrainCore/Protocols/AudioTranscriber.swift` (lines 1-18)

**Protocol pattern** (lines 7-17):
```swift
public protocol AudioTranscriber {
    associatedtype Request
    associatedtype Response
    
    /// Transcribe the given audio request and return the full transcript.
    ///
    /// - Parameter request: Provider-specific request payload (e.g., audio file URL).
    /// - Returns: Provider-specific response payload (e.g., transcript text).
    /// - Throws: ``ProviderError`` on failure.
    func transcribe(_ request: Request) async throws -> Response
}
```

**Adaptation notes:**
- `NoteWriter` is simpler - no `associatedtype` needed (A-02)
- Specific signature: `func write(_ note: NormalizedNote, to destination: URL) async throws`
- Doc comment should reference WRITE-04 (atomic write) and WRITE-05 (.icloud detection)
- Throws `NoteWriterError` (not `ProviderError`)

---

### 4. `Sources/UnibrainCore/Errors/NoteWriterError.swift` (error enum, validation)

**Analog:** `Sources/UnibrainCore/Errors/ProviderError.swift` (lines 1-31)

**Error enum pattern** (lines 16-30):
```swift
public enum ProviderError: Error {
    /// Network request failed (e.g., connection refused, timeout).
    case networkFailure(URLRequest, URLError)
    /// The model returned an error or produced invalid output.
    case modelError(String)
    /// The provider rate-limited the request.
    case rateLimited(retryAfter: TimeInterval?)
    /// The response could not be parsed or was unexpected.
    case invalidResponse(String)
    /// The request was cancelled (e.g., user tapped stop).
    case cancelled
    /// An underlying error from the backend.
    case underlying(any Error)
}
```

**Adaptation notes:**
- Copy enum structure exactly: `public enum NoteWriterError: Error`
- Include `///` doc comments for each case
- Cases per CONTEXT.md A-04: `.iCloudPlaceholder(URL)`, `.diskFull`, `.permissionDenied(URL)`, `.alreadyExists(URL)`, `.directoryCreationFailed(URL, underlying: any Error)`, `.underlying(any Error)`
- Note: ProviderError is NOT `Sendable` (line 9 comment) - same applies to NoteWriterError

---

### 5. `Sources/UnibrainCore/Classification/CalendarEvent.swift` (value type, request-response)

**Analog:** `Sources/UnibrainCore/Schemas/FrontmatterSchema.swift` (lines 12-51)

**Sendable struct pattern** (lines 12-51):
```swift
public struct FrontmatterSchema: Codable, Sendable {
    /// Schema version for forward compatibility.
    public var schemaVersion: Int
    /// Course code (e.g., "CS101").
    public var course: String
    // ... other fields
    
    public init(
        schemaVersion: Int,
        course: String,
        // ... other parameters
    ) {
        self.schemaVersion = schemaVersion
        self.course = course
        // ... other assignments
    }
}
```

**Adaptation notes:**
- `Codable, Sendable` conformance (exact copy)
- 5 fields per CONTEXT.md C-01: `id: String`, `title: String`, `startDate: Date`, `endDate: Date`, `location: String?`
- Public init with all parameters
- Optional `location` uses `String?`

---

### 6. `Sources/UnibrainCore/Classification/CourseMatch.swift` (enum, validation)

**Analog:** `Sources/UnibrainCore/ModelLoadGate/ModelLoadGateError.swift` (lines 1-13)

**Enum with associated values pattern** (lines 8-12):
```swift
public enum ModelLoadGateError: Error, Sendable {
    /// A different heavy model is currently held by the gate.
    /// - Parameter currentModel: The model kind currently loaded, if any.
    case busy(currentModel: HeavyModelKind?)
}
```

**Adaptation notes:**
- `CourseMatch` is NOT an `Error` type (remove `: Error` conformance)
- Keep `Sendable` conformance
- Three cases per CONTEXT.md C-02: `.single(CalendarEvent)`, `.multiple([CalendarEvent])`, `.none`
- `///` doc comments for each case explaining when it occurs

---

### 7. `Sources/UnibrainCore/Classification/CourseClassifier.swift` (utility, transform)

**No exact analog exists.** RESEARCH.md provides complete implementation (lines 601-643).

**Pure static matcher pattern** (from RESEARCH.md):
```swift
struct CourseClassifier {
    /// Matches a recording timestamp against calendar events using a ±30min overlap window.
    static func match(
        events: [CalendarEvent],
        against recordingStart: Date,
        window: TimeInterval = 1800
    ) -> CourseMatch {
        let windowStart = recordingStart.addingTimeInterval(-window)
        let windowEnd = recordingStart.addingTimeInterval(window)
        
        let overlapping = events.filter { event in
            return event.startDate <= windowEnd && event.endDate >= windowStart
        }
        
        switch overlapping.count {
        case 0: return .none
        case 1: return .single(overlapping[0])
        default: return .multiple(overlapping)
        }
    }
}
```

**Adaptation notes:**
- Use `struct` with `static func` (no state)
- Time-overlap algorithm per CONTEXT.md C-03
- Return `CourseMatch` enum
- Default window = 1800 seconds (±30min)

---

### 8. `Sources/UnibrainCore/Classification/FolderNameSanitizer.swift` (utility, transform)

**No exact analog exists.** RESEARCH.md provides complete implementation (lines 645-694).

**Pure static sanitizer pattern** (from RESEARCH.md):
```swift
struct FolderNameSanitizer {
    /// Sanitizes a string for safe use as a macOS/iOS folder name.
    static func sanitize(folderName: String) -> String {
        var sanitized = folderName
        
        // Replace reserved characters with space
        sanitized = sanitized
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        
        // Strip leading dots
        while sanitized.hasPrefix(".") {
            sanitized.removeFirst()
        }
        
        // Collapse whitespace runs
        let whitespacePattern = /\s+/
        sanitized = sanitized.replacing(whitespacePattern, with: " ")
        
        // Trim leading/trailing whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespaces)
        
        // Enforce max length
        if sanitized.count > 100 {
            sanitized = String(sanitized.prefix(100)).trimmingCharacters(in: .whitespaces)
        }
        
        return sanitized.isEmpty ? "Untitled Course" : sanitized
    }
}
```

**Adaptation notes:**
- Use `struct` with `static func`
- Follow CONTEXT.md C-05 rules exactly
- Use regex pattern `/\s+/` for whitespace collapsing (Swift 6 regex literal)

---

### 9. `Sources/UnibrainCore/Pipeline/PipelineState.swift` (enum, event-driven)

**Analog:** `Sources/UnibrainCore/ModelLoadGate/ModelLoadGateError.swift` (lines 8-12)

**Enum with associated value pattern** (lines 8-12):
```swift
public enum ModelLoadGateError: Error, Sendable {
    /// A different heavy model is currently held by the gate.
    case busy(currentModel: HeavyModelKind?)
}
```

**Adaptation notes:**
- 8 states per CONTEXT.md O-01: `.idle`, `.transcribing`, `.classifying`, `.normalizing`, `.writing`, `.completed`, `.failed(any Error)`, `.cancelled`
- `Sendable` conformance (use `@unchecked Sendable` if needed for `any Error`)
- `///` doc comments for each state
- `.failed(any Error)` carries the error - use `@unchecked Sendable` per RESEARCH.md

---

### 10. `Sources/UnibrainCore/Pipeline/PipelineInputs.swift` (value type, request-response)

**Analog:** `Sources/UnibrainCore/Schemas/FrontmatterSchema.swift` (lines 12-79)

**Sendable struct pattern** (lines 53-79):
```swift
public init(
    schemaVersion: Int,
    course: String,
    courseName: String,
    term: String,
    datetime: Date,
    durationSeconds: Int,
    source: String,
    audioFile: String,
    tags: [String],
    syllabusLink: String? = nil,
    vectorId: String? = nil,
    summaryModel: String? = nil
) {
    self.schemaVersion = schemaVersion
    self.course = course
    self.courseName = courseName
    self.term = term
    self.datetime = datetime
    self.durationSeconds = durationSeconds
    self.source = source
    self.audioFile = audioFile
    self.tags = tags
    self.syllabusLink = syllabusLink
    self.vectorId = vectorId
    self.summaryModel = summaryModel
}
```

**Adaptation notes:**
- `Sendable` conformance (not `Codable` - no serialization needed)
- 6 fields per CONTEXT.md O-05: `recordingURL: URL`, `recordingStart: Date`, `recordingEnd: Date`, `durationSeconds: Int`, `source: String`, `events: [CalendarEvent]`
- Public init with all parameters

---

### 11. `Sources/UnibrainCore/Pipeline/PipelineOrchestrator.swift` (actor, event-driven)

**Analog:** `Sources/UnibrainCore/ModelLoadGate/ModelLoadGate.swift` (lines 1-51)

**Actor isolation pattern** (lines 17-51):
```swift
public actor ModelLoadGate {
    /// The currently held model kind, or `nil` if the gate is free.
    private var currentModel: HeavyModelKind? = nil
    
    public init() {}
    
    /// Attempt to acquire a lease for the given model kind.
    public func acquire(_ kind: HeavyModelKind) async throws -> ModelLease {
        if let current = currentModel, current != kind {
            throw ModelLoadGateError.busy(currentModel: current)
        }
        currentModel = kind
        return ModelLease(kind: kind, gate: self)
    }
    
    /// Release the gate for the given model kind.
    public func release(_ kind: HeavyModelKind) async {
        if currentModel == kind {
            currentModel = nil
        }
    }
}
```

**Cooperative cancellation pattern** (from RESEARCH.md lines 418-473):
```swift
actor PipelineOrchestrator {
    private var state: PipelineState = .idle
    private var activeTask: Task<Void, Error>?
    
    func run(inputs: PipelineInputs) async throws {
        guard case .idle = state else {
            throw PipelineError.alreadyRunning
        }
        
        state = .transcribing
        activeTask = Task {
            try Task.checkCancellation()
            let transcript = try await transcriber.transcribe(inputs.recordingURL)
            
            state = .classifying
            try Task.checkCancellation()
            let match = CourseClassifier.match(events: inputs.events, against: inputs.recordingStart, window: 1800)
            
            // ... continue through normalizing and writing stages
            
            state = .completed
        }
        
        try await activeTask?.value
    }
    
    func cancel() async {
        activeTask?.cancel()
        state = .cancelled
    }
    
    var currentState: PipelineState {
        return state
    }
}
```

**Adaptation notes:**
- Copy actor isolation structure exactly
- Store `Task` in actor state so `cancel()` can access it
- Synchronous `guard` check at entry (actor isolation serializes this)
- Call `Task.checkCancellation()` before each async stage
- Fail-fast: any error transitions to `.failed(error)` (terminal)
- Dependencies injected via `init` (transcriber, writer, normalizer, etc.)

---

### 12. `Sources/UnibrainCore/Schemas/FrontmatterSchema.swift` (modification)

**Existing file:** Add `validate()` method

**Validation method pattern** (from CONTEXT.md "Claude's Discretion"):
```swift
public struct FrontmatterSchema: Codable, Sendable {
    // ... existing fields ...
    
    /// Validates the frontmatter schema for required fields and data consistency.
    ///
    /// - Throws: `FrontmatterValidationError` if validation fails.
    public func validate() throws {
        // Check required fields are non-empty
        guard !course.isEmpty else {
            throw FrontmatterValidationError.emptyField("course")
        }
        guard !courseName.isEmpty else {
            throw FrontmatterValidationError.emptyField("course_name")
        }
        guard !term.isEmpty else {
            throw FrontmatterValidationError.emptyField("term")
        }
        guard durationSeconds > 0 else {
            throw FrontmatterValidationError.invalidDuration(durationSeconds)
        }
        // Additional sanity checks as needed
    }
}
```

**Adaptation notes:**
- Add method to existing struct (no changes to fields)
- Create new `FrontmatterValidationError` enum for validation failures
- Check: required fields non-empty, duration > 0, tags non-empty
- Called by NoteNormalizer before emitting `NormalizedNote`

---

### 13. `Tests/UnibrainCoreTests/NormalizationTests/NoteNormalizerTests.swift` (test, unit)

**Analog:** `Tests/UnibrainCoreTests/FrontmatterSchemaTests.swift` (lines 1-125)

**Swift Testing pattern** (lines 6-29):
```swift
@Suite("FrontmatterSchema")
struct FrontmatterSchemaTests {

    @Test("Creating FrontmatterSchema with required fields")
    func createSchema() throws {
        let schema = FrontmatterSchema(
            schemaVersion: 1,
            course: "CS101",
            // ... other fields
        )
        #expect(schema.course == "CS101")
        #expect(schema.schemaVersion == 1)
    }
    
    @Test("Full Yams round-trip preserves all 12 fields")
    func roundTripPreservesAllFields() throws {
        // ... test implementation
    }
}
```

**Adaptation notes:**
- Use `@Suite` and `@Test` macros (exact copy)
- Use `#expect` for assertions (no `XCTAssertEqual`)
- Test cases per CONTEXT.md:
  - Paragraph grouping by 3s gap (N-04)
  - H1 title format `YYYY-MM-DD — {course} Lecture` (N-02)
  - Audio wiki-link emission `![[audio_file]]` (N-01)
  - Empty transcript handling
  - Frontmatter validation errors

---

### 14. `Tests/UnibrainCoreTests/NormalizationTests/NoteWriterTests.swift` (test, unit)

**Analog:** `Tests/UnibrainCoreTests/ProviderProtocolTests.swift` (lines 47-156)

**Protocol mock pattern** (lines 119-156):
```swift
private struct MockLLMSummarizer: LLMSummarizer {
    typealias Request = String
    typealias Response = String
    
    func summarize(_ request: Request) async throws -> Response {
        String(request.reversed())
    }
}
```

**TestNoteWriter pattern** (from RESEARCH.md lines 477-507):
```swift
struct TestNoteWriter: NoteWriter {
    func write(_ note: NormalizedNote, to destination: URL) async throws {
        // Check for .icloud placeholder
        if destination.pathComponents.contains(".icloud") {
            throw NoteWriterError.iCloudPlaceholder(destination)
        }
        
        // Create intermediate directories
        let directory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Serialize and write atomically
        let encoder = YAMLEncoder()
        let yamlFrontmatter = try encoder.encode(note.frontmatter)
        let content = "\(yamlFrontmatter)\n\n\(note.body)"
        try content.write(to: destination, atomically: true, encoding: .utf8)
    }
}
```

**Adaptation notes:**
- Create `TestNoteWriter: NoteWriter` in test file
- Test cases: atomic write, .icloud detection, directory creation, all error cases
- Use temporary directory via `FileManager.temporaryDirectory`
- Clean up temp files in `defer` blocks

---

### 15. `Tests/UnibrainCoreTests/ClassificationTests/CourseClassifierTests.swift` (test, unit)

**Analog:** `Tests/UnibrainCoreTests/ModelLoadGateTests.swift` (lines 4-68)

**Actor test pattern** (lines 7-46):
```swift
@Suite("ModelLoadGate")
struct ModelLoadGateTests {

    @Test("Acquire ASR lease succeeds when gate is free")
    func acquireASRSucceeds() async throws {
        let gate = ModelLoadGate()
        let lease = try await gate.acquire(.asr)
        #expect(lease.kind == .asr)
        await lease.release()
    }
    
    @Test("Acquiring LLM while ASR is held throws busy")
    func denyOnConflict() async throws {
        let gate = ModelLoadGate()
        let asrLease = try await gate.acquire(.asr)
        
        await #expect(throws: ModelLoadGateError.self) {
            _ = try await gate.acquire(.llm)
        }
        
        await asrLease.release()
    }
}
```

**Adaptation notes:**
- Test `CourseClassifier.match(events:against:window:)`
- Cases: single match, multiple matches, no match, edge cases (exact boundary, ±30min window)
- Use fake `CalendarEvent` instances with UUIDs for `id`
- Test window parameterization

---

### 16. `Tests/UnibrainCoreTests/ClassificationTests/FolderNameSanitizerTests.swift` (test, unit)

**Analog:** `Tests/UnibrainCoreTests/FrontmatterSchemaTests.swift` (lines 9-29)

**Parameterized test pattern** (from Swift Testing docs):
```swift
@Suite("FolderNameSanitizer")
struct FolderNameSanitizerTests {

    @Test("Strips reserved characters")
    func stripsReservedChars() throws {
        let input = "CS/101:Intro"
        let output = FolderNameSanitizer.sanitize(folderName: input)
        #expect(output == "CS 101 Intro")
    }
    
    @Test("Collapses whitespace")
    func collapsesWhitespace() throws {
        let input = "CS101   Intro"
        let output = FolderNameSanitizer.sanitize(folderName: input)
        #expect(output == "CS101 Intro")
    }
}
```

**Adaptation notes:**
- Test cases per CONTEXT.md C-05:
  - Strip `/`, `:`, newlines
  - Strip leading dots
  - Collapse whitespace
  - Enforce 100-char cap
  - Path traversal vectors (`../../etc/passwd`)
  - Empty string returns "Untitled Course"

---

### 17. `Tests/UnibrainCoreTests/PipelineTests/PipelineOrchestratorTests.swift` (test, unit)

**Analog:** `Tests/UnibrainCoreTests/ModelLoadGateTests.swift` (lines 7-68)

**Actor isolation test pattern** (lines 15-36):
```swift
@Test("Acquiring LLM while ASR is held throws busy")
func denyOnConflict() async throws {
    let gate = ModelLoadGate()
    let asrLease = try await gate.acquire(.asr)
    
    await #expect(throws: ModelLoadGateError.self) {
        _ = try await gate.acquire(.llm)
    }
    
    await asrLease.release()
}
```

**Cooperative cancellation test pattern** (from RESEARCH.md):
```swift
@Test("Cancellation stops pipeline and transitions to .cancelled")
func cancellationStopsPipeline() async throws {
    let orchestrator = PipelineOrchestrator(
        transcriber: MockTranscriber(),
        writer: TestNoteWriter()
    )
    
    let inputs = PipelineInputs(/* ... */)
    
    // Start pipeline in background
    let runTask = Task {
        try await orchestrator.run(inputs: inputs)
    }
    
    // Cancel immediately
    await orchestrator.cancel()
    
    // Should throw CancellationError or complete with .cancelled state
    await #expect(throws: CancellationError.self) {
        try await runTask.value
    }
    
    #expect(orchestrator.currentState == .cancelled)
}
```

**Adaptation notes:**
- Test 8-state transitions per CONTEXT.md O-01
- Test concurrent-run rejection (O-02)
- Test cooperative cancellation (O-04)
- Test fail-fast error handling (O-03)
- Inject mock dependencies (MockTranscriber, TestNoteWriter, etc.)

---

## Shared Patterns

### Swift 6 Actor Isolation

**Source:** `Sources/UnibrainCore/ModelLoadGate/ModelLoadGate.swift` (lines 17-51)
**Apply to:** `PipelineOrchestrator`
```swift
public actor ModelLoadGate {
    private var currentModel: HeavyModelKind? = nil
    
    public init() {}
    
    public func acquire(_ kind: HeavyModelKind) async throws -> ModelLease {
        if let current = currentModel, current != kind {
            throw ModelLoadGateError.busy(currentModel: current)
        }
        currentModel = kind
        return ModelLease(kind: kind, gate: self)
    }
}
```

### Protocol-Based Dependency Injection

**Source:** `Sources/UnibrainCore/Protocols/AudioTranscriber.swift` (lines 7-17)
**Apply to:** `NoteWriter`, `PipelineOrchestrator` dependencies
```swift
public protocol AudioTranscriber {
    associatedtype Request
    associatedtype Response
    
    func transcribe(_ request: Request) async throws -> Response
}
```

### Structured Error Enum

**Source:** `Sources/UnibrainCore/Errors/ProviderError.swift` (lines 16-30)
**Apply to:** `NoteWriterError`, `FrontmatterValidationError`
```swift
public enum ProviderError: Error {
    case networkFailure(URLRequest, URLError)
    case modelError(String)
    case rateLimited(retryAfter: TimeInterval?)
    case invalidResponse(String)
    case cancelled
    case underlying(any Error)
}
```

### Sendable Value Types

**Source:** `Sources/UnibrainCore/Schemas/FrontmatterSchema.swift` (lines 12-79)
**Apply to:** `NormalizedNote`, `CalendarEvent`, `PipelineInputs`, `CourseMatch`
```swift
public struct FrontmatterSchema: Codable, Sendable {
    public var schemaVersion: Int
    public var course: String
    // ... other fields
    
    public init(...) {
        // ... assignments
    }
}
```

### Swift Testing Framework

**Source:** `Tests/UnibrainCoreTests/FrontmatterSchemaTests.swift` (lines 6-29)
**Apply to:** All Phase 2 test files
```swift
@Suite("FrontmatterSchema")
struct FrontmatterSchemaTests {

    @Test("Creating FrontmatterSchema with required fields")
    func createSchema() throws {
        let schema = FrontmatterSchema(...)
        #expect(schema.course == "CS101")
    }
}
```

### Mock Protocol Conformance

**Source:** `Tests/UnibrainCoreTests/ProviderProtocolTests.swift` (lines 119-156)
**Apply to:** `TestNoteWriter`, mock transcriber/normalizer
```swift
private struct MockLLMSummarizer: LLMSummarizer {
    typealias Request = String
    typealias Response = String
    
    func summarize(_ request: Request) async throws -> Response {
        String(request.reversed())
    }
}
```

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `Sources/UnibrainCore/Classification/CourseClassifier.swift` | utility | transform | No pure static matcher exists in Phase 1 - RESEARCH.md provides complete algorithm (lines 601-643) |
| `Sources/UnibrainCore/Classification/FolderNameSanitizer.swift` | utility | transform | No string sanitization utility exists in Phase 1 - RESEARCH.md provides complete implementation (lines 645-694) |

## Metadata

**Analog search scope:** `Sources/UnibrainCore/`, `Tests/UnibrainCoreTests/`
**Files scanned:** 13 source files + 3 test files
**Pattern extraction date:** 2026-07-14

**Key pattern insights:**
1. **Actor isolation** is the primary concurrency pattern - `ModelLoadGate` is the exact analog for `PipelineOrchestrator`
2. **Protocol-based abstraction** - all provider protocols follow the same shape (single-shot async/throws)
3. **Sendable value types** - all data transfer objects are `struct` with `Sendable` conformance
4. **swift-testing** - all tests use `@Test` and `#expect` (no XCTest)
5. **Error enums** - structured error types with `.underlying(any Error)` catch-all

**Pattern quality:** 15/17 files have exact or role-match analogs. Only 2 files (CourseClassifier, FolderNameSanitizer) rely on RESEARCH.md for complete implementation patterns.
