# Changelog

All notable changes to TapTagKit are documented here.
This project adheres to [Semantic Versioning](https://semver.org).

## [3.2.0] — 2026-06-25

### Added
- **Per-tag VoiceOver:** while a session is active, each hashtag is exposed as
  its own VoiceOver button whose value reflects selection; activating it toggles
  the tag like a tap. The core tap-to-select is now operable without sight.

## [3.1.0] — 2026-06-25

### Added
- **Injectable services:** haptics and VoiceOver announcements now go through
  an injectable `TapTextViewServices` (`textView.services`), defaulting to
  `LiveTapTextViewServices`. Lets callers silence/customize haptics and lets
  tests assert them with a fake.

### Changed
- The default haptic now respects **Reduce Motion** (skipped when enabled).

## [3.0.0] — 2026-06-25

### Added
- **SwiftUI adapter:** `TapTagView` (`UIViewRepresentable`) with `text` /
  `isSelecting` bindings, backed by the same UIKit engine.
- **Built-in localization (English + French):** all labels, captions, and
  VoiceOver strings ship localized via the package bundle; still overridable
  per instance through `Configuration`.
- **Captioned action bar:** the bar is now a grouped, rounded card (`TagActionBar`,
  SwiftUI-hosted) whose buttons pair an icon with a small caption.
- **Delete confirmation:** tapping Delete asks for confirmation before removing
  the selected tags; Done finishes the session immediately.
- **Hashtag clean-up:** `cleanUpHashtags()` removes duplicate (case-insensitive)
  and invalid hashtags; runs automatically on `beginSelection()` unless
  `removesDuplicatesOnSelection` is set to `false`.

### Changed
- Captions shrink to fit longer locales (no truncation), and the text view is
  inset while the bar is shown so it never covers the last line.
- The bar's hosting controller is added to the view-controller tree so its
  confirmation alert presents reliably.
- Action labels are short captions that double as VoiceOver labels (one string
  per action in `Configuration.accessibility`).
- **Self-contained toolbar:** the selection actions now live in a `UIToolbar`
  the view shows/hides itself. `addTagSelectorToolBar(viewController:)` is gone
  and the delegate is no longer needed to reveal the bar — just
  `makeTapTextViewButton()` (or `beginSelection()`). The bar also got polish:
  destructive Delete in red, a prominent Done, and the highlight tint.
- Tightened the MVVM split: tag/text composition (grouping, the `#`-prefixed
  list) and the grouping session state now live in `TagSelectionViewModel`;
  the view only renders. Extracted view helpers and narrowed access control.

### Removed
- **Breaking:** the built-in placeholder, keyboard avoidance, and the info "?"
  button + alert — all the host app's concern. `Configuration` shrank to the
  highlight colors and accessibility strings.

## [2.0.0] — 2026-06-25

### Added
- Programmatic selection API: `selectTag(_:)`, `deselectTag(_:)`,
  `clearSelection()`, `selectedTagsInOrder`, and `isSelecting`.
- Programmatic action API: `copySelectedTags()`, `cutSelectedTags()`,
  `groupSelectedTags()`, `deleteSelectedTags()`.
- Programmatic session control: `beginSelection()` and `endSelection()`.
- `Configuration.selectedTagTextColor` for the highlighted text color.
- VoiceOver support: selection-change announcements and a selection hint.
- Public `makeToolbarItems()` so the actions can be placed anywhere.
- DocC catalog, a `CHANGELOG`, and a reproducible README demo GIF
  (`Scripts/record-gif.sh`).

### Changed
- **Breaking:** accessibility strings moved into `Configuration.accessibility`
  (e.g. `configuration.accessibility.selectButtonLabel`).
- Tapping captures the whole `#token` (e.g. `#c++`), not just the first word.
- Highlight and delete match tags as whole whitespace-delimited tokens.
- Compiled tag regexes are cached; the haptic generator is reused.

### Fixed
- Repeated grouping no longer fuses tags (`#y#x`).
- Caller-supplied text attributes (fonts, colors, links) survive highlighting.
- Keyboard-avoidance and placeholder observers are no longer duplicated.
- Tags ending in punctuation are highlighted and deleted correctly.

## [1.1.0]
- Built-in placeholder and keyboard avoidance.

## [1.0.0]
- Initial release: tappable hashtag selection for any `UITextView`.
