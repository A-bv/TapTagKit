import SwiftUI
import UIKit

/// A SwiftUI wrapper around ``TapTextView``.
///
/// Bind `isSelecting` to a SwiftUI control to start and finish hashtag-selection
/// sessions. The UIKit text view continues to own rich-text editing and the
/// self-presented action bar.
public struct TapTagView: UIViewRepresentable {
    @Binding private var text: String
    @Binding private var isSelecting: Bool

    private let configuration: TapTextView.Configuration

    public init(
        text: Binding<String>,
        isSelecting: Binding<Bool>,
        configuration: TapTextView.Configuration = .init()
    ) {
        _text = text
        _isSelecting = isSelecting
        self.configuration = configuration
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeUIView(context: Context) -> TapTextView {
        let textView = TapTextView()
        textView.delegate = context.coordinator
        textView.tagDelegate = context.coordinator
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        return textView
    }

    public func updateUIView(_ textView: TapTextView, context: Context) {
        context.coordinator.parent = self

        if textView.text != text {
            textView.text = text
        }
        textView.configuration = configuration

        context.coordinator.synchronizeSelection(of: textView)
    }

    public final class Coordinator: NSObject, UITextViewDelegate, TapTextViewDelegate {
        fileprivate var parent: TapTagView
        private var isSelectionStartPending = false

        fileprivate init(parent: TapTagView) {
            self.parent = parent
        }

        public func textViewDidChange(_ textView: UITextView) {
            updateText(textView.text)
        }

        public func tapTextViewDidStartSelection(_ textView: TapTextView) {
            parent.isSelecting = true
            updateText(textView.text)
        }

        public func tapTextViewDidFinishSelection(_ textView: TapTextView) {
            parent.isSelecting = false
            updateText(textView.text)
        }

        public func tapTextViewDidChangeText(_ textView: TapTextView) {
            updateText(textView.text)
        }

        fileprivate func synchronizeSelection(of textView: TapTextView) {
            guard parent.isSelecting != textView.isSelecting else { return }

            if parent.isSelecting {
                beginSelectionWhenAttached(to: textView)
            } else {
                textView.endSelection()
            }
        }

        private func beginSelectionWhenAttached(to textView: TapTextView) {
            guard textView.window == nil else {
                textView.beginSelection()
                return
            }
            guard !isSelectionStartPending else { return }

            isSelectionStartPending = true
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView else { return }
                self.isSelectionStartPending = false
                guard self.parent.isSelecting, !textView.isSelecting else { return }
                textView.beginSelection()
            }
        }

        private func updateText(_ newText: String) {
            guard parent.text != newText else { return }
            parent.text = newText
        }
    }
}
