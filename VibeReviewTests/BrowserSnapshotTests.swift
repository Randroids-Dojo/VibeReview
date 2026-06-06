import XCTest
@testable import VibeReview

final class BrowserSnapshotTests: XCTestCase {
    func testDecodesExtensionSnapshot() throws {
        let json = """
        {
          "capturedAt": "2026-06-06T20:00:00.000Z",
          "url": "http://localhost:5173",
          "title": "Game",
          "viewport": { "width": 1280, "height": 720, "devicePixelRatio": 2 },
          "scroll": { "x": 0, "y": 10 },
          "selectedText": "",
          "focusedElement": "canvas#game",
          "domSummary": {
            "bodyTextSample": "score 100",
            "interactiveElementCount": 3,
            "headings": ["Game"],
            "buttons": ["Start"]
          },
          "storage": { "localStorage": { "save": "1" }, "sessionStorage": {} },
          "canvases": [{ "width": 1280, "height": 720, "label": "game" }],
          "consoleMessages": [{ "level": "log", "message": "ready", "timestamp": "2026-06-06T20:00:00.000Z" }]
        }
        """

        let snapshot = try JSONCoding.decoder().decode(BrowserSnapshot.self, from: Data(json.utf8))

        XCTAssertEqual(snapshot.url, "http://localhost:5173")
        XCTAssertEqual(snapshot.canvases.first?.width, 1280)
        XCTAssertEqual(snapshot.consoleMessages.first?.message, "ready")
    }
}
