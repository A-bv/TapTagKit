import SwiftUI
import XCTest
@testable import TapTagKit

@MainActor
final class TapTextViewTests: XCTestCase {

    func testActionBar_hasSixCaptionedItems() {
        let textView = TapTextView()
        let a11y = textView.configuration.accessibility
        let items = textView.makeActionBar().items

        // copy, cut, group, deselect, delete, done — each captioned/labeled.
        // Compared against the (localized) config labels, not English literals.
        XCTAssertEqual(items.count, 6)
        XCTAssertTrue(items.allSatisfy { !$0.title.isEmpty })
        XCTAssertTrue(items.contains { $0.title == a11y.doneLabel && $0.confirmationTitle == nil })
        XCTAssertTrue(items.contains {
            $0.title == a11y.deleteLabel && $0.confirmationTitle == a11y.deleteConfirmationTitle
        })
    }

    func testInjectedServices_receiveHapticsAndAnnouncements() {
        let services = SpyServices()
        let textView = TapTextView()
        textView.services = services
        textView.text = "#swift #ios"

        textView.beginSelection()
        XCTAssertEqual(services.prepareCount, 1)

        textView.selectTag("swift")
        XCTAssertEqual(services.announcements.count, 1)
        XCTAssertEqual(services.announcements.first?.contains("swift"), true)
    }

    private final class SpyServices: TapTextViewServices {
        var prepareCount = 0
        var hapticCount = 0
        var announcements: [String] = []
        func prepareHaptics() { prepareCount += 1 }
        func playSelectionHaptic() { hapticCount += 1 }
        func announce(_ message: String) { announcements.append(message) }
    }

    func testBeginSelection_removesDuplicatesAutomatically() {
        let textView = TapTextView()
        textView.text = "#swift #swift #ios #IOS #swiftui"

        textView.beginSelection()

        // Exact and case-insensitive duplicates gone, first occurrence kept.
        XCTAssertEqual(textView.text, "#swift #ios #swiftui")
    }

    func testBeginSelection_respectsRemovesDuplicatesToggle() {
        let textView = TapTextView()
        textView.removesDuplicatesOnSelection = false
        textView.text = "#swift #swift"

        textView.beginSelection()

        XCTAssertEqual(textView.text, "#swift #swift")
    }

    func testActionBar_hostsItsControllerInTheVCTreeDuringSession() {
        let host = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = host
        window.makeKeyAndVisible()

        let textView = TapTextView()
        host.view.addSubview(textView)

        textView.beginSelection()
        // The bar's SwiftUI hosting controller must be a child VC so its alert
        // (Delete confirmation) can present.
        XCTAssertFalse(host.children.isEmpty)

        textView.endSelection()
        XCTAssertTrue(host.children.isEmpty)
    }

    func testActionBar_insetsTextWhileShownAndRestoresAfter() {
        let host = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = host
        window.makeKeyAndVisible()

        let textView = TapTextView()
        host.view.addSubview(textView)
        let before = textView.contentInset.bottom

        textView.beginSelection()
        XCTAssertGreaterThan(textView.contentInset.bottom, before)

        textView.endSelection()
        XCTAssertEqual(textView.contentInset.bottom, before, accuracy: 0.5)
    }

    func testDoneAction_endsSelectionWithoutConfirmation() {
        let textView = TapTextView()
        textView.beginSelection()
        let done = textView.makeActionBar().items.first {
            $0.title == textView.configuration.accessibility.doneLabel
        }

        done?.handler()

        XCTAssertFalse(textView.isSelecting)
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

        let titles = textView.makeActionBar().items.map(\.title)
        XCTAssertTrue(titles.contains("Copier"))
    }

    func testSwiftUIAdapter_propagatesTextAndSelectionChanges() {
        var text = "#swift"
        var isSelecting = false
        let view = TapTagView(
            text: Binding(get: { text }, set: { text = $0 }),
            isSelecting: Binding(get: { isSelecting }, set: { isSelecting = $0 })
        )
        let coordinator = view.makeCoordinator()
        let textView = TapTextView()

        textView.text = "#swift #ios"
        coordinator.tapTextViewDidChangeText(textView)
        coordinator.tapTextViewDidStartSelection(textView)

        XCTAssertEqual(text, "#swift #ios")
        XCTAssertTrue(isSelecting)

        coordinator.tapTextViewDidFinishSelection(textView)
        XCTAssertFalse(isSelecting)
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
