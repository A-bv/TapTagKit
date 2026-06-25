import UIKit

/// A VoiceOver element for one hashtag occurrence while a selection session is
/// active. It reads as a button whose value reflects selection, and activating
/// it (VoiceOver double-tap) toggles that tag — exactly like a sighted tap.
final class TagAccessibilityElement: UIAccessibilityElement {
    /// The tag word, without the leading `#`.
    let word: String
    private let onActivate: (String) -> Void

    init(
        container: Any,
        word: String,
        frame: CGRect,
        isSelected: Bool,
        onActivate: @escaping (String) -> Void
    ) {
        self.word = word
        self.onActivate = onActivate
        super.init(accessibilityContainer: container)
        accessibilityLabel = "#" + word
        accessibilityFrameInContainerSpace = frame
        // `.selected` makes VoiceOver announce "selected"; `.button` prompts
        // "double-tap to activate".
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }

    override func accessibilityActivate() -> Bool {
        onActivate(word)
        return true
    }
}
