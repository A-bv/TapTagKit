#!/usr/bin/env bash
#
# Renders the README demo GIF by running ReadmeGIFTests on a simulator.
# The test is skipped during normal `swift test` / CI; this script opts in by
# passing GIF_OUTPUT_DIR through to the test runner.
#
# Usage:
#   Scripts/record-gif.sh [output_dir]
#   SIMULATOR_DEST='platform=iOS Simulator,name=iPhone 16' Scripts/record-gif.sh
#
set -euo pipefail

OUT_DIR="${1:-$PWD/Assets}"
DEST="${SIMULATOR_DEST:-platform=iOS Simulator,name=iPhone 17 Pro}"

mkdir -p "$OUT_DIR"

# TEST_RUNNER_-prefixed env vars are forwarded (prefix stripped) to the test process.
TEST_RUNNER_GIF_OUTPUT_DIR="$OUT_DIR" \
xcodebuild test \
  -scheme TapTagKit \
  -destination "$DEST" \
  -only-testing:TapTagKitTests/ReadmeGIFTests/testRenderReadmeGIF \
  -only-testing:TapTagKitTests/ActionBarSnapshotTests/testRenderActionBar \
  CODE_SIGNING_ALLOWED=NO

echo "✅ Wrote $OUT_DIR/demo.gif and $OUT_DIR/action-bar.png"
