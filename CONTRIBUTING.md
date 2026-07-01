# Contributing to TapTagKit

Thanks for your interest in improving TapTagKit. This is a small, focused
library — contributions that keep it that way are very welcome.

## Getting started

TapTagKit is a Swift package with no dependencies. It targets iOS, so build and
test through a simulator (a native `swift build` fails with `no such module
'UIKit'`).

```bash
# Build and test
xcodebuild test \
  -scheme TapTagKit \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Lint (matches CI)
swiftlint lint --strict

# Build the documentation
xcodebuild docbuild \
  -scheme TapTagKit \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Requires the Swift 6.0 toolchain (Xcode 16 or later). The runtime deployment
target is iOS 15.

## Guidelines

- **Keep the core UIKit-free.** All tag and text logic lives in
  `TagSelectionViewModel`, which imports no UIKit and is unit-tested in
  isolation. Put new logic there and let `TapTextView` render it.
- **Add tests.** New behavior should come with tests; the suite is fast.
- **Match the surrounding style.** CI runs SwiftLint in strict mode.
- **Update the CHANGELOG.** Add a note under `## [Unreleased]`.
- **Localize new strings** in both English and French
  (`Sources/TapTagKit/Resources`).

## Pull requests

Keep pull requests focused and describe the user-visible change. CI must be
green: build and test on two simulators, lint, and the documentation build.
