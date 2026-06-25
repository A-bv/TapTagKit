import UIKit

public protocol TapTextViewDelegate: AnyObject {
    func tapTextViewDidStartSelection(_ textView: TapTextView)
    func tapTextViewDidFinishSelection(_ textView: TapTextView)
    func tapTextViewDidChangeText(_ textView: TapTextView)
    func tapTextView(_ textView: TapTextView, didSelect tag: String)
    func tapTextView(_ textView: TapTextView, didDeselect tag: String)
}

public extension TapTextViewDelegate {
    func tapTextViewDidStartSelection(_ textView: TapTextView) {}
    func tapTextViewDidFinishSelection(_ textView: TapTextView) {}
    func tapTextViewDidChangeText(_ textView: TapTextView) {}
    func tapTextView(_ textView: TapTextView, didSelect tag: String) {}
    func tapTextView(_ textView: TapTextView, didDeselect tag: String) {}
}

/// A `UITextView` whose hashtags become tappable: enter selection mode, tap a
/// tag to highlight every occurrence, then copy, cut, group, deselect, or
/// delete the whole selection from a built-in toolbar that manages itself.
public class TapTextView: UITextView {

    /// Highlight colors and accessibility strings — injectable for theming and
    /// localization. Tweak a single field, e.g. `config.accessibility.copyLabel`.
    public struct Configuration {
        public var tagHighlightColor: UIColor
        /// Text color drawn over a highlighted tag.
        public var selectedTagTextColor: UIColor
        public var accessibility: Accessibility

        /// Short labels double as the button captions and the VoiceOver labels,
        /// so there's one localizable string per action.
        public struct Accessibility {
            public var selectButtonLabel = "Select hashtags"
            public var copyLabel = "Copy"
            public var cutLabel = "Cut"
            public var groupLabel = "Group"
            public var deselectLabel = "Deselect"
            public var deleteLabel = "Delete"
            public var doneLabel = "Done"
            public var selectionHint = "Double tap a hashtag to select it."
            /// Shown on the confirmation alert when finishing with edits made.
            public var keepChangesTitle = "Keep your changes?"
            public var undoLabel = "Undo"
            public var didSelectAnnouncement: (_ tag: String) -> String = { "Selected \($0)" }
            public var didDeselectAnnouncement: (_ tag: String) -> String = { "Deselected \($0)" }
            public init() {}
        }

        public init(
            tagHighlightColor: UIColor = UIColor(red: 0.808, green: 0.027, blue: 0.333, alpha: 1),
            selectedTagTextColor: UIColor = .white,
            accessibility: Accessibility = Accessibility()
        ) {
            self.tagHighlightColor = tagHighlightColor
            self.selectedTagTextColor = selectedTagTextColor
            self.accessibility = accessibility
        }
    }

    public var configuration = Configuration() {
        didSet { applyHighlighting() }
    }
    public weak var tagDelegate: TapTextViewDelegate?

    /// Removes duplicate/invalid hashtags automatically when a session starts.
    public var removesDuplicatesOnSelection = true

