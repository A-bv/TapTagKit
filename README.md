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
