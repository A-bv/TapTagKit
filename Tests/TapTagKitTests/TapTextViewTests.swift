import XCTest
@testable import TapTagKit

@MainActor
final class TapTextViewTests: XCTestCase {

    func testActionBar_hasSixCaptionedButtons() {
        let textView = TapTextView()
        let buttons = textView.makeActionBar().buttons

        // copy, cut, group, deselect, delete, done — each captioned/labeled.
        XCTAssertEqual(buttons.count, 6)
        XCTAssertTrue(buttons.allSatisfy { $0.accessibilityLabel != nil })
        XCTAssertTrue(buttons.contains { $0.configuration?.title == "Done" })
    }

    func testTapTextViewButton_usesTheConfiguredAccessibilityLabel() {
        let textView = TapTextView()
        var config = TapTextView.Configuration()
        config.accessibility.selectButtonLabel = "Choisir les hashtags"
        textView.configuration = config

        let button = textView.makeTapTextViewButton()

        XCTAssertEqual(button.accessibilityLabel, "Choisir les hashtags")
    }

    func testActionBar_usesConfiguredLabels() {
        let textView = TapTextView()
        var config = TapTextView.Configuration()
        config.accessibility.copyLabel = "Copier"
        textView.configuration = config

        let titles = textView.makeActionBar().buttons.compactMap { $0.configuration?.title }
        XCTAssertTrue(titles.contains("Copier"))
    }

    func testCleanUpHashtags_removesDuplicates() {
        let textView = TapTextView()
        textView.text = "#sun #sun #sea"

        textView.cleanUpHashtags()

        XCTAssertEqual(textView.text, "#sun #sea")
    }

    func testProgrammaticSelection_selectsDeselectsAndClears() {
        let textView = TapTextView()
        textView.text = "#sun and #sea"

        textView.selectTag("#sun")          // leading # is tolerated
        textView.selectTag("sea")
        XCTAssertEqual(textView.selectedTagsInOrder, ["sun", "sea"])

        textView.selectTag("sun")           // duplicate is a no-op
        XCTAssertEqual(textView.selectedTagsInOrder, ["sun", "sea"])

        textView.deselectTag("sun")
        XCTAssertEqual(textView.selectedTagsInOrder, ["sea"])

        textView.clearSelection()
        XCTAssertTrue(textView.selectedTagsInOrder.isEmpty)
    }

    func testCopySelectedTags_writesHashPrefixedListToPasteboard() {
        let pasteboard = UIPasteboard.withUniqueName()
        defer { UIPasteboard.remove(withName: pasteboard.name) }
        let textView = TapTextView()
        textView.pasteboard = pasteboard
        textView.text = "#sun and #sea"
        textView.selectTag("sun")
        textView.selectTag("sea")

        textView.copySelectedTags()

        XCTAssertEqual(pasteboard.string, "#sun #sea")
    }

    func testHighlight_usesConfiguredSelectedTextColor() {
        let textView = TapTextView()
        var config = TapTextView.Configuration()
        config.selectedTagTextColor = .systemYellow
        textView.configuration = config
        textView.text = "#sun"

        textView.selectTag("sun")

        var found = false
        textView.attributedText.enumerateAttribute(
            .foregroundColor, in: NSRange(location: 0, length: textView.attributedText.length)) { value, _, _ in
            if let color = value as? UIColor, color == .systemYellow { found = true }
        }
        XCTAssertTrue(found)
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

        textView.deleteSelectedTags()

        XCTAssertFalse(textView.text.contains("#sun"))
        XCTAssertTrue(textView.text.contains("#sea"))
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

    func testHashtagWord_capturesTheWholeTokenIncludingPunctuation() {
        let textView = TapTextView()
        textView.text = "#c++ and #sea"

        // Index 1 sits inside "#c++"; the whole token is returned, not just "c".
        XCTAssertEqual(textView.hashtagWord(at: 1), "c++")
        // Index 10 sits inside "#sea".
        XCTAssertEqual(textView.hashtagWord(at: 10), "sea")
        // Index 6 sits inside the plain word "and" — not a hashtag.
        XCTAssertNil(textView.hashtagWord(at: 6))
    }

    func testGroup_repeatedGroupingKeepsTagsSeparated() {
        let textView = TapTextView()
        textView.text = "a #x b #y c"

        textView.processTappedWord(tappedWord: "x")
        textView.groupSelectedTags()                 // "#x\n\na b #y c"
        textView.processTappedWord(tappedWord: "x")  // deselect, leaving #x at the top
        textView.processTappedWord(tappedWord: "y")
        textView.groupSelectedTags()                 // #y must land above #x, not fuse

        XCTAssertTrue(textView.text.hasPrefix("#y #x"),
                      "Repeated grouping must not fuse tags, got: \(textView.text ?? "")")
        XCTAssertFalse(textView.text.contains("#y#x"))
    }

    func testGroup_movesSelectedTagsToTopInTapOrder() {
        let textView = TapTextView()
        textView.text = "alpha #one mid #two end #three"

        textView.processTappedWord(tappedWord: "two")
        textView.processTappedWord(tappedWord: "one")
        textView.groupSelectedTags()

        XCTAssertTrue(textView.text.hasPrefix("#two #one"),
                      "Grouped tags should appear at the top in tap order, got: \(textView.text ?? "")")
        XCTAssertEqual(textView.selectedTags, ["one", "two"])
    }

    func testDelete_doesNotLeaveDoubleSpaces() {
        let textView = TapTextView()
        textView.text = "#sun and #sea today"
        textView.processTappedWord(tappedWord: "sun")

        textView.deleteSelectedTags()

        XCTAssertFalse(textView.text.contains("  "), "Deleting a tag should not leave a double space")
        XCTAssertTrue(textView.text.contains("#sea"))
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
