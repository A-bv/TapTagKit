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

        public struct Accessibility {
            public var selectButtonLabel = "Select hashtags"
            public var copyLabel = "Copy selected hashtags"
            public var cutLabel = "Cut selected hashtags"
            public var groupLabel = "Group selected hashtags at top"
            public var deselectLabel = "Deselect all hashtags"
            public var deleteLabel = "Delete selected hashtags"
            public var doneLabel = "Done"
            public var selectionHint = "Double tap a hashtag to select it."
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

    /// Starts a session: taps select hashtags, editing is suspended, and the
    /// action toolbar appears.
    @objc public func beginSelection() {
        guard !isSelecting else { return }
        resignFirstResponder()
        setEditingSuspended(true)
        feedbackGenerator.prepare()
        accessibilityHint = configuration.accessibility.selectionHint
        presentToolbar()
        tagDelegate?.tapTextViewDidStartSelection(self)
    }

    /// Ends the session: clears the selection, hides the toolbar, restores editing.
    @objc public func endSelection() {
        clearSelection()
        viewModel.resetGrouping()
        setEditingSuspended(false)
        accessibilityHint = nil
        dismissToolbar()
        tagDelegate?.tapTextViewDidFinishSelection(self)
    }

    private func setEditingSuspended(_ suspended: Bool) {
        tapGestureRecognizer.isEnabled = suspended
        isEditable = !suspended
        isSelectable = !suspended
        activateButton.isEnabled = !suspended
    }

    // MARK: - Self-contained toolbar

    /// The action toolbar while a session is active; removed when it ends, so a
    /// discarded text view never leaves one behind.
    private var activeToolbar: UIToolbar?

    private func presentToolbar() {
        guard activeToolbar == nil, let host = window ?? superview else { return }
        let toolbar = makeSelectionToolbar()
        activeToolbar = toolbar
        host.addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: host.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private func dismissToolbar() {
        activeToolbar?.removeFromSuperview()
        activeToolbar = nil
    }

    public override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil { dismissToolbar() }
    }

    /// Builds the action toolbar. Internal so tests can inspect its items.
    func makeSelectionToolbar() -> UIToolbar {
        let a11y = configuration.accessibility
        let actions: [(symbol: String, selector: Selector, label: String, tint: UIColor?)] = [
            ("doc.on.doc", #selector(copySelectedTags), a11y.copyLabel, nil),
            ("scissors", #selector(cutSelectedTags), a11y.cutLabel, nil),
            ("square.grid.2x2", #selector(groupSelectedTags), a11y.groupLabel, nil),
            ("xmark.circle", #selector(clearSelection), a11y.deselectLabel, nil),
            ("trash", #selector(deleteSelectedTags), a11y.deleteLabel, .systemRed),
        ]

        var items: [UIBarButtonItem] = []
        for action in actions {
            items.append(.flexibleSpace())
            items.append(makeActionItem(action))
        }
        items.append(.flexibleSpace())
        items.append(UIBarButtonItem(
            title: a11y.doneLabel, style: .done, target: self, action: #selector(endSelection)))

        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.tintColor = configuration.tagHighlightColor
        toolbar.items = items
        return toolbar
    }

    private func makeActionItem(
        _ action: (symbol: String, selector: Selector, label: String, tint: UIColor?)
    ) -> UIBarButtonItem {
        let item = UIBarButtonItem(
            image: UIImage(systemName: action.symbol),
            style: .plain, target: self, action: action.selector)
        item.accessibilityLabel = action.label
        item.tintColor = action.tint
        return item
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
        scrollRangeToVisible(NSRange(location: 0, length: 0))
    }

    /// Removes every selected tag from the text.
    @objc public func deleteSelectedTags() {
        text = viewModel.removingSelectedTags(from: text ?? "")
        viewModel.clear()
        applyHighlighting()
    }
}
