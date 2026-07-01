# TapTagKit — Portfolio-Grade Audit

> ## Second pass — 2026-07-01 (post-4.0.0)
>
> Re-audited after the F1–F8 fixes and the 4.0.0 release. Baseline re-verified:
> clean tree, **46 tests pass** (2 skipped), `swiftlint --strict` clean, DocC
> builds with `--warnings-as-errors`, CI green on all three jobs.
>
> **Verdict:** the substantive gaps are closed. What remains is one surface-level
> completeness item and a short list of taste/positioning notes. Checked and
> deliberately *not* flagged (no manufactured findings): the action-bar hosting
> has no retain cycle (handlers are `[weak self]`; `willMove(toWindow:nil)` tears
> it down); the Swift 6 concurrency is clean (the coordinator's `main.async`
> captures weakly and builds under complete checking); the tag-removal
> space-swallow handles space and newline adjacency correctly.
>
> ### F9 — DocC catalog curates only part of the public API
> **FOLLOW-UP** · [L2 · Correct→Showcase] · **Observed** ·
> `Sources/TapTagKit/TapTagKit.docc/TapTagKit.md`
>
> The Topics list omits the entire injectable-services API
> (``TapTextViewServices``, ``LiveTapTextViewServices``, ``TapTextView/services``)
> plus ``TapTextView/cleanUpHashtags()``, ``TapTextView/removesDuplicatesOnSelection``,
> and ``TapTextView/selectedTags``. These are public but uncurated — orphan pages,
> not part of the documented surface. _Fix direction:_ add topic groups for
> clean-up and for side-effect injection, and list the missing selection symbol;
> verify with `docbuild --warnings-as-errors`.
>
> ### Taste / positioning (DON'T-BLOCK — not in the fix queue)
> - **Single platform.** iOS-only; Mac Catalyst / visionOS would widen reach.
>   Positioning choice, not a defect.
> - **No code-coverage measurement** in CI. Tests are strong; there's just no
>   emitted number or badge to prove it.
> - **Tab-delimited tag removal** leaves a stray tab (only ASCII space is
>   swallowed). Exotic input; not worth special-casing.
> - Localization covers two languages (en/fr).
>
> **Fix queue (second pass):** F9 only. The rest is taste.
>
> ---
>
> _Original first-pass audit (all items resolved) follows._

---

_Staff-engineer audit. Audit only: no code was modified._
_Date: 2026-07-01 · Branch: `main` @ `142238d` · Working tree: clean_

## Resolution status — all findings closed (2026-07-01)

Worked top-down, one commit per finding, verified and pushed to `main`:

| Finding | Commit  | Summary                                             |
|---------|---------|-----------------------------------------------------|
| F1      | ce50580 | `chore: adopt Swift 6 language mode`                |
| F2      | 9f4d321 | `fix: host the action bar on its view controller`   |
| F5      | 051e2e8 | `ci: build documentation in CI`                     |
| F3      | f64b079 | `fix: don't clear the pasteboard on empty copy`     |
| F6      | 2a0f9ca | `docs: highlight accessibility and rich text`       |
| F4      | c86902a | `fix: match tags case-insensitively`                |
| F7      | 5993368 | `chore: enforce SwiftLint in CI`                    |
| F8      | d421c9b | `docs: add contributing and community files`        |

Notes: F5 was resolved in three parts (DocC done; lint step folded into F7;
old-OS simulator job declined — see the F5 section). The test suite grew from 42
to 46 passing (2 skipped) and stays green under the Swift 6 language mode.

## Ground truth (established, not assumed)

- **What it is:** a Swift Package Manager **library** — a `UITextView` subclass
  (`TapTextView`) that makes hashtags tappable, plus a SwiftUI adapter
  (`TapTagView`). ~1050 LOC of source, ~1020 LOC of tests across 6 test files.
- **Toolchain (declared):** `swift-tools-version: 5.9`, `platforms: [.iOS(.v15)]`,
  no external dependencies.
- **Toolchain (installed here):** Swift 6.3.2, Xcode 26.5.
- **Build:** `xcodebuild ... build` → **0 warnings, 0 errors** under the declared
  5.9 mode. (`swift build` fails natively with `no such module 'UIKit'` — expected
  for a UIKit lib; simulator is the correct target.) [Observed]
- **Tests:** `xcodebuild test` on iPhone 17 Pro → **42 executed, 0 failures, 2
  skipped**. The 2 skips are `XCTSkip`-gated GIF/snapshot rendering tooling
  (`GIF_OUTPUT_DIR`), not broken tests. [Observed]
- **Distribution integrity:** all 8 semver git tags (`1.0.0`…`3.3.0`) exist and
  resolve; `README` install `from: "3.0.0"` is satisfiable via SPM. CHANGELOG is
  dated and follows semver, with the tip-of-main change parked under
  `[Unreleased]`. [Observed]
