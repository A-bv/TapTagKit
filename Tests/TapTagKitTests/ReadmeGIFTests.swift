import XCTest
@testable import TapTagKit

/// Renders the README demo GIFs — one English, one French — each walking
/// through the action-bar buttons. Tooling, not a behavioral test: runs only
/// when `GIF_OUTPUT_DIR` is set (see `Scripts/record-gif.sh`).
@MainActor
final class ReadmeGIFTests: XCTestCase {

    private enum Layout {
        static let width: CGFloat = 380
        static let cardHeight: CGFloat = 430
        static let scale: CGFloat = 2
        static let tapSize: CGFloat = 46
    }

    /// Per-language captions for each beat of the demo.
    private struct Script {
        let language: String
        let fileName: String
        let intro: String
        let group: String
        let deselect: String
        let pickMore: String
        let delete: String
        let done: String
    }

    // The demo is rendered in English regardless of the machine's locale.
    private let english = Script(
        language: "en", fileName: "demo.gif",
        intro: "Tap hashtags to select them",
        group: "Group — lift them to the top ↑",
        deselect: "Deselect — clear the selection",
        pickMore: "Pick a couple more",
        delete: "Delete — remove them",
        done: "Done")

    private let tagText = """
    #swift #swiftui #iosdev
    #xcode #wwdc #coding
    #apps #developer #mobile
    """

    func testRenderReadmeGIF() throws {
        guard let outputDir = ProcessInfo.processInfo.environment["GIF_OUTPUT_DIR"] else {
            throw XCTSkip("Set GIF_OUTPUT_DIR (use Scripts/record-gif.sh) to render the GIF.")
        }
        try render(english, to: outputDir)
    }

