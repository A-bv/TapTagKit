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
    public struct Configuration {
        public var toolbarInfoTitle: String
        public var toolbarInfoMessage: String
        public var infoButtonTitle: String
        public var selectButtonAccessibilityLabel: String
        public var tagHighlightColor: UIColor
        /// Shown while the text view is empty; nil disables the placeholder.
        public var placeholder: String?
        /// Keeps the text content above the keyboard via content insets.
        public var avoidsKeyboard: Bool

        public init(
            toolbarInfoTitle: String = "Actions on selected hashtags",
            toolbarInfoMessage: String = "Copy, cut, group, deselect, or delete every selected hashtag at once.",
            infoButtonTitle: String = "OK",
            selectButtonAccessibilityLabel: String = "Select hashtags",
            tagHighlightColor: UIColor = UIColor(red: 0.808, green: 0.027, blue: 0.333, alpha: 1),
            placeholder: String? = nil,
            avoidsKeyboard: Bool = false
        ) {
            self.toolbarInfoTitle = toolbarInfoTitle
            self.toolbarInfoMessage = toolbarInfoMessage
            self.infoButtonTitle = infoButtonTitle
            self.selectButtonAccessibilityLabel = selectButtonAccessibilityLabel
            self.tagHighlightColor = tagHighlightColor
            self.placeholder = placeholder
            self.avoidsKeyboard = avoidsKeyboard
        }
    }

    public var configuration = Configuration() {
        didSet { applyConfiguration() }
    }
    public weak var tagDelegate: TapTextViewDelegate?

    /// The tag words currently selected (without the `#` prefix).
    public var selectedTags: Set<String> { Set(selectionDict.keys) }

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
        didSet { refreshPlaceholder() }
    }

    public override var attributedText: NSAttributedString! {
        didSet { refreshPlaceholder() }
    }

    var selectionDict = [String: Int]()
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

    private func installPlaceholderIfNeeded() {
        guard let placeholder = configuration.placeholder else {
            placeholderLabel.removeFromSuperview()
            return
        }

        placeholderLabel.text = placeholder
        placeholderLabel.font = .italicSystemFont(ofSize: font?.pointSize ?? UIFont.labelFontSize)
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.sizeToFit()
        placeholderLabel.frame.origin = CGPoint(x: 5, y: (font?.pointSize ?? UIFont.labelFontSize) / 2)

        if placeholderLabel.superview == nil {
            addSubview(placeholderLabel)
            NotificationCenter.default.addObserver(
                self, selector: #selector(refreshPlaceholder),
                name: UITextView.textDidChangeNotification, object: self)
        }
        refreshPlaceholder()
    }

    @objc private func refreshPlaceholder() {
        placeholderLabel.isHidden = !(text ?? "").isEmpty
    }

    private func installKeyboardAvoidanceIfNeeded() {
        guard configuration.avoidsKeyboard else { return }
        NotificationCenter.default.addObserver(
            self, selector: #selector(adjustForKeyboard),
            name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(adjustForKeyboard),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
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
        let img = UIImage(systemName: "hand.point.up.left")!
        activateButton = UIBarButtonItem(image: img, style: .plain, target: self, action: #selector(startTagSelection))
        activateButton.accessibilityLabel = configuration.selectButtonAccessibilityLabel
        return activateButton
    }

    @objc private func startTagSelection() {
        guard !tapGestureRecognizer.isEnabled else { return }
        self.resignFirstResponder()
        tapGestureRecognizer.isEnabled = true
        isEditable = false
        isSelectable = false
        tagDelegate?.tapTextViewDidStartSelection(self)
        activateButton.isEnabled = false
    }

    @objc private func doneTagSelection() {
        cleanTagSelection()
        tapGestureRecognizer.isEnabled = false
        isEditable = true
        isSelectable = true
        firstTimeGrouped = false
        tagDelegate?.tapTextViewDidFinishSelection(self)
        activateButton.isEnabled = true
    }

    private func installTapRecognizer() {
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapResponse(recognizer:)))
        tapGestureRecognizer.isEnabled = false
        addGestureRecognizer(tapGestureRecognizer)
    }

    // MARK: - Toolbar

    private func makeToolbarItems() -> [UIBarButtonItem] {
        let toolbarIcons = [
            UIImage(systemName: "doc.on.doc"),
            UIImage(systemName: "scissors"),
            UIImage(systemName: "square.grid.2x2"),
            UIImage(systemName: "clear"),
            UIImage(systemName: "delete.right"),
            UIImage(systemName: "questionmark.circle.fill")]

        let actions: [Selector] = [
            #selector(copyTagSelection),
            #selector(cutTagSelection),
            #selector(groupTagSelection),
            #selector(cleanTagSelection),
            #selector(deleteTagSelection),
            #selector(toolbarInfo)
        ]

        var toolbar: [UIBarButtonItem] = []

        for (icon, action) in zip(toolbarIcons, actions) {
            let item = UIBarButtonItem(image: icon!, style: .plain, target: self, action: action)

            if icon == toolbarIcons.last {
                item.tintColor = .systemOrange
            }
            toolbar.append(item)

            let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
            toolbar.append(spacer)
        }

        toolbar.append(UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTagSelection)))

        return toolbar
    }

    // MARK: - Selection

    @objc private func tapResponse(recognizer: UITapGestureRecognizer) {
        let location: CGPoint = recognizer.location(in: self)
        let position: CGPoint = CGPoint(x: location.x, y: location.y)

        guard
            let tapPosition: UITextPosition = closestPosition(to: position),
            let textRange: UITextRange = tokenizer.rangeEnclosingPosition(
                tapPosition, with: UITextGranularity.word, inDirection: UITextDirection(rawValue: 1))
        else {
            return
        }

        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        let tappedWord: String? = self.text(in: textRange)
        processTappedWord(tappedWord: tappedWord)
    }

    func processTappedWord(tappedWord: String?) {
        guard let tappedWord, !tappedWord.isEmpty else { return }

        if selectionDict[tappedWord] != nil {
            selectionDict[tappedWord] = nil
            tagDelegate?.tapTextView(self, didDeselect: tappedWord)
        } else {
            selectionDict[tappedWord] = selectionDict.count + 1
            tagDelegate?.tapTextView(self, didSelect: tappedWord)
        }
        applyHighlighting()
    }

    private func applyHighlighting() {
        let base = text ?? ""
        let attributed = NSMutableAttributedString(
            string: base,
            attributes: [
                .font: font ?? UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label,
            ]
        )
        for tag in selectionDict.keys {
            let pattern = "\\#\(NSRegularExpression.escapedPattern(for: tag))\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(base.startIndex..., in: base)
            for match in regex.matches(in: base, range: range) {
                attributed.addAttributes([
                    .backgroundColor: configuration.tagHighlightColor,
                    .foregroundColor: UIColor.white,
                ], range: match.range)
            }
        }
        attributedText = attributed
    }

    // MARK: - Toolbar actions

    @objc private func copyTagSelection() {
        let arrayToCopy = selectionDict.keys.map { "#" + $0 }
        UIPasteboard.general.string = arrayToCopy.joined(separator: " ")
    }

    @objc private func cutTagSelection() {
        copyTagSelection()
        deleteTagSelection()
    }

    @objc private func groupTagSelection() {
        cutTagSelection()

        //get from clipboard
        let movedTags = UIPasteboard.general.string

        let jump = firstTimeGrouped == false ? "\n\n" : ""
        firstTimeGrouped = true

        guard let movedTags, !movedTags.isEmpty else {
            return
        }

        if let position = self.textRange(from: self.beginningOfDocument, to: self.beginningOfDocument) {
            self.replace(position, withText: "\(movedTags)" + jump)
        }

        let movedTagsArray = movedTags.components(separatedBy: " ")

        for tag in movedTagsArray {
            let tappedWordWithoutHashtag = String(tag.dropFirst(1))
            processTappedWord(tappedWord: tappedWordWithoutHashtag)
        }

        self.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }

    @objc private func cleanTagSelection() {
        selectionDict.removeAll()
        applyHighlighting()
    }

    @objc func deleteTagSelection() {
        let toDelete = Array(selectionDict.keys)
        selectionDict.removeAll()
        applyHighlighting()
        for tag in toDelete {
            text = text.replacingOccurrences(
                of: "#\(NSRegularExpression.escapedPattern(for: tag))\\b",
                with: "",
                options: .regularExpression)
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
