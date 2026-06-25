#if DEBUG
import UIKit
import SwiftUI

/// A live, tappable `TapTextView` for the Xcode canvas. It opens a selection
/// session with `#swift` already highlighted; the action toolbar manages itself.
private final class PreviewViewController: UIViewController {

    private let tapTextView: TapTextView = {
        let textView = TapTextView()
        var config = TapTextView.Configuration()
        config.tagHighlightColor = .systemIndigo
        textView.configuration = config

        textView.font = .preferredFont(forTextStyle: .body)
        textView.text = "#swift makes #iOS fun.\nShare #swift tips, learn #swift, build #iOS apps."
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    private let hint: UILabel = {
        let label = UILabel()
        label.text = "Tap a hashtag — every match lights up. Use the toolbar below to copy, group, or delete."
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "TapTagKit"
        navigationItem.rightBarButtonItem = tapTextView.makeTapTextViewButton()

        view.addSubview(tapTextView)
        view.addSubview(hint)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            tapTextView.topAnchor.constraint(equalTo: safe.topAnchor, constant: 16),
            tapTextView.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            tapTextView.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),

            hint.topAnchor.constraint(equalTo: tapTextView.bottomAnchor, constant: 12),
            hint.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 20),
            hint.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -20),
        ])

        // Open a session so the self-contained toolbar shows, with #swift lit up.
        tapTextView.beginSelection()
        tapTextView.selectTag("swift")
    }
}

private struct PreviewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(rootViewController: PreviewViewController())
    }
    func updateUIViewController(_ vc: UINavigationController, context: Context) {}
}

#Preview("Light") {
    PreviewRepresentable().edgesIgnoringSafeArea(.all)
}

#Preview("Dark") {
    PreviewRepresentable()
        .edgesIgnoringSafeArea(.all)
        .preferredColorScheme(.dark)
}
#endif
