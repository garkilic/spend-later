import SwiftUI
import UIKit

struct CurrencyTextField: UIViewRepresentable {
    @Binding var value: Decimal
    var placeholder: String

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.keyboardType = .decimalPad
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        textField.textAlignment = .left
        textField.font = UIFont.preferredFont(forTextStyle: .title3)
        textField.adjustsFontForContentSizeCategory = true
        textField.text = context.coordinator.format(value)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        let formatted = context.coordinator.format(value)
        if uiView.text != formatted {
            uiView.text = formatted
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        private let value: Binding<Decimal>
        private let formatter: NumberFormatter
        private let decimalSeparator: String

        init(value: Binding<Decimal>) {
            self.value = value
            self.formatter = CurrencyFormatter.usdFormatter
            self.decimalSeparator = Locale(identifier: "en_US").decimalSeparator ?? "."
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard let current = textField.text as NSString? else { return true }
            if string.rangeOfCharacter(from: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".")).inverted) != nil {
                return false
            }
            let updated = current.replacingCharacters(in: range, with: string)
            let sanitized = updated.replacingOccurrences(of: ",", with: decimalSeparator)
            if sanitized.components(separatedBy: decimalSeparator).count > 2 {
                return false
            }
            if sanitized.isEmpty {
                value.wrappedValue = .zero
                textField.text = ""
                return false
            }
            if let decimal = Decimal(string: sanitized, locale: Locale(identifier: "en_US")) {
                value.wrappedValue = decimal
                textField.text = format(value.wrappedValue)
            }
            return false
        }

        func format(_ decimal: Decimal) -> String {
            CurrencyFormatter.string(from: decimal)
        }
    }
}
