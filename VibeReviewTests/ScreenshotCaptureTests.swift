import CoreGraphics
import XCTest
@testable import VibeReview

final class ScreenshotCaptureTests: XCTestCase {
    func testUsesDisplayContainingCursorPointBeforeFallbackSelection() {
        let displays = [
            CaptureDisplayCandidate(id: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900)),
            CaptureDisplayCandidate(id: 2, frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080))
        ]

        let selected = ScreenshotCapture.displayIDContainingMouse(
            mouseLocation: CGPoint(x: 100, y: 100),
            displayContainingPoint: { point in
                XCTAssertEqual(point, CGPoint(x: 100, y: 100))
                return 2
            },
            candidates: displays,
            fallback: 1
        )

        XCTAssertEqual(selected, 2)
    }

    func testSelectsDisplayContainingMouse() {
        let displays = [
            CaptureDisplayCandidate(id: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900)),
            CaptureDisplayCandidate(id: 2, frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080))
        ]

        let selected = ScreenshotCapture.selectedDisplayID(
            mouseLocation: CGPoint(x: 1800, y: 500),
            candidates: displays,
            fallback: 1
        )

        XCTAssertEqual(selected, 2)
    }

    func testFallsBackToNearestDisplayWhenMouseIsOutsideAllFrames() {
        let displays = [
            CaptureDisplayCandidate(id: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900)),
            CaptureDisplayCandidate(id: 2, frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080))
        ]

        let selected = ScreenshotCapture.selectedDisplayID(
            mouseLocation: CGPoint(x: 3400, y: 500),
            candidates: displays,
            fallback: 1
        )

        XCTAssertEqual(selected, 2)
    }
}
