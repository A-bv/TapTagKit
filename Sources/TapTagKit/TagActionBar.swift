import UIKit

private enum Constants {
    static let cornerRadius: CGFloat = 22
    static let shadowOpacity: Float = 0.12
    static let shadowRadius: CGFloat = 14
    static let shadowOffset = CGSize(width: 0, height: 4)
    static let stackSpacing: CGFloat = 2
    static let stackInset: CGFloat = 8
    static let imagePadding: CGFloat = 5
    static let contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
    static let titleFontSize: CGFloat = 11
    static let prominentBackgroundAlpha: CGFloat = 0.15
}

/// The grouped, captioned action bar shown during a selection session: a
/// rounded floating card whose buttons each pair an SF Symbol with a small
/// label. Self-contained — `TapTextView` presents and dismisses it.
final class TagActionBar: UIView {

    /// One captioned button. `handler` runs on tap.
    struct Item {
        let symbol: String
        let title: String
        let tint: UIColor?
        let isProminent: Bool
        let handler: () -> Void
    }

    private(set) var buttons: [UIButton] = []

    init(items: [Item], tint: UIColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = Constants.cornerRadius
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = Constants.shadowOpacity
        layer.shadowRadius = Constants.shadowRadius
        layer.shadowOffset = Constants.shadowOffset

        buttons = items.map { makeButton($0, defaultTint: tint) }
        let stack = UIStackView(arrangedSubviews: buttons)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.spacing = Constants.stackSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Constants.stackInset),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Constants.stackInset),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.stackInset),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.stackInset),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makeButton(_ item: Item, defaultTint: UIColor) -> UIButton {
        var config: UIButton.Configuration = item.isProminent ? .tinted() : .plain()
        config.image = UIImage(systemName: item.symbol)
        config.title = item.title
        config.imagePlacement = .top
        config.imagePadding = Constants.imagePadding
        config.contentInsets = Constants.contentInsets
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: Constants.titleFontSize, weight: .medium)
            return outgoing
        }
        config.baseForegroundColor = item.tint ?? defaultTint
        if item.isProminent {
            config.baseBackgroundColor = (item.tint ?? defaultTint)
                .withAlphaComponent(Constants.prominentBackgroundAlpha)
        }

        let button = UIButton(configuration: config, primaryAction: UIAction { _ in item.handler() })
        button.accessibilityLabel = item.title
        return button
    }
}
