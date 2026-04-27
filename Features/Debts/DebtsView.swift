import SwiftUI
import UniformTypeIdentifiers

private enum DebtListFilter: String, CaseIterable, Identifiable {
    case active
    case cards
    case loans
    case paid

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch (self, language) {
        case (.active, .spanish): return "Activas"
        case (.active, .english): return "Active"
        case (.cards, .spanish): return "Tarjetas"
        case (.cards, .english): return "Cards"
        case (.loans, .spanish): return "Préstamos"
        case (.loans, .english): return "Loans"
        case (.paid, .spanish): return "Pagadas"
        case (.paid, .english): return "Paid"
        }
    }

    func icon(language: AppLanguage) -> String {
        switch self {
        case .active: return "list.bullet.rectangle"
        case .cards: return "creditcard.fill"
        case .loans: return "doc.text.fill"
        case .paid: return "checkmark.seal.fill"
        }
    }
}

struct DebtsView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    let moneyAccounts: [MoneyAccount]
    let onRegisterCardExpense: (Expense) -> Void
    let onRegisterDebtPayment: (_ amount: Double, _ moneyAccountId: UUID) -> Void

    @State private var debts: [Debt] = []
    @State private var selectedFilter: DebtListFilter = .active

    @State private var showEditor = false
    @State private var showCalendar = false
    @State private var editingDebt: Debt?
    @State private var debtPendingDelete: Debt?
    @State private var debtSelectedForExpense: Debt?
    
    @State private var debtPendingPaidConfirmation: Debt?
    @State private var paidConfirmationOriginalDebt: Debt?

    @State private var showDeletionBlockedAlert = false
    @State private var deletionBlockedTitle = ""
    @State private var deletionBlockedMessage = ""

    @State private var exportDocument = ExportFileDocument()
    @State private var exportContentType: UTType = .json
    @State private var exportFilename = "wallet_debts.json"
    @State private var showExporter = false
    @State private var exportErrorMessage: String?

    private let deletionGuard = DebtDeletionGuard()
    private let exportService = DebtsExportService()

    private var activeDebts: [Debt] {
        debts.filter { $0.isActive }
    }

    private var activeCards: [Debt] {
        debts.filter { $0.isActive && $0.isCreditCard }
    }

    private var activeLoans: [Debt] {
        debts.filter { $0.isActive && $0.isLoan }
    }

    private var paidDebts: [Debt] {
        debts.filter { $0.isPaid }
    }

    private var totalActiveDebt: Double {
        activeDebts.reduce(0) { $0 + $1.remainingDebt }
    }

    private var totalCardLimit: Double {
        activeCards.reduce(0) { $0 + $1.totalLimit }
    }

    private var totalAvailableCredit: Double {
        activeCards.reduce(0) { $0 + $1.availableCredit }
    }

    private var totalLoanPending: Double {
        activeLoans.reduce(0) { $0 + $1.remainingDebt }
    }

    private var averageCardUsage: Double {
        guard totalCardLimit > 0 else { return 0 }
        return activeCards.reduce(0) { $0 + $1.remainingDebt } / totalCardLimit
    }

    private var mostExpensiveDebt: Debt? {
        activeDebts.max { $0.remainingDebt < $1.remainingDebt }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    walletHeroCard
                    walletStatsSection
                    filterSection
                    walletSectionHeader
                    debtsContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                    }

                    Menu {
                        Button {
                            prepareExport(.csv)
                        } label: {
                            Label(
                                settings.language == .spanish ? "Exportar CSV" : "Export CSV",
                                systemImage: "tablecells"
                            )
                        }

                        Button {
                            prepareExport(.json)
                        } label: {
                            Label(
                                settings.language == .spanish ? "Exportar JSON" : "Export JSON",
                                systemImage: "curlybraces"
                            )
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Button {
                        startCreatingDebt()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                AddDebtView(existingDebt: editingDebt) { savedDebt in
                    upsertDebt(savedDebt)
                }
                .environmentObject(auth)
                .environmentObject(settings)
            }
            .sheet(isPresented: $showCalendar) {
                DebtCalendarView(debts: debts)
                    .environmentObject(settings)
            }
            .sheet(item: $debtSelectedForExpense) { debt in
                AddExpenseView(
                    moneyAccounts: moneyAccounts,
                    debts: debts,
                    preselectedCreditCardId: debt.id
                ) { newExpense in
                    onRegisterCardExpense(newExpense)
                    debts = DataManager.shared.loadDebts(user: auth.currentUser)
                }
                .environmentObject(auth)
                .environmentObject(settings)
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: exportContentType,
                defaultFilename: exportFilename
            ) { result in
                if case let .failure(error) = result {
                    exportErrorMessage = error.localizedDescription
                }
            }
            .alert(
                settings.language == .spanish ? "Eliminar deuda" : "Delete debt",
                isPresented: Binding(
                    get: { debtPendingDelete != nil },
                    set: { newValue in
                        if !newValue {
                            debtPendingDelete = nil
                        }
                    }
                )
            ) {
                Button(settings.t("common.cancel"), role: .cancel) {
                    debtPendingDelete = nil
                }

                Button(settings.language == .spanish ? "Eliminar" : "Delete", role: .destructive) {
                    if let debtPendingDelete {
                        removeDebt(debtPendingDelete)
                    }
                    self.debtPendingDelete = nil
                }
            } message: {
                Text(
                    settings.language == .spanish
                    ? "Se borrará \"\(debtPendingDelete?.cardName ?? "")\" de forma permanente."
                    : "\"\(debtPendingDelete?.cardName ?? "")\" will be permanently removed."
                )
            }
            .alert(
                settings.language == .spanish ? "Deuda pagada" : "Debt paid",
                isPresented: Binding(
                    get: { debtPendingPaidConfirmation != nil },
                    set: { newValue in
                        if !newValue {
                            debtPendingPaidConfirmation = nil
                            paidConfirmationOriginalDebt = nil
                        }
                    }
                )
            ) {
                Button(settings.language == .spanish ? "Mover a pagadas" : "Move to paid") {
                    confirmMovePendingDebtToPaid()
                }

                Button(settings.language == .spanish ? "Mantener activa" : "Keep active", role: .cancel) {
                    keepPendingDebtActive()
                }
            } message: {
                Text(
                    settings.language == .spanish
                    ? "\"\(debtPendingPaidConfirmation?.cardName ?? "")\" quedó con saldo pendiente en cero. ¿Quieres moverla a la sección de deudas pagadas y quitar su pago fijo vinculado?"
                    : "\"\(debtPendingPaidConfirmation?.cardName ?? "")\" now has a zero remaining balance. Do you want to move it to paid debts and remove its linked recurring payment?"
                )
            }
            .alert(deletionBlockedTitle, isPresented: $showDeletionBlockedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deletionBlockedMessage)
            }
            .alert(
                settings.language == .spanish ? "No se pudo exportar" : "Could not export",
                isPresented: Binding(
                    get: { exportErrorMessage != nil },
                    set: { newValue in
                        if !newValue { exportErrorMessage = nil }
                    }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportErrorMessage ?? "")
            }
            .onAppear {
                debts = DataManager.shared.loadDebts(user: auth.currentUser)
            }
            .onChange(of: debts) { _, newValue in
                DataManager.shared.saveDebts(newValue, user: auth.currentUser)
            }
        }
    }

    private var walletHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(settings.language == .spanish ? "Deudas" : "Debts")
                        .font(.caption.bold())
                        .foregroundColor(BrandPalette.primary)

                    Text(settings.language == .spanish ? "Tarjetas y préstamos" : "Cards and loans")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(
                        settings.language == .spanish
                        ? "Controla tarjetas, préstamos, pagos mínimos, cuotas pendientes y deudas ya pagadas desde un solo lugar."
                        : "Track cards, loans, minimum payments, remaining installments and paid debts from one place."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(BrandPalette.primary)
                    .frame(width: 52, height: 52)
                    .background(BrandPalette.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            ViewThatFits {
                HStack(spacing: 8) {
                    infoPill(
                        icon: "creditcard.fill",
                        text: settings.language == .spanish
                        ? "\(activeCards.count) tarjetas"
                        : "\(activeCards.count) cards"
                    )

                    infoPill(
                        icon: "doc.text.fill",
                        text: settings.language == .spanish
                        ? "\(activeLoans.count) préstamos"
                        : "\(activeLoans.count) loans"
                    )

                    infoPill(
                        icon: "checkmark.seal.fill",
                        text: settings.language == .spanish
                        ? "\(paidDebts.count) pagadas"
                        : "\(paidDebts.count) paid"
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    infoPill(
                        icon: "creditcard.fill",
                        text: settings.language == .spanish
                        ? "\(activeCards.count) tarjetas"
                        : "\(activeCards.count) cards"
                    )

                    infoPill(
                        icon: "doc.text.fill",
                        text: settings.language == .spanish
                        ? "\(activeLoans.count) préstamos"
                        : "\(activeLoans.count) loans"
                    )

                    infoPill(
                        icon: "checkmark.seal.fill",
                        text: settings.language == .spanish
                        ? "\(paidDebts.count) pagadas"
                        : "\(paidDebts.count) paid"
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

    private var walletStatsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statCard(
                    title: settings.language == .spanish ? "Total adeudado" : "Total debt",
                    value: money(totalActiveDebt),
                    accent: .red
                )

                statCard(
                    title: settings.language == .spanish ? "Disponible" : "Available",
                    value: money(totalAvailableCredit),
                    accent: BrandPalette.primary
                )
            }

            HStack(spacing: 12) {
                statCard(
                    title: settings.language == .spanish ? "Préstamos" : "Loans",
                    value: money(totalLoanPending),
                    accent: .orange
                )

                statCard(
                    title: settings.language == .spanish ? "Pagadas" : "Paid",
                    value: "\(paidDebts.count)",
                    accent: .green
                )
            }
        }
    }

    private var filterSection: some View {
        Picker(
            settings.language == .spanish ? "Vista de deudas" : "Debt view",
            selection: $selectedFilter
        ) {
            ForEach(DebtListFilter.allCases) { filter in
                Text(filter.title(language: settings.language))
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    private var walletSectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sectionTitle)
                    .font(.headline)

                Text(sectionSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(currentFilterCount)")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(BrandPalette.surface)
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var debtsContent: some View {
        switch selectedFilter {
        case .active:
            if activeCards.isEmpty && activeLoans.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 16) {
                    if !activeCards.isEmpty {
                        debtSection(
                            title: settings.language == .spanish ? "Tarjetas activas" : "Active cards",
                            subtitle: settings.language == .spanish ? "Control de cupo, deuda y pago mínimo." : "Credit limit, balance and minimum payment.",
                            items: activeCards
                        )
                    }

                    if !activeLoans.isEmpty {
                        debtSection(
                            title: settings.language == .spanish ? "Préstamos activos" : "Active loans",
                            subtitle: settings.language == .spanish ? "Cuotas, saldo pendiente y avance de pago." : "Installments, remaining balance and payment progress.",
                            items: activeLoans
                        )
                    }
                }
            }

        case .cards:
            if activeCards.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 16) {
                    debtSection(
                        title: settings.language == .spanish ? "Tarjetas" : "Cards",
                        subtitle: settings.language == .spanish ? "Solo tarjetas de crédito activas." : "Active credit cards only.",
                        items: activeCards
                    )
                }
            }

        case .loans:
            if activeLoans.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 16) {
                    debtSection(
                        title: settings.language == .spanish ? "Préstamos" : "Loans",
                        subtitle: settings.language == .spanish ? "Solo préstamos activos." : "Active loans only.",
                        items: activeLoans
                    )
                }
            }

        case .paid:
            if paidDebts.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 16) {
                    debtSection(
                        title: settings.language == .spanish ? "Deudas pagadas" : "Paid debts",
                        subtitle: settings.language == .spanish ? "Historial de tarjetas y préstamos ya cerrados." : "Closed cards and loans history.",
                        items: paidDebts
                    )
                }
            }
        }
    }

    private func debtSection(title: String, subtitle: String, items: [Debt]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(items) { debt in
                if let debtBinding = binding(for: debt) {
                    debtCard(for: debtBinding)
                }
            }
        }
    }

    private func debtCard(for debt: Binding<Debt>) -> some View {
        DebtCard(
            debt: debt,
            moneyAccounts: moneyAccounts,
            onEdit: {
                startEditing(debt.wrappedValue)
            },
            onDelete: {
                debtPendingDelete = debt.wrappedValue
            },
            onRegisterExpense: {
                debtSelectedForExpense = debt.wrappedValue
            },
            onRegisterPayment: { amount, moneyAccountId in
                onRegisterDebtPayment(amount, moneyAccountId)
            },
            onMarkDebtAsPaid: { paidDebt in
                markDebtAsPaid(paidDebt)
            }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text(emptyStateTitle)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if selectedFilter != .paid {
                Button {
                    startCreatingDebt()
                } label: {
                    Label(
                        settings.language == .spanish ? "Agregar deuda" : "Add debt",
                        systemImage: "plus"
                    )
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

    private func statCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.headline.bold())
                .foregroundColor(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            RoundedRectangle(cornerRadius: 99, style: .continuous)
                .fill(accent.opacity(0.18))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 99, style: .continuous)
                        .fill(accent)
                        .frame(width: 54, height: 6)
                }
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

    private func prepareExport(_ format: DebtsExportFormat) {
        do {
            let payload = try exportService.makeExport(from: debts, format: format)
            exportDocument = ExportFileDocument(
                data: payload.data,
                contentType: payload.contentType
            )
            exportContentType = payload.contentType
            exportFilename = payload.fileName
            showExporter = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func startCreatingDebt() {
        editingDebt = nil
        showEditor = true
    }

    private func startEditing(_ debt: Debt) {
        editingDebt = debt
        showEditor = true
    }

    private func upsertDebt(_ savedDebt: Debt) {
        if let index = debts.firstIndex(where: { $0.id == savedDebt.id }) {
            let previousDebt = debts[index]
            var debtToSave = savedDebt

            let shouldAskToMoveToPaid = savedDebt.isFullyPaid && previousDebt.isActive

            if shouldAskToMoveToPaid {
                debtToSave.status = .active
            }

            debts[index] = debtToSave

            AuditLogStore.shared.logDebtUpdated(
                from: previousDebt,
                to: debtToSave,
                user: auth.currentUser
            )

            if shouldAskToMoveToPaid {
                debtPendingPaidConfirmation = debtToSave
                paidConfirmationOriginalDebt = previousDebt
            }
        } else {
            var newDebt = savedDebt
            let shouldAskToMoveToPaid = savedDebt.isFullyPaid

            if shouldAskToMoveToPaid {
                newDebt.status = .active
            }

            debts.append(newDebt)
            AuditLogStore.shared.logDebtCreated(newDebt, user: auth.currentUser)

            if shouldAskToMoveToPaid {
                debtPendingPaidConfirmation = newDebt
                paidConfirmationOriginalDebt = nil
            }
        }
    }

    private func markDebtAsPaid(_ paidDebt: Debt) {
        guard let index = debts.firstIndex(where: { $0.id == paidDebt.id }) else {
            return
        }

        let previousDebt = debts[index]

        var archivedDebt = paidDebt
        archivedDebt.markAsPaid()

        debts[index] = archivedDebt
        selectedFilter = .paid

        removeLinkedRecurringPayment(for: archivedDebt)

        AuditLogStore.shared.logDebtUpdated(
            from: previousDebt,
            to: archivedDebt,
            user: auth.currentUser,
            note: settings.language == .spanish
            ? "Deuda movida a pagadas."
            : "Debt moved to paid."
        )
    }

    private func confirmMovePendingDebtToPaid() {
        guard let debtPendingPaidConfirmation else {
            return
        }

        markDebtAsPaid(debtPendingPaidConfirmation)
        self.debtPendingPaidConfirmation = nil
        self.paidConfirmationOriginalDebt = nil
    }

    private func keepPendingDebtActive() {
        guard let debtPendingPaidConfirmation,
              let index = debts.firstIndex(where: { $0.id == debtPendingPaidConfirmation.id }) else {
            self.debtPendingPaidConfirmation = nil
            self.paidConfirmationOriginalDebt = nil
            return
        }

        var activeDebt = debts[index]
        activeDebt.status = .active
        debts[index] = activeDebt

        self.debtPendingPaidConfirmation = nil
        self.paidConfirmationOriginalDebt = nil
    }

    private func removeDebt(_ debt: Debt) {
        let expenses = DataManager.shared.loadExpenses(user: auth.currentUser)

        let impact = deletionGuard.impact(
            for: debt.id,
            expenses: expenses
        )

        guard !impact.hasLinkedRecords else {
            presentDeletionBlockedAlert(for: debt, impact: impact)
            return
        }

        removeLinkedRecurringPayment(for: debt)
        AuditLogStore.shared.logDebtDeleted(debt, user: auth.currentUser)
        debts.removeAll { $0.id == debt.id }
    }

    private func removeLinkedRecurringPayment(for debt: Debt) {
        var payments = DataManager.shared.loadRecurringPayments(user: auth.currentUser)
        let originalCount = payments.count

        payments.removeAll { payment in
            payment.id == debt.linkedRecurringPaymentId || payment.linkedDebtId == debt.id
        }

        if payments.count != originalCount {
            DataManager.shared.saveRecurringPayments(payments, user: auth.currentUser)
        }
    }

    private func presentDeletionBlockedAlert(for debt: Debt, impact: DebtDeletionImpact) {
        deletionBlockedTitle = settings.language == .spanish
        ? "No puedes eliminar esta deuda"
        : "You cannot delete this debt"

        let recordText: String
        if settings.language == .spanish {
            recordText = impact.expenseCount == 1
            ? "1 gasto"
            : "\(impact.expenseCount) gastos"
        } else {
            recordText = impact.expenseCount == 1
            ? "1 expense"
            : "\(impact.expenseCount) expenses"
        }

        deletionBlockedMessage = settings.language == .spanish
        ? "La deuda \"\(debt.cardName)\" está siendo usada en \(recordText). Reasigna o elimina esos movimientos primero."
        : "The debt \"\(debt.cardName)\" is currently used in \(recordText). Reassign or delete those records first."

        showDeletionBlockedAlert = true
    }

    private func binding(for debt: Debt) -> Binding<Debt>? {
        guard let index = debts.firstIndex(where: { $0.id == debt.id }) else {
            return nil
        }

        return Binding(
            get: {
                debts[index]
            },
            set: { newValue in
                debts[index] = newValue
            }
        )
    }

    private var sectionTitle: String {
        switch selectedFilter {
        case .active:
            return settings.language == .spanish ? "Deudas activas" : "Active debts"
        case .cards:
            return settings.language == .spanish ? "Tarjetas" : "Cards"
        case .loans:
            return settings.language == .spanish ? "Préstamos" : "Loans"
        case .paid:
            return settings.language == .spanish ? "Deudas pagadas" : "Paid debts"
        }
    }

    private var sectionSubtitle: String {
        switch selectedFilter {
        case .active:
            return settings.language == .spanish
            ? "Separadas por tarjetas y préstamos."
            : "Separated by cards and loans."
        case .cards:
            return settings.language == .spanish
            ? "Uso promedio del cupo: \(Int((averageCardUsage * 100).rounded()))%"
            : "Average credit usage: \(Int((averageCardUsage * 100).rounded()))%"
        case .loans:
            return settings.language == .spanish
            ? "Saldo pendiente en préstamos: \(money(totalLoanPending))"
            : "Pending loan balance: \(money(totalLoanPending))"
        case .paid:
            return settings.language == .spanish
            ? "Historial de deudas cerradas."
            : "Closed debt history."
        }
    }

    private var currentFilterCount: Int {
        switch selectedFilter {
        case .active:
            return activeDebts.count
        case .cards:
            return activeCards.count
        case .loans:
            return activeLoans.count
        case .paid:
            return paidDebts.count
        }
    }

    private var emptyStateIcon: String {
        switch selectedFilter {
        case .active:
            return "creditcard.and.123"
        case .cards:
            return "creditcard"
        case .loans:
            return "doc.text"
        case .paid:
            return "checkmark.seal"
        }
    }

    private var emptyStateTitle: String {
        switch selectedFilter {
        case .active:
            return settings.language == .spanish
            ? "No tienes deudas activas"
            : "You do not have active debts"
        case .cards:
            return settings.language == .spanish
            ? "No tienes tarjetas activas"
            : "You do not have active cards"
        case .loans:
            return settings.language == .spanish
            ? "No tienes préstamos activos"
            : "You do not have active loans"
        case .paid:
            return settings.language == .spanish
            ? "No tienes deudas pagadas"
            : "You do not have paid debts"
        }
    }

    private var emptyStateMessage: String {
        switch selectedFilter {
        case .active:
            return settings.language == .spanish
            ? "Agrega una tarjeta o préstamo para empezar a controlar pagos, saldos y cuotas."
            : "Add a card or loan to start tracking payments, balances and installments."
        case .cards:
            return settings.language == .spanish
            ? "Aquí verás solo tus tarjetas de crédito activas."
            : "Only your active credit cards will appear here."
        case .loans:
            return settings.language == .spanish
            ? "Aquí verás préstamos como ortodoncia, estudios, compras financiadas u otros compromisos mensuales."
            : "Loans such as orthodontics, education, financed purchases or other monthly commitments will appear here."
        case .paid:
            return settings.language == .spanish
            ? "Cuando cierres una tarjeta o termines un préstamo, aparecerá en esta sección."
            : "When you close a card or finish a loan, it will appear in this section."
        }
    }

    private func money(_ amount: Double) -> String {
        settings.secureCurrency(amount, decimals: 2)
    }
}
