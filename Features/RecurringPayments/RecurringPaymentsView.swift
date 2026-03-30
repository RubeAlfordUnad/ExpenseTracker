import SwiftUI

struct RecurringPaymentsView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    @State private var payments: [RecurringPayment] = []
    @State private var showPaymentEditor = false
    @State private var editingPayment: RecurringPayment?
    @State private var paymentPendingDelete: RecurringPayment?
    @State private var selectedFilter: PaymentFilter = .all

    private enum PaymentFilter: CaseIterable, Identifiable {
        case all
        case pending
        case paid
        case late

        var id: String {
            switch self {
            case .all: return "all"
            case .pending: return "pending"
            case .paid: return "paid"
            case .late: return "late"
            }
        }

        func title(language: AppLanguage) -> String {
            switch (self, language) {
            case (.all, .spanish): return "Todos"
            case (.pending, .spanish): return "Pendientes"
            case (.paid, .spanish): return "Pagados"
            case (.late, .spanish): return "Atrasados"
            case (.all, .english): return "All"
            case (.pending, .english): return "Pending"
            case (.paid, .english): return "Paid"
            case (.late, .english): return "Late"
            }
        }
    }

    private var monthlyCommitment: Double {
        payments
            .filter(\.isActive)
            .reduce(0) { $0 + $1.amount }
    }

    private var pendingAmount: Double {
        payments
            .filter { isPending($0) }
            .reduce(0) { $0 + $1.amount }
    }

    private var paidCount: Int {
        payments.filter { $0.isPaidForCurrentMonth && $0.isActive }.count
    }

    private var lateCount: Int {
        payments.filter { isLate($0) }.count
    }

    private var nextPayment: RecurringPayment? {
        payments
            .filter { isPending($0) }
            .sorted(by: sortPayments)
            .first
    }

    private var filteredPayments: [RecurringPayment] {
        switch selectedFilter {
        case .all:
            return payments.sorted(by: sortPayments)
        case .pending:
            return payments.filter { isPending($0) }.sorted(by: sortPayments)
        case .paid:
            return payments
                .filter { $0.isPaidForCurrentMonth && $0.isActive }
                .sorted(by: sortPayments)
        case .late:
            return payments.filter { isLate($0) }.sorted(by: sortPayments)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                heroCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 0, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        summaryCard(
                            title: settings.t("recurring.monthlyCommitment"),
                            value: settings.formatCurrency(monthlyCommitment, decimals: 0),
                            accent: BrandPalette.primary
                        )

                        summaryCard(
                            title: settings.t("recurring.pending"),
                            value: settings.formatCurrency(pendingAmount, decimals: 0),
                            accent: BrandPalette.secondary
                        )
                    }

                    HStack(spacing: 12) {
                        summaryCard(
                            title: settings.t("recurring.paid"),
                            value: "\(paidCount)",
                            accent: .green
                        )

                        summaryCard(
                            title: settings.language == .spanish ? "Atrasados" : "Late",
                            value: "\(lateCount)",
                            accent: .red
                        )
                    }
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 0, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                Picker("", selection: $selectedFilter) {
                    ForEach(PaymentFilter.allCases) { filter in
                        Text(filter.title(language: settings.language))
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 6, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                if filteredPayments.isEmpty {
                    emptyState
                        .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 20, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredPayments) { payment in
                        RecurringPaymentCard(
                            payment: payment,
                            onEdit: {
                                startEditing(payment)
                            },
                            onToggleActive: {
                                toggleActive(for: payment.id)
                            },
                            onDelete: {
                                paymentPendingDelete = payment
                            }
                        )
                        .environmentObject(settings)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if payment.isActive {
                                Button {
                                    togglePaymentStatus(for: payment.id)
                                } label: {
                                    Label(
                                        payment.isPaidForCurrentMonth
                                        ? (settings.language == .spanish ? "Desmarcar" : "Unmark")
                                        : (settings.language == .spanish ? "Pagado" : "Paid"),
                                        systemImage: payment.isPaidForCurrentMonth
                                        ? "arrow.uturn.backward.circle.fill"
                                        : "checkmark.circle.fill"
                                    )
                                }
                                .tint(payment.isPaidForCurrentMonth ? BrandPalette.secondary : .green)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                startEditing(payment)
                            } label: {
                                Label(
                                    settings.language == .spanish ? "Editar" : "Edit",
                                    systemImage: "square.and.pencil"
                                )
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                paymentPendingDelete = payment
                            } label: {
                                Label(
                                    settings.language == .spanish ? "Eliminar" : "Delete",
                                    systemImage: "trash"
                                )
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle(settings.t("recurring.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startCreatingPayment()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showPaymentEditor, onDismiss: {
                editingPayment = nil
            }) {
                AddRecurringPaymentView(existingPayment: editingPayment) { savedPayment in
                    upsertPayment(savedPayment)
                }
                .environmentObject(settings)
            }
            .alert(
                settings.language == .spanish ? "Eliminar pago fijo" : "Delete recurring payment",
                isPresented: Binding(
                    get: { paymentPendingDelete != nil },
                    set: { newValue in
                        if !newValue {
                            paymentPendingDelete = nil
                        }
                    }
                )
            ) {
                Button(settings.t("common.cancel"), role: .cancel) {
                    paymentPendingDelete = nil
                }

                Button(settings.language == .spanish ? "Eliminar" : "Delete", role: .destructive) {
                    if let paymentPendingDelete {
                        removePayment(paymentPendingDelete)
                    }
                    self.paymentPendingDelete = nil
                }
            } message: {
                Text(
                    settings.language == .spanish
                    ? "Se borrará \"\(paymentPendingDelete?.title ?? "")\" de forma permanente."
                    : "\"\(paymentPendingDelete?.title ?? "")\" will be permanently removed."
                )
            }
            .onAppear {
                payments = DataManager.shared.loadRecurringPayments(user: auth.currentUser)
                NotificationManager.shared.syncRecurringPaymentNotifications(for: auth.currentUser)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(settings.t("recurring.title"))
                        .font(.caption.bold())
                        .foregroundColor(BrandPalette.primary)

                    Text(settings.t("recurring.heroTitle"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(settings.t("recurring.heroSubtitle"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(BrandPalette.primary)
                    .frame(width: 48, height: 48)
                    .background(BrandPalette.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            ViewThatFits {
                HStack(spacing: 8) {
                    infoPill(
                        icon: "calendar",
                        text: nextPayment.map {
                            settings.tr("recurring.nextDay", $0.effectiveDueDay(inMonthOf: Date()))
                        } ?? settings.t("recurring.noUpcoming")
                    )

                    infoPill(
                        icon: "list.bullet",
                        text: settings.tr("recurring.savedCount", payments.count)
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    infoPill(
                        icon: "calendar",
                        text: nextPayment.map {
                            settings.tr("recurring.nextDay", $0.effectiveDueDay(inMonthOf: Date()))
                        } ?? settings.t("recurring.noUpcoming")
                    )

                    infoPill(
                        icon: "list.bullet",
                        text: settings.tr("recurring.savedCount", payments.count)
                    )
                }
            }
        }
        .padding(18)
        .background(BrandPalette.heroGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 30))
                .foregroundColor(.secondary)

            Text(
                selectedFilter == .all
                ? settings.t("recurring.emptyAll")
                : settings.t("recurring.emptyFiltered")
            )
            .font(.headline)

            Text(settings.t("recurring.emptySubtitle"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if selectedFilter == .all {
                Button {
                    startCreatingPayment()
                } label: {
                    Label(settings.t("recurring.addButton"), systemImage: "plus")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(BrandPalette.primary)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(BrandPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func summaryCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.headline.bold())
                .foregroundColor(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func infoPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(BrandPalette.primary)

            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(BrandPalette.surface)
        .clipShape(Capsule())
    }

    private func sortPayments(_ lhs: RecurringPayment, _ rhs: RecurringPayment) -> Bool {
        if lhs.isActive != rhs.isActive {
            return lhs.isActive && !rhs.isActive
        }

        if effectiveDueDayThisMonth(for: lhs) != effectiveDueDayThisMonth(for: rhs) {
            return effectiveDueDayThisMonth(for: lhs) < effectiveDueDayThisMonth(for: rhs)
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func effectiveDueDayThisMonth(for payment: RecurringPayment) -> Int {
        payment.effectiveDueDay(inMonthOf: Date())
    }

    private func isLate(_ payment: RecurringPayment) -> Bool {
        guard payment.isActive else { return false }
        guard !payment.isPaidForCurrentMonth else { return false }

        let today = Calendar.current.component(.day, from: Date())
        return today > effectiveDueDayThisMonth(for: payment)
    }

    private func isPending(_ payment: RecurringPayment) -> Bool {
        guard payment.isActive else { return false }
        guard !payment.isPaidForCurrentMonth else { return false }
        return !isLate(payment)
    }

    private func startCreatingPayment() {
        editingPayment = nil
        showPaymentEditor = true
    }

    private func startEditing(_ payment: RecurringPayment) {
        editingPayment = payment
        showPaymentEditor = true
    }

    private func upsertPayment(_ savedPayment: RecurringPayment) {
        if let index = payments.firstIndex(where: { $0.id == savedPayment.id }) {
            payments[index] = savedPayment
        } else {
            payments.append(savedPayment)
        }

        persist()
    }

    private func togglePaymentStatus(for id: UUID) {
        guard let index = payments.firstIndex(where: { $0.id == id }) else { return }
        guard payments[index].isActive else { return }

        withAnimation(.spring()) {
            let currentMonth = Calendar.current.component(.month, from: Date())
            let currentYear = Calendar.current.component(.year, from: Date())

            if payments[index].isPaidForCurrentMonth {
                payments[index].lastPaidMonth = nil
                payments[index].lastPaidYear = nil
            } else {
                payments[index].lastPaidMonth = currentMonth
                payments[index].lastPaidYear = currentYear
            }
        }

        persist()
    }

    private func toggleActive(for id: UUID) {
        guard let index = payments.firstIndex(where: { $0.id == id }) else { return }

        withAnimation(.spring()) {
            payments[index].isActive.toggle()
        }

        persist()
    }

    private func removePayment(_ payment: RecurringPayment) {
        NotificationManager.shared.cancelNotification(for: payment)

        withAnimation(.spring()) {
            payments.removeAll { $0.id == payment.id }
        }

        persist()
    }

    private func persist() {
        DataManager.shared.saveRecurringPayments(payments, user: auth.currentUser)
        NotificationManager.shared.syncRecurringPaymentNotifications(for: auth.currentUser)
    }
}
