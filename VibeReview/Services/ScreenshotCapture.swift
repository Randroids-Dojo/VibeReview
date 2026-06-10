import AppKit
import Foundation

protocol ScreenshotCapturing {
    func captureDisplayContainingMouse(to url: URL) throws
}

enum ScreenshotCaptureError: Error, LocalizedError {
    case noDisplayImage
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .noDisplayImage:
            "Unable to capture the selected display. Screen Recording permission may be missing."
        case .pngEncodingFailed:
            "The captured screenshot could not be encoded as PNG."
        }
    }
}

struct CaptureDisplayCandidate {
    var id: CGDirectDisplayID
    var frame: CGRect
}

struct ScreenshotCapture: ScreenshotCapturing {
    func captureDisplayContainingMouse(to url: URL) throws {
        let displayID = Self.displayIDContainingMouse()
        guard let image = CGDisplayCreateImage(displayID) else {
            throw ScreenshotCaptureError.noDisplayImage
        }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenshotCaptureError.pngEncodingFailed
        }
        try data.write(to: url, options: .atomic)
    }

    static func displayIDContainingMouse() -> CGDirectDisplayID {
        let mouseLocation = currentMouseLocation()
        return displayIDContainingMouse(
            mouseLocation: mouseLocation,
            displayContainingPoint: displayID(containing:),
            candidates: activeDisplayCandidates(),
            fallback: CGMainDisplayID()
        )
    }

    static func displayIDContainingMouse(
        mouseLocation: CGPoint,
        displayContainingPoint: (CGPoint) -> CGDirectDisplayID?,
        candidates: [CaptureDisplayCandidate],
        fallback: CGDirectDisplayID
    ) -> CGDirectDisplayID {
        if let displayID = displayContainingPoint(mouseLocation) {
            return displayID
        }
        return selectedDisplayID(mouseLocation: mouseLocation, candidates: candidates, fallback: fallback)
    }

    static func selectedDisplayID(
        mouseLocation: CGPoint,
        candidates: [CaptureDisplayCandidate],
        fallback: CGDirectDisplayID
    ) -> CGDirectDisplayID {
        if let containingDisplay = candidates.first(where: { $0.frame.contains(mouseLocation) }) {
            return containingDisplay.id
        }

        guard let nearestDisplay = candidates.min(by: {
            distanceSquared(from: mouseLocation, to: $0.frame) < distanceSquared(from: mouseLocation, to: $1.frame)
        }) else {
            return fallback
        }
        return nearestDisplay.id
    }

    private static func currentMouseLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? NSEvent.mouseLocation
    }

    private static func displayID(containing point: CGPoint) -> CGDirectDisplayID? {
        var matchingDisplayCount: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 1)
        let error = CGGetDisplaysWithPoint(point, UInt32(displays.count), &displays, &matchingDisplayCount)
        guard error == .success, matchingDisplayCount > 0 else {
            return nil
        }
        return displays[0]
    }

    private static func activeDisplayCandidates() -> [CaptureDisplayCandidate] {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            return []
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displays, &displayCount) == .success else {
            return []
        }

        return displays.prefix(Int(displayCount)).map { displayID in
            CaptureDisplayCandidate(id: displayID, frame: CGDisplayBounds(displayID))
        }
    }

    private static func distanceSquared(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let clampedX = min(max(point.x, rect.minX), rect.maxX)
        let clampedY = min(max(point.y, rect.minY), rect.maxY)
        let dx = point.x - clampedX
        let dy = point.y - clampedY
        return dx * dx + dy * dy
    }
}
