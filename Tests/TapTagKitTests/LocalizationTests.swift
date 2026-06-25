import XCTest
@testable import TapTagKit

/// Verifies the package ships English and French translations for its strings.
final class LocalizationTests: XCTestCase {

    private func string(_ key: String, language: String) -> String? {
        guard let url = L.bundle.url(forResource: language, withExtension: "lproj"),
              let bundle = Bundle(url: url)
        else { return nil }
        return bundle.localizedString(forKey: key, value: "MISSING", table: nil)
    }

    func testEnglishStringsArePresent() {
        XCTAssertEqual(string("ttk.copy", language: "en"), "Copy")
        XCTAssertEqual(string("ttk.delete", language: "en"), "Delete")
        XCTAssertEqual(string("ttk.done", language: "en"), "Done")
    }

    func testFrenchStringsArePresent() {
        XCTAssertEqual(string("ttk.copy", language: "fr"), "Copier")
        XCTAssertEqual(string("ttk.delete", language: "fr"), "Supprimer")
        XCTAssertEqual(string("ttk.done", language: "fr"), "Terminé")
    }

    func testEveryActionKeyIsTranslatedInBothLanguages() {
        let keys = ["ttk.select", "ttk.copy", "ttk.cut", "ttk.group",
                    "ttk.deselect", "ttk.delete", "ttk.done", "ttk.cancel",
                    "ttk.deleteConfirm", "ttk.hint", "ttk.selected", "ttk.deselected"]
        for key in keys {
            XCTAssertNotEqual(string(key, language: "en"), "MISSING", "Missing en: \(key)")
            XCTAssertNotEqual(string(key, language: "fr"), "MISSING", "Missing fr: \(key)")
        }
    }
}
