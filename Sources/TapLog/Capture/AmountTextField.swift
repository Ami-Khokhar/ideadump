import SwiftUI
import UIKit

/// An amount field that gives the validator the actual edit range and
/// replacement string. SwiftUI's `onChange` only exposes before/after text and
/// cannot reliably tell a paste from a one-character selection replacement.
struct AmountTextField: UIViewRepresentable {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var placeholder: String = "0"
    var fontSize: CGFloat
    var minimumFontSize: CGFloat = AmountFont.minFontSize
    var textColor: UIColor = .label
    var tintColor: UIColor = .systemBlue
    var onErrorChanged: (String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.text = text
        field.placeholder = placeholder
        field.keyboardType = .decimalPad
        field.textAlignment = .left
        field.font = .monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)
        field.textColor = textColor
        field.tintColor = tintColor
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = minimumFontSize
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.accessibilityLabel = "Amount"
        field.accessibilityValue = text.isEmpty ? "No amount" : text
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            context.coordinator.applyExternalText(text, to: uiView)
        }
        // Assign only what actually changed. Rewriting properties on a focused
        // field on every keystroke dirties the view and can bounce focus.
        if uiView.placeholder != placeholder {
            uiView.placeholder = placeholder
        }
        let font = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)
        if uiView.font != font {
            uiView.font = font
        }
        if uiView.minimumFontSize != minimumFontSize {
            uiView.minimumFontSize = minimumFontSize
        }
        if uiView.textColor != textColor {
            uiView.textColor = textColor
        }
        if uiView.tintColor != tintColor {
            uiView.tintColor = tintColor
        }
        let accessibilityValue = text.isEmpty ? "No amount" : text
        if uiView.accessibilityValue != accessibilityValue {
            uiView.accessibilityValue = accessibilityValue
        }

        context.coordinator.syncFocus(with: uiView, shouldBeFocused: isFocused.wrappedValue)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AmountTextField
        private var isApplyingProgrammaticText = false
        private var pendingNativeResult: AmountEditResult?
        private var pendingFocusRequest: Bool?

        init(parent: AmountTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ textField: UITextField) {
            guard !isApplyingProgrammaticText else { return }

            let currentText = textField.text ?? ""
            parent.text = currentText
            parent.onErrorChanged(validationResult(for: currentText).error)
            textField.accessibilityValue = currentText.isEmpty ? "No amount" : currentText
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            guard !parent.isFocused.wrappedValue else { return }
            parent.isFocused.wrappedValue = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            guard parent.isFocused.wrappedValue else { return }
            parent.isFocused.wrappedValue = false
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let current = textField.text ?? ""
            let originalSelection = selectedRange(in: textField)
            let result = AmountInputFilter.filterEdit(
                current: current,
                range: range,
                replacement: string
            )
            if Self.shouldApplyEditNatively(
                current: current,
                editRange: range,
                replacement: string,
                result: result
            ) {
                pendingNativeResult = result
                return true
            }

            // We apply every result ourselves so rejected pastes can stay visible
            // while typed overflow is restored to the prior value.
            applyProgrammaticText(result.text, to: textField)
            let selection = Self.selectionAfterEdit(
                current: current,
                originalSelection: originalSelection,
                editRange: range,
                replacement: string,
                result: result
            )
            setSelection(selection, in: textField)
            parent.text = result.text
            parent.onErrorChanged(result.error)
            return false
        }

        static func shouldApplyEditNatively(
            current: String,
            editRange: NSRange,
            replacement: String,
            result: AmountEditResult
        ) -> Bool {
            guard !result.restoresPrevious else { return false }
            let candidate = (current as NSString).replacingCharacters(in: editRange, with: replacement)
            return candidate == result.text
        }

        static func selectionAfterEdit(
            current: String,
            originalSelection: NSRange?,
            editRange: NSRange,
            replacement: String,
            result: AmountEditResult
        ) -> NSRange? {
            if result.restoresPrevious {
                return originalSelection
            }

            let candidate = (current as NSString).replacingCharacters(in: editRange, with: replacement)
            let rawCaret = min(candidate.utf16.count, max(0, editRange.location) + replacement.utf16.count)
            let candidatePrefix = (candidate as NSString).substring(with: NSRange(location: 0, length: rawCaret))
            let resultUnits = Array(result.text.utf16)
            var matched = 0
            for unit in candidatePrefix.utf16 where matched < resultUnits.count {
                if unit == resultUnits[matched] { matched += 1 }
            }
            let caret = min(result.text.utf16.count, matched)
            return NSRange(location: caret, length: 0)
        }

        func applyExternalText(_ text: String, to textField: UITextField) {
            applyProgrammaticText(text, to: textField)
        }

        /// Acquisition-only focus sync. SwiftUI's focus system does not own
        /// this UITextField, so it can clobber a manually-mirrored binding back
        /// to `false` during the very update pass the mirror triggered; acting
        /// on that stale `false` here is what resigned the field right after
        /// the first accepted edit. Resignation is therefore left to UIKit —
        /// focusing another field auto-resigns this one, and the delegate
        /// mirrors the change back into the binding.
        func syncFocus(with textField: UITextField, shouldBeFocused: Bool) {
            guard shouldBeFocused, !textField.isFirstResponder else { return }

            if textField.window == nil {
                // Not yet in a window — retry once outside the current
                // transaction; UIKit drops first-responder claims until then.
                guard pendingFocusRequest != true else { return }
                pendingFocusRequest = true
                DispatchQueue.main.async { [weak self, weak textField] in
                    guard let self, let textField else { return }
                    self.pendingFocusRequest = nil
                    guard !textField.isFirstResponder else { return }
                    textField.becomeFirstResponder()
                }
            } else {
                textField.becomeFirstResponder()
            }
        }

        private func applyProgrammaticText(_ text: String, to textField: UITextField) {
            isApplyingProgrammaticText = true
            textField.text = text
            textField.accessibilityValue = text.isEmpty ? "No amount" : text
            isApplyingProgrammaticText = false
        }

        private func validationResult(for text: String) -> AmountEditResult {
            if let pendingNativeResult, pendingNativeResult.text == text {
                self.pendingNativeResult = nil
                return pendingNativeResult
            }

            return AmountInputFilter.filterEdit(
                current: "",
                range: NSRange(location: 0, length: 0),
                replacement: text
            )
        }

        private func selectedRange(in textField: UITextField) -> NSRange? {
            guard let selectedTextRange = textField.selectedTextRange else { return nil }
            let location = textField.offset(
                from: textField.beginningOfDocument,
                to: selectedTextRange.start
            )
            let end = textField.offset(
                from: textField.beginningOfDocument,
                to: selectedTextRange.end
            )
            return NSRange(location: location, length: end - location)
        }

        private func setSelection(_ range: NSRange?, in textField: UITextField) {
            guard let range else { return }
            let textLength = (textField.text ?? "").utf16.count
            let location = min(max(0, range.location), textLength)
            let length = min(max(0, range.length), textLength - location)
            guard let start = textField.position(from: textField.beginningOfDocument, offset: location),
                  let end = textField.position(from: start, offset: length) else { return }
            textField.selectedTextRange = textField.textRange(from: start, to: end)
        }
    }
}
