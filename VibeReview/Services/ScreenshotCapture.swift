import AppKit
import Foundation

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

struct ScreenshotCapture {
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

    static func displayIDContainingMouse(
        mouseLocation: CGPoint = NSEvent.mouseLocation,
        screens: [NSScreen] = NSScreen.screens,
        mainDisplayID: CGDirectDisplayID = CGMainDisplayID()
    ) -> CGDirectDisplayID {
        let candidates = screens.compactMap { screen -> CaptureDisplayCandidate? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            return CaptureDisplayCandidate(id: CGDirectDisplayID(number.uint32Value), frame: screen.frame)
        }
        return selectedDisplayID(mouseLocation: mouseLocation, candidates: candidates, fallback: mainDisplayID)
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

    private static func distanceSquared(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let clampedX = min(max(point.x, rect.minX), rect.maxX)
        let clampedY = min(max(point.y, rect.minY), rect.maxY)
        let dx = point.x - clampedX
        let dy = point.y - clampedY
        return dx * dx + dy * dy
    }
}
