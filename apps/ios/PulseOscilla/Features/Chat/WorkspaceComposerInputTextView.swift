import SwiftUI
import UIKit

struct WorkspaceComposerInputTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat

    var isFocused: FocusState<Bool>.Binding
    let placeholder: String
    let onSubmit: () -> Void

    private let minHeight: CGFloat = 44
    private let maxHeight: CGFloat = 132

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textColor = UIColor.label
        textView.tintColor = UIColor.label
        textView.font = AppFont.uiFont(size: 15, textStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 10, right: 12)
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.keyboardDismissMode = .interactive
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.textContentType = nil
        if #available(iOS 17.0, *) {
            textView.inlinePredictionType = .no
        }
        textView.keyboardType = .asciiCapable
        textView.returnKeyType = .default
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        context.coordinator.placeholderLabel.text = placeholder
        context.coordinator.placeholderLabel.font = textView.font
        context.coordinator.placeholderLabel.textColor = UIColor.placeholderText
        context.coordinator.placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(context.coordinator.placeholderLabel)
        NSLayoutConstraint.activate([
            context.coordinator.placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 12),
            context.coordinator.placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -12),
            context.coordinator.placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 12)
        ])

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self

        if textView.text != text {
            textView.text = text
        }
        if textView.font != AppFont.uiFont(size: 15, textStyle: .body) {
            textView.font = AppFont.uiFont(size: 15, textStyle: .body)
        }

        context.coordinator.placeholderLabel.isHidden = !text.isEmpty

        context.coordinator.reconcileFocus(for: textView, shouldFocus: isFocused.wrappedValue)

        context.coordinator.recalculateHeight(for: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: WorkspaceComposerInputTextView
        let placeholderLabel = UILabel()
        private var userIsEditing = false
        private var pendingFocusRequest: Bool?

        init(parent: WorkspaceComposerInputTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            userIsEditing = true
            DispatchQueue.main.async {
                self.parent.isFocused.wrappedValue = true
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            userIsEditing = false
            DispatchQueue.main.async {
                self.parent.isFocused.wrappedValue = false
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            placeholderLabel.isHidden = !textView.text.isEmpty
            recalculateHeight(for: textView)
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText replacement: String
        ) -> Bool {
            guard replacement == "\n",
                  textView.text.trimmingCharacters(in: .whitespacesAndNewlines).contains("\n") == false,
                  !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return true
            }

            parent.onSubmit()
            return false
        }

        func recalculateHeight(for textView: UITextView) {
            let fittingWidth = max(textView.bounds.width, 1)
            let fittingSize = CGSize(width: fittingWidth, height: .greatestFiniteMagnitude)
            let rawHeight = textView.sizeThatFits(fittingSize).height
            let clamped = min(max(rawHeight, parent.minHeight), parent.maxHeight)
            let shouldScroll = rawHeight > parent.maxHeight

            if abs(parent.measuredHeight - clamped) > 0.5 {
                DispatchQueue.main.async {
                    self.parent.measuredHeight = clamped
                }
            }

            if textView.isScrollEnabled != shouldScroll {
                textView.isScrollEnabled = shouldScroll
            }
        }

        func reconcileFocus(for textView: UITextView, shouldFocus: Bool) {
            let effectiveShouldFocus = shouldFocus || userIsEditing

            if effectiveShouldFocus, !textView.isFirstResponder {
                requestFocus(true, textView: textView)
            } else if !effectiveShouldFocus, textView.isFirstResponder {
                requestFocus(false, textView: textView)
            }
        }

        private func requestFocus(_ shouldFocus: Bool, textView: UITextView) {
            guard pendingFocusRequest != shouldFocus else { return }
            pendingFocusRequest = shouldFocus

            DispatchQueue.main.async {
                self.pendingFocusRequest = nil
                guard textView.window != nil else { return }

                if shouldFocus {
                    if !textView.isFirstResponder {
                        textView.becomeFirstResponder()
                    }
                } else if !self.userIsEditing, textView.isFirstResponder {
                    textView.resignFirstResponder()
                }
            }
        }
    }
}
