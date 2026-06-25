import UIKit

public protocol TapTextViewDelegate: AnyObject {
    func tapTextViewDidStartSelection(_ textView: TapTextView)
    func tapTextViewDidFinishSelection(_ textView: TapTextView)
    func tapTextView(_ textView: TapTextView, didSelect tag: String)
    func tapTextView(_ textView: TapTextView, didDeselect tag: String)
}

public extension TapTextViewDelegate {
    func tapTextViewDidStartSelection(_ textView: TapTextView) {}
    func tapTextViewDidFinishSelection(_ textView: TapTextView) {}
    func tapTextView(_ textView: TapTextView, didSelect tag: String) {}
    func tapTextView(_ textView: TapTextView, didDeselect tag: String) {}
}

/// A `UITextView` whose hashtags become tappable: a selection mode where
/// tapping a tag highlights every occurrence, plus a toolbar to copy, cut,
/// group, deselect, or delete the selected tags at once.
public class TapTextView: UITextView {

    /// UI strings and styling, injectable for localization and theming.
    /// Properties are mutable, so tweak a single field with e.g.
    /// `config.accessibility.copyLabel = "…"` without restating the rest.
    public struct Configuration {
        public var toolbarInfoTitle: String
        public var toolbarInfoMessage: String
        public var infoButtonTitle: String
        public var tagHighlightColor: UIColor
        /// Shown while the text view is empty; nil disables the placeholder.
        public var placeholder: String?
        /// Keeps the text content above the keyboard via content insets.
        public var avoidsKeyboard: Bool
        /// VoiceOver labels, hints, and announcements.
        public var accessibility: Accessibility

        /// All accessibility-facing strings, grouped so localization lives in
        /// one place. Announcements are closures so callers control wording.
        public struct Accessibility {
            public var selectButtonLabel = "Select hashtags"
            public var copyLabel = "Copy selected hashtags"
            public var cutLabel = "Cut selected hashtags"
            public var groupLabel = "Group selected hashtags at top"
            public var deselectLabel = "Deselect all hashtags"
            public var deleteLabel = "Delete selected hashtags"
            public var infoLabel = "About these actions"
            public var selectionHint = "Double tap a hashtag to select it."
            public var didSelectAnnouncement: (_ tag: String) -> String = { "Selected \($0)" }
            public var didDeselectAnnouncement: (_ tag: String) -> String = { "Deselected \($0)" }
            public init() {}
        }

        public init(
            toolbarInfoTitle: String = "Actions on selected hashtags",
            toolbarInfoMessage: String = "Copy, cut, group, deselect, or delete every selected hashtag at once.",
            infoButtonTitle: String = "OK",
            tagHighlightColor: UIColor = UIColor(red: 0.808, green: 0.027, blue: 0.333, alpha: 1),
            placeholder: String? = nil,
            avoidsKeyboard: Bool = false,
            accessibility: Accessibility = Accessibility()
        ) {
            self.toolbarInfoTitle = toolbarInfoTitle
            self.toolbarInfoMessage = toolbarInfoMessage
            self.infoButtonTitle = infoButtonTitle
            self.tagHighlightColor = tagHighlightColor
            self.placeholder = placeholder
            self.avoidsKeyboard = avoidsKeyboard
            self.accessibility = accessibility
        }
    }

    public var configuration = Configuration() {
        didSet { applyConfiguration() }
    }
    public weak var tagDelegate: TapTextViewDelegate?

    /// The tag words currently selected (without the `#` prefix).
    public var selectedTags: Set<String> { Set(selectedTagWords) }

    /// The selected tag words in the order they were selected.
    public var selectedTagsInOrder: [String] { selectedTagWords }

    /// Whether a tag-selection session is currently active.
    public var isSelecting: Bool { tapGestureRecognizer.isEnabled }

    /// Selects `tag` (with or without a leading `#`) and highlights it.
    public func selectTag(_ tag: String) {
        let word = normalizedTag(tag)
        guard !word.isEmpty, !selectedTagWords.contains(word) else { return }
        selectedTagWords.append(word)
        tagDelegate?.tapTextView(self, didSelect: word)
        announce(word, selected: true)
        applyHighlighting()
    }

