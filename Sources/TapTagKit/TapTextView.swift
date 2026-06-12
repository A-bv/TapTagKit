import UIKit

public protocol TapTextViewDelegate: AnyObject {
    func tapTextViewDidStartSelection(_ textView: TapTextView)
    func tapTextViewDidFinishSelection(_ textView: TapTextView)
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

    private enum TagSelectionState {
        case selected
        case notSelected
    }

    private enum Constants {
        static let cornerRadiusMultiplier: CGFloat = 4.0

        enum Insets {
            static let horizontal: CGFloat = -1
            static let vertical: CGFloat = 2
        }
    }

    public var configuration = Configuration() {
        didSet { applyConfiguration() }
    }
    public weak var tagDelegate: TapTextViewDelegate?

    public override var text: String! {
        didSet { refreshPlaceholder() }
    }

    public override var attributedText: NSAttributedString! {
        didSet { refreshPlaceholder() }
    }

    var selectionDict = [String: Int]()
    private var viewTagCount = Int()
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
        self.resignFirstResponder()
        tapGestureRecognizer.isEnabled = true
        isEditable = false
        isSelectable = false
        addTappedTagRecognizer()
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

    private func addTappedTagRecognizer() {
        tapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(tapResponse(recognizer:)))

        tapGestureRecognizer.delegate = self as? UIGestureRecognizerDelegate
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
        guard let tappedWord else { return }

        if let selectedTag = selectionDict[tappedWord] {
            selectTag(base: tappedWord, tag: selectedTag, state: .selected)
            selectionDict[tappedWord] = nil
        } else {
            viewTagCount += 1
            selectionDict[tappedWord] = viewTagCount    //tappedWord = unique key
            selectTag(base: tappedWord, tag: viewTagCount, state: .notSelected)
        }
    }

    private func selectTag(base: String, tag: Int, state: TagSelectionState) {
        var textColorAttribute = [NSAttributedString.Key: UIColor]()
        let myString = NSMutableAttributedString(attributedString: self.attributedText)

        let pattern = "\\#\(NSRegularExpression.escapedPattern(for: base))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let range = NSRange(self.text.startIndex..., in: self.text)
        let matches = regex.matches(in: self.text, options: [], range: range)

        for match in matches {
            switch state {
            case .notSelected:
                textColorAttribute = [.foregroundColor: UIColor.white]

                let frame = frameOfTextInRange(range: match.range)
                let framePadding = frame.insetBy(dx: Constants.Insets.horizontal, dy: Constants.Insets.vertical)

                let view = UIView(frame: framePadding)
                view.layer.cornerRadius = frame.height / Constants.cornerRadiusMultiplier
                view.tag = tag
                self.insertSubview(view, at: 0)
                view.backgroundColor = configuration.tagHighlightColor

            case .selected:
                textColorAttribute = [.foregroundColor: .label]
                self.removeSpecificView(tag: tag)
            }

            myString.addAttributes(textColorAttribute, range: match.range)
        }

        self.attributedText = myString.copy() as? NSAttributedString
    }

    private func frameOfTextInRange(range: NSRange) -> CGRect {
        let beginning = beginningOfDocument
        guard
            let start = position(from: beginning, offset: range.location),
            let end = position(from: start, offset: range.length),
            let textRange = textRange(from: start, to: end)
        else {
            return CGRect.zero
        }
        return convert(firstRect(for: textRange), from: self)
    }

    private func removeSpecificView(tag: Int) {
        subviews
            .filter({ $0.tag == tag })
            .forEach({ $0.removeFromSuperview() })
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
        for tag in selectionDict.keys {
            processTappedWord(tappedWord: tag)
        }
    }

    @objc func deleteTagSelection() {
        for tag in selectionDict.keys {
            processTappedWord(tappedWord: tag)
            self.text = self.text.replacingOccurrences(
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
