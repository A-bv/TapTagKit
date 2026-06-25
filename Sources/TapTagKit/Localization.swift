import Foundation

/// Localized strings shipped by the package (English + French). Resolved from
/// `Bundle.module` so they follow the app's language, and overridable per
/// instance through ``TapTextView/Configuration/Accessibility``.
enum L {
    // Keys — kept together so the string table stays in sync with the code.
    private enum Key {
        static let select = "ttk.select"
        static let copy = "ttk.copy"
        static let cut = "ttk.cut"
        static let group = "ttk.group"
        static let deselect = "ttk.deselect"
        static let delete = "ttk.delete"
        static let done = "ttk.done"
        static let cancel = "ttk.cancel"
        static let deleteConfirm = "ttk.deleteConfirm"
        static let hint = "ttk.hint"
        static let selected = "ttk.selected"
        static let deselected = "ttk.deselected"
    }

    static var select: String { string(Key.select, "Select hashtags") }
    static var copy: String { string(Key.copy, "Copy") }
    static var cut: String { string(Key.cut, "Cut") }
    static var group: String { string(Key.group, "Group") }
    static var deselect: String { string(Key.deselect, "Deselect") }
    static var delete: String { string(Key.delete, "Delete") }
    static var done: String { string(Key.done, "Done") }
    static var cancel: String { string(Key.cancel, "Cancel") }
    static var deleteConfirm: String { string(Key.deleteConfirm, "Delete these hashtags?") }
    static var hint: String { string(Key.hint, "Double tap a hashtag to select it.") }

    static func selected(_ tag: String) -> String { String(format: string(Key.selected, "Selected %@"), tag) }
    static func deselected(_ tag: String) -> String { String(format: string(Key.deselected, "Deselected %@"), tag) }

    private static func string(_ key: String, _ fallback: String) -> String {
        NSLocalizedString(key, bundle: .module, value: fallback, comment: "")
    }

    /// The package's resource bundle — exposed so tests can read a specific
    /// language's table directly.
    static var bundle: Bundle { .module }
}
