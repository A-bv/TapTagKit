import Foundation

private enum Constants {
    static let hashPrefix = "#"
    /// A hashtag token: `#` up to the next whitespace.
    static let tokenPattern = "#\\S+"
    /// Boundaries that match `#tag` only as a whole whitespace-delimited token.
    static let tagBoundaryPrefix = "(?<!\\S)#"
    static let tagBoundarySuffix = "(?!\\S)"
    /// One optional trailing space, swallowed when removing a tag.
    static let trailingSpacePattern = " ?"
    static let spaceCharacter: unichar = 32
    /// Separators inserted above the grouped tags (first grouping vs. later).
    static let firstGroupSeparator = "\n\n"
    static let laterGroupSeparator = " "
}

/// Owns the tag-selection state and the pure text logic behind it: which tags
/// are selected, which hashtag a tap lands on, and how selected tags map onto
/// ranges and edits in the text.
///
/// It holds no UIKit or view state, so it is unit-testable in isolation —
/// `TapTextView` renders whatever this model reports and feeds back user intent.
final class TagSelectionViewModel {

    /// Selected tag words (without `#`) in the order they were selected.
    private(set) var selectedTags: [String] = []

    /// Compiled regexes are cached; a tag's pattern never changes.
    private var regexCache: [String: NSRegularExpression] = [:]

    /// Whether a grouping has already happened this session, which decides the
    /// separator the next grouping inserts.
    private var hasGrouped = false

    var isEmpty: Bool { selectedTags.isEmpty }

    /// The selection as a single `#`-prefixed, space-separated string — the form
    /// used for the clipboard and for the grouped header.
    var hashtagList: String {
        selectedTags.map { Constants.hashPrefix + $0 }.joined(separator: " ")
    }

    // MARK: - Intents

    /// Toggles `tag`, returning the normalized word and its new state.
    @discardableResult
    func toggle(_ tag: String) -> (word: String, isSelected: Bool) {
        let word = normalized(tag)
        if let index = selectedTags.firstIndex(of: word) {
            selectedTags.remove(at: index)
            return (word, false)
        }
        selectedTags.append(word)
        return (word, true)
    }

    /// Adds `tag` if not already selected. Returns the word, or nil for a no-op.
    func select(_ tag: String) -> String? {
        let word = normalized(tag)
        guard !word.isEmpty, !selectedTags.contains(word) else { return nil }
        selectedTags.append(word)
        return word
    }

    /// Removes `tag`. Returns the word, or nil if it wasn't selected.
    func deselect(_ tag: String) -> String? {
        guard let index = selectedTags.firstIndex(of: normalized(tag)) else { return nil }
        return selectedTags.remove(at: index)
    }

    func clear() { selectedTags.removeAll() }

    /// Resets per-session grouping state. Call when a selection session ends.
    func resetGrouping() { hasGrouped = false }

    // MARK: - Text logic

    /// The hashtag word (without `#`) whose token contains `index`, else nil.
    /// A hashtag is `#` up to the next whitespace, so `#c++` is captured whole.
    func hashtagWord(in text: String, at index: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: Constants.tokenPattern) else { return nil }
        let ns = text as NSString
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        where NSLocationInRange(index, match.range) {
            return String(ns.substring(with: match.range).dropFirst())
        }
        return nil
    }

    /// Ranges of every selected tag in `text`, for the view to highlight.
    func highlightRanges(in text: String) -> [NSRange] {
        let full = NSRange(text.startIndex..., in: text)
        return selectedTags.flatMap { tag -> [NSRange] in
            guard let regex = tagRegex(for: tag) else { return [] }
            return regex.matches(in: text, range: full).map(\.range)
        }
    }

    /// `text` with every selected tag removed — plus one trailing space each, so
    /// removing a tag from mid-line doesn't leave a double space.
    func removingSelectedTags(from text: String) -> String {
        selectedTags.reduce(text) { partial, tag in
            let pattern = Constants.tagBoundaryPrefix
                + NSRegularExpression.escapedPattern(for: tag)
                + Constants.tagBoundarySuffix
                + Constants.trailingSpacePattern
            return partial.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
    }

    /// `text` with the selected tags lifted out of their positions and grouped
    /// at the top (in selection order). The first grouping of a session pushes
    /// the body down with a blank line; later ones use a space so the new header
    /// doesn't fuse onto a previously grouped one (`#y#x`). Selection is kept.
    func groupingSelectedTagsAtTop(of text: String) -> String {
        guard !selectedTags.isEmpty else { return text }
        let body = removingSelectedTags(from: text)
        let separator = hasGrouped ? Constants.laterGroupSeparator : Constants.firstGroupSeparator
        hasGrouped = true
        return hashtagList + separator + body
    }

    /// `text` with invalid hashtags and duplicate hashtags removed (keeping the
    /// first occurrence of each, compared case-insensitively). A hashtag is
    /// valid when `#` is followed by a letter, digit, or underscore.
    func cleanedText(_ text: String) -> String {
        let ns = text as NSString
        guard let regex = try? NSRegularExpression(pattern: Constants.tokenPattern) else { return text }

        var seen = Set<String>()
        var rangesToRemove: [NSRange] = []
        regex.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match else { return }
            let word = ns.substring(with: match.range).dropFirst()
            let isValid = word.unicodeScalars.first.map {
                CharacterSet.alphanumerics.contains($0) || $0 == "_"
            } ?? false

            let isDuplicate = isValid && !seen.insert(word.lowercased()).inserted
            guard !isValid || isDuplicate else { return }

            // Swallow one trailing space so removal doesn't leave a double space.
            var range = match.range
            let after = range.location + range.length
            if after < ns.length, ns.character(at: after) == Constants.spaceCharacter { range.length += 1 }
            rangesToRemove.append(range)
        }

        let result = NSMutableString(string: text)
        for range in rangesToRemove.reversed() { result.deleteCharacters(in: range) }
        return result as String
    }

    // MARK: - Helpers

    private func normalized(_ tag: String) -> String {
        tag.hasPrefix(Constants.hashPrefix) ? String(tag.dropFirst()) : tag
    }

    /// Matches `#tag` only as a whole whitespace-delimited token, so `#sun`
    /// never matches inside `#sunny` or `a#sun`, while `#c++` still matches.
    private func tagRegex(for tag: String) -> NSRegularExpression? {
        if let cached = regexCache[tag] { return cached }
        let pattern = Constants.tagBoundaryPrefix
            + NSRegularExpression.escapedPattern(for: tag)
            + Constants.tagBoundarySuffix
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        regexCache[tag] = regex
        return regex
    }
}
