import UIKit

/// The system side-effects ``TapTextView`` performs: haptic feedback and
/// VoiceOver announcements.
///
/// Injected (`textView.services = …`) so they can be faked in tests or
/// customized by callers — e.g. silencing haptics. Defaults to
/// ``LiveTapTextViewServices``.
public protocol TapTextViewServices: AnyObject {
    /// Warms up the haptic engine ahead of a tap.
    func prepareHaptics()
    /// Plays the per-tap selection haptic.
    func playSelectionHaptic()
    /// Posts a VoiceOver announcement.
    func announce(_ message: String)
}

/// Production services: the Taptic Engine and VoiceOver. Honors Reduce Motion
/// by skipping the haptic.
public final class LiveTapTextViewServices: TapTextViewServices {
    private let feedback = UIImpactFeedbackGenerator(style: .rigid)

    public init() {}

    public func prepareHaptics() {
        feedback.prepare()
    }

    public func playSelectionHaptic() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        feedback.impactOccurred()
        feedback.prepare()   // keep the Taptic Engine warm for the next tap
    }

    public func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
