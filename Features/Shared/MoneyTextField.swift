import SwiftUI
import UIKit

struct MoneyTextField: UIViewRepresentable {

    @EnvironmentObject private var settings: AppSettings

    let title: String
    @Binding var text: String
    let accessibilityIdentifier: String
    var maximumFractionDigits: Int = 2

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.placeholder = title
        textField.keyboardType = .decimalPad
        textField.borderStyle = .none
        textField.clearButtonMode = .never
        textField.textAlignment = .natural
        textField.accessibilityIdentifier = accessibilityIdentifier

        let displayText = MoneyInputFormatter.formatRawForDisplay(
            text,
            locale: settings.appLocale,
            maximumFractionDigits: maximumFractionDigits
        )
        textField.text = displayText

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.locale = settings.appLocale

        uiView.placeholder = title
        uiView.accessibilityIdentifier = accessibilityIdentifier

        let displayText = MoneyInputFormatter.formatRawForDisplay(
            text,
            locale: settings.appLocale,
            maximumFractionDigits: maximumFractionDigits
        )

        if !uiView.isFirstResponder, uiView.text != displayText {
            uiView.text = displayText
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, locale: settings.appLocale)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {

        var parent: MoneyTextField
        var locale: Locale

        init(parent: MoneyTextField, locale: Locale) {
            self.parent = parent
            self.locale = locale
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let currentDisplayText = textField.text ?? ""

            guard let swiftRange = Range(range, in: currentDisplayText) else {
                return false
            }

            let updatedDisplayText = currentDisplayText.replacingCharacters(
                in: swiftRange,
                with: string
            )

            applyFormatting(to: textField, displayText: updatedDisplayText)
            return false
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            applyFormatting(to: textField, displayText: textField.text ?? "")
        }

        private func applyFormatting(to textField: UITextField, displayText: String) {
            let rawValue = MoneyInputFormatter.sanitizeInput(
                displayText,
                locale: locale,
                maximumFractionDigits: parent.maximumFractionDigits
            )

            let formattedDisplay = MoneyInputFormatter.formatRawForDisplay(
                rawValue,
                locale: locale,
                maximumFractionDigits: parent.maximumFractionDigits
            )

            textField.text = formattedDisplay

            if parent.text != rawValue {
                parent.text = rawValue
            }

            moveCursorToEnd(in: textField)
        }

        private func moveCursorToEnd(in textField: UITextField) {
            let endPosition = textField.endOfDocument
            if let range = textField.textRange(from: endPosition, to: endPosition) {
                textField.selectedTextRange = range
            }
        }
    }
}
