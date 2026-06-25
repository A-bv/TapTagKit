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
