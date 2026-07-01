# ``TapTagKit``

Tappable hashtags for any `UITextView`.

## Overview

`TapTextView` is a `UITextView` subclass with a selection mode: tap a hashtag
to highlight every occurrence, then act on the whole selection from a toolbar —
copy, cut, group at the top, deselect, or delete.

```swift
let textView = TapTextView()
navigationItem.rightBarButtonItem = textView.makeTapTextViewButton()
```

That's it — the action toolbar appears and hides itself for the session. The
highlight color and accessibility labels are injectable through
``TapTextView/Configuration``.

## Topics

### Essentials

- ``TapTextView``
- ``TapTagView``
- ``TapTextView/Configuration``
- ``TapTextViewDelegate``

### Sessions

- ``TapTextView/makeTapTextViewButton()``
- ``TapTextView/beginSelection()``
- ``TapTextView/endSelection()``

### Selecting tags

- ``TapTextView/selectTag(_:)``
- ``TapTextView/deselectTag(_:)``
- ``TapTextView/clearSelection()``
- ``TapTextView/selectedTags``
- ``TapTextView/selectedTagsInOrder``
- ``TapTextView/isSelecting``

### Acting on the selection

- ``TapTextView/copySelectedTags()``
- ``TapTextView/cutSelectedTags()``
- ``TapTextView/groupSelectedTags()``
- ``TapTextView/deleteSelectedTags()``

### Cleaning up hashtags

- ``TapTextView/cleanUpHashtags()``
- ``TapTextView/cleanedHashtags(in:)``

### Customizing side effects

- ``TapTextView/services``
- ``TapTextViewServices``
- ``LiveTapTextViewServices``
