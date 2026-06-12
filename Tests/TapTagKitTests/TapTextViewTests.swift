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
        XCTAssertEqual(textView.selectionDict.keys.sorted(), ["sun"])

        textView.processTappedWord(tappedWord: "sun")
        XCTAssertTrue(textView.selectionDict.isEmpty)
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

        XCTAssertEqual(textView.selectionDict.keys.sorted(), ["c++"])
    }
}