- **Ignore hygiene:** `.DS_Store`, `.swiftpm/`, `xcuserdata/` exist on disk but
  are **not** tracked (`git ls-files` clean; 26 tracked files). [Observed]

---

## 1. Verdict

This is already a strong, coherent library — not a rough draft that needs
structural work. The L0 foundation is genuinely good: a UIKit-free
`TagSelectionViewModel` owns all tag/text logic and is tested in isolation, while
`TapTextView` is a thin renderer over it. Behavior (L1) is correct and covered:
whole-token regex matching, attributed-text preservation through group/delete/
clean-up, scroll preservation, and a real VoiceOver story (per-tag activatable
elements, priority announcements). Surface (L2) is documented (DocC + README),
localized (en/fr), and CI-gated on two simulators. **Nothing here is broken.**

The gap between this and a top-tier 2026 showcase is therefore not correctness —
it's **currency and edge-hardening**. The one substantive finding: the package
is not clean under Swift 6 language mode / complete strict concurrency (3 compile
errors when forced), which visibly dates it now that Swift 6 is the default
toolchain — even though it does not break consumers today. Everything else is
FOLLOW-UP or taste. Honestly assessed, this reads as senior work with a couple of
showcase-polish gaps, not a project with foundational debt.

---

## 2. Findings (deep → shallow)

### F1 — Not Swift 6 / strict-concurrency clean
**FOLLOW-UP** · [L1 · Correct→Senior] · **Observed**
`Sources/TapTagKit/TapTextViewServices.swift:20`, `Sources/TapTagKit/TapTagView.swift:53`

Forcing `SWIFT_VERSION=6 SWIFT_STRICT_CONCURRENCY=complete` produces 3 errors:
- `TapTagView.Coordinator`'s conformance to `TapTextViewDelegate` "crosses into
  main actor-isolated code and can cause data races."
- `LiveTapTextViewServices` — "main actor-isolated default value in a nonisolated
  context" (the `UIImpactFeedbackGenerator` stored property).

This does **not** break downstream consumers (a Swift-5-mode module imports fine
into a Swift 6 app; the UIView types are inferred `@MainActor` at the call site).
But for a portfolio piece and a dependency in 2026, shipping without Swift 6
readiness is the single most dating signal. Every type here is inherently
main-actor already, so the fix is annotation, not redesign.

_Fix direction:_ annotate `TapTextViewServices`/`LiveTapTextViewServices` and
`TapTagView.Coordinator` with `@MainActor`; bump to `swift-tools-version: 6.0`
and add `.enableUpcomingFeature` / `swiftLanguageModes: [.v6]` (or adopt
incrementally with `StrictConcurrency`), then confirm the suite still passes.

### F2 — Action bar is attached to the window, not the owning view
**FOLLOW-UP** · [L1 · Works→Correct] · **Inferred / Needs-verification**
`Sources/TapTagKit/TapTextView.swift:209` (`host = window ?? superview`)

`presentActionBar()` adds the bar as a subview of the **window** and pins it to
the window's `safeAreaLayoutGuide`, while its SwiftUI hosting controller is added
as a child of the nearest view controller (`owningViewController`). For the common
full-screen editor this works. But when the text view lives in a non-full-window
host — a `.sheet`/form-sheet, a split-view column, or a secondary scene — the bar
will pin to the **window** bottom rather than the presenting container, and the
view-hierarchy/controller-hierarchy split becomes fragile.

_Needs-verification:_ present `TapTextView` inside a `.pageSheet` at medium
detent and start a session — confirm whether the bar tracks the sheet or the
window. _Fix direction:_ prefer `owningViewController?.view` as the host and
constrain to that view's safe area; fall back to window only when no VC is found.

### F3 — Empty-selection copy/cut silently writes an empty string
**DON'T-BLOCK** · [L2 · Works→Senior] · **Observed**
`Sources/TapTagKit/TapTextView.swift:427`, `TagSelectionViewModel.swift:42`

`hashtagList` maps an empty `selectedTags` to `""`, so `copySelectedTags()` (and
therefore `cutSelectedTags()`) with nothing selected overwrites the system
pasteboard with an empty string. Minor API footgun — copy should be a no-op when
the selection is empty.

_Fix direction:_ `guard !viewModel.isEmpty else { return }` in `copySelectedTags()`.

### F4 — Case-insensitive clean-up vs. case-sensitive select/highlight
**DON'T-BLOCK** · [L2 · Works→Correct] · **Observed**
`TagSelectionViewModel.swift:190` (dedupe via `lowercased()`) vs `:218` (`tagRegex` case-sensitive)

Clean-up treats `#Sun`/`#sun` as duplicates, but selection and highlighting are
case-sensitive. With `removesDuplicatesOnSelection = false`, selecting `sun`
highlights `#sun` but not `#Sun`. Consistent in the default path (clean-up runs
first), so this only surfaces when the caller disables clean-up. Pick one policy
and document it.

