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

/// Production services: the Taptic Engine and VoiceOver.
public final class LiveTapTextViewServices: TapTextViewServices {
    private let feedback = UIImpactFeedbackGenerator(style: .rigid)

    public init() {}

    public func prepareHaptics() {
        feedback.prepare()
    }

    public func playSelectionHaptic() {
        feedback.impactOccurred()
        feedback.prepare()   // keep the Taptic Engine warm for the next tap
    }

    public func announce(_ message: String) {
        // High priority so a quick run of tag toggles doesn't drop announcements
        // (a default-priority one is discarded if another arrives mid-utterance).
        if #available(iOS 17.0, *) {
            let announcement = NSAttributedString(
                string: message,
                attributes: [.accessibilitySpeechAnnouncementPriority: UIAccessibilityPriority.high]
            )
            UIAccessibility.post(notification: .announcement, argument: announcement)
        } else {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}
