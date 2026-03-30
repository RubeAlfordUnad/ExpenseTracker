import SwiftUI

struct DebtCard: View {

    @EnvironmentObject var settings: AppSettings
    @Binding var debt: Debt

    @State private var showPayment = false

    let onEdit: () -> Void
    let onDelete: () -> Void

    private var utilizationColor: Color {
        if debt.utilization >= 0.85 { return .red }
        if debt.utilization >= 0.60 { return BrandPalette.secondary }
        return BrandPalette.primary
    }

    private var brandAccent: Color {
        switch debt.brand {
        case .visa:
            return BrandPalette.primary
        case .mastercard:
            return BrandPalette.secondary
        case .amex:
            return .green
        case .other:
            return .white.opacity(0.9)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: debt.brand.systemImageName)
                        .font(.headline)
                        .foregroundColor(brandAccent)
                        .frame(width: 42, height: 42)
                        .background(brandAccent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(debt.cardName)
                            .font(.headline)

                        Text(debt.brand.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Text("\(debt.utilizationPercentage)%")
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
                                settings.language == .spanish ? "Editar tarjeta" : "Edit card",
                                systemImage: "square.and.pencil"
                            )
                        }

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label(
                                settings.language == .spanish ? "Eliminar tarjeta" : "Delete card",
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
                }
            }

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
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    BrandPalette.surface,
                    brandAccent.opacity(0.08),
                    BrandPalette.surfaceRaised
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .sheet(isPresented: $showPayment) {
            AddPaymentView(debt: $debt)
        }
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

    private func money(_ amount: Double) -> String {
        amount.asCurrency(
            code: settings.effectiveCurrency.rawValue,
            locale: settings.appLocale,
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        )
    }
}
