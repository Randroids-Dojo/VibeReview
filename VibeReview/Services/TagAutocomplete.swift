import Foundation

enum TagAutocomplete {
    static func suggestions(for text: String, knownTags: [String], limit: Int = 5) -> [String] {
        let token = currentToken(in: text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return [] }

        var seen = Set<String>()
        let tokenKey = token.lowercased()
        return knownTags
            .filter { tag in
                let key = tag.lowercased()
                guard !seen.contains(key), key.hasPrefix(tokenKey), key != tokenKey else {
                    return false
                }
                seen.insert(key)
                return true
            }
            .sorted { first, second in
                first.localizedCaseInsensitiveCompare(second) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    static func replacingCurrentToken(in text: String, with tag: String) -> String {
        guard let commaRange = text.range(of: ",", options: .backwards) else {
            return "\(tag), "
        }

        let prefix = text[..<commaRange.upperBound]
        let afterComma = text[commaRange.upperBound...]
        let whitespace = afterComma.prefix { character in
            character.isWhitespace
        }
        return "\(prefix)\(whitespace)\(tag), "
    }

    private static func currentToken(in text: String) -> String {
        guard let commaRange = text.range(of: ",", options: .backwards) else {
            return text
        }
        return String(text[commaRange.upperBound...])
    }
}
