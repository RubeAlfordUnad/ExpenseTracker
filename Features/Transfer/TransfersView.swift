import SwiftUI

struct TransfersView: View {

    @EnvironmentObject private var settings: AppSettings

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

    var body: some View {
        List {
            Section {
                HStack {
                    Text(settings.language == .spanish ? "Transferencias este mes" : "Transfers this month")
                    Spacer()
                    Text("\(currentMonthTransfers.count)")
                        .fontWeight(.semibold)
                }

                HStack {
                    Text(settings.language == .spanish ? "Monto movido" : "Amount moved")
                    Spacer()
                    Text(settings.secureCurrency(currentMonthTransferVolume))
                        .fontWeight(.semibold)
                }
            }

            if !canCreateTransfers {
                Section {
                    Text(
                        settings.language == .spanish
                        ? "Necesitas al menos dos cuentas de dinero para poder transferir entre ellas."
                        : "You need at least two money accounts to transfer between them."
                    )
                    .foregroundColor(.secondary)
                }
            }

            Section(settings.language == .spanish ? "Historial de transferencias" : "Transfer history") {
                if sortedTransfers.isEmpty {
                    Text(
                        settings.language == .spanish
                        ? "Aún no has registrado transferencias."
                        : "You have not recorded transfers yet."
                    )
                    .foregroundColor(.secondary)
                } else {
                    ForEach(sortedTransfers) { transfer in
                        Button {
                            editingTransfer = transfer
                        } label: {
                            transferRow(transfer)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                editingTransfer = transfer
                            } label: {
                                Label(
                                    settings.language == .spanish ? "Editar" : "Edit",
                                    systemImage: "pencil"
                                )
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                pendingDelete = transfer
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
        }
        .navigationTitle(settings.language == .spanish ? "Transferencias" : "Transfers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canCreateTransfers {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
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
        .confirmationDialog(
            settings.language == .spanish ? "Eliminar transferencia" : "Delete transfer",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDelete = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let pendingDelete {
                Button(
                    settings.language == .spanish ? "Eliminar" : "Delete",
                    role: .destructive
                ) {
                    deleteTransfer(pendingDelete)
                    self.pendingDelete = nil
                }
            }

            Button(settings.language == .spanish ? "Cancelar" : "Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text(
                settings.language == .spanish
                ? "Se revertirán los saldos afectados por esta transferencia."
                : "This will revert the balances affected by this transfer."
            )
        }
    }

    private func updateTransfer(_ updatedTransfer: AccountTransfer) {
        guard let index = transfers.firstIndex(where: { $0.id == updatedTransfer.id }) else {
            return
        }

        let previousTransfer = transfers[index]
        transfers[index] = updatedTransfer
        transfers.sort { $0.date > $1.date }

        sync.applyTransferUpdate(from: previousTransfer, to: updatedTransfer, accounts: &moneyAccounts)

        onPersistTransfers()
        onPersistMoneyAccounts()
    }

    private func deleteTransfer(_ transfer: AccountTransfer) {
        sync.applyTransferDeletion(transfer, accounts: &moneyAccounts)
        transfers.removeAll { $0.id == transfer.id }

        onPersistTransfers()
        onPersistMoneyAccounts()
    }

    @ViewBuilder
    private func transferRow(_ transfer: AccountTransfer) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.14))
                    .frame(width: 40, height: 40)

                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(accountName(for: transfer.fromAccountId)) → \(accountName(for: transfer.toAccountId))")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(settings.shortDateString(from: transfer.date))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let note = transfer.normalizedNote {
                    Text(note)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(settings.secureCurrency(transfer.amount))
                .font(.subheadline.bold())
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 4)
    }

    private func accountName(for id: UUID) -> String {
        guard let account = moneyAccounts.first(where: { $0.id == id }) else {
            return settings.language == .spanish ? "Cuenta eliminada" : "Deleted account"
        }

        return account.name
    }
}
