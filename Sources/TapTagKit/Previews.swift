#if DEBUG
import UIKit
import SwiftUI

private final class PreviewViewController: UIViewController {

    private let tapTextView: TapTextView = {
        let tv = TapTextView()
        tv.font = .preferredFont(forTextStyle: .body)
        tv.text = "#swift #UIKit and #iOS — use #TapTagKit to organize your #tags and #hashtags effortlessly"
        tv.isScrollEnabled = false
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tv.layer.cornerRadius = 12
        tv.layer.borderWidth = 1
        tv.layer.borderColor = UIColor.separator.cgColor
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "TapTagKit"

        tapTextView.addTagSelectorToolBar(viewController: self)
        navigationItem.rightBarButtonItem = tapTextView.makeTapTextViewButton()

        view.addSubview(tapTextView)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            tapTextView.topAnchor.constraint(equalTo: safe.topAnchor, constant: 16),
            tapTextView.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            tapTextView.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
        ])
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

#Preview("TapTagKit") {
    PreviewRepresentable().edgesIgnoringSafeArea(.all)
}
#endif
