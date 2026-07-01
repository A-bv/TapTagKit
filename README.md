# TapTagKit

Hashtags you can actually tap. `TapTextView` is a `UITextView` subclass: an ordinary text view that also recognizes the hashtags inside it and lets you act on them from a toolbar.

[![CI](https://github.com/A-bv/TapTagKit/actions/workflows/ci.yml/badge.svg)](https://github.com/A-bv/TapTagKit/actions/workflows/ci.yml)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)
![iOS 15+](https://img.shields.io/badge/iOS-15%2B-007AFF?logo=apple&logoColor=white)
![SPM](https://img.shields.io/badge/SPM-compatible-success)
![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey)

Start a selection session, from a bar button or in code, then tap the hashtags you want. A toolbar appears where you can copy, cut, group at the top, delete, or deselect them, and it disappears when the session ends. Every action is available programmatically too.

<p align="center">
  <img src=".github/demo.gif" alt="Selecting hashtags in a text view, then grouping them at the top" width="380">
</p>

## Install

Install with Swift Package Manager. In Xcode, add the package using its URL:

```
https://github.com/A-bv/TapTagKit
```

or declare it in `Package.swift`:

```swift
.package(url: "https://github.com/A-bv/TapTagKit", from: "5.0.0")
```

## Usage

### UIKit

```swift
let textView = TapTextView()                       // behaves like any UITextView
navigationItem.rightBarButtonItem = textView.makeTapTextViewButton()
```

The bar button opens a selection session, and the toolbar shows and hides itself. If you'd rather drive it yourself, call `beginSelection()` and `endSelection()` from any control.

### SwiftUI

```swift
@State private var text = "Try #swift and #swiftui"
@State private var isSelecting = false

TapTagView(text: $text, isSelecting: $isSelecting)
```

`TapTagView` takes a text binding and reflects the session through `isSelecting`; toggle `isSelecting` from a button to begin or end selection.

## Customization

```swift
var config = TapTextView.Configuration()
config.tagHighlightColor = .systemIndigo
config.selectedTagTextColor = .white
textView.configuration = config
```

Set the tag highlight and selected-text colors through `Configuration`.

## Localization

The built-in labels, captions, and VoiceOver strings ship in English and French. Override any of them through `Configuration`:

```swift
config.accessibility.copyLabel = "Copier"
```

## Behavior

- **Matching is case-insensitive and whole-token.** `#Sun` and `#sun` are the same tag, `#c++` matches in full, and tapping `#sun` leaves `#sunny` untouched.
- **Clean-up is on demand.** Call `cleanUpHashtags()` to remove duplicate and invalid hashtags. It never runs on its own, so entering selection mode never rewrites your text. In SwiftUI, tidy a bound string with `TapTextView.cleanedHashtags(in:)`.
- **Your text keeps its styling.** Highlighting, grouping, and deleting all work on the attributed string, so fonts, colors, and links survive; only the tags themselves move or disappear.
- **The scroll position holds.** Tapping a tag in a long, scrolled text view does not snap back to the top.

## Accessibility

- Each hashtag is exposed as its own VoiceOver element; activating it toggles that tag, exactly like a tap.
- VoiceOver announces every selection and deselection.

## Implementation

The logic is isolated so it stays testable: every tag and text rule lives in `TagSelectionViewModel`, a plain type with no UIKit, and `TapTextView` just renders what it decides. Haptics and VoiceOver announcements sit behind the `TapTextViewServices` protocol, so tests use fakes and callers can swap them. The toolbar is a SwiftUI view hosted with `UIHostingController`, and the package has no dependencies and builds in Swift 6 under complete strict concurrency.

## License

MIT. See [LICENSE](LICENSE).
