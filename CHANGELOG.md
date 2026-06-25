# Changelog

All notable changes to TapTagKit are documented here.
This project adheres to [Semantic Versioning](https://semver.org).

## [2.0.0] — Unreleased

### Added
- Programmatic selection API: `selectTag(_:)`, `deselectTag(_:)`,
  `clearSelection()`, `selectedTagsInOrder`, and `isSelecting`.
- VoiceOver support: selection-change announcements and a selection hint.
- Public `makeToolbarItems()` so the actions can be placed anywhere.
- DocC catalog and a `CHANGELOG`.

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
