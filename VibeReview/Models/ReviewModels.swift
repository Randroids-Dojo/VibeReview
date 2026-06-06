import Foundation

enum SessionStatus: String, Codable, CaseIterable {
    case active
    case paused
    case ended
}

enum CaptureSeverity: String, Codable, CaseIterable, Identifiable {
    case note
    case polish
    case issue
    case blocksRelease

    var id: String { rawValue }

    var title: String {
        switch self {
        case .note: "Note"
        case .polish: "Polish"
        case .issue: "Issue"
        case .blocksRelease: "Blocks Release"
        }
    }

    var followupPriority: String? {
        switch self {
        case .note:
            nil
        case .polish:
            "polish"
        case .issue:
            "nice-to-have"
        case .blocksRelease:
            "blocks-release"
        }
    }
}

struct BrowserSnapshot: Codable, Equatable {
    var capturedAt: Date
    var url: String?
    var title: String?
    var viewport: Viewport?
    var scroll: ScrollPosition?
    var selectedText: String?
    var focusedElement: String?
    var domSummary: DOMSummary?
    var storage: StorageSummary?
    var canvases: [CanvasSummary]
    var consoleMessages: [ConsoleMessage]

    struct Viewport: Codable, Equatable {
        var width: Int
        var height: Int
        var devicePixelRatio: Double
    }

    struct ScrollPosition: Codable, Equatable {
        var x: Double
        var y: Double
    }

    struct DOMSummary: Codable, Equatable {
        var bodyTextSample: String
        var interactiveElementCount: Int
        var headings: [String]
        var buttons: [String]
    }

    struct StorageSummary: Codable, Equatable {
        var localStorage: [String: String]
        var sessionStorage: [String: String]
    }

    struct CanvasSummary: Codable, Equatable {
        var width: Int
        var height: Int
        var label: String?
    }

    struct ConsoleMessage: Codable, Equatable {
        var level: String
        var message: String
        var timestamp: Date
    }
}

struct ReviewCapture: Codable, Identifiable, Equatable {
    var id: UUID
    var createdAt: Date
    var note: String
    var severity: CaptureSeverity
    var rating: Int
    var tags: [String]
    var screenshotRelativePath: String
    var browserSnapshotRelativePath: String?
    var browserURL: String?
    var browserTitle: String?
    var degradedReason: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        note: String,
        severity: CaptureSeverity,
        rating: Int,
        tags: [String],
        screenshotRelativePath: String,
        browserSnapshotRelativePath: String?,
        browserURL: String?,
        browserTitle: String?,
        degradedReason: String?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.note = note
        self.severity = severity
        self.rating = rating
        self.tags = tags
        self.screenshotRelativePath = screenshotRelativePath
        self.browserSnapshotRelativePath = browserSnapshotRelativePath
        self.browserURL = browserURL
        self.browserTitle = browserTitle
        self.degradedReason = degradedReason
    }
}

struct ReviewSession: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var projectRootPath: String
    var artifactRootPath: String
    var docsProfile: ProjectDocsProfile
    var status: SessionStatus
    var createdAt: Date
    var resumedAt: Date?
    var endedAt: Date?
    var captures: [ReviewCapture]
}
