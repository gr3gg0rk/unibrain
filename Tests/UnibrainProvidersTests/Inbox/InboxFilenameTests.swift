import Testing
import Foundation
@testable import UnibrainProviders

@Suite("InboxFilename")
struct InboxFilenameTests {

    // MARK: - Test 1 (IC-03): Full filename matches pattern

    @Test("generate produces correct IC-03 filename")
    func generateProducesCorrectFilename() throws {
        // Test 1: iphone-20260915T101530-a3f8.m4a
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 15
        components.hour = 10
        components.minute = 15
        components.second = 30
        components.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let filename = InboxFilename.generate(
            source: "iphone",
            timestamp: date,
            uuidSuffix: "a3f8"
        )

        #expect(filename == "iphone-20260915T101530-a3f8.m4a")
    }

    // MARK: - Test 2 (IC-03): ISO 8601 timestamp format

    @Test("generate produces ISO 8601 YYYYMMDDTHHMMSS timestamp")
    func generateProducesISO8601Timestamp() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 12
        components.day = 31
        components.hour = 23
        components.minute = 59
        components.second = 59
        components.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let filename = InboxFilename.generate(
            source: "macos",
            timestamp: date,
            uuidSuffix: "b71c"
        )

        // The timestamp portion should be 20261231T235959
        #expect(filename == "macos-20261231T235959-b71c.m4a")
    }

    // MARK: - Test 3 (IC-03): Always uses .m4a extension

    @Test("generate always uses .m4a extension")
    func generateAlwaysUsesM4AExtension() throws {
        let date = Date()

        let filename = InboxFilename.generate(
            source: "iphone",
            timestamp: date,
            uuidSuffix: "xxxx"
        )

        #expect(filename.hasSuffix(".m4a"))
    }

    // MARK: - Test 4: Different sources produce different prefixes

    @Test("generate uses source prefix correctly")
    func generateUsesSourcePrefix() throws {
        let date = Date()

        let iphoneFilename = InboxFilename.generate(
            source: "iphone",
            timestamp: date,
            uuidSuffix: "a3f8"
        )
        let macosFilename = InboxFilename.generate(
            source: "macos",
            timestamp: date,
            uuidSuffix: "a3f8"
        )

        #expect(iphoneFilename.hasPrefix("iphone-"))
        #expect(macosFilename.hasPrefix("macos-"))
        #expect(iphoneFilename != macosFilename)
    }
}