    /// The tag words currently selected (without the `#` prefix).
    public var selectedTags: Set<String> { Set(viewModel.selectedTags) }
    /// The selected tag words in the order they were selected.
    public var selectedTagsInOrder: [String] { viewModel.selectedTags }
    /// Whether a tag-selection session is currently active.
    public var isSelecting: Bool { tapGestureRecognizer.isEnabled }

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
        didSet { captureBaseText() }
    }

    public override var attributedText: NSAttributedString! {
        didSet { captureBaseText() }
    }

    private let viewModel = TagSelectionViewModel()
    /// The caller's text with its own styling, before our highlight overlay.
    private var baseText = NSAttributedString()
    private var isApplyingHighlight = false
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private var tapGestureRecognizer = UITapGestureRecognizer()
    private var activateButton = UIBarButtonItem()
    /// Text captured when the session began, restored by Undo.
    private var initialText: String?
    /// Pasteboard used by copy/cut. Injectable so tests avoid the shared global.
    var pasteboard: UIPasteboard = .general

    private func installTapRecognizer() {
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapResponse(recognizer:)))
        tapGestureRecognizer.isEnabled = false
        addGestureRecognizer(tapGestureRecognizer)
    }

    // MARK: - Session

    /// A bar button that starts a selection session — drop it in a nav bar, or
    /// just call `beginSelection()` from any control you like.
    public func makeTapTextViewButton() -> UIBarButtonItem {
        activateButton = UIBarButtonItem(
            image: UIImage(systemName: "hand.point.up.left"),
            style: .plain, target: self, action: #selector(beginSelection))
        activateButton.accessibilityLabel = configuration.accessibility.selectButtonLabel
        return activateButton
    }

    /// Starts a session: snapshots the text for Undo, removes duplicate/invalid
    /// hashtags, suspends editing, and shows the action bar.
    @objc public func beginSelection() {
        guard !isSelecting else { return }
        initialText = text
        resignFirstResponder()
        if removesDuplicatesOnSelection { cleanUpHashtags() }
        setEditingSuspended(true)
        feedbackGenerator.prepare()
        accessibilityHint = configuration.accessibility.selectionHint
        presentActionBar()
        tagDelegate?.tapTextViewDidStartSelection(self)
    }

    /// Ends the session immediately: clears the selection, hides the bar, and
    /// restores editing. (The Done button routes through `confirmEndSelection`.)
    @objc public func endSelection() {
        clearSelection()
        viewModel.resetGrouping()
        setEditingSuspended(false)
        accessibilityHint = nil
        dismissActionBar()
        tagDelegate?.tapTextViewDidFinishSelection(self)
    }

    /// Removes duplicate and invalid hashtags from the text. Run automatically
    /// when a session starts; also callable on its own.
    public func cleanUpHashtags() {
        let cleanedText = viewModel.cleanedText(text ?? "")
        guard cleanedText != text else { return }
        text = cleanedText
        applyHighlighting()
        notifyTextChanged()
    }

    /// The Done button's action: if edits were made, offer Undo (restore the
    /// text as it was when the session began) or Done (keep them).
    @objc private func confirmEndSelection() {
        guard text != initialText, let presenter = owningViewController else {
            endSelection()
            return
        }
        let a11y = configuration.accessibility
        let alert = UIAlertController(title: a11y.keepChangesTitle, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: a11y.undoLabel, style: .destructive) { [weak self] _ in
            guard let self else { return }
            if let initialText {
                text = initialText
                notifyTextChanged()
            }
            endSelection()
        })
        alert.addAction(UIAlertAction(title: a11y.doneLabel, style: .default) { [weak self] _ in
            self?.endSelection()
        })
        presenter.present(alert, animated: true)
    }

    private var owningViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let viewController = next as? UIViewController { return viewController }
            responder = next
        }
        return nil
    }

    private func setEditingSuspended(_ suspended: Bool) {
        tapGestureRecognizer.isEnabled = suspended
        isEditable = !suspended
        isSelectable = !suspended
        activateButton.isEnabled = !suspended
    }

    // MARK: - Self-contained action bar

    /// The captioned bar while a session is active; removed when it ends, so a
    /// discarded text view never leaves one behind.
    private var activeBar: TagActionBar?

    private func presentActionBar() {
        guard activeBar == nil, let host = window ?? superview else { return }
        let bar = makeActionBar()
        activeBar = bar
        host.addSubview(bar)
        let safe = host.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 12),
            bar.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -12),
            bar.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -8),
        ])
    }

    private func dismissActionBar() {
        activeBar?.removeFromSuperview()
        activeBar = nil
    }

    public override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil { dismissActionBar() }
    }

    /// Builds the captioned action bar. Internal so tests can inspect it.
    func makeActionBar() -> TagActionBar {
        let a11y = configuration.accessibility
        let items: [TagActionBar.Item] = [
            .init(symbol: "doc.on.doc", title: a11y.copyLabel, tint: nil, isProminent: false,
                  handler: { [weak self] in self?.copySelectedTags() }),
            .init(symbol: "scissors", title: a11y.cutLabel, tint: nil, isProminent: false,
                  handler: { [weak self] in self?.cutSelectedTags() }),
            .init(symbol: "square.grid.2x2", title: a11y.groupLabel, tint: nil, isProminent: false,
                  handler: { [weak self] in self?.groupSelectedTags() }),
            .init(symbol: "xmark.circle", title: a11y.deselectLabel, tint: nil, isProminent: false,
                  handler: { [weak self] in self?.clearSelection() }),
            .init(symbol: "trash", title: a11y.deleteLabel, tint: .systemRed, isProminent: false,
                  handler: { [weak self] in self?.deleteSelectedTags() }),
            .init(symbol: "checkmark", title: a11y.doneLabel, tint: nil, isProminent: true,
                  handler: { [weak self] in self?.confirmEndSelection() }),
        ]
        return TagActionBar(items: items, tint: configuration.tagHighlightColor)
    }

    // MARK: - Tapping

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
    func hashtagWord(at index: Int) -> String? {
        viewModel.hashtagWord(in: text ?? "", at: index)
    }

    func processTappedWord(tappedWord: String?) {
        guard let tappedWord, !tappedWord.isEmpty else { return }
        let change = viewModel.toggle(tappedWord)
        notifyDelegate(of: change.word, selected: change.isSelected)
        applyHighlighting()
    }

    // MARK: - Programmatic selection

    /// Selects `tag` (with or without a leading `#`) and highlights it.
    public func selectTag(_ tag: String) {
        guard let word = viewModel.select(tag) else { return }
        notifyDelegate(of: word, selected: true)
        applyHighlighting()
    }

    /// Removes `tag` from the selection.
    public func deselectTag(_ tag: String) {
        guard let word = viewModel.deselect(tag) else { return }
        notifyDelegate(of: word, selected: false)
        applyHighlighting()
    }

    /// Clears the whole selection (without changing the text).
    @objc public func clearSelection() {
        viewModel.clear()
        applyHighlighting()
    }

    private func notifyTextChanged() {
        tagDelegate?.tapTextViewDidChangeText(self)
    }

    private func notifyDelegate(of tag: String, selected: Bool) {
        if selected {
            tagDelegate?.tapTextView(self, didSelect: tag)
        } else {
            tagDelegate?.tapTextView(self, didDeselect: tag)
        }
        announceSelectionChange(of: tag, selected: selected)
    }

    /// Posts a VoiceOver announcement so selection changes aren't silent.
    private func announceSelectionChange(of tag: String, selected: Bool) {
        let a11y = configuration.accessibility
        let message = selected ? a11y.didSelectAnnouncement("#\(tag)")
                               : a11y.didDeselectAnnouncement("#\(tag)")
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    // MARK: - Highlighting

    /// Snapshots the caller's styled text so highlighting can be layered over it
    /// without discarding their fonts, colors, and links. Skipped while we are
    /// the ones writing the highlighted result back.
    private func captureBaseText() {
        guard !isApplyingHighlight else { return }
        baseText = attributedText ?? NSAttributedString(string: text ?? "")
    }

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

    /// Copies the selected tags (space-separated, each prefixed with `#`).
    @objc public func copySelectedTags() {
        pasteboard.string = viewModel.hashtagList
    }

    /// Copies the selected tags, then removes them from the text.
    @objc public func cutSelectedTags() {
        copySelectedTags()
        deleteSelectedTags()
    }

    /// Moves every selected tag to the top of the text, in selection order.
    /// The tags stay selected (and highlighted) at their new position.
    @objc public func groupSelectedTags() {
        guard !viewModel.isEmpty else { return }
        text = viewModel.groupingSelectedTagsAtTop(of: text ?? "")
        applyHighlighting()
        notifyTextChanged()
        scrollRangeToVisible(NSRange(location: 0, length: 0))
    }

    /// Removes every selected tag from the text.
    @objc public func deleteSelectedTags() {
        text = viewModel.removingSelectedTags(from: text ?? "")
        viewModel.clear()
        applyHighlighting()
        notifyTextChanged()
    }
}
