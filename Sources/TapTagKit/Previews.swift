#if DEBUG
import UIKit
import SwiftUI

/// A live, tappable `TapTextView` for the Xcode canvas. It opens with `#swift`
/// already selected so every occurrence is highlighted on sight; tap the
/// activate button to enter selection mode and toggle tags yourself.
private final class PreviewViewController: UIViewController {

    private let tapTextView: TapTextView = {
        let tv = TapTextView()
        var config = TapTextView.Configuration()
        config.tagHighlightColor = .systemIndigo
        config.placeholder = "Add some #tags…"
        tv.configuration = config

        tv.font = .preferredFont(forTextStyle: .body)
        tv.text = "#swift makes #iOS fun.\nShare #swift tips, learn #swift, build #iOS apps."
        tv.isScrollEnabled = false
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tv.layer.cornerRadius = 12
        tv.layer.borderWidth = 1
        tv.layer.borderColor = UIColor.separator.cgColor
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let hint: UILabel = {
        let label = UILabel()
        label.text = "Tap the hand button, then tap a hashtag — every match lights up."
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

        tapTextView.addTagSelectorToolBar(viewController: self)
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

        // Show the headline feature immediately: highlight every "#swift".
        tapTextView.selectTag("swift")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: false)
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
