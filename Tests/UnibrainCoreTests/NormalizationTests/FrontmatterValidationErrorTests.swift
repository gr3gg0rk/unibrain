import Testing
import Foundation
@testable import UnibrainCore

@Suite("FrontmatterValidationError")
struct FrontmatterValidationErrorTests {

    @Test("emptyField case constructs with field name")
    func emptyFieldConstructs() throws {
        let error = FrontmatterValidationError.emptyField("course")
        if case .emptyField(let field) = error {
            #expect(field == "course")
        } else {
            Issue.record("Expected .emptyField case")
        }
    }

    @Test("invalidDuration case constructs with duration value")
    func invalidDurationConstructs() throws {
        let error = FrontmatterValidationError.invalidDuration(0)
        if case .invalidDuration(let duration) = error {
            #expect(duration == 0)
        } else {
            Issue.record("Expected .invalidDuration case")
        }
    }

    @Test("missingRequiredField case constructs with field name")
    func missingRequiredFieldConstructs() throws {
        let error = FrontmatterValidationError.missingRequiredField("datetime")
        if case .missingRequiredField(let field) = error {
            #expect(field == "datetime")
        } else {
            Issue.record("Expected .missingRequiredField case")
        }
    }

    @Test("Error enum is catchable as Error type")
    func catchableAsError() throws {
        func throwError() throws {
            throw FrontmatterValidationError.emptyField("test")
        }

        #expect(throws: FrontmatterValidationError.self) {
            try throwError()
        }
    }
}
