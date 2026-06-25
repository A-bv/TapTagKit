import XCTest
@testable import TapTagKit

/// Renders the captioned action bar (with a tag list above it) so the design
/// can be eyeballed. Tooling — runs only when `GIF_OUTPUT_DIR` is set.
@MainActor
final class ActionBarSnapshotTests: XCTestCase {

    func testRenderActionBar() throws {
        guard let outputDir = ProcessInfo.processInfo.environment["GIF_OUTPUT_DIR"] else {
            throw XCTSkip("Set GIF_OUTPUT_DIR to render the action bar.")
        }

        let width: CGFloat = 390
        let card = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 320))
        card.backgroundColor = .systemGroupedBackground

        var config = TapTextView.Configuration()
        config.tagHighlightColor = .systemIndigo
        let textView = TapTextView(frame: CGRect(x: 16, y: 16, width: width - 32, height: 188))
        textView.configuration = config
        textView.font = .preferredFont(forTextStyle: .body)
        textView.text = """
        #swift #swiftui #iosdev #Swift #xcode
        #wwdc #coding #apps #! #coding #developer
        """
        textView.cleanUpHashtags()   // removes #Swift, #!, the 2nd #coding
        textView.isScrollEnabled = false
        textView.backgroundColor = .systemBackground
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.separator.cgColor
        card.addSubview(textView)
        ["swift", "iosdev", "coding"].forEach(textView.selectTag)

        let bar = textView.makeActionBar()
        card.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            bar.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            bar.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])

        let window = UIWindow(frame: card.bounds)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(card)
        window.makeKeyAndVisible()
        card.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(bounds: card.bounds, format: format).image { context in
            card.layer.render(in: context.cgContext)
        }

        let url = URL(fileURLWithPath: outputDir, isDirectory: true)
            .appendingPathComponent("action-bar.png")
        try image.pngData()?.write(to: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        print("🎛  action bar written to \(url.path)")
    }
}
