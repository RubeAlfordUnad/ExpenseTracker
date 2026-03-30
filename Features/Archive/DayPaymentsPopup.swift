import SwiftUI

struct DayPaymentsPopup: View {

    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    var day: Int
    var payments: [RecurringPayment]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(settings.language == .spanish ? "Pagos del día \(day)" : "Payments for day \(day)")
                    .font(.title3.bold())

                if payments.isEmpty {
                    Text(settings.language == .spanish ? "No hay pagos programados" : "No scheduled payments")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(payments) { payment in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(payment.title)
                                    .font(.headline)

                                Text(payment.category.displayName(language: settings.language))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(settings.formatCurrency(payment.amount, decimals: 2))
                                .font(.headline)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle(settings.language == .spanish ? "Detalle" : "Details")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.language == .spanish ? "Cerrar" : "Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
