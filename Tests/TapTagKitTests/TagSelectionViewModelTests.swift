import XCTest
@testable import TapTagKit

/// The view model is plain logic with no UIKit, so it tests fast and directly.
final class TagSelectionViewModelTests: XCTestCase {

    func testToggle_addsThenRemovesInOrder() {
        let vm = TagSelectionViewModel()

        XCTAssertEqual(vm.toggle("#sun").isSelected, true)
        XCTAssertEqual(vm.toggle("sea").isSelected, true)   // leading # optional
        XCTAssertEqual(vm.selectedTags, ["sun", "sea"])

        XCTAssertEqual(vm.toggle("sun").isSelected, false)
        XCTAssertEqual(vm.selectedTags, ["sea"])
    }

    func testSelectDeselect_areNoOpsWhenRedundant() {
        let vm = TagSelectionViewModel()

        XCTAssertEqual(vm.select("sun"), "sun")
        XCTAssertNil(vm.select("sun"))       // already selected
        XCTAssertNil(vm.select(""))          // empty
        XCTAssertNil(vm.deselect("sea"))     // not selected
        XCTAssertEqual(vm.deselect("#sun"), "sun")
        XCTAssertTrue(vm.isEmpty)
    }

    func testSelection_isCaseInsensitive() {
        let vm = TagSelectionViewModel()

        // Selecting one case treats the other as the same tag.
        XCTAssertEqual(vm.toggle("Sun").isSelected, true)
        XCTAssertNil(vm.select("sun"), "same tag in another case is already selected")
        XCTAssertEqual(vm.toggle("sun").isSelected, false, "toggling the other case deselects it")
        XCTAssertTrue(vm.isEmpty)
    }

    func testHighlightAndRemoval_matchAcrossCase() {
        let vm = TagSelectionViewModel()
        _ = vm.select("sun")

        // A selected "sun" highlights every case variant as a whole token.
        XCTAssertEqual(vm.highlightRanges(in: "#sun #Sun #SUN #sunny").count, 3)
        // ...and removal drops them all.
        XCTAssertEqual(vm.removingSelectedTags(from: "#Sun and #sun today"), "and today")
    }

    func testHashtagWord_readsWholeTokens() {
        let vm = TagSelectionViewModel()
        let text = "#c++ and #sea"

        XCTAssertEqual(vm.hashtagWord(in: text, at: 1), "c++")
        XCTAssertEqual(vm.hashtagWord(in: text, at: 10), "sea")
        XCTAssertNil(vm.hashtagWord(in: text, at: 6))   // "and"
    }

    func testHighlightRanges_matchWholeTokensOnly() {
        let vm = TagSelectionViewModel()
        _ = vm.select("c++")
        let text = "#c++ and #c++ but #c++plus"

        XCTAssertEqual(vm.highlightRanges(in: text).count, 2)   // not #c++plus
    }

    func testRemovingSelectedTags_dropsTagsWithoutDoubleSpaces() {
        let vm = TagSelectionViewModel()
        _ = vm.select("sun")

        let result = vm.removingSelectedTags(from: "#sun and #sea today")

        XCTAssertEqual(result, "and #sea today")
    }

    func testRemovingSelectedTags_atEndDropsTheLeadingSpaceToo() {
        let vm = TagSelectionViewModel()
        _ = vm.select("sun")

        // No trailing space to swallow, so the leading one goes instead —
        // no dangling space at the end of the line/string.
        XCTAssertEqual(vm.removingSelectedTags(from: "hello #sun"), "hello")
        XCTAssertEqual(vm.removingSelectedTags(from: "hello #sun\nbye"), "hello\nbye")
    }

    func testRemovingSelectedTags_preservesSurroundingAttributes() {
        let vm = TagSelectionViewModel()
        _ = vm.select("sun")

        let key = NSAttributedString.Key("ttk.test")
        let styled = NSMutableAttributedString(string: "#sun shines bright")
        styled.addAttribute(key, value: "kept", range: (styled.string as NSString).range(of: "shines"))

        let result = vm.removingSelectedTags(from: styled)

        XCTAssertEqual(result.string, "shines bright")
        let attribute = result.attribute(key, at: 0, effectiveRange: nil) as? String
        XCTAssertEqual(attribute, "kept", "Removing a tag must not discard surrounding attributes")
    }

    func testGroupingSelectedTagsAtTop_preservesLiftedTagAttributes() {
        let vm = TagSelectionViewModel()
        _ = vm.select("sun")

        let key = NSAttributedString.Key("ttk.test")
        let styled = NSMutableAttributedString(string: "a #sun b")
        styled.addAttribute(key, value: "kept", range: (styled.string as NSString).range(of: "#sun"))

        let result = vm.groupingSelectedTagsAtTop(of: styled)

        XCTAssertEqual(result.string, "#sun\n\na b")
        // The lifted "#sun" now sits at the top and keeps its styling.
        let attribute = result.attribute(key, at: 0, effectiveRange: nil) as? String
        XCTAssertEqual(attribute, "kept", "A grouped tag must keep its original attributes")
    }

    func testCleanedText_dropsInvalidAndCaseInsensitiveDuplicates() {
        let vm = TagSelectionViewModel()

        // "#Sun" duplicates "#sun" (case-insensitive); "#!" is invalid.
        XCTAssertEqual(vm.cleanedText("#sun #Sun #sea #! end"), "#sun #sea end")
    }

    func testHashtagList_joinsSelectedTagsWithHashes() {
        let vm = TagSelectionViewModel()
        _ = vm.select("sun")
        _ = vm.select("sea")

        XCTAssertEqual(vm.hashtagList, "#sun #sea")
    }

    func testGroupingSelectedTagsAtTop_liftsTagsAndKeepsSelection() {
        let vm = TagSelectionViewModel()
        _ = vm.select("x")

        XCTAssertEqual(vm.groupingSelectedTagsAtTop(of: "a #x b"), "#x\n\na b")
        XCTAssertEqual(vm.selectedTags, ["x"], "grouping must not change the selection")
    }

    func testGroupingSelectedTagsAtTop_separatorTracksSessionAndReset() {
        let vm = TagSelectionViewModel()
        _ = vm.select("x")

        _ = vm.groupingSelectedTagsAtTop(of: "a #x")                                  // first → blank line
        XCTAssertTrue(vm.groupingSelectedTagsAtTop(of: "b #x").hasPrefix("#x "))      // later → space
        vm.resetGrouping()
        XCTAssertTrue(vm.groupingSelectedTagsAtTop(of: "c #x").hasPrefix("#x\n\n"))   // reset → blank line
    }
}
