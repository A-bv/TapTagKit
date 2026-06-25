import UIKit

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
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 4)

        buttons = items.map { makeButton($0, defaultTint: tint) }
        let stack = UIStackView(arrangedSubviews: buttons)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makeButton(_ item: Item, defaultTint: UIColor) -> UIButton {
        var config: UIButton.Configuration = item.isProminent ? .tinted() : .plain()
        config.image = UIImage(systemName: item.symbol)
        config.title = item.title
        config.imagePlacement = .top
        config.imagePadding = 5
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 11, weight: .medium)
            return outgoing
        }
        config.baseForegroundColor = item.tint ?? defaultTint
        if item.isProminent { config.baseBackgroundColor = (item.tint ?? defaultTint).withAlphaComponent(0.15) }

        let button = UIButton(configuration: config, primaryAction: UIAction { _ in item.handler() })
        button.accessibilityLabel = item.title
        return button
    }
}