### F5 — CI doesn't guard DocC, lint, or the minimum deployment target
**FOLLOW-UP** · [L2 · Correct→Senior] · **Observed** · `.github/workflows/ci.yml`

CI builds+tests on two `OS=latest` simulators (good baseline), but: it never
builds the DocC catalog (so doc breakage ships silently), runs no linter/formatter
check, and never exercises an iOS-15-era runtime — the `iOS 15+` claim is untested.

_Fix direction:_ add a `xcodebuild docbuild` step; add a lint step if F7 lands;
pin at least one destination to an older OS image if the runner offers one.

_Resolution (2026-07-01):_
- **DocC:** done — a `docs` CI job runs `xcodebuild docbuild` with
  `--warnings-as-errors`, so broken symbol links fail the build.
- **Lint:** deliberately deferred to **F7**, which adds the SwiftLint config the
  CI step depends on; the CI lint step lands in that commit.
- **Old-OS destination:** deliberately **declined**. macOS-15/26 runner images do
  not ship an iOS 15 simulator, so pinning `OS=15.x` would fail with
  "destination not found." The iOS 15 floor is already compiler-enforced at build
  time (any ungated iOS 16+ API breaks the existing build), so a runtime-only
  iOS 15 job is low-value and fragile — not worth adding.

### F6 — Accessibility & rich-text handling are under-marketed
**DON'T-BLOCK** · [L2 · Senior→Showcase] · **Observed** · `README.md`

The strongest engineering in this repo — per-tag VoiceOver buttons that activate
like taps, priority announcements, Reduce-Motion-aware haptics, attributed-text
preservation through every edit — is barely mentioned in the README (one line
under "Customize"). For a portfolio piece, the README undersells the best work.

_Fix direction:_ add a short "Accessibility" section and a one-liner that edits
preserve fonts/colors/links; these are differentiators, not footnotes.

### F7 — No enforced style config (SwiftLint / swift-format)
**DON'T-BLOCK (taste)** · [L3 · Senior→Showcase] · **Observed**

No `.swiftlint.yml` / `.swift-format`. The code is already consistent, so this is
signaling rigor for contributors rather than fixing a problem.

### F8 — Missing OSS project meta
**DON'T-BLOCK (taste)** · [L3] · **Observed**

No `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, or issue/PR templates.
Optional, but expected furniture for a repo meant to be depended on.

---

## Non-findings (checked, deliberately not flagged)

- iOS version gating is correct — `accessibilitySpeechAnnouncementPriority` is
  `#available(iOS 17)`-gated; `.ultraThinMaterial`/`UIHostingController` are 15-safe.
- Regex-metacharacter tags (`#c++`) are escaped and tested; whole-token boundaries
  (`#sun` ∌ `#sunny`) hold.
- Lifecycle: `willMove(toWindow: nil)` tears the bar down — no leak on discard.
- `attributedText`/`text` `didSet` re-entrancy is guarded by `isApplyingHighlight`.
- `.gitignore` correctly excludes `.DS_Store`/`.swiftpm`/`xcuserdata`; none tracked.

---

## 3. Ranked action list (fix queue — deepest gap first)

1. **F1** — Adopt Swift 6 / strict concurrency (annotate `@MainActor`, bump tools to 6.0). _Deepest, highest signal._
2. **F2** — Host the action bar on the owning VC's view, not the window; verify in a sheet.
3. **F5** — Add DocC build (and lint) to CI.
4. **F3** — No-op copy/cut on empty selection.
5. **F6** — Surface accessibility + rich-text preservation in the README.
6. **F4** — Reconcile case sensitivity between clean-up and selection; document the policy.
7. **F7 / F8** — Add lint/format config and OSS meta files. _Polish last._

---

## 4. Single highest-leverage change right now

**Make the package Swift 6 / strict-concurrency clean (F1).** It's the one change
that materially moves the "is this current, senior work?" needle for a 2026
showcase, it's what a discerning reviewer will check first, and — because every
type is already main-actor in practice — it's a few annotations plus a tools bump,
not a redesign. Everything else is edges and polish on an already-solid base.

## 5. Showcase readiness

**Reads as portfolio-grade already:**
- Clean L0 separation (UIKit-free, unit-tested view model) with a genuinely thin view layer.
- Real, tested accessibility — not the usual afterthought.
- Rich-text-preserving edits, cached regexes, injected side-effects for testability.
- 42 focused tests, 0 warnings, dated CHANGELOG, DocC, en/fr localization, green CI, correct semver tags.

**Top 3 gaps blocking top-tier:**
1. Not Swift 6 / strict-concurrency clean (F1).
2. Action-bar hosting is window-bound and untested outside full-screen (F2).
3. The best work (a11y, rich-text) is under-told in the README (F6).
