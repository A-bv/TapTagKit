# TapTagKit

**Hashtags you can actually tap.** A `UITextView` subclass that turns every `#tag` into a target: tap one to light up all its twins, then act on the whole set from a toolbar.

[![CI](https://github.com/A-bv/TapTagKit/actions/workflows/ci.yml/badge.svg)](https://github.com/A-bv/TapTagKit/actions/workflows/ci.yml)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)
![iOS 15+](https://img.shields.io/badge/iOS-15%2B-007AFF?logo=apple&logoColor=white)
![SPM](https://img.shields.io/badge/SPM-compatible-success)
![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey)

<p align="center">
  <img src="Assets/demo.gif" alt="Selecting #swift highlights every match, then groups the tags to the top" width="380">
</p>

## Install

Swift Package Manager:

```swift
.package(url: "https://github.com/A-bv/TapTagKit", from: "2.0.0")
```

## 60-second start

```swift
let textView = TapTextView()
navigationItem.rightBarButtonItem = textView.makeTapTextViewButton()
```

That's the whole setup. Tapping the button starts a session; the action toolbar
shows and hides itself — no navigation-controller wiring, no delegate dance. Or
drive it yourself with `beginSelection()` / `endSelection()`.

## What you get

- **One tap, every match** — selecting `#swift` highlights it everywhere at once.
- **Self-managing toolbar** — copy · cut · group-to-top · deselect · delete · done.
- **Drive it in code** — `selectTag`, `deselectTag`, `groupSelectedTags`, `selectedTagsInOrder`.
- **Yours to style** — highlight color and every VoiceOver string via `Configuration`.
- **Won't trample your text** — fonts, colors, and links survive highlighting; awkward tags like `#c++` are matched whole.

## Customize

```swift
var config = TapTextView.Configuration()
config.tagHighlightColor = .systemIndigo
config.accessibility.copyLabel = "Copier"   // localize any string
textView.configuration = config
```

## Under the hood

Selection state and all tag/text logic live in a UIKit-free `TagSelectionViewModel` (MVVM), so the rules are unit-tested without a single simulated view. History lives in the [CHANGELOG](CHANGELOG.md).

## Preview

Open `Sources/TapTagKit/Previews.swift` and switch on the canvas (**Editor › Canvas**) for a live, tappable demo. The animation above is reproducible — `Scripts/record-gif.sh` renders it to `Assets/demo.gif`.

## Requirements & license

iOS 15 · Swift 5.9 · [MIT](LICENSE).
