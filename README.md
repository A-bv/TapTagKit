# TapTagKit

Hashtags you can actually tap. A `UITextView` subclass: use it as a normal text view, and it also detects hashtags and shows a toolbar — on demand — to act on them.

[![CI](https://github.com/A-bv/TapTagKit/actions/workflows/ci.yml/badge.svg)](https://github.com/A-bv/TapTagKit/actions/workflows/ci.yml)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)
![iOS 15+](https://img.shields.io/badge/iOS-15%2B-007AFF?logo=apple&logoColor=white)
![SPM](https://img.shields.io/badge/SPM-compatible-success)
![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey)

Tap a hashtag to select every occurrence of it, then from the toolbar:

- **Copy** the selected tags
- **Cut** them — copy, then remove from the text
- **Group** them at the top of the text
- **Delete** them
- **Deselect** / clear the selection

The toolbar appears when a selection session starts and hides when it ends. You can also select and act on tags programmatically.

<p align="center">
  <img src="Assets/demo.gif" alt="Tapping #swift selects every match, then grouping moves the tags to the top" width="380">
</p>

## Install

Swift Package Manager — add the package URL in Xcode:

```
https://github.com/A-bv/TapTagKit
```

or in `Package.swift`:

```swift
.package(url: "https://github.com/A-bv/TapTagKit", from: "4.0.0")
```

## Usage

### UIKit

```swift
let textView = TapTextView()                       // behaves like any UITextView
navigationItem.rightBarButtonItem = textView.makeTapTextViewButton()
```

The bar button starts a session; the toolbar shows and hides itself. You can also call `beginSelection()` / `endSelection()` from any control.

### SwiftUI

```swift
@State private var text = "Try #swift and #swiftui"
@State private var isSelecting = false

TapTagView(text: $text, isSelecting: $isSelecting)
```

Toggle `isSelecting` — e.g. from a button — to start and end a session.

## Configuration

```swift
var config = TapTextView.Configuration()
config.tagHighlightColor = .systemIndigo
config.accessibility.copyLabel = "Copier"
textView.configuration = config
```

- **Colors** — `tagHighlightColor`, `selectedTagTextColor`.
- **Localization** — labels, captions, and VoiceOver strings ship in English and French; override any through `Configuration`.
- **Clean-up** — remove duplicate and invalid hashtags when a session starts (`removesDuplicatesOnSelection`, on by default).

## Behavior

- **Matching** — case-insensitive and whole-token: `#Sun` and `#sun` are the same tag, `#c++` matches, and `#sunny` doesn't when you tap `#sun`.
- **Attributed text preserved** — highlighting, grouping, and deleting keep caller fonts, colors, and links; only the tags move or disappear.
- **Scroll kept** — tapping a tag in a long text view doesn't jump the scroll position.

## Accessibility

- Each hashtag is its own VoiceOver element; activating it toggles the tag, like a tap.
- VoiceOver announces every selection and deselection.
- All spoken strings are localizable through `Configuration.accessibility`.

## Implementation

- **MVVM** — all tag and text logic lives in a UIKit-free `TagSelectionViewModel`, unit-tested without a simulated view.
- **Injected side effects** — haptics and VoiceOver announcements sit behind `TapTextViewServices`, swappable in tests or by callers.
- **Self-contained toolbar** — a SwiftUI action bar hosted in the view-controller tree via `UIHostingController`.
- **Safe matching** — user text is escaped before it reaches a regex, so metacharacter tags like `#c++` can't break selection.
- **Swift 6** language mode with complete strict concurrency, and zero third-party dependencies.

## License

MIT — see [LICENSE](LICENSE).
