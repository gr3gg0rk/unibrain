import Testing
import Foundation
@testable import UnibrainCore

@Suite("NoteNormalizer Paragraph Grouping")
struct NoteNormalizerGroupParagraphsTests {

    @Test("groupParagraphs with empty segments returns empty array")
    func emptySegmentsReturnsEmpty() throws {
        let result = NoteNormalizer.groupParagraphs(segments: [])
        #expect(result.isEmpty)
    }

    @Test("groupParagraphs with single segment returns single paragraph")
    func singleSegmentReturnsSingleParagraph() throws {
        let segments = [(start: 0.0, end: 5.0, text: "Hello world")]
        let result = NoteNormalizer.groupParagraphs(segments: segments)
        #expect(result.count == 1)
        #expect(result[0] == ["Hello world"])
    }

    @Test("groupParagraphs groups segments within 3-second gap into same paragraph")
    func groupsWithinThreshold() throws {
        let segments = [
            (start: 0.0, end: 5.0, text: "First segment"),
            (start: 6.0, end: 10.0, text: "Second segment"),
            (start: 11.0, end: 15.0, text: "Third segment"),
        ]
        let result = NoteNormalizer.groupParagraphs(segments: segments)
        #expect(result.count == 1)
        #expect(result[0].count == 3)
        #expect(result[0][0] == "First segment")
        #expect(result[0][1] == "Second segment")
        #expect(result[0][2] == "Third segment")
    }

    @Test("groupParagraphs starts new paragraph when gap >= 3 seconds")
    func startsNewParagraphOnLargeGap() throws {
        let segments = [
            (start: 0.0, end: 5.0, text: "First paragraph"),
            (start: 10.0, end: 15.0, text: "Gap too large"),  // gap = 5.0s >= 3.0
            (start: 16.0, end: 20.0, text: "Second paragraph continues"),
        ]
        let result = NoteNormalizer.groupParagraphs(segments: segments)
        #expect(result.count == 2)
        #expect(result[0] == ["First paragraph"])
        #expect(result[1] == ["Gap too large", "Second paragraph continues"])
    }

    @Test("groupParagraphs handles consecutive segments with zero gap")
    func handlesZeroGap() throws {
        let segments = [
            (start: 0.0, end: 5.0, text: "Zero gap one"),
            (start: 5.0, end: 10.0, text: "Zero gap two"),
        ]
        let result = NoteNormalizer.groupParagraphs(segments: segments)
        #expect(result.count == 1)
        #expect(result[0].count == 2)
    }

    @Test("groupParagraphs filters segments with empty/whitespace-only text")
    func filtersEmptySegments() throws {
        let segments = [
            (start: 0.0, end: 5.0, text: "Real content"),
            (start: 5.5, end: 6.0, text: ""),
            (start: 6.5, end: 7.0, text: "   "),
            (start: 7.0, end: 9.0, text: "More content"),
        ]
        let result = NoteNormalizer.groupParagraphs(segments: segments)
        #expect(result.count == 1)
        #expect(result[0].count == 2)
        #expect(result[0][0] == "Real content")
        #expect(result[0][1] == "More content")
    }
}
