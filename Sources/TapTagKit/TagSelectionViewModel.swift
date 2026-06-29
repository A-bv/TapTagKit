import Foundation

private enum Constants {
    static let hashPrefix = "#"
    /// A hashtag token: `#` up to the next whitespace.
    static let tokenPattern = "#\\S+"
    /// Boundaries that match `#tag` only as a whole whitespace-delimited token.
    static let tagBoundaryPrefix = "(?<!\\S)#"
    static let tagBoundarySuffix = "(?!\\S)"
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

    /// The hashtag-token regex (`#\S+`) is constant, so compile it once and
    /// reuse it across taps, token scans, and clean-up.
    private lazy var tokenRegex = try? NSRegularExpression(pattern: Constants.tokenPattern)

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
        guard let regex = tokenRegex else { return nil }
        let ns = text as NSString
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        where NSLocationInRange(index, match.range) {
            return String(ns.substring(with: match.range).dropFirst())
        }
        return nil
    }

    /// Every hashtag token in `text` as its word (without `#`) and range —
    /// used to expose each tag as a VoiceOver element.
    func hashtagTokens(in text: String) -> [(word: String, range: NSRange)] {
        guard let regex = tokenRegex else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            let word = String(ns.substring(with: match.range).dropFirst())
            return word.isEmpty ? nil : (word, match.range)
        }
    }

    /// Ranges of every selected tag in `text`, for the view to highlight.
    func highlightRanges(in text: String) -> [NSRange] {
        let full = NSRange(text.startIndex..., in: text)
        return selectedTags.flatMap { tag -> [NSRange] in
            guard let regex = tagRegex(for: tag) else { return [] }
            return regex.matches(in: text, range: full).map(\.range)
        }
    }

    /// `text` (attributed, so the caller's fonts/colors/links survive) with every
    /// selected tag removed. Each removal also swallows one adjacent space —
    /// trailing when present, otherwise leading — so neither a mid-line double
    /// space nor a dangling edge space is left behind.
    func removingSelectedTags(from text: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text)
        for tag in selectedTags {
            guard let regex = tagRegex(for: tag) else { continue }
            let ns = result.string as NSString
            let matches = regex.matches(in: result.string, range: NSRange(location: 0, length: ns.length))
            // Delete from the end so earlier ranges stay valid as we mutate.
            for match in matches.reversed() {
                var range = match.range
                let after = range.location + range.length
                if after < ns.length, ns.character(at: after) == Constants.spaceCharacter {
                    range.length += 1                       // swallow the trailing space
                } else if range.location > 0, ns.character(at: range.location - 1) == Constants.spaceCharacter {
                    range.location -= 1                      // else swallow the leading space
                    range.length += 1
                }
                result.deleteCharacters(in: range)
            }
        }
        return result
    }

    /// Plain-text convenience over the attributed `removingSelectedTags(from:)`.
    func removingSelectedTags(from text: String) -> String {
        removingSelectedTags(from: NSAttributedString(string: text)).string
    }

    /// `text` with the selected tags lifted out of their positions and grouped
    /// at the top (in selection order). The first grouping of a session pushes
    /// the body down with a blank line; later ones use a space so the new header
    /// doesn't fuse onto a previously grouped one (`#y#x`). Selection is kept.
    func groupingSelectedTagsAtTop(of text: NSAttributedString) -> NSAttributedString {
        guard !selectedTags.isEmpty else { return text }
        let body = removingSelectedTags(from: text)

        // Rebuild the `#tag #tag` header from each tag's original attributed run,
        // so a lifted tag keeps the styling it had in place.
        let header = NSMutableAttributedString()
        for tag in selectedTags {
            if header.length > 0 { header.append(NSAttributedString(string: Constants.laterGroupSeparator)) }
            header.append(attributedToken(for: tag, in: text))
        }

        let separator = hasGrouped ? Constants.laterGroupSeparator : Constants.firstGroupSeparator
        hasGrouped = true
        let result = NSMutableAttributedString(attributedString: header)
        result.append(NSAttributedString(string: separator))
        result.append(body)
        return result
    }

    /// Plain-text convenience over the attributed `groupingSelectedTagsAtTop(of:)`.
    func groupingSelectedTagsAtTop(of text: String) -> String {
        groupingSelectedTagsAtTop(of: NSAttributedString(string: text)).string
    }

    /// `text` with invalid hashtags and duplicate hashtags removed (keeping the
    /// first occurrence of each, compared case-insensitively). A hashtag is
    /// valid when `#` is followed by a letter, digit, or underscore.
    func cleanedText(_ text: NSAttributedString) -> NSAttributedString {
        let source = text.string
        let ns = source as NSString
        guard let regex = tokenRegex else { return text }

        var seen = Set<String>()
        var rangesToRemove: [NSRange] = []
        regex.enumerateMatches(in: source, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
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

        let result = NSMutableAttributedString(attributedString: text)
        for range in rangesToRemove.reversed() { result.deleteCharacters(in: range) }
        return result
    }

    /// Plain-text convenience over the attributed `cleanedText(_:)`.
    func cleanedText(_ text: String) -> String {
        cleanedText(NSAttributedString(string: text)).string
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

    /// The attributed `#tag` run as it appears in `text` (first occurrence), so a
    /// lifted tag keeps its original styling. Falls back to a plain `#tag` when
    /// the tag isn't present in the text (e.g. selected programmatically).
    private func attributedToken(for tag: String, in text: NSAttributedString) -> NSAttributedString {
        let source = text.string
        if let regex = tagRegex(for: tag),
           let match = regex.firstMatch(in: source, range: NSRange(location: 0, length: (source as NSString).length)) {
            return text.attributedSubstring(from: match.range)
        }
        return NSAttributedString(string: Constants.hashPrefix + tag)
    }
}
