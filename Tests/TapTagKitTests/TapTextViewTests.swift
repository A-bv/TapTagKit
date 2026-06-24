import XCTest
@testable import TapTagKit

@MainActor
final class TapTextViewTests: XCTestCase {

    func testToolbar_installsAllActionsOnTheHost() {
        let textView = TapTextView()
        let host = UIViewController()

        textView.addTagSelectorToolBar(viewController: host)

        // 6 action buttons, 6 flexible spacers, 1 done button.
        XCTAssertEqual(host.toolbarItems?.count, 13)

        // Every action button is labeled for VoiceOver.
        let labeled = host.toolbarItems?.filter { $0.accessibilityLabel != nil }
        XCTAssertEqual(labeled?.count, 6)
    }

    func testTapTextViewButton_usesTheConfiguredAccessibilityLabel() {
        let textView = TapTextView()
        textView.configuration = .init(selectButtonAccessibilityLabel: "Choisir les hashtags")

        let button = textView.makeTapTextViewButton()

        XCTAssertEqual(button.accessibilityLabel, "Choisir les hashtags")
    }

    func testTappingAWord_togglesItsSelection() {
        let textView = TapTextView()
        textView.text = "#sun and #sea"

        textView.processTappedWord(tappedWord: "sun")
        XCTAssertEqual(textView.selectedTags, ["sun"])

        textView.processTappedWord(tappedWord: "sun")
        XCTAssertTrue(textView.selectedTags.isEmpty)
    }

    func testDelete_removesSelectedTagsFromTheText() {
        let textView = TapTextView()
        textView.text = "#sun and #sea"
        textView.processTappedWord(tappedWord: "sun")

        textView.deleteTagSelection()

        XCTAssertFalse(textView.text.contains("#sun"))
        XCTAssertTrue(textView.text.contains("#sea"))
    }

    func testPlaceholder_showsWhileEmptyAndHidesWithText() {
        let textView = TapTextView()
        textView.configuration = .init(placeholder: "Type here")

        let label = textView.subviews.compactMap { $0 as? UILabel }.first
        XCTAssertEqual(label?.text, "Type here")
        XCTAssertEqual(label?.isHidden, false)

        textView.text = "#sun"
        XCTAssertEqual(label?.isHidden, true)

        textView.text = ""
        XCTAssertEqual(label?.isHidden, false)
    }

    func testTagsWithRegexMetacharacters_doNotBreakSelection() {
        let textView = TapTextView()
        textView.text = "#c++ and #sea"

        textView.processTappedWord(tappedWord: "c++")

        XCTAssertEqual(textView.selectedTags, ["c++"])
    }

    func testHighlight_marksEveryOccurrenceIncludingPunctuationTags() {
        let textView = TapTextView()
        textView.text = "#c++ and #c++ but not #c++plus"

        textView.processTappedWord(tappedWord: "c++")

        // Both standalone "#c++" are highlighted; "#c++plus" is not.
        let highlighted = highlightRanges(in: textView.attributedText,
                                          color: textView.configuration.tagHighlightColor)
        XCTAssertEqual(highlighted.count, 2)
    }

    func testHighlight_preservesCallerSuppliedAttributes() {
        let textView = TapTextView()
        let styled = NSMutableAttributedString(string: "#sun shines")
        styled.addAttribute(.link, value: "https://example.com",
                            range: NSRange(location: 5, length: 6)) // "shines"
        textView.attributedText = styled

        textView.processTappedWord(tappedWord: "sun")

        var foundLink = false
        textView.attributedText.enumerateAttribute(
            .link, in: NSRange(location: 0, length: textView.attributedText.length)) { value, _, _ in
            if value != nil { foundLink = true }
        }
        XCTAssertTrue(foundLink, "Highlighting must not discard existing attributes")
    }

    func testGroup_movesSelectedTagsToTopInTapOrder() {
        let textView = TapTextView()
        textView.text = "alpha #one mid #two end #three"

        textView.processTappedWord(tappedWord: "two")
        textView.processTappedWord(tappedWord: "one")
        textView.groupTagSelection()

        XCTAssertTrue(textView.text.hasPrefix("#two #one"),
                      "Grouped tags should appear at the top in tap order, got: \(textView.text ?? "")")
        XCTAssertEqual(textView.selectedTags, ["one", "two"])
    }

    func testDelete_doesNotLeaveDoubleSpaces() {
        let textView = TapTextView()
        textView.text = "#sun and #sea today"
        textView.processTappedWord(tappedWord: "sun")

        textView.deleteTagSelection()

        XCTAssertFalse(textView.text.contains("  "), "Deleting a tag should not leave a double space")
        XCTAssertTrue(textView.text.contains("#sea"))
    }

    func testKeyboardAvoidance_canBeToggledOffWithoutLingeringObservers() {
        let textView = TapTextView()
        textView.configuration = .init(avoidsKeyboard: true)

        let frame = CGRect(x: 0, y: 0, width: 320, height: 250)
        func postKeyboardChange() {
            NotificationCenter.default.post(
                name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
                userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: frame)])
        }

        postKeyboardChange()
        XCTAssertEqual(textView.contentInset.bottom, 250, accuracy: 0.5)

        // Turning avoidance off must remove the observers and reset the inset.
        textView.configuration = .init(avoidsKeyboard: false)
        XCTAssertEqual(textView.contentInset.bottom, 0, accuracy: 0.5)

        postKeyboardChange()
        XCTAssertEqual(textView.contentInset.bottom, 0, accuracy: 0.5,
                       "Keyboard observers should be gone after avoidsKeyboard is turned off")
    }

    // MARK: - Helpers

    private func highlightRanges(in attributed: NSAttributedString, color: UIColor) -> [NSRange] {
        var ranges = [NSRange]()
        attributed.enumerateAttribute(
            .backgroundColor, in: NSRange(location: 0, length: attributed.length)) { value, range, _ in
            if let used = value as? UIColor, used == color { ranges.append(range) }
        }
        return ranges
    }
}
