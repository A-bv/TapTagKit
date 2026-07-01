# TapTagKit

Hashtags you can actually tap. A `UITextView` subclass that detects hashtags and lets you act on them.

[![CI](https://github.com/A-bv/TapTagKit/actions/workflows/ci.yml/badge.svg)](https://github.com/A-bv/TapTagKit/actions/workflows/ci.yml)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)
![iOS 15+](https://img.shields.io/badge/iOS-15%2B-007AFF?logo=apple&logoColor=white)
![SPM](https://img.shields.io/badge/SPM-compatible-success)
![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey)

Tap a hashtag to select every occurrence of it, then from a toolbar:

- **Copy** the selected tags
- **Cut** them — copy, then remove from the text
- **Group** them at the top of the text
- **Delete** them
- **Deselect** / clear the selection

You can also select and act on tags programmatically.

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

UIKit — add the button; the toolbar shows and hides itself for the session:

```swift
let textView = TapTextView()
navigationItem.rightBarButtonItem = textView.makeTapTextViewButton()
```

Or drive it directly with `beginSelection()` / `endSelection()`.

SwiftUI:

```swift
@State private var text = "Try #swift and #swiftui"
@State private var isSelecting = false

TapTagView(text: $text, isSelecting: $isSelecting)
```

## Configuration

```swift
var config = TapTextView.Configuration()
config.tagHighlightColor = .systemIndigo
config.accessibility.copyLabel = "Copier"
textView.configuration = config
```

- **Colors** — `tagHighlightColor`, `selectedTagTextColor`.
- **Localization** — labels, captions, and VoiceOver strings ship in English and French; override any through `Configuration`.
- **Clean-up** — duplicate and invalid hashtags are removed when a session starts (`removesDuplicatesOnSelection`).
- **Matching** — case-insensitive: `#Sun` and `#sun` are the same tag.

## Accessibility

- Each hashtag is its own VoiceOver element; activating it toggles that tag, like a tap.
- Selection changes are announced (high priority on iOS 17+, so fast toggles aren't dropped).
- All spoken strings are localizable via `Configuration.accessibility`.

## Rich text

Highlighting, grouping, deleting, and clean-up operate on the attributed text, so caller fonts, colors, and links are preserved — only the tags move or disappear. Scroll position is kept when tapping a tag.

## Implementation

- **MVVM** — all tag/text logic lives in a UIKit-free `TagSelectionViewModel`, unit-tested without a simulated view.
- **Dependency injection** — haptics and VoiceOver announcements sit behind `TapTextViewServices`, swappable in tests or by callers.
- **Self-contained toolbar** — a SwiftUI action bar hosted via `UIHostingController` in the view-controller tree.
- **Whole-token matching** — cached, escaped regexes match `#c++` and skip `#sunny` when you tap `#sun`.
- **Swift 6 language mode** with complete strict concurrency; **zero third-party dependencies**.

## License

MIT — see [LICENSE](LICENSE).
