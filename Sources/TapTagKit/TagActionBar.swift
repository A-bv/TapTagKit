import SwiftUI
import UIKit

private enum Constants {
    static let cornerRadius: CGFloat = 22
    static let shadowOpacity = 0.12
    static let shadowRadius: CGFloat = 14
    static let shadowOffset: CGFloat = 4
    static let stackSpacing: CGFloat = 2
    static let stackInset: CGFloat = 8
    static let buttonHorizontalInset: CGFloat = 4
    static let buttonVerticalInset: CGFloat = 8
    static let imagePadding: CGFloat = 5
    static let titleFontSize: CGFloat = 11
    static let prominentBackgroundAlpha = 0.15
    static let barHeight: CGFloat = 70
}

/// A UIKit container for the SwiftUI action bar presented by ``TapTextView``.
final class TagActionBar: UIView {

    /// One captioned button. `handler` runs on tap.
    struct Item: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let tint: UIColor?
        let isProminent: Bool
        let confirmationTitle: String?
        let cancelTitle: String?
        let handler: () -> Void

        init(
            symbol: String,
            title: String,
            tint: UIColor?,
            isProminent: Bool,
            confirmationTitle: String? = nil,
            cancelTitle: String? = nil,
            handler: @escaping () -> Void
        ) {
            self.symbol = symbol
            self.title = title
            self.tint = tint
            self.isProminent = isProminent
            self.confirmationTitle = confirmationTitle
            self.cancelTitle = cancelTitle
            self.handler = handler
        }
    }

    private(set) var items: [Item]
    private let hostingController: UIHostingController<TagActionBarContent>

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Constants.barHeight)
    }

    init(items: [Item], tint: UIColor) {
        self.items = items
        hostingController = UIHostingController(
            rootView: TagActionBarContent(items: items, defaultTint: tint)
        )
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        let hostedView = hostingController.view!
        hostedView.backgroundColor = .clear
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: bottomAnchor),
            hostedView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct TagActionBarContent: View {
    let items: [TagActionBar.Item]
    let defaultTint: UIColor

    @State private var pendingConfirmation: TagActionBar.Item?

    var body: some View {
        HStack(spacing: Constants.stackSpacing) {
            ForEach(items) { item in
                actionButton(for: item)
            }
        }
        .padding(Constants.stackInset)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous))
        .shadow(
            color: .black.opacity(Constants.shadowOpacity),
            radius: Constants.shadowRadius,
            y: Constants.shadowOffset
        )
        .ignoresSafeArea()
        .alert(item: $pendingConfirmation) { item in
            Alert(
                title: Text(item.confirmationTitle ?? item.title),
                primaryButton: .destructive(Text(item.title), action: item.handler),
                secondaryButton: .cancel(Text(item.cancelTitle ?? "Cancel"))
            )
        }
    }

    private func actionButton(for item: TagActionBar.Item) -> some View {
        let tint = Color(uiColor: item.tint ?? defaultTint)

        return Button {
            if item.confirmationTitle == nil {
                item.handler()
            } else {
                pendingConfirmation = item
            }
        } label: {
            VStack(spacing: Constants.imagePadding) {
                Image(systemName: item.symbol)
                Text(item.title)
                    .font(.system(size: Constants.titleFontSize, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Constants.buttonHorizontalInset)
            .padding(.vertical, Constants.buttonVerticalInset)
            .foregroundColor(tint)
            .background {
                if item.isProminent {
                    RoundedRectangle(cornerRadius: Constants.cornerRadius / 2, style: .continuous)
                        .fill(tint.opacity(Constants.prominentBackgroundAlpha))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
    }
}
