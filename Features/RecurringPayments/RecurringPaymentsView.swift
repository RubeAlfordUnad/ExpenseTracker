import SwiftUI

struct RecurringPaymentsView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    let moneyAccounts: [MoneyAccount]
    let onRegisterPaidRecurringExpense: (RecurringPayment, UUID, UUID) -> Void
    let onDeletePaidRecurringExpense: (UUID) -> Void

    @State private var payments: [RecurringPayment] = []
    @State private var showPaymentEditor = false
    @State private var editingPayment: RecurringPayment?
    @State private var paymentPendingDelete: RecurringPayment?
    @State private var paymentPendingFundingSelection: RecurringPayment?
    @State private var linkedPaymentPendingArchiveRemoval: RecurringPayment?
    @State private var loanPendingPaidConfirmation: Debt?
    @State private var showMissingAccountAlert = false
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
    
    private let recurringLoanSync = RecurringLoanPaymentSync()

    private var isFundingSheetPresented: Binding<Bool> {
        Binding(
            get: { paymentPendingFundingSelection != nil },
            set: { newValue in
                if !newValue {
                    paymentPendingFundingSelection = nil
                }
            }
        )
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
                            value: settings.secureCurrency(monthlyCommitment, decimals: 2),
                            accent: BrandPalette.primary
                        )

                        summaryCard(
                            title: settings.t("recurring.pending"),
                            value: settings.secureCurrency(pendingAmount, decimals: 2),
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
                                    handlePaymentStatusAction(for: payment)
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
            .sheet(isPresented: isFundingSheetPresented, onDismiss: {
                paymentPendingFundingSelection = nil
            }) {
                if let payment = paymentPendingFundingSelection {
                    MarkRecurringPaymentSheetView(
                        payment: payment,
                        moneyAccounts: moneyAccounts
                    ) { moneyAccountId in
                        markPaymentAsPaid(paymentId: payment.id, from: moneyAccountId)
                        paymentPendingFundingSelection = nil
                    }
                    .environmentObject(settings)
                } else {
                    EmptyView()
                }
            }
            
            .alert(
                settings.language == .spanish ? "Préstamo pagado" : "Loan paid",
                isPresented: Binding(
                    get: { loanPendingPaidConfirmation != nil },
                    set: { newValue in
                        if !newValue {
                            loanPendingPaidConfirmation = nil
                            linkedPaymentPendingArchiveRemoval = nil
                        }
                    }
                )
            ) {
                Button(settings.language == .spanish ? "Mover a pagadas" : "Move to paid") {
                    confirmArchiveLinkedLoan()
                }

                Button(settings.language == .spanish ? "Mantener activa" : "Keep active", role: .cancel) {
                    keepLinkedLoanActive()
                }
            } message: {
                Text(
                    settings.language == .spanish
                    ? "\"\(loanPendingPaidConfirmation?.cardName ?? "")\" quedó con saldo pendiente en cero. ¿Quieres moverlo a Deudas pagadas y eliminar su pago fijo vinculado?"
                    : "\"\(loanPendingPaidConfirmation?.cardName ?? "")\" now has a zero remaining balance. Do you want to move it to paid debts and remove its linked recurring payment?"
                )
            }
            
            .alert(
                settings.language == .spanish ? "Sin cuentas disponibles" : "No accounts available",
                isPresented: $showMissingAccountAlert
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(
                    settings.language == .spanish
                        ? "Crea una cuenta de dinero antes de marcar este pago como pagado."
                        : "Create a money account before marking this payment as paid."
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
            let previousPayment = payments[index]
            payments[index] = savedPayment
            payments.sort(by: sortPayments)

            AuditLogStore.shared.logRecurringPaymentUpdated(
                from: previousPayment,
                to: savedPayment,
                user: auth.currentUser
            )
        } else {
            payments.append(savedPayment)
            payments.sort(by: sortPayments)

            AuditLogStore.shared.logRecurringPaymentCreated(savedPayment, user: auth.currentUser)
        }

        persist()
    }

    private func handlePaymentStatusAction(for payment: RecurringPayment) {
        guard payment.isActive else { return }

        if payment.isPaidForCurrentMonth {
            unmarkPaymentStatus(for: payment.id)
            return
        }

        guard !moneyAccounts.isEmpty else {
            showMissingAccountAlert = true
            return
        }

        paymentPendingFundingSelection = payment
    }

    private func markPaymentAsPaid(paymentId: UUID, from moneyAccountId: UUID) {
        guard let index = payments.firstIndex(where: { $0.id == paymentId }) else { return }

        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        let generatedExpenseId = UUID()

        withAnimation(.spring()) {
            payments[index].lastPaidMonth = currentMonth
            payments[index].lastPaidYear = currentYear
            payments[index].lastPaidExpenseId = generatedExpenseId
        }

        let savedPayment = payments[index]

        let sourceAccountName = moneyAccounts.first(where: { $0.id == moneyAccountId })?.name ?? "Unknown"

        AuditLogStore.shared.logRecurringPaymentMarkedPaid(
            savedPayment,
            fromAccountName: sourceAccountName,
            user: auth.currentUser
        )

        persist()

        onRegisterPaidRecurringExpense(savedPayment, moneyAccountId, generatedExpenseId)

        syncLinkedLoanAfterMarkingPaid(
            savedPayment,
            fromAccountName: sourceAccountName
        )
    }

    private func unmarkPaymentStatus(for id: UUID) {
        guard let index = payments.firstIndex(where: { $0.id == id }) else { return }

        let paymentBeforeUnmarking = payments[index]
        let generatedExpenseId = payments[index].lastPaidExpenseId

        withAnimation(.spring()) {
            payments[index].lastPaidMonth = nil
            payments[index].lastPaidYear = nil
            payments[index].lastPaidExpenseId = nil
        }

        let updatedPayment = payments[index]

        AuditLogStore.shared.logRecurringPaymentMarkedUnpaid(
            updatedPayment,
            user: auth.currentUser
        )

        persist()

        if let generatedExpenseId {
            onDeletePaidRecurringExpense(generatedExpenseId)
            syncLinkedLoanAfterUnmarkingPaid(paymentBeforeUnmarking)
        }
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

        AuditLogStore.shared.logRecurringPaymentDeleted(payment, user: auth.currentUser)
        persist()
    }
    
    private func syncLinkedLoanAfterMarkingPaid(
        _ payment: RecurringPayment,
        fromAccountName: String
    ) {
        var debts = DataManager.shared.loadDebts(user: auth.currentUser)

        let result = recurringLoanSync.applyRecurringPayment(
            payment,
            debts: &debts
        )

        guard let previousDebt = result.previousDebt,
              let updatedDebt = result.updatedDebt else {
            return
        }

        DataManager.shared.saveDebts(debts, user: auth.currentUser)

        AuditLogStore.shared.logDebtPaymentApplied(
            from: previousDebt,
            to: updatedDebt,
            amount: payment.amount,
            fromAccountName: fromAccountName,
            source: .linkedRecurringPayment,
            user: auth.currentUser
        )

        guard result.shouldAskToArchivePaidLoan else {
            return
        }

        loanPendingPaidConfirmation = updatedDebt
        linkedPaymentPendingArchiveRemoval = payment
    }

    private func syncLinkedLoanAfterUnmarkingPaid(_ payment: RecurringPayment) {
        var debts = DataManager.shared.loadDebts(user: auth.currentUser)

        let result = recurringLoanSync.revertRecurringPayment(
            payment,
            debts: &debts
        )

        guard let previousDebt = result.previousDebt,
              let updatedDebt = result.updatedDebt else {
            return
        }

        DataManager.shared.saveDebts(debts, user: auth.currentUser)

        AuditLogStore.shared.logLinkedLoanRecurringPaymentReverted(
            from: previousDebt,
            to: updatedDebt,
            payment: payment,
            user: auth.currentUser
        )
    }

    private func confirmArchiveLinkedLoan() {
        guard let loanPendingPaidConfirmation else {
            clearLinkedLoanArchiveState()
            return
        }

        var debts = DataManager.shared.loadDebts(user: auth.currentUser)

        guard let debtIndex = debts.firstIndex(where: { $0.id == loanPendingPaidConfirmation.id }) else {
            clearLinkedLoanArchiveState()
            return
        }

        let previousDebt = debts[debtIndex]

        var archivedDebt = debts[debtIndex]
        archivedDebt.markAsPaid()

        debts[debtIndex] = archivedDebt
        DataManager.shared.saveDebts(debts, user: auth.currentUser)

        AuditLogStore.shared.logDebtMovedToPaid(
            from: previousDebt,
            to: archivedDebt,
            trigger: .linkedRecurringPayment,
            removedRecurringPayment: linkedPaymentPendingArchiveRemoval,
            user: auth.currentUser
        )

        removeArchivedLoanRecurringPayment(for: archivedDebt)
        clearLinkedLoanArchiveState()
    }
    
    private func keepLinkedLoanActive() {
        clearLinkedLoanArchiveState()
    }

    private func removeArchivedLoanRecurringPayment(for debt: Debt) {
        guard let paymentToRemove = linkedPaymentPendingArchiveRemoval else {
            return
        }

        NotificationManager.shared.cancelNotification(for: paymentToRemove)

        withAnimation(.spring()) {
            payments.removeAll { payment in
                payment.id == paymentToRemove.id || payment.linkedDebtId == debt.id
            }
        }

        AuditLogStore.shared.logLoanRecurringPaymentRemovedAfterDebtArchive(
            loan: debt,
            payment: paymentToRemove,
            user: auth.currentUser
        )

        persist()
    }

    private func clearLinkedLoanArchiveState() {
        loanPendingPaidConfirmation = nil
        linkedPaymentPendingArchiveRemoval = nil
    }

    private func persist() {
        DataManager.shared.saveRecurringPayments(payments, user: auth.currentUser)
        NotificationManager.shared.syncRecurringPaymentNotifications(for: auth.currentUser)
    }
}
