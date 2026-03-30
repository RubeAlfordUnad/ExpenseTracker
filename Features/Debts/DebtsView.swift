import SwiftUI
import UniformTypeIdentifiers

struct DebtsView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    @State private var debts: [Debt] = []
    @State private var showEditor = false
    @State private var editingDebt: Debt?
    @State private var debtPendingDelete: Debt?

    @State private var exportDocument = ExportFileDocument()
    @State private var exportContentType: UTType = .json
    @State private var exportFilename = "wallet_cards.json"
    @State private var showExporter = false
    @State private var exportErrorMessage: String?
		
    private let exportService = DebtsExportService()

    private var totalDebt: Double {
        debts.reduce(0) { $0 + $1.remainingDebt }
    }

    private var totalLimit: Double {
        debts.reduce(0) { $0 + $1.totalLimit }
    }

    private var totalAvailableCredit: Double {
        debts.reduce(0) { $0 + $1.availableCredit }
    }

    private var averageUsage: Double {
        guard totalLimit > 0 else { return 0 }
        return totalDebt / totalLimit
    }

    private var mostExpensiveDebt: Debt? {
        debts.max { $0.remainingDebt < $1.remainingDebt }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    walletHeroCard
                    walletStatsSection
                    walletSectionHeader

                    if debts.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(debts.indices), id: \.self) { index in
                                DebtCard(
                                    debt: $debts[index],
                                    onEdit: {
                                        startEditing(debts[index])
                                    },
                                    onDelete: {
                                        debtPendingDelete = debts[index]
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
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
                settings.language == .spanish ? "Eliminar tarjeta" : "Delete card",
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
                    Text(settings.language == .spanish ? "Wallet" : "Wallet")
                        .font(.caption.bold())
                        .foregroundColor(BrandPalette.primary)

                    Text(settings.language == .spanish ? "Mis tarjetas" : "My cards")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(
                        settings.language == .spanish
                        ? "Controla deuda, cupo disponible y exporta tu wallet cuando lo necesites."
                        : "Track debt, available credit and export your wallet whenever you need it."
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
                        icon: "creditcard",
                        text: settings.language == .spanish
                        ? "\(debts.count) tarjetas"
                        : "\(debts.count) cards"
                    )

                    infoPill(
                        icon: "exclamationmark.triangle",
                        text: mostExpensiveDebt?.cardName ?? (
                            settings.language == .spanish ? "Sin deuda alta" : "No high balance"
                        )
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    infoPill(
                        icon: "creditcard",
                        text: settings.language == .spanish
                        ? "\(debts.count) tarjetas"
                        : "\(debts.count) cards"
                    )

                    infoPill(
                        icon: "exclamationmark.triangle",
                        text: mostExpensiveDebt?.cardName ?? (
                            settings.language == .spanish ? "Sin deuda alta" : "No high balance"
                        )
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
        HStack(spacing: 12) {
            statCard(
                title: settings.language == .spanish ? "Total adeudado" : "Total debt",
                value: money(totalDebt),
                accent: .red
            )

            statCard(
                title: settings.language == .spanish ? "Disponible" : "Available",
                value: money(totalAvailableCredit),
                accent: BrandPalette.primary
            )
        }
    }

    private var walletSectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(settings.language == .spanish ? "Tus tarjetas" : "Your cards")
                    .font(.headline)

                Text(
                    settings.language == .spanish
                    ? "Uso promedio del cupo: \(Int((averageUsage * 100).rounded()))%"
                    : "Average credit usage: \(Int((averageUsage * 100).rounded()))%"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(debts.count)")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(BrandPalette.surface)
                .clipShape(Capsule())
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "creditcard")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text(
                settings.language == .spanish
                ? "Todavía no tienes tarjetas"
                : "You do not have cards yet"
            )
            .font(.headline)

            Text(
                settings.language == .spanish
                ? "Agrega tu primera tarjeta para empezar a controlar deuda, cupo y pagos desde un solo lugar."
                : "Add your first card to start tracking debt, credit and payments in one place."
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)

            Button {
                startCreatingDebt()
            } label: {
                Label(
                    settings.language == .spanish ? "Agregar tarjeta" : "Add card",
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
            debts[index] = savedDebt
        } else {
            debts.append(savedDebt)
        }
    }

    private func removeDebt(_ debt: Debt) {
        debts.removeAll { $0.id == debt.id }
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
