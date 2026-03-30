import SwiftUI

struct AddPaymentView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings

    @Binding var debt: Debt
    @State private var payment = ""
    @State private var showValidationAlert = false

    private var validationError: FormValidationError? {
        FormValidator.validateDebtPayment(
            payment: payment,
            remainingDebt: debt.remainingDebt
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Text("\(settings.t("debts.balancePending")): \(settings.formatCurrency(debt.remainingDebt, decimals: 2))")
                    .fontWeight(.semibold)

                TextField(settings.t("debts.paymentAmount"), text: $payment)
                    .keyboardType(.decimalPad)

                if let validationError {
                    Section {
                        Text(validationError.message(language: settings.language))
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(settings.t("debts.registerPayment"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(settings.t("common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.t("debts.apply")) {
                        applyPayment()
                    }
                    .disabled(validationError != nil)
                }
            }
            .alert(
                validationError?.title(language: settings.language) ?? "",
                isPresented: $showValidationAlert
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationError?.message(language: settings.language) ?? "")
            }
        }
    }

    private func applyPayment() {
        guard validationError == nil else {
            showValidationAlert = true
            return
        }

        guard let value = FormValidator.normalizedPositiveAmount(from: payment) else {
            showValidationAlert = true
            return
        }

        debt.remainingDebt = max(debt.remainingDebt - value, 0)
        dismiss()
    }
}
