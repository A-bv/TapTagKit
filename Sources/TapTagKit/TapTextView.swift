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
        /// Text color drawn over a highlighted tag.
        public var selectedTagTextColor: UIColor
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
            selectedTagTextColor: UIColor = .white,
            placeholder: String? = nil,
            avoidsKeyboard: Bool = false,
            accessibility: Accessibility = Accessibility()
        ) {
            self.toolbarInfoTitle = toolbarInfoTitle
            self.toolbarInfoMessage = toolbarInfoMessage
            self.infoButtonTitle = infoButtonTitle
            self.tagHighlightColor = tagHighlightColor
            self.selectedTagTextColor = selectedTagTextColor
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
    public var selectedTags: Set<String> { Set(viewModel.selectedTags) }

    /// The selected tag words in the order they were selected.
    public var selectedTagsInOrder: [String] { viewModel.selectedTags }

    /// Whether a tag-selection session is currently active.
    public var isSelecting: Bool { tapGestureRecognizer.isEnabled }

    /// Selects `tag` (with or without a leading `#`) and highlights it.
    public func selectTag(_ tag: String) {
        guard let word = viewModel.select(tag) else { return }
        tagDelegate?.tapTextView(self, didSelect: word)
        announce(word, selected: true)
        applyHighlighting()
    }

    /// Removes `tag` from the selection.
    public func deselectTag(_ tag: String) {
        guard let word = viewModel.deselect(tag) else { return }
        tagDelegate?.tapTextView(self, didDeselect: word)
        announce(word, selected: false)
        applyHighlighting()
    }

    /// Clears the whole selection (without changing the text).
    @objc public func clearSelection() {
        viewModel.clear()
        applyHighlighting()
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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public override var text: String! {
        didSet { captureBaseText(); refreshPlaceholder() }
    }

    public override var attributedText: NSAttributedString! {
        didSet { captureBaseText(); refreshPlaceholder() }
    }

    /// Selection state and pure tag/text logic; this view only renders it.
    let viewModel = TagSelectionViewModel()
    /// The caller's text with its own styling, before our highlight overlay.
    /// Highlighting is rebuilt from this each time so user attributes survive.
    private var baseText = NSAttributedString()
    private var isApplyingHighlight = false
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
            style: .plain, target: self, action: #selector(beginSelection))
        activateButton.accessibilityLabel = configuration.accessibility.selectButtonLabel
        return activateButton
    }

    /// Starts a tag-selection session: taps begin selecting hashtags and editing
    /// is suspended. The same thing the activate bar button does.
    @objc public func beginSelection() {
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

    /// Ends the session, clears the selection, and restores editing.
    @objc public func endSelection() {
        clearSelection()
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
            ("doc.on.doc", #selector(copySelectedTags), a11y.copyLabel),
            ("scissors", #selector(cutSelectedTags), a11y.cutLabel),
            ("square.grid.2x2", #selector(groupSelectedTags), a11y.groupLabel),
            ("clear", #selector(clearSelection), a11y.deselectLabel),
            ("delete.right", #selector(deleteSelectedTags), a11y.deleteLabel),
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

        toolbar.append(UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(endSelection)))

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

    /// The hashtag word (without `#`) whose token contains `index`, or nil.
    /// Thin pass-through to the view model over the current text.
    func hashtagWord(at index: Int) -> String? {
        viewModel.hashtagWord(in: text ?? "", at: index)
    }

    func processTappedWord(tappedWord: String?) {
        guard let tappedWord, !tappedWord.isEmpty else { return }
        let change = viewModel.toggle(tappedWord)
        if change.isSelected {
            tagDelegate?.tapTextView(self, didSelect: change.word)
        } else {
            tagDelegate?.tapTextView(self, didDeselect: change.word)
        }
        announce(change.word, selected: change.isSelected)
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

    /// Renders the view model's highlight ranges onto a copy of the base text.
    private func applyHighlighting() {
        let highlighted = NSMutableAttributedString(attributedString: baseText)
        for range in viewModel.highlightRanges(in: baseText.string) {
            highlighted.addAttributes([
                .backgroundColor: configuration.tagHighlightColor,
                .foregroundColor: configuration.selectedTagTextColor,
            ], range: range)
        }
        isApplyingHighlight = true
        attributedText = highlighted
        isApplyingHighlight = false
    }

    // MARK: - Tag actions

    /// Copies the selected tags (space-separated, each prefixed with `#`) to the
    /// general pasteboard.
    @objc public func copySelectedTags() {
        let arrayToCopy = viewModel.selectedTags.map { "#" + $0 }
        UIPasteboard.general.string = arrayToCopy.joined(separator: " ")
    }

    /// Copies the selected tags, then removes them from the text.
    @objc public func cutSelectedTags() {
        copySelectedTags()
        deleteSelectedTags()
    }

    /// Moves every selected tag to the top of the text, in selection order.
    @objc public func groupSelectedTags() {
        let movedWords = viewModel.selectedTags
        guard !movedWords.isEmpty else { return }

        // Remove the tags from their current positions (also clears selection).
        deleteSelectedTags()

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

    /// Removes every selected tag from the text.
    @objc public func deleteSelectedTags() {
        let newText = viewModel.removingSelectedTags(from: text ?? "")
        viewModel.clear()
        text = newText
        applyHighlighting()
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
