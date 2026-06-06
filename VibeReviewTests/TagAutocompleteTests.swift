import XCTest
@testable import VibeReview

final class TagAutocompleteTests: XCTestCase {
    func testSuggestsExistingTagsForCurrentToken() {
        let suggestions = TagAutocomplete.suggestions(
            for: "ghost-libr",
            knownTags: ["controls", "ghost-library", "ghost-loop"]
        )

        XCTAssertEqual(suggestions, ["ghost-library"])
    }

    func testReplacesOnlyCurrentCommaSeparatedToken() {
        let completed = TagAutocomplete.replacingCurrentToken(
            in: "controls, ghost-libr",
            with: "ghost-library"
        )

        XCTAssertEqual(completed, "controls, ghost-library, ")
    }

    func testDoesNotSuggestExactExistingTag() {
        let suggestions = TagAutocomplete.suggestions(
            for: "ghost-library",
            knownTags: ["ghost-library"]
        )

        XCTAssertEqual(suggestions, [])
    }
}
