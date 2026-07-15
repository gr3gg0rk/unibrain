import Testing
import Foundation
@testable import UnibrainCore

@Suite("FolderNameSanitizer")
struct FolderNameSanitizerTests {

    @Test("sanitize strips reserved characters: /, :, newline, carriage return")
    func stripsReservedCharacters() throws {
        let result = FolderNameSanitizer.sanitize(folderName: "CS/101:Intro\nCS\r101")
        #expect(result == "CS 101 Intro CS 101")
    }

    @Test("sanitize strips leading dots to prevent hidden-file creation")
    func stripsLeadingDots() throws {
        let result = FolderNameSanitizer.sanitize(folderName: "...Course")
        #expect(result == "Course")
    }

    @Test("sanitize collapses whitespace runs to single space")
    func collapsesWhitespace() throws {
        let result = FolderNameSanitizer.sanitize(folderName: "CS101   Intro   to   CS")
        #expect(result == "CS101 Intro to CS")
    }

    @Test("sanitize trims leading and trailing whitespace")
    func trimsWhitespace() throws {
        let result = FolderNameSanitizer.sanitize(folderName: "   CS101   ")
        #expect(result == "CS101")
    }

    @Test("sanitize enforces 100-character max length")
    func enforcesMaxLength() throws {
        let longName = String(repeating: "A", count: 150)
        let result = FolderNameSanitizer.sanitize(folderName: longName)
        #expect(result.count <= 100)
    }

    @Test("sanitize returns Untitled Course for empty-string input")
    func emptyStringReturnsDefault() throws {
        let result = FolderNameSanitizer.sanitize(folderName: "")
        #expect(result == "Untitled Course")
    }

    @Test("sanitize prevents path traversal vectors")
    func preventsPathTraversal() throws {
        let result = FolderNameSanitizer.sanitize(folderName: "../../etc/passwd")
        // Slashes replaced with spaces, dots stripped from leading position only
        // ../../etc/passwd -> .. .. etc passwd (leading dots stripped → "etc passwd")
        // After stripping leading dots: ".." is still at start, so dots are stripped
        // Result: "..  etc passwd" → collapsed whitespace → ".. etc passwd"
        #expect(!result.contains("/"))
        #expect(result.count > 0)
    }

    @Test("sanitize handles Unicode characters correctly")
    func handlesUnicode() throws {
        // Accents preserved
        let accentResult = FolderNameSanitizer.sanitize(folderName: "Mathématique 101")
        #expect(accentResult == "Mathématique 101")

        // Emoji preserved
        let emojiResult = FolderNameSanitizer.sanitize(folderName: "🧮 Course")
        #expect(emojiResult == "🧮 Course")
    }

    // MARK: - Additional Edge Cases

    @Test("sanitize returns Untitled Course for whitespace-only input")
    func whitespaceOnlyReturnsDefault() throws {
        let result = FolderNameSanitizer.sanitize(folderName: "   \n\t\r  ")
        #expect(result == "Untitled Course")
    }

    @Test("sanitize returns Untitled Course for dots-only input")
    func dotsOnlyReturnsDefault() throws {
        let result = FolderNameSanitizer.sanitize(folderName: "...")
        #expect(result == "Untitled Course")
    }
}
