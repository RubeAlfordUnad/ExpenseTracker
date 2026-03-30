import SwiftUI

struct RecurringPaymentCard: View {

    @EnvironmentObject var settings: AppSettings

    let payment: RecurringPayment
    let onEdit: () -> Void
    let onToggleActive: () -> Void
    let onDelete: () -> Void

    private var today: Int {
        Calendar.current.component(.day, from: Date())
    }

    private var effectiveDueDayThisMonth: Int {
        payment.effectiveDueDay(inMonthOf: Date())
    }

    private var isLateThisMonth: Bool {
        payment.isActive &&
        !payment.isPaidForCurrentMonth &&
        today > effectiveDueDayThisMonth
    }

    private var statusColor: Color {
        if !payment.isActive { return .gray }
        if payment.isPaidForCurrentMonth { return .green }
        if isLateThisMonth { return .red }
        return BrandPalette.secondary
    }

    private var statusText: String {
        if !payment.isActive {
            return settings.language == .spanish ? "Inactivo" : "Inactive"
        }

        if payment.isPaidForCurrentMonth {
            return settings.language == .spanish ? "Pagado" : "Paid"
        }

        if isLateThisMonth {
            return settings.language == .spanish ? "Atrasado" : "Late"
        }

        return settings.language == .spanish ? "Pendiente" : "Pending"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: iconForCategory(payment.category))
                        .font(.headline)
                        .foregroundColor(colorForCategory(payment.category))
                        .frame(width: 42, height: 42)
                        .background(colorForCategory(payment.category).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(payment.title)
                            .font(.headline)

                        Text(payment.category.displayName(language: settings.language))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Text(statusText)
                        .font(.caption.bold())
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())

                    Menu {
                        Button {
                            onEdit()
                        } label: {
                            Label(
                                settings.language == .spanish ? "Editar" : "Edit",
                                systemImage: "square.and.pencil"
                            )
                        }

                        Button {
                            onToggleActive()
                        } label: {
                            Label(
                                payment.isActive
                                ? (settings.language == .spanish ? "Desactivar" : "Deactivate")
                                : (settings.language == .spanish ? "Activar" : "Activate"),
                                systemImage: payment.isActive
                                ? "pause.circle"
                                : "play.circle"
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

            HStack(spacing: 12) {
                block(
                    title: settings.language == .spanish ? "Monto" : "Amount",
                    value: settings.formatCurrency(payment.amount, decimals: 0),
                    tint: BrandPalette.primary
                )

                block(
                    title: settings.language == .spanish ? "Vence" : "Due",
                    value: payment.displayDueText(language: settings.language),
                    tint: statusColor
                )
            }

            HStack {
                Label(
                    settings.language == .spanish
                    ? "Desliza o usa el menú"
                    : "Swipe or use the menu",
                    systemImage: "hand.draw"
                )
                .font(.caption)
                .foregroundColor(.secondary)

                Spacer()

                if !payment.isActive {
                    Label(
                        settings.language == .spanish ? "Pausado" : "Paused",
                        systemImage: "pause.circle.fill"
                    )
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                } else if payment.isPaidForCurrentMonth {
                    Label(
                        settings.language == .spanish ? "Al día" : "Up to date",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption.bold())
                    .foregroundColor(.green)
                } else if isLateThisMonth {
                    Label(
                        settings.language == .spanish ? "Vencido este mes" : "Due date passed",
                        systemImage: "exclamationmark.circle.fill"
                    )
                    .font(.caption.bold())
                    .foregroundColor(.red)
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    BrandPalette.surface,
                    colorForCategory(payment.category).opacity(0.08),
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
    }

    private func block(title: String, value: String, tint: Color) -> some View {
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

    private func iconForCategory(_ category: RecurringPaymentCategory) -> String {
        switch category {
        case .housing: return "house.fill"
        case .transport: return "car.fill"
        case .utilities: return "bolt.fill"
        case .insurance: return "shield.fill"
        case .health: return "cross.case.fill"
        case .subscriptions: return "play.rectangle.fill"
        case .education: return "book.fill"
        case .loans: return "creditcard.fill"
        case .other: return "circle.fill"
        }
    }

    private func colorForCategory(_ category: RecurringPaymentCategory) -> Color {
        switch category {
        case .housing: return BrandPalette.primary
        case .transport: return .teal
        case .utilities: return BrandPalette.secondary
        case .insurance: return .indigo
        case .health: return .red
        case .subscriptions: return .purple
        case .education: return .mint
        case .loans: return .orange
        case .other: return .gray
        }
    }
}
