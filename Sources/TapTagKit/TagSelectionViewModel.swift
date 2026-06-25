import Foundation

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
        selectedTags.map { "#" + $0 }.joined(separator: " ")
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
        guard let regex = try? NSRegularExpression(pattern: "#\\S+") else { return nil }
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
            let pattern = "(?<!\\S)#\(NSRegularExpression.escapedPattern(for: tag))(?!\\S) ?"
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
        let separator = hasGrouped ? " " : "\n\n"
        hasGrouped = true
        return hashtagList + separator + body
    }

    // MARK: - Helpers

    private func normalized(_ tag: String) -> String {
        tag.hasPrefix("#") ? String(tag.dropFirst()) : tag
    }

    /// Matches `#tag` only as a whole whitespace-delimited token, so `#sun`
    /// never matches inside `#sunny` or `a#sun`, while `#c++` still matches.
    private func tagRegex(for tag: String) -> NSRegularExpression? {
        if let cached = regexCache[tag] { return cached }
        let pattern = "(?<!\\S)#\(NSRegularExpression.escapedPattern(for: tag))(?!\\S)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        regexCache[tag] = regex
        return regex
    }
}
