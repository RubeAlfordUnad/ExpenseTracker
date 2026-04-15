import SwiftUI

struct ActivityLogView: View {
    
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings
    
    @State private var entries: [AuditLogEntry] = []
    @State private var showClearAlert = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                
                if entries.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(entries) { entry in
                            entryCard(entry)
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationTitle(screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(clearTitle, role: .destructive) {
                        showClearAlert = true
                    }
                }
            }
        }
        .alert(clearTitle, isPresented: $showClearAlert) {
            Button(settings.t("common.cancel"), role: .cancel) { }
            Button(clearTitle, role: .destructive) {
                AuditLogStore.shared.clear(user: auth.currentUser)
                reload()
            }
        } message: {
            Text(clearMessage)
        }
        .onAppear {
            reload()
        }
    }
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BrandPalette.primary.opacity(0.12))
                        .frame(width: 54, height: 54)
                    
                    Image(systemName: "list.clipboard")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(BrandPalette.primary)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(screenTitle)
                        .font(.title2.bold())
                    
                    Text(
                        settings.language == .spanish
                        ? "Aquí se registran cambios importantes sobre valores y movimientos financieros."
                        : "Important changes to values and financial records are tracked here."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            
            HStack(spacing: 8) {
                summaryChip(
                    text: settings.language == .spanish
                    ? "\(entries.count) eventos guardados"
                    : "\(entries.count) saved events"
                )
                
                if let latest = entries.first {
                    summaryChip(
                        text: latest.action.title(language: settings.language)
                    )
                }
            }
        }
        .padding(18)
        .background(BrandPalette.heroGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text(
                settings.language == .spanish ? "Aún no hay cambios registrados" : "No tracked changes yet"
            )
            .font(.headline)
            
            Text(
                settings.language == .spanish
                ? "Cuando crees, edites o elimines movimientos con valores, aparecerán aquí."
                : "When you create, edit, or delete value-based records, they will appear here."
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    private func entryCard(_ entry: AuditLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(actionTint(for: entry).opacity(0.14))
                        .frame(width: 46, height: 46)
                    
                    Image(systemName: entry.entity.icon)
                        .foregroundColor(actionTint(for: entry))
                        .font(.headline.weight(.semibold))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        actionBadge(for: entry)
                        entityBadge(for: entry)
                    }
                    
                    Text(entry.title)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(dateText(for: entry.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 10) {
                if let resolvedOriginalValue = (entry.originalValue?.isEmpty == false ? entry.originalValue : entry.previousValue),
                   !resolvedOriginalValue.isEmpty {
                    infoBlock(
                        title: settings.language == .spanish ? "Original" : "Original",
                        value: resolvedOriginalValue,
                        timestamp: entry.originalTimestamp ?? entry.previousTimestamp ?? entry.timestamp,
                        tint: .blue
                    )
                }
                
                if let previousValue = entry.previousValue, !previousValue.isEmpty {
                    infoBlock(
                        title: settings.language == .spanish ? "Antes" : "Before",
                        value: previousValue,
                        timestamp: entry.previousTimestamp ?? entry.timestamp,
                        tint: .orange
                    )
                }
                
                if let newValue = entry.newValue, !newValue.isEmpty {
                    infoBlock(
                        title: settings.language == .spanish ? "Después" : "After",
                        value: newValue,
                        timestamp: entry.newTimestamp ?? entry.timestamp,
                        tint: .green
                    )
                }
                
                if entry.originalValue == nil && entry.previousValue == nil && entry.newValue == nil {
                    infoBlock(
                        title: settings.language == .spanish ? "Registro" : "Record",
                        value: entry.detail,
                        timestamp: entry.timestamp,
                        tint: BrandPalette.primary
                    )
                }
                
                if let note = entry.note, !note.isEmpty {
                    infoBlock(
                        title: settings.language == .spanish ? "Nota" : "Note",
                        value: note,
                        timestamp: entry.timestamp,
                        tint: .purple
                    )
                }
            }
        }
        .padding(16)
        .background(BrandPalette.cardGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    
    private func infoBlock(title: String, value: String, timestamp: Date, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
                
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text(blockTimestampText(for: timestamp))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.10))
                    .clipShape(Capsule())
            }
            
            Text(value)
                .font(.footnote)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(BrandPalette.surface.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func actionBadge(for entry: AuditLogEntry) -> some View {
        Text(entry.action.title(language: settings.language))
            .font(.caption.weight(.semibold))
            .foregroundColor(actionTint(for: entry))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(actionTint(for: entry).opacity(0.12))
            .clipShape(Capsule())
    }
    
    private func entityBadge(for entry: AuditLogEntry) -> some View {
        Text(entry.entity.title(language: settings.language))
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(BrandPalette.surfaceRaised)
            .clipShape(Capsule())
    }
    
    private func summaryChip(text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(BrandPalette.surfaceRaised)
            .clipShape(Capsule())
    }
    
    private func actionTint(for entry: AuditLogEntry) -> Color {
        switch entry.action {
        case .created:
            return .green
        case .updated:
            return BrandPalette.primary
        case .deleted:
            return .red
        case .markedPaid:
            return .green
        case .markedUnpaid:
            return .orange
        case .paymentApplied:
            return .blue
        }
    }
    
    private func reload() {
        entries = AuditLogStore.shared.loadEntries(user: auth.currentUser)
    }
    
    private func dateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = settings.appLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func blockTimestampText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = settings.appLocale
        formatter.dateFormat = settings.language == .spanish ? "h:mm:ss a" : "h:mm:ss a"
        return formatter.string(from: date)
    }
    
    private var screenTitle: String {
        settings.language == .spanish ? "Logs de actividad" : "Activity log"
    }

    private var clearTitle: String {
        settings.language == .spanish ? "Limpiar logs" : "Clear logs"
    }

    private var clearMessage: String {
        settings.language == .spanish
        ? "Esto eliminará el historial de cambios guardado para esta cuenta en este dispositivo."
        : "This will remove the saved change history for this account on this device."
    }
}
