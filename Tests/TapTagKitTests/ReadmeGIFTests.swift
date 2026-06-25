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

        let scene = makeScene()
        let window = UIWindow(frame: scene.card.bounds)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(scene.card)
        window.makeKeyAndVisible()

        var frames: [AnimatedGIF.Frame] = []
        func capture(_ message: String, hold: Double) {
            scene.caption.text = message
            scene.card.setNeedsLayout()
            scene.card.layoutIfNeeded()
            frames.append(.init(image: snapshot(scene.card), delay: hold))
        }
        func showTap(on token: String) {
            if let center = tagCenter(of: token, in: scene.textView, container: scene.card) {
                scene.tapDot.center = center
                scene.tapDot.isHidden = false
            }
        }
        func hideTap() { scene.tapDot.isHidden = true }

        scene.textView.text = sampleText
        capture("Tap a hashtag to select it", hold: 0.9)

        showTap(on: "#swift")
        capture("Tap #swift…", hold: 0.5)

        hideTap()
        scene.textView.selectTag("swift")
        capture("Every #swift lights up · 3 matches", hold: 1.0)

        showTap(on: "#iOS")
        capture("Tap #iOS…", hold: 0.5)

        hideTap()
        scene.textView.selectTag("iOS")
        capture("Select as many as you like", hold: 0.9)

        scene.textView.groupSelectedTags()
        capture("Group them to the top ↑", hold: 1.2)

        scene.textView.deleteSelectedTags()
        scene.textView.text = scene.textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        capture("…or delete them in one tap", hold: 1.4)

        let url = URL(fileURLWithPath: outputDir, isDirectory: true)
            .appendingPathComponent("demo.gif")
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: outputDir, isDirectory: true),
            withIntermediateDirectories: true)
        try AnimatedGIF.write(frames, to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        print("📽  README GIF written to \(url.path) (\(frames.count) frames)")
    }

    // MARK: - Demo scene

    private struct Scene {
        let card: UIView
        let textView: TapTextView
        let caption: UILabel
        let tapDot: UIView
    }

    private func makeScene() -> Scene {
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

        // A translucent "finger tap" indicator, hidden until a tap is shown.
        let tapDot = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        tapDot.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.28)
        tapDot.layer.cornerRadius = 20
        tapDot.layer.borderWidth = 2
        tapDot.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.85).cgColor
        tapDot.isHidden = true
        card.addSubview(tapDot)

        return Scene(card: card, textView: textView, caption: caption, tapDot: tapDot)
    }

    /// Center (in `container` coordinates) of the first occurrence of `token`.
    private func tagCenter(of token: String, in textView: TapTextView, container: UIView) -> CGPoint? {
        let range = (textView.text as NSString).range(of: token)
        guard range.location != NSNotFound,
              let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
              let end = textView.position(from: start, offset: range.length),
              let textRange = textView.textRange(from: start, to: end)
        else { return nil }
        let rect = textView.firstRect(for: textRange)
        return textView.convert(CGPoint(x: rect.midX, y: rect.midY), to: container)
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
