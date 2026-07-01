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

You get a text view that edits normally. A **selection session** is the mode where editing pauses, a toolbar appears, and you tap hashtags to act on them. Below is a complete screen in each framework.

### UIKit

`TapTextView` is a `UITextView` subclass, so you add it and set its text like any text view. `makeTapTextViewButton()` gives you a button that turns the session on and off.

```swift
import UIKit
import TapTagKit

final class EditorViewController: UIViewController {
    private let textView = TapTextView()

    override func viewDidLoad() {
        super.viewDidLoad()

        textView.text = "Try #swift and #swiftui"
        textView.frame = view.bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(textView)

        // Put the selection button in the navigation bar.
        navigationItem.rightBarButtonItem = textView.makeTapTextViewButton()
    }
}
```

Tap the button to start a session: editing pauses and the toolbar appears. Tap hashtags to select them, use the toolbar, then tap Done to finish. If you have no navigation bar, call `textView.beginSelection()` and `textView.endSelection()` from any button of your own.

### SwiftUI

`TapTagView` is driven by two values you own. `text` is the string being edited. `isSelecting` turns the session on or off: set it to `true` and the toolbar appears, set it back to `false` to finish. The `$` in front of each hands them to the view so it can update them for you.

```swift
import SwiftUI
import TapTagKit

struct EditorView: View {
    @State private var text = "Try #swift and #swiftui"
    @State private var isSelecting = false

    var body: some View {
        VStack {
            TapTagView(text: $text, isSelecting: $isSelecting)

            Button(isSelecting ? "Done" : "Select hashtags") {
                isSelecting.toggle()
            }
        }
    }
}
```

Tapping the button flips `isSelecting`, which starts or ends the session. While it is on, tap hashtags to select them and use the toolbar; `text` always holds the current text.

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

## Layout

```text
Package.swift     ┐
Sources/          │  the package: what SPM builds and ships
Tests/            ┘

README.md         ┐
LICENSE           │  essential docs, kept at root by convention
CHANGELOG.md      ┘

.gitignore        ┐
.swiftlint.yml    ┘  tooling config

.github/          CI workflow, CONTRIBUTING, SECURITY, demo GIF
```

## License

MIT. See [LICENSE](LICENSE).
