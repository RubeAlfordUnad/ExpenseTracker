import SwiftUI

struct TransfersView: View {

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject var auth: AuthManager

    @Binding var transfers: [AccountTransfer]
    @Binding var moneyAccounts: [MoneyAccount]

    let onPersistTransfers: () -> Void
    let onPersistMoneyAccounts: () -> Void

    @State private var showAddTransfer = false
    @State private var editingTransfer: AccountTransfer?
    @State private var pendingDelete: AccountTransfer?

    private let calendar = Calendar.current
    private let sync = MoneyAccountTransferSync()

    private var sortedTransfers: [AccountTransfer] {
        transfers.sorted { $0.date > $1.date }
    }

    private var currentMonthTransfers: [AccountTransfer] {
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)

        return sortedTransfers.filter {
            calendar.component(.month, from: $0.date) == month &&
            calendar.component(.year, from: $0.date) == year
        }
    }

    private var currentMonthTransferVolume: Double {
        currentMonthTransfers.reduce(0) { $0 + $1.amount }
    }

    private var canCreateTransfers: Bool {
        moneyAccounts.count >= 2
    }

    private var latestTransfer: AccountTransfer? {
        sortedTransfers.first
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                heroCard
                sectionHeader

                if !canCreateTransfers {
                    requirementsCard
                } else if sortedTransfers.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedTransfers) { transfer in
                            transferCard(transfer)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationTitle(settings.language == .spanish ? "Transferencias" : "Transfers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canCreateTransfers {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingTransfer = nil
                        showAddTransfer = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("transfers.add.button")
                }
            }
        }
        .sheet(isPresented: $showAddTransfer) {
            NavigationStack {
                AddTransferView(moneyAccounts: moneyAccounts) { newTransfer in
                    transfers.append(newTransfer)
                    transfers.sort { $0.date > $1.date }

                    sync.applyNewTransfer(newTransfer, accounts: &moneyAccounts)

                    let fromName = moneyAccounts.first(where: { $0.id == newTransfer.fromAccountId })?.name ?? "Unknown"
                    let toName = moneyAccounts.first(where: { $0.id == newTransfer.toAccountId })?.name ?? "Unknown"

                    AuditLogStore.shared.logTransferCreated(
                        newTransfer,
                        fromName: fromName,
                        toName: toName,
                        user: auth.currentUser
                    )

                    onPersistTransfers()
                    onPersistMoneyAccounts()
                }
                .environmentObject(settings)
            }
        }
        .sheet(item: $editingTransfer) { transfer in
            NavigationStack {
                AddTransferView(existingTransfer: transfer, moneyAccounts: moneyAccounts) { updatedTransfer in
                    updateTransfer(updatedTransfer)
                }
                .environmentObject(settings)
            }
        }
        .alert(
            settings.language == .spanish ? "Eliminar transferencia" : "Delete transfer",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { newValue in
                    if !newValue {
                        pendingDelete = nil
                    }
                }
            )
        ) {
            Button(settings.t("common.cancel"), role: .cancel) {
                pendingDelete = nil
            }

            Button(settings.language == .spanish ? "Eliminar" : "Delete", role: .destructive) {
                if let pendingDelete {
                    deleteTransfer(pendingDelete)
                }
                self.pendingDelete = nil
            }
        } message: {
            Text(
                settings.language == .spanish
                ? "Se revertirán los saldos afectados por esta transferencia."
                : "This will revert the balances affected by this transfer."
            )
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(settings.language == .spanish ? "Movimiento interno" : "Internal movement")
                        .font(.caption.bold())
                        .foregroundColor(BrandPalette.primary)

                    Text(settings.language == .spanish ? "Tus transferencias" : "Your transfers")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(
                        settings.language == .spanish
                        ? "Mueve dinero entre tus cuentas sin afectar ingresos, gastos ni presupuesto."
                        : "Move money between your accounts without affecting income, expenses, or your budget."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 52, height: 52)
                    .background(BrandPalette.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            HStack(spacing: 12) {
                statPill(
                    icon: "arrow.left.arrow.right",
                    text: settings.language == .spanish
                    ? "Este mes: \(settings.secureCurrency(currentMonthTransferVolume))"
                    : "This month: \(settings.secureCurrency(currentMonthTransferVolume))"
                )

                statPill(
                    icon: "clock",
                    text: latestTransferRouteText
                )
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

    private var latestTransferRouteText: String {
        guard let latestTransfer else {
            return settings.language == .spanish ? "Sin transferencias aún" : "No transfers yet"
        }

        return "\(accountName(for: latestTransfer.fromAccountId)) → \(accountName(for: latestTransfer.toAccountId))"
    }

    private var sectionHeader: some View {
        HStack {
            Text(settings.language == .spanish ? "Historial de transferencias" : "Transfer history")
                .font(.headline)

            Spacer()

            Text(
                settings.language == .spanish
                ? "\(sortedTransfers.count) registros"
                : "\(sortedTransfers.count) records"
            )
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    private var requirementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)

                Text(
                    settings.language == .spanish
                    ? "Necesitas al menos dos cuentas"
                    : "You need at least two accounts"
                )
                .font(.headline)
            }

            Text(
                settings.language == .spanish
                ? "Crea mínimo dos cuentas de dinero para poder mover saldo entre ellas y registrar transferencias."
                : "Create at least two money accounts before moving balances between them and recording transfers."
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(settings.language == .spanish ? "Aún no tienes transferencias" : "You do not have transfers yet")
                .font(.headline)

            Text(
                settings.language == .spanish
                ? "Usa esta sección para mover dinero entre cuentas, por ejemplo de efectivo a ahorros o de banco a billetera digital."
                : "Use this section to move money between accounts, for example from cash to savings or from bank to digital wallet."
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func transferCard(_ transfer: AccountTransfer) -> some View {
        Button {
            editingTransfer = transfer
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: "arrow.left.arrow.right")
                        .font(.headline)
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(accountName(for: transfer.fromAccountId)) → \(accountName(for: transfer.toAccountId))")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(
                        settings.language == .spanish
                        ? "Movimiento entre cuentas"
                        : "Movement between accounts"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    if let note = transfer.normalizedNote {
                        Text(note)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Text(settings.shortDateString(from: transfer.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.blue)

                        Text(settings.secureCurrency(transfer.amount))
                            .font(.headline)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Menu {
                        Button(settings.language == .spanish ? "Editar" : "Edit") {
                            editingTransfer = transfer
                        }

                        Button(settings.language == .spanish ? "Eliminar" : "Delete", role: .destructive) {
                            pendingDelete = transfer
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(BrandPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statPill(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundColor(BrandPalette.primary)

            Text(text)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(BrandPalette.surface)
        .clipShape(Capsule())
    }

    private func updateTransfer(_ updatedTransfer: AccountTransfer) {
        guard let index = transfers.firstIndex(where: { $0.id == updatedTransfer.id }) else {
            return
        }

        let previousTransfer = transfers[index]
        transfers[index] = updatedTransfer
        transfers.sort { $0.date > $1.date }

        sync.applyTransferUpdate(from: previousTransfer, to: updatedTransfer, accounts: &moneyAccounts)
        
        let oldFromName = accountName(for: previousTransfer.fromAccountId)
        let oldToName = accountName(for: previousTransfer.toAccountId)
        let newFromName = accountName(for: updatedTransfer.fromAccountId)
        let newToName = accountName(for: updatedTransfer.toAccountId)

        AuditLogStore.shared.logTransferUpdated(
            previousTransfer,
            new: updatedTransfer,
            fromOldName: oldFromName,
            toOldName: oldToName,
            fromNewName: newFromName,
            toNewName: newToName,
            user: auth.currentUser
        )

        onPersistTransfers()
        onPersistMoneyAccounts()
    }

    private func deleteTransfer(_ transfer: AccountTransfer) {
        sync.applyTransferDeletion(transfer, accounts: &moneyAccounts)
        transfers.removeAll { $0.id == transfer.id }
        
        let fromName = accountName(for: transfer.fromAccountId)
        let toName = accountName(for: transfer.toAccountId)

        AuditLogStore.shared.logTransferDeleted(
            transfer,
            fromName: fromName,
            toName: toName,
            user: auth.currentUser
        )

        onPersistTransfers()
        onPersistMoneyAccounts()
    }

    private func accountName(for id: UUID) -> String {
        guard let account = moneyAccounts.first(where: { $0.id == id }) else {
            return settings.language == .spanish ? "Cuenta eliminada" : "Deleted account"
        }

        return account.name
    }
}
