# ``TapTagKit``

Tappable hashtags for any `UITextView`.

## Overview

`TapTextView` is a `UITextView` subclass with a selection mode: tap a hashtag
to highlight every occurrence, then act on the whole selection from a toolbar —
copy, cut, group at the top, deselect, or delete.

```swift
let textView = TapTextView()
textView.addTagSelectorToolBar(viewController: self)
navigationItem.rightBarButtonItem = textView.makeTapTextViewButton()
```

Strings, highlight color, placeholder, and accessibility labels are injectable
through ``TapTextView/Configuration``.

## Topics

### Essentials

- ``TapTextView``
- ``TapTextView/Configuration``
- ``TapTextViewDelegate``

### Selecting tags

- ``TapTextView/selectTag(_:)``
- ``TapTextView/deselectTag(_:)``
- ``TapTextView/clearSelection()``
- ``TapTextView/selectedTagsInOrder``
- ``TapTextView/isSelecting``
