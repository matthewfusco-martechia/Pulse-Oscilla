import UIKit

@MainActor
final class HapticFeedback {
    static let shared = HapticFeedback()

    private init() {}

    func triggerImpactFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    func triggerNotificationFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    func triggerResponseStartedFeedback() {
        Task { @MainActor in
            triggerImpactFeedback(style: .light)
            try? await Task.sleep(for: .milliseconds(135))
            triggerImpactFeedback(style: .light)
            try? await Task.sleep(for: .milliseconds(55))
            triggerImpactFeedback(style: .medium)
        }
    }
}