    /// Removes `tag` from the selection.
    public func deselectTag(_ tag: String) {
        guard let index = selectedTagWords.firstIndex(of: normalizedTag(tag)) else { return }
        let word = selectedTagWords.remove(at: index)
        tagDelegate?.tapTextView(self, didDeselect: word)
        announce(word, selected: false)
        applyHighlighting()
    }

    /// Clears the whole selection.
    public func clearSelection() { cleanTagSelection() }

    private func normalizedTag(_ tag: String) -> String {
        tag.hasPrefix("#") ? String(tag.dropFirst()) : tag
    }

    // MARK: - Init

    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        installTapRecognizer()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        installTapRecognizer()
    }

    public override var text: String! {
        didSet { captureBaseText(); refreshPlaceholder() }
    }

    public override var attributedText: NSAttributedString! {
        didSet { captureBaseText(); refreshPlaceholder() }
    }

    /// Selected tag words in tap order (without `#`). Ordered so actions like
    /// grouping are deterministic; uniqueness is enforced on insert.
    var selectedTagWords = [String]()
    /// The caller's text with its own styling, before our highlight overlay.
    /// Highlighting is rebuilt from this each time so user attributes survive.
    private var baseText = NSAttributedString()
    private var isApplyingHighlight = false
    private var regexCache = [String: NSRegularExpression]()
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private var tapGestureRecognizer = UITapGestureRecognizer()
    private var firstTimeGrouped = false
    private var activateButton = UIBarButtonItem()
    private weak var presentingViewController: UIViewController?
    private let placeholderLabel = UILabel()

    // MARK: - Configuration

    private func applyConfiguration() {
        installPlaceholderIfNeeded()
        installKeyboardAvoidanceIfNeeded()
    }

    private var placeholderObserverInstalled = false

    private func installPlaceholderIfNeeded() {
        guard let placeholder = configuration.placeholder else {
            placeholderLabel.removeFromSuperview()
            if placeholderObserverInstalled {
                placeholderObserverInstalled = false
                NotificationCenter.default.removeObserver(
                    self, name: UITextView.textDidChangeNotification, object: self)
            }
            return
        }

        placeholderLabel.text = placeholder
        placeholderLabel.font = .italicSystemFont(ofSize: font?.pointSize ?? UIFont.labelFontSize)
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.sizeToFit()
        // Align with the real text origin instead of a magic inset.
        placeholderLabel.frame.origin = CGPoint(
            x: textContainerInset.left + textContainer.lineFragmentPadding,
            y: textContainerInset.top)

        if placeholderLabel.superview == nil {
            addSubview(placeholderLabel)
        }
        if !placeholderObserverInstalled {
            placeholderObserverInstalled = true
            NotificationCenter.default.addObserver(
                self, selector: #selector(refreshPlaceholder),
                name: UITextView.textDidChangeNotification, object: self)
        }
        refreshPlaceholder()
    }

    @objc private func refreshPlaceholder() {
        placeholderLabel.isHidden = !(text ?? "").isEmpty
    }

    private var keyboardObserversInstalled = false

    private func installKeyboardAvoidanceIfNeeded() {
        // applyConfiguration() runs on every `configuration` assignment, so this
        // must be idempotent — and must tear down when the flag is turned off.
        if configuration.avoidsKeyboard {
            guard !keyboardObserversInstalled else { return }
            keyboardObserversInstalled = true
            NotificationCenter.default.addObserver(
                self, selector: #selector(adjustForKeyboard),
                name: UIResponder.keyboardWillHideNotification, object: nil)
            NotificationCenter.default.addObserver(
                self, selector: #selector(adjustForKeyboard),
                name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        } else if keyboardObserversInstalled {
            keyboardObserversInstalled = false
            NotificationCenter.default.removeObserver(
                self, name: UIResponder.keyboardWillHideNotification, object: nil)
            NotificationCenter.default.removeObserver(
                self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
            contentInset = .zero
            scrollIndicatorInsets = .zero
        }
    }

    @objc private func adjustForKeyboard(notification: Notification) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

        if notification.name == UIResponder.keyboardWillHideNotification {
            contentInset = .zero
        } else {
            contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardValue.cgRectValue.height, right: 0)
        }
        scrollIndicatorInsets = contentInset
    }

    // MARK: - Activation

    /// Installs the selection toolbar on `viewController` (shown while a
    /// selection session is active).
    public func addTagSelectorToolBar(viewController: UIViewController) {
        presentingViewController = viewController
        viewController.toolbarItems = makeToolbarItems()
    }

    /// The bar button that starts a tag-selection session.
    public func makeTapTextViewButton() -> UIBarButtonItem {
        activateButton = UIBarButtonItem(
            image: UIImage(systemName: "hand.point.up.left"),
            style: .plain, target: self, action: #selector(startTagSelection))
        activateButton.accessibilityLabel = configuration.accessibility.selectButtonLabel
        return activateButton
    }

    @objc private func startTagSelection() {
        guard !tapGestureRecognizer.isEnabled else { return }
        self.resignFirstResponder()
        tapGestureRecognizer.isEnabled = true
        isEditable = false
        isSelectable = false
        feedbackGenerator.prepare()
        accessibilityHint = configuration.accessibility.selectionHint
        tagDelegate?.tapTextViewDidStartSelection(self)
        activateButton.isEnabled = false
    }

    @objc private func doneTagSelection() {
        cleanTagSelection()
        tapGestureRecognizer.isEnabled = false
        isEditable = true
        isSelectable = true
        firstTimeGrouped = false
        accessibilityHint = nil
        tagDelegate?.tapTextViewDidFinishSelection(self)
        activateButton.isEnabled = true
    }

    private func installTapRecognizer() {
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapResponse(recognizer:)))
        tapGestureRecognizer.isEnabled = false
        addGestureRecognizer(tapGestureRecognizer)
    }

    // MARK: - Toolbar

    /// The selection actions as toolbar items: 6 buttons interleaved with
    /// flexible spacers, ending in a Done button. Public so callers can place
    /// them anywhere (a custom `UIToolbar`, an input accessory view) rather than
    /// only on the host's `toolbarItems`.
    public func makeToolbarItems() -> [UIBarButtonItem] {
        let a11y = configuration.accessibility
        let buttons: [(symbol: String, action: Selector, label: String)] = [
            ("doc.on.doc", #selector(copyTagSelection), a11y.copyLabel),
            ("scissors", #selector(cutTagSelection), a11y.cutLabel),
            ("square.grid.2x2", #selector(groupTagSelection), a11y.groupLabel),
            ("clear", #selector(cleanTagSelection), a11y.deselectLabel),
            ("delete.right", #selector(deleteTagSelection), a11y.deleteLabel),
            ("questionmark.circle.fill", #selector(toolbarInfo), a11y.infoLabel),
        ]

        var toolbar: [UIBarButtonItem] = []

        for (index, button) in buttons.enumerated() {
            let item = UIBarButtonItem(
                image: UIImage(systemName: button.symbol),
                style: .plain, target: self, action: button.action)
            item.accessibilityLabel = button.label

            if index == buttons.count - 1 {
                item.tintColor = .systemOrange
            }
            toolbar.append(item)
            toolbar.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil))
        }

        toolbar.append(UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTagSelection)))

        return toolbar
    }

    // MARK: - Selection

    @objc private func tapResponse(recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: self)
        guard let tapPosition = closestPosition(to: location) else { return }

        let index = offset(from: beginningOfDocument, to: tapPosition)
        guard let word = hashtagWord(at: index) else { return }

        feedbackGenerator.impactOccurred()
        feedbackGenerator.prepare()   // keep the Taptic Engine warm for the next tap
        processTappedWord(tappedWord: word)
    }

    /// The hashtag word (without `#`) whose token contains `index`, or nil if
    /// the tap landed outside a hashtag. A hashtag is `#` up to the next
    /// whitespace, so multi-character tags like `#c++` are captured whole —
    /// unlike word-granularity tokenizing, which stops at the first `+`.
    func hashtagWord(at index: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "#\\S+") else { return nil }
        let source = text ?? ""
        let ns = source as NSString
        for match in regex.matches(in: source, range: NSRange(location: 0, length: ns.length))
        where NSLocationInRange(index, match.range) {
            return String(ns.substring(with: match.range).dropFirst())
        }
        return nil
    }

    func processTappedWord(tappedWord: String?) {
        guard let tappedWord, !tappedWord.isEmpty else { return }

        if let index = selectedTagWords.firstIndex(of: tappedWord) {
            selectedTagWords.remove(at: index)
            tagDelegate?.tapTextView(self, didDeselect: tappedWord)
            announce(tappedWord, selected: false)
        } else {
            selectedTagWords.append(tappedWord)
            tagDelegate?.tapTextView(self, didSelect: tappedWord)
            announce(tappedWord, selected: true)
        }
        applyHighlighting()
    }

    /// Posts a VoiceOver announcement so selection changes aren't silent.
    private func announce(_ tag: String, selected: Bool) {
        let a11y = configuration.accessibility
        let message = selected ? a11y.didSelectAnnouncement("#\(tag)")
                               : a11y.didDeselectAnnouncement("#\(tag)")
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    /// Snapshots the caller's styled text so highlighting can be layered on top
    /// of it without discarding their fonts, colors, links, etc. Skipped while
    /// we are the ones writing the highlighted result back.
    private func captureBaseText() {
        guard !isApplyingHighlight else { return }
        baseText = attributedText ?? NSAttributedString(string: text ?? "")
    }

    /// Matches `#tag` only as a whole whitespace-delimited token, so `#sun`
    /// never matches inside `#sunny` or `a#sun`, while punctuation tags like
    /// `#c++` still match. Mirrors how `hashtagWord(at:)` reads tokens.
    /// Compiled regexes are cached since the pattern depends only on the tag.
    private func tagRegex(for tag: String) -> NSRegularExpression? {
        if let cached = regexCache[tag] { return cached }
        let pattern = "(?<!\\S)#\(NSRegularExpression.escapedPattern(for: tag))(?!\\S)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        regexCache[tag] = regex
        return regex
    }

    private func applyHighlighting() {
        let highlighted = NSMutableAttributedString(attributedString: baseText)
        let source = baseText.string
        let fullRange = NSRange(source.startIndex..., in: source)
        for tag in selectedTagWords {
            guard let regex = tagRegex(for: tag) else { continue }
            for match in regex.matches(in: source, range: fullRange) {
                highlighted.addAttributes([
                    .backgroundColor: configuration.tagHighlightColor,
                    .foregroundColor: UIColor.white,
                ], range: match.range)
            }
        }
        isApplyingHighlight = true
        attributedText = highlighted
        isApplyingHighlight = false
    }

    // MARK: - Toolbar actions

    @objc private func copyTagSelection() {
        let arrayToCopy = selectedTagWords.map { "#" + $0 }
        UIPasteboard.general.string = arrayToCopy.joined(separator: " ")
    }

    @objc private func cutTagSelection() {
        copyTagSelection()
        deleteTagSelection()
    }

    @objc func groupTagSelection() {
        let movedWords = selectedTagWords
        guard !movedWords.isEmpty else { return }

        // Remove the tags from their current positions (also clears selection).
        deleteTagSelection()

        // Re-insert them, grouped, at the top. The first grouping pushes the
        // body down with a blank line; later groupings only need a space so the
        // new tags don't fuse onto the previously grouped ones (#y#x).
        let separator = firstTimeGrouped ? " " : "\n\n"
        firstTimeGrouped = true
        let grouped = movedWords.map { "#" + $0 }.joined(separator: " ")
        text = grouped + separator + (text ?? "")

        // Restore the selection (and highlight) on the moved tags.
        movedWords.forEach { processTappedWord(tappedWord: $0) }

        scrollRangeToVisible(NSRange(location: 0, length: 0))
    }

    @objc private func cleanTagSelection() {
        selectedTagWords.removeAll()
        applyHighlighting()
    }

    @objc func deleteTagSelection() {
        let toDelete = selectedTagWords
        selectedTagWords.removeAll()
        applyHighlighting()
        for tag in toDelete {
            // Consume one trailing space with the tag so removing a tag from the
            // middle of a line doesn't leave a double space behind.
            let pattern = "(?<!\\S)#\(NSRegularExpression.escapedPattern(for: tag))(?!\\S) ?"
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
    }

    @objc private func toolbarInfo() {
        guard let presentingViewController else { return }
        let alert = UIAlertController(
            title: configuration.toolbarInfoTitle,
            message: configuration.toolbarInfoMessage,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: configuration.infoButtonTitle, style: .default))
        presentingViewController.present(alert, animated: true)
    }
}
