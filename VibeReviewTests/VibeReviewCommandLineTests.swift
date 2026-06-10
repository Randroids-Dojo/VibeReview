import XCTest
@testable import VibeReview

final class VibeReviewCommandLineTests: XCTestCase {
    func testParsesCaptureDefaultsAndTags() throws {
        let command = try VibeReviewCommandLine.parse([
            "capture",
            "--project", "/tmp/game",
            "--note", "Jump timing feels late",
            "--tags", "controls, feel,",
        ])

        XCTAssertEqual(
            command,
            .capture(
                projectPath: "/tmp/game",
                note: .value("Jump timing feels late"),
                severity: .issue,
                rating: 3,
                tags: ["controls", "feel"]
            )
        )
    }

    func testParsesStartWithEqualsStyleFlags() throws {
        let command = try VibeReviewCommandLine.parse([
            "start",
            "--project=/tmp/game",
            "--title=Clankers",
        ])

        XCTAssertEqual(command, .start(projectPath: "/tmp/game", title: "Clankers"))
    }

    func testRejectsInvalidRating() {
        XCTAssertThrowsError(try VibeReviewCommandLine.parse([
            "capture",
            "--project", "/tmp/game",
            "--note", "Too hard",
            "--rating", "9",
        ])) { error in
            XCTAssertEqual(error.localizedDescription, "Invalid rating `9`. Use an integer from 1 through 5.")
        }
    }

    func testRejectsUnknownFlags() {
        XCTAssertThrowsError(try VibeReviewCommandLine.parse([
            "status",
            "--session", "abc",
        ])) { error in
            XCTAssertEqual(error.localizedDescription, "Unknown flag `--session`.")
        }
    }
}
