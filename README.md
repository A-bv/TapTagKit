# TapTagKit

**Hashtags you can actually tap.** A `UITextView` subclass that turns every `#tag` into a target: tap one to light up all its twins, then act on the whole set from a toolbar.

[![CI](https://github.com/A-bv/TapTagKit/actions/workflows/ci.yml/badge.svg)](https://github.com/A-bv/TapTagKit/actions/workflows/ci.yml)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)
![iOS 15+](https://img.shields.io/badge/iOS-15%2B-007AFF?logo=apple&logoColor=white)
![SPM](https://img.shields.io/badge/SPM-compatible-success)
![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey)

## Install

Swift Package Manager:

```swift
.package(url: "https://github.com/A-bv/TapTagKit", from: "2.0.0")
```

## 60-second start

```swift
let textView = TapTextView()
textView.addTagSelectorToolBar(viewController: self)                 // the actions toolbar
navigationItem.rightBarButtonItem = textView.makeTapTextViewButton() // enters selection mode
```

Reveal the toolbar only while a session is live:

```swift
extension MyViewController: TapTextViewDelegate {
    func tapTextViewDidStartSelection(_ tv: TapTextView) { navigationController?.setToolbarHidden(false, animated: true) }
    func tapTextViewDidFinishSelection(_ tv: TapTextView) { navigationController?.setToolbarHidden(true, animated: true) }
}
```

## What you get

- **One tap, every match** — selecting `#swift` highlights it everywhere at once.
- **Batch toolbar** — copy · cut · group-to-top · deselect · delete.
- **Drive it in code** — `selectTag`, `deselectTag`, `clearSelection`, `selectedTagsInOrder`.
- **Yours to style** — highlight color, placeholder, keyboard avoidance, and every VoiceOver string, all via `Configuration`.
- **Won't trample your text** — fonts, colors, and links survive highlighting; awkward tags like `#c++` are matched whole.

## Customize

```swift
var config = TapTextView.Configuration()
config.tagHighlightColor = .systemIndigo
config.placeholder = "Add some #tags…"
config.accessibility.copyLabel = "Copier"   // localize any string
textView.configuration = config
```

## Under the hood

Selection state and all tag/text logic live in a UIKit-free `TagSelectionViewModel` (MVVM), so the rules are unit-tested without a single simulated view. History lives in the [CHANGELOG](CHANGELOG.md).

## Preview

Open `Sources/TapTagKit/Previews.swift` and switch on the canvas (**Editor › Canvas**) for a live, tappable demo.

## Requirements & license

iOS 15 · Swift 5.9 · [MIT](LICENSE).
