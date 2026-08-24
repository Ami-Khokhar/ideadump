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
            uiView.text = text
        }
        uiView.placeholder = placeholder
        uiView.font = .monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)
        uiView.minimumFontSize = minimumFontSize
        uiView.textColor = textColor
        uiView.tintColor = tintColor
        uiView.accessibilityLabel = "Amount"
        uiView.accessibilityValue = text.isEmpty ? "No amount" : text

        if isFocused.wrappedValue, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused.wrappedValue, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AmountTextField

        init(parent: AmountTextField) {
            self.parent = parent
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.isFocused.wrappedValue = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
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

            // We apply every result ourselves so rejected pastes can stay visible
            // while typed overflow is restored to the prior value.
            textField.text = result.text
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