    private func render(_ script: Script, to outputDir: String) throws {
        let scene = makeScene(language: script.language)
        let window = UIWindow(frame: scene.card.bounds)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(scene.card)
        window.makeKeyAndVisible()
        scene.card.layoutIfNeeded()

        var frames: [AnimatedGIF.Frame] = []
        func capture(_ message: String, hold: Double) {
            scene.caption.text = message
            scene.card.layoutIfNeeded()
            frames.append(.init(image: snapshot(scene.card), delay: hold))
        }
        func tap(at center: CGPoint, _ message: String) {
            scene.tap.center = center
            scene.tap.isHidden = false
            scene.tap.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
            capture(message, hold: 0.12)
            scene.tap.transform = .identity
            capture(message, hold: 0.18)
            scene.tap.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            capture(message, hold: 0.12)
            scene.tap.isHidden = true
        }
        func tapTag(_ token: String, _ message: String) {
            if let center = tagCenter(of: token, in: scene.textView, container: scene.card) {
                tap(at: center, message)
            }
        }
        func tapButton(_ index: Int, _ message: String) {
            tap(at: barButtonCenter(index, in: scene), message)
        }

        capture(script.intro, hold: 0.9)
        tapTag("#swift", script.intro)
        scene.textView.selectTag("swift")
        tapTag("#iosdev", script.intro)
        scene.textView.selectTag("iosdev")
        tapTag("#coding", script.intro)
        scene.textView.selectTag("coding")
        capture(script.intro, hold: 0.6)

        tapButton(2, script.group)                       // Group
        scene.textView.groupSelectedTags()
        capture(script.group, hold: 1.1)

        tapButton(3, script.deselect)                    // Deselect
        scene.textView.clearSelection()
        capture(script.deselect, hold: 1.0)

        tapTag("#xcode", script.pickMore)
        scene.textView.selectTag("xcode")
        tapTag("#wwdc", script.pickMore)
        scene.textView.selectTag("wwdc")
        capture(script.pickMore, hold: 0.6)

        tapButton(4, script.delete)                      // Delete
        scene.textView.deleteSelectedTags()
        scene.textView.text = scene.textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        capture(script.delete, hold: 1.1)

        tapButton(5, script.done)                        // Done
        capture(script.done, hold: 1.2)

        let url = URL(fileURLWithPath: outputDir, isDirectory: true).appendingPathComponent(script.fileName)
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: outputDir, isDirectory: true), withIntermediateDirectories: true)
        try AnimatedGIF.write(frames, to: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        print("📽  \(script.fileName) written (\(frames.count) frames)")
    }

    // MARK: - Scene

    private struct Scene {
        let card: UIView
        let textView: TapTextView
        let actionBar: TagActionBar
        let caption: UILabel
        let tap: UIView
    }

    private func makeScene(language: String) -> Scene {
        let card = UIView(frame: CGRect(x: 0, y: 0, width: Layout.width, height: Layout.cardHeight))
        card.backgroundColor = .secondarySystemBackground

        let title = UILabel(frame: CGRect(x: 20, y: 18, width: Layout.width - 40, height: 26))
        title.text = "TapTagKit"
        title.font = .systemFont(ofSize: 20, weight: .bold)
        card.addSubview(title)

        let textView = TapTextView(frame: CGRect(x: 20, y: 54, width: Layout.width - 40, height: 200))
        textView.configuration = localizedConfig(language: language)
        textView.font = .systemFont(ofSize: 18)
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.backgroundColor = .systemBackground
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        textView.layer.cornerRadius = 14
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.text = tagText
        card.addSubview(textView)

        let caption = UILabel(frame: CGRect(x: 20, y: 268, width: Layout.width - 40, height: 44))
        caption.font = .systemFont(ofSize: 15, weight: .medium)
        caption.textColor = .secondaryLabel
        caption.numberOfLines = 2
        card.addSubview(caption)

        let actionBar = textView.makeActionBar()
        card.addSubview(actionBar)
        NSLayoutConstraint.activate([
            actionBar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            actionBar.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            actionBar.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])

        let tap = makeTapIndicator()
        card.addSubview(tap)

        return Scene(card: card, textView: textView, actionBar: actionBar, caption: caption, tap: tap)
    }

    /// A `Configuration` whose action labels come from the package's bundle for
    /// `language` — so the rendered bar really is localized.
    private func localizedConfig(language: String) -> TapTextView.Configuration {
        var config = TapTextView.Configuration()
        config.tagHighlightColor = .systemIndigo
        guard let url = L.bundle.url(forResource: language, withExtension: "lproj"),
              let bundle = Bundle(url: url) else { return config }
        func string(_ key: String, _ fallback: String) -> String {
            bundle.localizedString(forKey: key, value: fallback, table: nil)
        }
        config.accessibility.copyLabel = string("ttk.copy", "Copy")
        config.accessibility.cutLabel = string("ttk.cut", "Cut")
        config.accessibility.groupLabel = string("ttk.group", "Group")
        config.accessibility.deselectLabel = string("ttk.deselect", "Deselect")
        config.accessibility.deleteLabel = string("ttk.delete", "Delete")
        config.accessibility.doneLabel = string("ttk.done", "Done")
        return config
    }

    private func makeTapIndicator() -> UIView {
        let size = Layout.tapSize
        let indicator = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        indicator.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.24)
        indicator.layer.cornerRadius = size / 2
        indicator.layer.borderWidth = 2
        indicator.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.9).cgColor
        indicator.isHidden = true
        let icon = UIImageView(image: UIImage(systemName: "hand.tap.fill"))
        icon.tintColor = .systemBlue
        icon.contentMode = .scaleAspectFit
        icon.frame = indicator.bounds.insetBy(dx: 12, dy: 12)
        indicator.addSubview(icon)
        return indicator
    }

    private func tagCenter(of token: String, in textView: TapTextView, container: UIView) -> CGPoint? {
        let range = (textView.text as NSString).range(of: token)
        guard range.location != NSNotFound,
              let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
              let end = textView.position(from: start, offset: range.length),
              let textRange = textView.textRange(from: start, to: end) else { return nil }
        let rect = textView.firstRect(for: textRange)
        return textView.convert(CGPoint(x: rect.midX, y: rect.midY), to: container)
    }

    private func barButtonCenter(_ index: Int, in scene: Scene) -> CGPoint {
        let count = scene.actionBar.items.count
        let width = scene.actionBar.bounds.width / CGFloat(count)
        let point = CGPoint(x: width * (CGFloat(index) + 0.5), y: scene.actionBar.bounds.midY)
        return scene.actionBar.convert(point, to: scene.card)
    }

    private func snapshot(_ view: UIView) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = Layout.scale
        return UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { context in
            view.layer.render(in: context.cgContext)
        }
    }
}
