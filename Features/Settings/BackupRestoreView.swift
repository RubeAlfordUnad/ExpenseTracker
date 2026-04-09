import SwiftUI
import UniformTypeIdentifiers

struct BackupRestoreView: View {
    
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings
    
    @State private var exportDocument = ExportFileDocument()
    @State private var showExporter = false
    @State private var showImporter = false
    
    @State private var importedSnapshot: AppBackupSnapshot?
    @State private var showImportConfirmation = false
    
    @State private var successMessage: String?
    @State private var errorMessage: String?
    
    private let service = AppBackupService()
    private let backupRestoreDidComplete = Notification.Name("backupRestoreDidComplete")
    
    private var currentSummary: AppBackupSummary {
        service.currentSummary(for: auth.currentUser)
    }
    
    private var screenTitle: String {
        settings.language == .spanish ? "Respaldo y restauración" : "Backup & restore"
    }
    
    private var currentUserLabel: String {
        auth.isUsingLocalMode
        ? (settings.language == .spanish ? "Modo local" : "Local mode")
        : auth.currentUser
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                heroCard
                currentDataCard
                actionsCard
                restoreNotesCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationTitle(screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: backupFileNameWithoutExtension
        ) { result in
            switch result {
            case .success:
                successMessage = settings.language == .spanish
                ? "Respaldo exportado correctamente."
                : "Backup exported successfully."
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json]
        ) { result in
            handleImport(result)
        }
        .alert(
            settings.language == .spanish ? "Restaurar respaldo" : "Restore backup",
            isPresented: $showImportConfirmation,
            presenting: importedSnapshot
        ) { snapshot in
            Button(settings.t("common.cancel"), role: .cancel) {
                importedSnapshot = nil
            }
            
            Button(settings.language == .spanish ? "Restaurar" : "Restore", role: .destructive) {
                restoreImportedSnapshot(snapshot)
            }
        } message: { snapshot in
            Text(importConfirmationMessage(for: snapshot))
        }
        .alert(
            settings.language == .spanish ? "Respaldo" : "Backup",
            isPresented: Binding(
                get: { successMessage != nil || errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        successMessage = nil
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                successMessage = nil
                errorMessage = nil
            }
        } message: {
            Text(successMessage ?? errorMessage ?? "")
        }
    }
    
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(settings.language == .spanish ? "Seguridad de tus datos" : "Your data safety")
                        .font(.caption.bold())
                        .foregroundColor(BrandPalette.primary)
                    
                    Text(settings.language == .spanish ? "Guarda una copia completa de tu progreso" : "Save a full copy of your progress")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .lineLimit(3)
                        .minimumScaleFactor(0.9)
                    
                    Text(
                        settings.language == .spanish
                        ? "Exporta un archivo JSON con gastos, ingresos, deudas, pagos fijos, cuentas de dinero, presupuesto, preferencias y foto de perfil."
                        : "Export a JSON file with expenses, incomes, debts, recurring payments, money accounts, budget, preferences, and profile image."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Image(systemName: "externaldrive.fill.badge.checkmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(BrandPalette.primary)
                    .frame(width: 54, height: 54)
                    .background(BrandPalette.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            
            HStack(spacing: 8) {
                pill(icon: "person.crop.circle", text: currentUserLabel)
                pill(icon: "doc", text: ".json")
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
    
    private var currentDataCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(settings.language == .spanish ? "Qué se incluirá en el respaldo" : "What will be included in the backup")
                .font(.headline)
            
            summaryGrid(summary: currentSummary)
            
            VStack(alignment: .leading, spacing: 8) {
                summaryRow(labelES: "Cuentas de dinero", labelEN: "Money accounts", value: "\(currentSummary.moneyAccountsCount)")
                summaryRow(labelES: "Presupuesto", labelEN: "Budget", value: currentSummary.hasBudget ? yesText : noText)
                summaryRow(labelES: "Foto de perfil", labelEN: "Profile image", value: currentSummary.hasProfileImage ? yesText : noText)
            }
            .padding(16)
            .background(BrandPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
    
    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.language == .spanish ? "Acciones" : "Actions")
                .font(.headline)
            
            Button {
                exportBackup()
            } label: {
                actionRow(
                    icon: "square.and.arrow.up",
                    title: settings.language == .spanish ? "Exportar respaldo completo" : "Export full backup",
                    subtitle: settings.language == .spanish
                    ? "Genera un archivo JSON para guardarlo en iCloud Drive, Archivos o tu Mac."
                    : "Generate a JSON file to save in iCloud Drive, Files, or your Mac."
                )
            }
            .buttonStyle(.plain)
            
            Button {
                showImporter = true
            } label: {
                actionRow(
                    icon: "square.and.arrow.down",
                    title: settings.language == .spanish ? "Importar y restaurar" : "Import and restore",
                    subtitle: settings.language == .spanish
                    ? "Reemplaza los datos actuales del usuario con el contenido del respaldo."
                    : "Replace the current user data with the content of the backup."
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var restoreNotesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.language == .spanish ? "Antes de restaurar" : "Before restoring")
                .font(.headline)
            
            noteRow(
                icon: "exclamationmark.triangle",
                textES: "La restauración reemplaza gastos, ingresos, deudas, pagos fijos, cuentas de dinero, presupuesto, preferencias y foto de perfil del usuario actual.",
                textEN: "Restoring replaces the current user's expenses, incomes, debts, recurring payments, money accounts, budget, preferences, and profile image."
            )
            
            noteRow(
                icon: "clock.arrow.circlepath",
                textES: "Haz un respaldo actual antes de importar otro archivo, por si quieres volver atrás.",
                textEN: "Create a fresh backup before importing another file, in case you want to roll back."
            )
            
            noteRow(
                icon: "bell.badge",
                textES: "Después de restaurar, la app vuelve a sincronizar los recordatorios de pagos fijos.",
                textEN: "After restoring, the app syncs recurring payment reminders again."
            )
        }
        .padding(18)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private var backupFileNameWithoutExtension: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return "nexora_backup_\(formatter.string(from: Date()))"
    }
    
    private var yesText: String {
        settings.language == .spanish ? "Sí" : "Yes"
    }
    
    private var noText: String {
        settings.language == .spanish ? "No" : "No"
    }
    
    private func summaryGrid(summary: AppBackupSummary) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statCard(titleES: "Gastos", titleEN: "Expenses", value: "\(summary.expensesCount)", accent: .red)
                statCard(titleES: "Ingresos", titleEN: "Incomes", value: "\(summary.incomesCount)", accent: .green)
            }
            
            HStack(spacing: 12) {
                statCard(titleES: "Deudas", titleEN: "Debts", value: "\(summary.debtsCount)", accent: .orange)
                statCard(titleES: "Pagos fijos", titleEN: "Recurring", value: "\(summary.recurringPaymentsCount)", accent: .blue)
            }
            
            HStack(spacing: 12) {
                statCard(titleES: "Cuentas", titleEN: "Accounts", value: "\(summary.moneyAccountsCount)", accent: .mint)
                statCard(titleES: "Transferencias", titleEN: "Transfers", value: "\(summary.accountTransfersCount)", accent: .purple)
            }
        }
    }
    
    private func statCard(titleES: String, titleEN: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(settings.language == .spanish ? titleES : titleEN)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2.bold())
            
            RoundedRectangle(cornerRadius: 999)
                .fill(accent.opacity(0.24))
                .frame(width: 40, height: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(BrandPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private func actionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(BrandPalette.primary)
                .frame(width: 22)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private func noteRow(icon: String, textES: String, textEN: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(BrandPalette.primary)
                .frame(width: 18)
            
            Text(settings.language == .spanish ? textES : textEN)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func summaryRow(labelES: String, labelEN: String, value: String) -> some View {
        HStack {
            Text(settings.language == .spanish ? labelES : labelEN)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
        }
    }
    
    private func pill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(BrandPalette.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(BrandPalette.primary.opacity(0.12))
        .clipShape(Capsule())
    }
    
    private func exportBackup() {
        do {
            let payload = try service.makeExport(for: auth.currentUser)
            exportDocument = ExportFileDocument(data: payload.data, contentType: payload.contentType)
            showExporter = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            let data = try Data(contentsOf: url)
            let snapshot = try service.importSnapshot(from: data)
            importedSnapshot = snapshot
            showImportConfirmation = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func restoreImportedSnapshot(_ snapshot: AppBackupSnapshot) {
        do {
            try service.restore(snapshot, to: auth.currentUser)
            NotificationManager.shared.syncRecurringPaymentNotifications(for: auth.currentUser)
            NotificationCenter.default.post(name: backupRestoreDidComplete, object: nil)
            
            importedSnapshot = nil
            successMessage = settings.language == .spanish
            ? "Respaldo restaurado correctamente."
            : "Backup restored successfully."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func importConfirmationMessage(for snapshot: AppBackupSnapshot) -> String {
        let summary = service.summary(for: snapshot)
        let dateText = settings.shortDateString(from: snapshot.exportedAt)
        
        if settings.language == .spanish {
            return "Archivo de \(snapshot.sourceUser) · \(dateText)\n\nSe importarán \(summary.expensesCount) gastos, \(summary.incomesCount) ingresos, \(summary.debtsCount) deudas, \(summary.recurringPaymentsCount) pagos fijos, \(summary.moneyAccountsCount) cuentas de dinero y \(summary.accountTransfersCount) transferencias.\n\nEsto reemplazará los datos actuales del usuario \"\(currentUserLabel)\"."
        } else {
            return "File from \(snapshot.sourceUser) · \(dateText)\n\nThis will import \(summary.expensesCount) expenses, \(summary.incomesCount) incomes, \(summary.debtsCount) debts, \(summary.recurringPaymentsCount) recurring payments, \(summary.moneyAccountsCount) money accounts, and \(summary.accountTransfersCount) transfers.\n\nThis will replace the current data for user \"\(currentUserLabel)\"."
        }
    }
}
