import SwiftUI

struct DebtCard: View {

    @EnvironmentObject var settings: AppSettings
    @Binding var debt: Debt

    @State private var showPayment = false

    let moneyAccounts: [MoneyAccount]
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onRegisterExpense: () -> Void
    let onRegisterPayment: (Double, UUID) -> Void
    let onMarkDebtAsPaid: (Debt) -> Void

    private var utilizationColor: Color {
        if debt.isPaid { return .green }
        if debt.isLoan { return debt.progress >= 1 ? .green : BrandPalette.secondary }
        if debt.utilization >= 0.85 { return .red }
        if debt.utilization >= 0.60 { return BrandPalette.secondary }
        return BrandPalette.primary
    }

    private var brandAccent: Color {
        if debt.isPaid { return .green }
        if debt.isLoan { return .orange }

        switch debt.brand {
        case .visa:
            return BrandPalette.primary
        case .mastercard:
            return BrandPalette.secondary
        case .amex:
            return .green
        case .other:
            return BrandPalette.primary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if debt.isLoan {
                loanSummary
                loanProgress
            } else {
                cardSummary
                cardProgress
                cardPaymentEstimate
            }

            if debt.isActive {
                actions
            } else {
                paidBadge
            }
        }
        .padding(18)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .sheet(isPresented: $showPayment) {
            AddPaymentView(
                debt: $debt,
                moneyAccounts: moneyAccounts,
                onApplyPayment: onRegisterPayment,
                onMarkDebtAsPaid: onMarkDebtAsPaid
            )
            .environmentObject(settings)
        }
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: [
                BrandPalette.surface,
                brandAccent.opacity(0.08),
                BrandPalette.surfaceRaised
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: debt.isLoan ? debt.kind.icon : debt.brand.systemImageName)
                    .font(.headline)
                    .foregroundColor(brandAccent)
                    .frame(width: 42, height: 42)
                    .background(brandAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(debt.cardName)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Text(statusPillText)
                    .font(.caption.bold())
                    .foregroundColor(utilizationColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(utilizationColor.opacity(0.12))
                    .clipShape(Capsule())

                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label(
                            settings.language == .spanish ? "Editar deuda" : "Edit debt",
                            systemImage: "square.and.pencil"
                        )
                    }

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label(
                            settings.language == .spanish ? "Eliminar" : "Delete",
                            systemImage: "trash"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 34, height: 34)
                }
            }
        }
    }

    private var cardSummary: some View {
        HStack(spacing: 12) {
            amountBlock(
                title: settings.language == .spanish ? "Deuda actual" : "Current debt",
                value: money(debt.remainingDebt),
                tint: .red
            )

            amountBlock(
                title: settings.language == .spanish ? "Disponible" : "Available",
                value: money(debt.availableCredit),
                tint: BrandPalette.primary
            )
        }
    }

    private var loanSummary: some View {
        HStack(spacing: 12) {
            amountBlock(
                title: settings.language == .spanish ? "Pagado" : "Paid",
                value: money(debt.paidAmount),
                tint: .green
            )

            amountBlock(
                title: settings.language == .spanish ? "Falta" : "Remaining",
                value: money(debt.remainingDebt),
                tint: .red
            )
        }
    }

    private var cardProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(settings.language == .spanish ? "Uso del cupo" : "Credit usage")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(
                    settings.language == .spanish
                    ? "\(debt.utilizationPercentage)% usado"
                    : "\(debt.utilizationPercentage)% used"
                )
                .font(.caption.bold())
                .foregroundColor(utilizationColor)
            }

            ProgressView(value: debt.utilization)
                .tint(utilizationColor)

            HStack {
                Text(settings.language == .spanish ? "Cupo total" : "Total limit")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(money(debt.totalLimit))
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }

    private var loanProgress: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(settings.language == .spanish ? "Avance del préstamo" : "Loan progress")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(debt.progressPercentage)%")
                    .font(.caption.bold())
                    .foregroundColor(utilizationColor)
            }

            ProgressView(value: debt.progress)
                .tint(utilizationColor)

            VStack(spacing: 8) {
                infoRow(
                    title: settings.language == .spanish ? "Cuotas" : "Installments",
                    value: installmentText
                )

                if let monthlyPayment = debt.monthlyPayment {
                    infoRow(
                        title: settings.language == .spanish ? "Cuota mensual" : "Monthly payment",
                        value: money(monthlyPayment)
                    )
                }

                if let firstPaymentDate = debt.firstPaymentDate {
                    infoRow(
                        title: settings.language == .spanish ? "Primer pago" : "First payment",
                        value: firstPaymentDate.formatted(date: .abbreviated, time: .omitted)
                    )
                }
            }
        }
    }

    private var cardPaymentEstimate: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                amountBlock(
                    title: settings.language == .spanish ? "Mínimo aprox." : "Approx. minimum",
                    value: money(debt.estimatedMinimumPayment),
                    tint: BrandPalette.secondary
                )

                amountBlock(
                    title: settings.language == .spanish ? "Con manejo" : "With fee",
                    value: money(debt.estimatedMonthlyCardPayment),
                    tint: .orange
                )
            }

            VStack(spacing: 8) {
                if let closingDay = debt.statementClosingDay {
                    infoRow(
                        title: settings.language == .spanish ? "Día de corte" : "Closing day",
                        value: settings.language == .spanish ? "Día \(closingDay)" : "Day \(closingDay)"
                    )
                }

                if let paymentDay = debt.minimumPaymentDueDay {
                    infoRow(
                        title: settings.language == .spanish ? "Pago mínimo" : "Minimum payment",
                        value: settings.language == .spanish ? "Día \(paymentDay)" : "Day \(paymentDay)"
                    )
                }

                if debt.managementFee > 0 {
                    infoRow(
                        title: settings.language == .spanish ? "Cuota de manejo" : "Management fee",
                        value: money(debt.managementFee)
                    )
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                showPayment = true
            } label: {
                Label(
                    settings.language == .spanish ? "Registrar pago" : "Register payment",
                    systemImage: "plus.circle.fill"
                )
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(BrandPalette.primary)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if debt.isCreditCard {
                Button {
                    onRegisterExpense()
                } label: {
                    Label(
                        settings.language == .spanish ? "Registrar gasto" : "Register expense",
                        systemImage: "cart.fill.badge.plus"
                    )
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(BrandPalette.surface)
                    .foregroundColor(BrandPalette.primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(BrandPalette.primary.opacity(0.25), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var paidBadge: some View {
        Label(
            settings.language == .spanish ? "Deuda pagada y archivada" : "Debt paid and archived",
            systemImage: "checkmark.seal.fill"
        )
        .font(.caption.bold())
        .foregroundColor(.green)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.green.opacity(0.12))
        .clipShape(Capsule())
    }

    private func amountBlock(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.headline.bold())
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.caption.bold())
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(BrandPalette.surface.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var subtitle: String {
        if debt.isPaid {
            return debt.isLoan
            ? (settings.language == .spanish ? "Préstamo pagado" : "Paid loan")
            : (settings.language == .spanish ? "Tarjeta pagada" : "Paid card")
        }

        if debt.isLoan {
            return debt.kind.title(language: settings.language)
        }

        return debt.brand.displayName(language: settings.language)
    }

    private var statusPillText: String {
        if debt.isPaid {
            return settings.language == .spanish ? "Pagada" : "Paid"
        }

        if debt.isLoan {
            return "\(debt.progressPercentage)%"
        }

        return "\(debt.utilizationPercentage)%"
    }

    private var installmentText: String {
        guard let installmentCount = debt.installmentCount else {
            return settings.language == .spanish ? "Sin número de cuotas" : "No installment count"
        }

        let remaining = debt.remainingInstallments ?? 0

        return settings.language == .spanish
        ? "\(debt.paymentsMade)/\(installmentCount) pagadas · faltan \(remaining)"
        : "\(debt.paymentsMade)/\(installmentCount) paid · \(remaining) left"
    }

    private func money(_ amount: Double) -> String {
        settings.secureCurrency(amount, decimals: 2)
    }
}
