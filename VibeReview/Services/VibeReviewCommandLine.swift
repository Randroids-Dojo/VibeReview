import Foundation

enum VibeReviewCLICommand: Equatable {
    case start(projectPath: String, title: String?)
    case capture(projectPath: String, note: NoteSource, severity: CaptureSeverity, rating: Int, tags: [String])
    case end(projectPath: String)
    case status(projectPath: String?)
    case list
    case version
    case help
}

enum NoteSource: Equatable {
    case value(String)
    case file(String)
    case standardInput
}

enum VibeReviewCommandLine {
    static func parse(_ arguments: [String]) throws -> VibeReviewCLICommand {
        var reader = ArgumentReader(arguments)
        guard let command = reader.next() else {
            return .help
        }

        switch command {
        case "-h", "--help", "help":
            return .help
        case "--version", "version":
            return .version
        case "start":
            let flags = try reader.readFlags()
            try flags.rejectUnknown(allowed: ["project", "title"])
            return .start(
                projectPath: try flags.required("project"),
                title: flags.optional("title")
            )
        case "capture":
            let flags = try reader.readFlags()
            try flags.rejectUnknown(allowed: ["project", "note", "note-file", "severity", "rating", "tags"])
            let note = try noteSource(from: flags)
            let severity = try severity(from: flags.optional("severity"))
            let rating = try rating(from: flags.optional("rating"))
            return .capture(
                projectPath: try flags.required("project"),
                note: note,
                severity: severity,
                rating: rating,
                tags: tags(from: flags.optional("tags"))
            )
        case "end":
            let flags = try reader.readFlags()
            try flags.rejectUnknown(allowed: ["project"])
            return .end(projectPath: try flags.required("project"))
        case "status":
            let flags = try reader.readFlags()
            try flags.rejectUnknown(allowed: ["project"])
            return .status(projectPath: flags.optional("project"))
        case "list":
            let flags = try reader.readFlags()
            try flags.rejectUnknown(allowed: [])
            return .list
        default:
            throw VibeReviewCLIError("Unknown command `\(command)`.")
        }
    }

    static let helpText = """
    Usage:
      vibereview start --project <path> [--title <title>]
      vibereview capture --project <path> --note <text> [--severity note|polish|issue|blocksRelease] [--rating 1...5] [--tags a,b,c]
      vibereview capture --project <path> --note-file <path-or->
      vibereview end --project <path>
      vibereview status [--project <path>]
      vibereview list
      vibereview --version
    """

    private static func noteSource(from flags: ParsedFlags) throws -> NoteSource {
        let note = flags.optional("note")
        let noteFile = flags.optional("note-file")
        if note != nil, noteFile != nil {
            throw VibeReviewCLIError("Use only one of `--note` or `--note-file`.")
        }
        if let note {
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw VibeReviewCLIError("`--note` cannot be empty.")
            }
            return .value(trimmed)
        }
        if let noteFile {
            guard !noteFile.isEmpty else {
                throw VibeReviewCLIError("`--note-file` cannot be empty.")
            }
            return noteFile == "-" ? .standardInput : .file(noteFile)
        }
        throw VibeReviewCLIError("Capture requires `--note` or `--note-file`.")
    }

    private static func severity(from rawValue: String?) throws -> CaptureSeverity {
        guard let rawValue else { return .issue }
        guard let severity = CaptureSeverity(rawValue: rawValue) else {
            throw VibeReviewCLIError("Invalid severity `\(rawValue)`. Use note, polish, issue, or blocksRelease.")
        }
        return severity
    }

    private static func rating(from rawValue: String?) throws -> Int {
        guard let rawValue else { return 3 }
        guard let rating = Int(rawValue), (1...5).contains(rating) else {
            throw VibeReviewCLIError("Invalid rating `\(rawValue)`. Use an integer from 1 through 5.")
        }
        return rating
    }

    private static func tags(from rawValue: String?) -> [String] {
        guard let rawValue else { return [] }
        return rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct VibeReviewCLIError: LocalizedError, Equatable {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}

private struct ArgumentReader {
    private var arguments: [String]
    private var index = 0

    init(_ arguments: [String]) {
        self.arguments = arguments
    }

    mutating func next() -> String? {
        guard index < arguments.count else { return nil }
        defer { index += 1 }
        return arguments[index]
    }

    mutating func readFlags() throws -> ParsedFlags {
        var values: [String: String] = [:]
        while let argument = next() {
            guard argument.hasPrefix("--") else {
                throw VibeReviewCLIError("Unexpected argument `\(argument)`.")
            }

            let trimmed = String(argument.dropFirst(2))
            let key: String
            let value: String
            if let equals = trimmed.firstIndex(of: "=") {
                key = String(trimmed[..<equals])
                value = String(trimmed[trimmed.index(after: equals)...])
            } else {
                key = trimmed
                guard let nextValue = next(), !nextValue.hasPrefix("--") else {
                    throw VibeReviewCLIError("Missing value for `--\(key)`.")
                }
                value = nextValue
            }

            guard !key.isEmpty else {
                throw VibeReviewCLIError("Empty flag name.")
            }
            values[key] = value
        }
        return ParsedFlags(values: values)
    }
}

private struct ParsedFlags {
    let values: [String: String]

    func required(_ key: String) throws -> String {
        guard let value = values[key], !value.isEmpty else {
            throw VibeReviewCLIError("Missing required `--\(key)`.")
        }
        return value
    }

    func optional(_ key: String) -> String? {
        values[key]
    }

    func rejectUnknown(allowed: Set<String>) throws {
        let unknown = values.keys.filter { !allowed.contains($0) }.sorted()
        guard unknown.isEmpty else {
            throw VibeReviewCLIError("Unknown flag `--\(unknown[0])`.")
        }
    }
}
