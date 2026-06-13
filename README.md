# TapTagKit

A `UITextView` whose hashtags become tappable. Enter selection mode, tap tags to highlight every occurrence, then act on the whole selection from a toolbar: copy, cut, group at the top, deselect, or delete.

## Usage

```swift
let textView = TapTextView()
textView.tagDelegate = self                                   // toolbar show/hide hooks
textView.addTagSelectorToolBar(viewController: self)          // installs the actions toolbar
navigationItem.rightBarButtonItem = textView.makeTapTextViewButton() // enters selection mode
```

The host shows the toolbar while a selection session is active:

```swift
extension MyViewController: TapTextViewDelegate {
    func tapTextViewDidStartSelection(_ textView: TapTextView) {
        navigationController?.setToolbarHidden(false, animated: false)
    }
    func tapTextViewDidFinishSelection(_ textView: TapTextView) {
        navigationController?.setToolbarHidden(true, animated: false)
    }
}
```

All UI strings and the highlight color are injectable via `TapTextView.Configuration` for localization and theming.

## Xcode Preview

Open `Sources/TapTagKit/Previews.swift` in Xcode and enable the canvas (**Editor › Canvas** or **⌥⌘↩**). The preview renders a live `TapTextView` inside a `UINavigationController`:

- The activate button (`hand.point.up.left`) is in the navigation bar — tap it to enter selection mode.
- The toolbar at the bottom shows all six actions (copy, cut, group, deselect, delete, info).
- Tap any hashtag in the text view to highlight it.

> The preview file is wrapped in `#if DEBUG` and is never compiled into release builds.
