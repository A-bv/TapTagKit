import UIKit

private enum Constants {
    // SF Symbol names.
    static let activateSymbol = "hand.point.up.left"
    static let copySymbol = "doc.on.doc"
    static let cutSymbol = "scissors"
    static let groupSymbol = "square.grid.2x2"
    static let deselectSymbol = "xmark.circle"
    static let deleteSymbol = "trash"
    static let doneSymbol = "checkmark"

    // Action-bar layout insets.
    static let barHorizontalInset: CGFloat = 12
    static let barBottomInset: CGFloat = 8
}

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
        /// The default tag highlight color (a magenta).
        public static let defaultHighlightColor = UIColor(red: 0.808, green: 0.027, blue: 0.333, alpha: 1)

        public var tagHighlightColor: UIColor
        /// Text color drawn over a highlighted tag.
        public var selectedTagTextColor: UIColor
        public var accessibility: Accessibility

        /// Short labels double as the button captions and the VoiceOver labels,
        /// so there's one localizable string per action.
        /// Defaults are localized (English + French) from the package bundle.
        public struct Accessibility {
            public var selectButtonLabel = L.select
            public var copyLabel = L.copy
            public var cutLabel = L.cut
            public var groupLabel = L.group
            public var deselectLabel = L.deselect
            public var deleteLabel = L.delete
            public var doneLabel = L.done
            public var selectionHint = L.hint
            public var deleteConfirmationTitle = L.deleteConfirm
            public var cancelLabel = L.cancel
            public var didSelectAnnouncement: (_ tag: String) -> String = { L.selected($0) }
            public var didDeselectAnnouncement: (_ tag: String) -> String = { L.deselected($0) }
            public init() {}
        }

        public init(
            tagHighlightColor: UIColor = Configuration.defaultHighlightColor,
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
    /// Haptics and VoiceOver announcements, injectable for testing and to let
    /// callers customize (e.g. silence haptics). Defaults to the live services.
    public var services: TapTextViewServices = LiveTapTextViewServices()
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
            image: UIImage(systemName: Constants.activateSymbol),
            style: .plain, target: self, action: #selector(beginSelection))
        activateButton.accessibilityLabel = configuration.accessibility.selectButtonLabel
        return activateButton
    }

    /// Starts a session: removes duplicate/invalid hashtags, suspends editing,
    /// and shows the action bar.
    @objc public func beginSelection() {
        guard !isSelecting else { return }
        resignFirstResponder()
        if removesDuplicatesOnSelection { cleanUpHashtags() }
        setEditingSuspended(true)
        services.prepareHaptics()
        accessibilityHint = configuration.accessibility.selectionHint
        presentActionBar()
        postAccessibilityModeChange()
        tagDelegate?.tapTextViewDidStartSelection(self)
    }

    /// Ends the session immediately: clears the selection, hides the bar, and
    /// restores editing.
    @objc public func endSelection() {
        clearSelection()
        viewModel.resetGrouping()
        setEditingSuspended(false)
        accessibilityHint = nil
        dismissActionBar()
        postAccessibilityModeChange()
        tagDelegate?.tapTextViewDidFinishSelection(self)
    }

    /// Tells VoiceOver the element structure changed (single text element ↔
    /// per-tag buttons) so it re-reads and re-focuses.
    private func postAccessibilityModeChange() {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .screenChanged, argument: nil)
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

    private var insetsBeforeBar: (content: UIEdgeInsets, indicator: UIEdgeInsets)?

    private func presentActionBar() {
        guard activeBar == nil, let host = window ?? superview else { return }
        let bar = makeActionBar()
        activeBar = bar
        host.addSubview(bar)
        let safe = host.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: Constants.barHorizontalInset),
            bar.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -Constants.barHorizontalInset),
            bar.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -Constants.barBottomInset),
        ])
        // Add the bar's SwiftUI hosting controller to the VC tree so its
        // confirmation alert can present.
        if let owner = owningViewController { bar.attach(to: owner) }

        // Inset the text so the bar never covers the last line.
        insetsBeforeBar = (contentInset, verticalScrollIndicatorInsets)
        let occlusion = bar.intrinsicContentSize.height + Constants.barBottomInset * 2
        contentInset.bottom += occlusion
        verticalScrollIndicatorInsets.bottom += occlusion
    }

    private func dismissActionBar() {
        activeBar?.detach()
        activeBar?.removeFromSuperview()
        activeBar = nil
        if let saved = insetsBeforeBar {
            contentInset = saved.content
            verticalScrollIndicatorInsets = saved.indicator
            insetsBeforeBar = nil
        }
    }

    /// The nearest view controller up the responder chain, used to host the
    /// action bar's SwiftUI controller.
    private var owningViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let viewController = next as? UIViewController { return viewController }
            responder = next
        }
        return nil
    }

    public override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil { dismissActionBar() }
    }

    /// Builds the captioned action bar. Internal so tests can inspect it.
    func makeActionBar() -> TagActionBar {
        let a11y = configuration.accessibility
        let items: [TagActionBar.Item] = [
            .init(symbol: Constants.copySymbol, title: a11y.copyLabel, tint: nil, isProminent: false,
                  handler: { [weak self] in self?.copySelectedTags() }),
            .init(symbol: Constants.cutSymbol, title: a11y.cutLabel, tint: nil, isProminent: false,
                  handler: { [weak self] in self?.cutSelectedTags() }),
            .init(symbol: Constants.groupSymbol, title: a11y.groupLabel, tint: nil, isProminent: false,
                  handler: { [weak self] in self?.groupSelectedTags() }),
            .init(symbol: Constants.deselectSymbol, title: a11y.deselectLabel, tint: nil, isProminent: false,
                  handler: { [weak self] in self?.clearSelection() }),
            .init(
                symbol: Constants.deleteSymbol,
                title: a11y.deleteLabel,
                tint: .systemRed,
                isProminent: false,
                confirmationTitle: a11y.deleteConfirmationTitle,
                cancelTitle: a11y.cancelLabel,
                handler: { [weak self] in self?.deleteSelectedTags() }
            ),
            .init(symbol: Constants.doneSymbol, title: a11y.doneLabel, tint: nil, isProminent: true,
                  handler: { [weak self] in self?.endSelection() }),
        ]
        return TagActionBar(items: items, tint: configuration.tagHighlightColor)
    }

    // MARK: - Tapping

    @objc private func tapResponse(recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: self)
        guard let tapPosition = closestPosition(to: location) else { return }

        let index = offset(from: beginningOfDocument, to: tapPosition)
        guard let word = hashtagWord(at: index) else { return }

        services.playSelectionHaptic()
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
        services.announce(message)
    }

    // MARK: - Accessibility

    // While selecting, expose each hashtag as its own VoiceOver button instead
    // of the text view reading as one element.
    public override var isAccessibilityElement: Bool {
        get { isSelecting ? false : super.isAccessibilityElement }
        set { super.isAccessibilityElement = newValue }
    }

    public override var accessibilityElements: [Any]? {
        get { isSelecting ? tagAccessibilityElements() : super.accessibilityElements }
        set { super.accessibilityElements = newValue }
    }

    private func tagAccessibilityElements() -> [TagAccessibilityElement] {
        let selected = selectedTags
        return viewModel.hashtagTokens(in: text ?? "").map { token in
            TagAccessibilityElement(
                container: self,
                word: token.word,
                frame: accessibilityFrame(for: token.range),
                isSelected: selected.contains(token.word)
            ) { [weak self] word in
                self?.processTappedWord(tappedWord: word)
            }
        }
    }

    private func accessibilityFrame(for range: NSRange) -> CGRect {
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length),
              let textRange = textRange(from: start, to: end) else { return .zero }
        return firstRect(for: textRange)
    }

    /// Nudges VoiceOver to re-read the tag elements after a selection change.
    private func refreshAccessibilityIfNeeded() {
        guard isSelecting, UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
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
        refreshAccessibilityIfNeeded()
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
