# TapTagKit

A `UITextView` whose hashtags become tappable. Enter selection mode, tap tags to highlight every occurrence, then act on the whole selection from a toolbar: copy, cut, group at the top, deselect, or delete.

## Features
- Tap-to-select hashtags — one tap highlights every occurrence.
- Selection toolbar: copy, cut, group-to-top, deselect, delete.
- Optional placeholder and keyboard avoidance.
- Strings and highlight color injectable via `Configuration` (localization + theming).

## Requirements
iOS 15 · Swift 5.9

## Installation
```swift
.package(url: "https://github.com/A-bv/TapTagKit", from: "1.1.0")
```

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
Open `Sources/TapTagKit/Previews.swift` and enable the canvas (**Editor › Canvas**). The preview renders a live `TapTextView` in a `UINavigationController`: tap the activate button (`hand.point.up.left`) in the nav bar to enter selection mode, tap any hashtag to highlight it, and use the bottom toolbar's six actions.
