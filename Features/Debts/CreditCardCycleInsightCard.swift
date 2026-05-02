import SwiftUI

struct CreditCardCycleInsightCard: View {

    @EnvironmentObject private var settings: AppSettings

    let estimate: CreditCardCyclePaymentEstimate

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(spacing: 12) {
                amountBlock(
                    title: settings.language == .spanish ? "Gastado en ciclo" : "Cycle spending",
                    value: money(estimate.cycleExpensesTotal),
                    tint: BrandPalette.secondary
                )

                amountBlock(
                    title: settings.language == .spanish ? "Pago aprox." : "Est. payment",
                    value: money(estimate.estimatedTotalDue),
                    tint: BrandPalette.primary
                )
            }

            VStack(spacing: 8) {
                detailRow(
                    title: settings.language == .spanish ? "Base calculada" : "Calculated basis",
                    value: money(estimate.balanceBasis)
                )

                detailRow(
                    title: settings.language == .spanish ? "Mínimo principal" : "Principal minimum",
                    value: money(estimate.principalMinimumPayment)
                )

                detailRow(
                    title: settings.language == .spanish ? "Cuota de manejo" : "Management fee",
                    value: money(estimate.managementFee)
                )

                detailRow(
                    title: settings.language == .spanish ? "Gastos en ciclo" : "Cycle expenses",
                    value: "\(estimate.cycleExpenses.count)"
                )
            }
        }
        .padding(16)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.headline)
                .foregroundColor(BrandPalette.primary)
                .frame(width: 38, height: 38)
                .background(BrandPalette.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(settings.language == .spanish ? "Ciclo de tarjeta" : "Card cycle")
                    .font(.subheadline.bold())

                Text(cycleText)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(dueText)
                    .font(.caption.bold())
                    .foregroundColor(dueColor)
            }

            Spacer()
        }
    }

    private func amountBlock(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.caption.bold())
                .foregroundColor(.primary)
        }
    }

    private var cycleText: String {
        let start = shortDate(estimate.cycleStart)
        let end = shortDate(estimate.cycleEnd)

        if settings.language == .spanish {
            return "\(start) – \(end)"
        }

        return "\(start) – \(end)"
    }

    private var dueText: String {
        guard let dueDate = estimate.dueDate else {
            return settings.language == .spanish
            ? "Sin día de pago mínimo configurado"
            : "No minimum payment day configured"
        }

        let dateText = shortDate(dueDate)

        if estimate.isDueToday {
            return settings.language == .spanish
            ? "Vence hoy · \(dateText)"
            : "Due today · \(dateText)"
        }

        if estimate.isOverdue {
            return settings.language == .spanish
            ? "Vencido · \(dateText)"
            : "Overdue · \(dateText)"
        }

        if let days = estimate.daysUntilDue {
            return settings.language == .spanish
            ? "Vence en \(days) días · \(dateText)"
            : "Due in \(days) days · \(dateText)"
        }

        return dateText
    }

    private var dueColor: Color {
        if estimate.isOverdue {
            return .red
        }

        if estimate.isDueToday {
            return .orange
        }

        return BrandPalette.primary
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .day()
                .month(.abbreviated)
                .locale(settings.appLocale)
        )
    }

    private func money(_ amount: Double) -> String {
        settings.secureCurrency(amount, decimals: 2)
    }
}
