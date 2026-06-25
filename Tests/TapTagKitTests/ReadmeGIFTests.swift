import XCTest
@testable import TapTagKit

/// Renders the animated demo shown in the README.
///
/// This is tooling, not a behavioral test: it only runs when `GIF_OUTPUT_DIR`
/// is set (see `Scripts/record-gif.sh`), so CI and `swift test` skip it.
@MainActor
final class ReadmeGIFTests: XCTestCase {

    private let sampleText =
        "Building #swift apps ✨\n#swift loves #SwiftUI\nLearn #iOS ship #iOS love #swift"

    func testRenderReadmeGIF() throws {
        guard let outputDir = ProcessInfo.processInfo.environment["GIF_OUTPUT_DIR"] else {
            throw XCTSkip("Set GIF_OUTPUT_DIR (use Scripts/record-gif.sh) to render the README GIF.")
        }

        let (card, textView, caption) = makeDemoCard()
        let window = UIWindow(frame: card.bounds)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(card)
        window.makeKeyAndVisible()

        var frames: [AnimatedGIF.Frame] = []
        func capture(_ message: String, hold: Double) {
            caption.text = message
            card.setNeedsLayout()
            card.layoutIfNeeded()
            frames.append(.init(image: snapshot(card), delay: hold))
        }

        textView.text = sampleText
        capture("Tap a hashtag — every match lights up", hold: 1.6)

        textView.selectTag("swift")
        capture("#swift selected · 3 matches", hold: 1.4)

        textView.selectTag("iOS")
        capture("Add #iOS to the selection", hold: 1.4)

        textView.groupSelectedTags()
        capture("Group them to the top ↑", hold: 2.2)

        let url = URL(fileURLWithPath: outputDir, isDirectory: true)
            .appendingPathComponent("demo.gif")
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: outputDir, isDirectory: true),
            withIntermediateDirectories: true)
        try AnimatedGIF.write(frames, to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        print("📽  README GIF written to \(url.path)")
    }

    // MARK: - Demo scene

    private func makeDemoCard() -> (card: UIView, textView: TapTextView, caption: UILabel) {
        let width: CGFloat = 380
        let card = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 320))
        card.backgroundColor = .secondarySystemBackground

        let title = UILabel(frame: CGRect(x: 20, y: 18, width: width - 40, height: 26))
        title.text = "TapTagKit"
        title.font = .systemFont(ofSize: 20, weight: .bold)
        title.textColor = .label
        card.addSubview(title)

        var config = TapTextView.Configuration()
        config.tagHighlightColor = .systemIndigo
        let textView = TapTextView(frame: CGRect(x: 20, y: 54, width: width - 40, height: 196))
        textView.configuration = config
        textView.font = .systemFont(ofSize: 18)
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.backgroundColor = .systemBackground
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        textView.layer.cornerRadius = 14
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.separator.cgColor
        card.addSubview(textView)

        let caption = UILabel(frame: CGRect(x: 20, y: 264, width: width - 40, height: 40))
        caption.font = .systemFont(ofSize: 15, weight: .medium)
        caption.textColor = .secondaryLabel
        caption.numberOfLines = 2
        card.addSubview(caption)

        return (card, textView, caption)
    }

    private func snapshot(_ view: UIView) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds, format: format)
        return renderer.image { context in
            view.layer.render(in: context.cgContext)
        }
    }
}
