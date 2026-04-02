import SwiftUI

struct BudgetEditSheetView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    @State private var budgetInput: String

    let onSave: (String) -> Void

    init(initialValue: String, onSave: @escaping (String) -> Void) {
        _budgetInput = State(initialValue: initialValue)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(settings.t("main.editBudgetMessage"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text(settings.t("main.editBudgetPlaceholder"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    MoneyTextField(
                        title: settings.t("main.editBudgetPlaceholder"),
                        text: $budgetInput,
                        accessibilityIdentifier: "main.budgetInput"
                    )
                    .frame(height: 44)
                    .padding(.horizontal, 14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle(settings.t("main.editBudgetTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(settings.t("common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.t("common.save")) {
                        onSave(budgetInput)
                    }
                    .accessibilityIdentifier("main.budgetSave")
                }
            }
        }
    }
}
