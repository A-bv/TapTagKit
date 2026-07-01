# TapTagKit

Hashtags you can actually tap. `TapTextView` is a `UITextView` subclass: an ordinary text view that also recognizes the hashtags inside it and, on demand, brings up a toolbar for acting on them.

[![CI](https://github.com/A-bv/TapTagKit/actions/workflows/ci.yml/badge.svg)](https://github.com/A-bv/TapTagKit/actions/workflows/ci.yml)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)
![iOS 15+](https://img.shields.io/badge/iOS-15%2B-007AFF?logo=apple&logoColor=white)
![SPM](https://img.shields.io/badge/SPM-compatible-success)
![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey)

Tap any hashtag to select every occurrence of it at once, then, from the toolbar:

- **Copy** the selected tags
- **Cut** them: copy, then remove them from the text
- **Group** them at the top of the text
- **Delete** them
- **Deselect** them, or clear the whole selection

The toolbar appears when a selection session begins and disappears when it ends. Every action is available programmatically too.

<p align="center">
  <img src="Assets/demo.gif" alt="Tapping #swift selects every match, then grouping moves the tags to the top" width="380">
</p>

## Install

Add the package in Xcode using its URL:

```
https://github.com/A-bv/TapTagKit
```

or declare it in `Package.swift`:

```swift
.package(url: "https://github.com/A-bv/TapTagKit", from: "4.0.0")
```

## Usage

### UIKit

```swift
let textView = TapTextView()                       // behaves like any UITextView
navigationItem.rightBarButtonItem = textView.makeTapTextViewButton()
```

The bar button opens a selection session, and the toolbar takes care of showing and hiding itself. If you'd rather drive it yourself, call `beginSelection()` and `endSelection()` from any control.

### SwiftUI

```swift
@State private var text = "Try #swift and #swiftui"
@State private var isSelecting = false

TapTagView(text: $text, isSelecting: $isSelecting)
```

`TapTagView` mirrors its session state through the `isSelecting` binding. Flip it from a button to begin or end selection.

## Configuration

```swift
var config = TapTextView.Configuration()
config.tagHighlightColor = .systemIndigo
config.accessibility.copyLabel = "Copier"
textView.configuration = config
```

- **Colors:** the highlight and selected-text colors (`tagHighlightColor`, `selectedTagTextColor`).
- **Localization:** labels, captions, and VoiceOver strings ship in English and French, and any of them can be overridden.
- **Clean-up:** duplicate and invalid hashtags are tidied away when a session begins; toggle it with `removesDuplicatesOnSelection` (on by default).

## Behavior

- **Matching is case-insensitive and whole-token.** `#Sun` and `#sun` are the same tag, `#c++` matches in full, and tapping `#sun` leaves `#sunny` untouched.
- **Your text keeps its styling.** Highlighting, grouping, and deleting all work on the attributed string, so fonts, colors, and links survive; only the tags themselves move or disappear.
- **The scroll position holds.** Tapping a tag in a long, scrolled text view no longer snaps back to the top.

## Accessibility

- Each hashtag is exposed as its own VoiceOver element; activating it toggles that tag, exactly like a tap.
- VoiceOver announces every selection and deselection.
- Every spoken string can be localized through `Configuration.accessibility`.

## Implementation

- **MVVM.** All tag and text logic lives in a UIKit-free `TagSelectionViewModel`, so the rules are unit-tested without ever instantiating a view.
- **Injected side effects.** Haptics and VoiceOver announcements sit behind the `TapTextViewServices` protocol, ready to be faked in tests or replaced by callers.
- **A self-contained toolbar.** The action bar is a SwiftUI view hosted in the view-controller tree through `UIHostingController`, so it can present its own confirmation dialogs.
- **Defensive matching.** Tag text is escaped before it reaches a regular expression, so hashtags containing regex metacharacters (like `#c++`) can never break selection.
- **Modern Swift.** Written in the Swift 6 language mode under complete strict concurrency, with no third-party dependencies.

## License

MIT. See [LICENSE](LICENSE).
