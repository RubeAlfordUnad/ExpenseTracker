import SwiftUI
import UserNotifications
import UIKit

struct NotificationSettingsView: View {

    private let notificationPreferencesDidChange = Notification.Name("notificationPreferencesDidChange")

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    @State private var recurringPayments = true
    @State private var recurringLeadDays = 0
    @State private var budgetAlerts = true
    @State private var budgetThreshold = 0.80
    @State private var dailySummary = false
    @State private var authorizationText = ""
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(settings.t("notifications.state"))
                    Spacer()
                    Text(authorizationText)
                        .foregroundColor(.secondary)
                }

                Button(settings.t("notifications.request")) {
                    NotificationManager.shared.requestPermission { granted in
                        DispatchQueue.main.async {
                            authorizationText = granted
                            ? settings.t("notifications.status.allowed")
                            : settings.t("notifications.status.denied")

                            loadAuthorizationStatus()

                            guard granted else { return }

                            NotificationManager.shared.syncRecurringPaymentNotifications(for: auth.currentUser)
                            NotificationCenter.default.post(name: notificationPreferencesDidChange, object: nil)
                        }
                    }
                }

                Button(settings.t("notifications.test")) {
                    NotificationManager.shared.testNotification()
                }

                if authorizationStatus == .denied {
                    Button(openSystemSettingsTitle) {
                        openSystemSettings()
                    }
                }
            } header: {
                Text(settings.t("notifications.permissions"))
            }

            Section {
                Toggle(settings.t("notifications.recurringToggle"), isOn: $recurringPayments)
                    .onChange(of: recurringPayments) { _, newValue in
                        savePreferences(recurringPaymentsEnabled: newValue)
                    }

                Picker(recurringLeadPickerTitle, selection: $recurringLeadDays) {
                    Text(leadDaysLabel(0)).tag(0)
                    Text(leadDaysLabel(1)).tag(1)
                    Text(leadDaysLabel(2)).tag(2)
                    Text(leadDaysLabel(3)).tag(3)
                }
                .disabled(!recurringPayments)
                .onChange(of: recurringLeadDays) { _, newValue in
                    savePreferences(recurringReminderLeadDays: newValue)
                }
            } header: {
                Text(settings.t("notifications.recurring"))
            } footer: {
                Text(recurringFooterText)
            }

            Section {
                Toggle(settings.t("notifications.budgetToggle"), isOn: $budgetAlerts)
                    .onChange(of: budgetAlerts) { _, newValue in
                        savePreferences(budgetAlertsEnabled: newValue)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text(settings.tr("notifications.threshold", Int(budgetThreshold * 100)))

                    Slider(value: $budgetThreshold, in: 0.10...0.99, step: 0.01)
                        .disabled(!budgetAlerts)
                        .onChange(of: budgetThreshold) { _, newValue in
                            savePreferences(budgetAlertThreshold: newValue)
                        }
                }
            } header: {
                Text(settings.t("notifications.budget"))
            }

            Section {
                Toggle(dailySummaryTitle, isOn: $dailySummary)
                    .onChange(of: dailySummary) { _, newValue in
                        savePreferences(dailySummaryEnabled: newValue)
                    }
            } header: {
                Text(dailySummarySectionTitle)
            } footer: {
                Text(dailySummaryFooterText)
            }
        }
        .navigationTitle(settings.t("notifications.title"))
        .onAppear {
            authorizationText = settings.t("notifications.status.unverified")
            loadPreferences()
            loadAuthorizationStatus()
        }
    }

    private var recurringLeadPickerTitle: String {
        settings.language == .spanish ? "Avisar con anticipación" : "Remind me before due date"
    }

    private var recurringFooterText: String {
        settings.language == .spanish
        ? "Esto cambia cuándo llega el recordatorio de cada pago recurrente."
        : "This changes when each recurring payment reminder is delivered."
    }

    private var dailySummarySectionTitle: String {
        settings.language == .spanish ? "Resumen diario" : "Daily review"
    }

    private var dailySummaryTitle: String {
        settings.language == .spanish ? "Recordarme revisar el día" : "Remind me to review the day"
    }

    private var dailySummaryFooterText: String {
        settings.language == .spanish
        ? "Se enviará una notificación diaria en la noche para revisar ingresos, gastos y presupuesto."
        : "A nightly reminder will be sent so you can review income, expenses, and budget."
    }

    private var openSystemSettingsTitle: String {
        settings.language == .spanish ? "Abrir Ajustes del sistema" : "Open system settings"
    }

    private func leadDaysLabel(_ value: Int) -> String {
        switch (settings.language, value) {
        case (.spanish, 0):
            return "El mismo día"
        case (.spanish, 1):
            return "1 día antes"
        case (.spanish, 2):
            return "2 días antes"
        case (.spanish, 3):
            return "3 días antes"
        case (.english, 0):
            return "Same day"
        case (.english, 1):
            return "1 day before"
        case (.english, 2):
            return "2 days before"
        default:
            return "3 days before"
        }
    }

    private func loadPreferences() {
        let preferences = DataManager.shared.loadNotificationPreferences(user: auth.currentUser)
        recurringPayments = preferences.recurringPaymentsEnabled
        recurringLeadDays = preferences.recurringReminderLeadDays
        budgetAlerts = preferences.budgetAlertsEnabled
        budgetThreshold = preferences.budgetAlertThreshold
        dailySummary = preferences.dailySummaryEnabled
    }

    private func savePreferences(
        recurringPaymentsEnabled: Bool? = nil,
        recurringReminderLeadDays: Int? = nil,
        budgetAlertsEnabled: Bool? = nil,
        budgetAlertThreshold: Double? = nil,
        dailySummaryEnabled: Bool? = nil
    ) {
        var current = DataManager.shared.loadNotificationPreferences(user: auth.currentUser)

        if let recurringPaymentsEnabled {
            current.recurringPaymentsEnabled = recurringPaymentsEnabled
        }

        if let recurringReminderLeadDays {
            current.recurringReminderLeadDays = min(max(recurringReminderLeadDays, 0), 3)
        }

        if let budgetAlertsEnabled {
            current.budgetAlertsEnabled = budgetAlertsEnabled
        }

        if let budgetAlertThreshold {
            current.budgetAlertThreshold = budgetAlertThreshold
        }

        if let dailySummaryEnabled {
            current.dailySummaryEnabled = dailySummaryEnabled
        }

        DataManager.shared.saveNotificationPreferences(current, user: auth.currentUser)

        if recurringPaymentsEnabled != nil || recurringReminderLeadDays != nil || dailySummaryEnabled != nil {
            NotificationManager.shared.syncRecurringPaymentNotifications(for: auth.currentUser)
        }

        if budgetAlertsEnabled == false {
            NotificationManager.shared.cancelBudgetNotifications()
        }

        if budgetAlertsEnabled != nil || budgetAlertThreshold != nil {
            NotificationCenter.default.post(name: notificationPreferencesDidChange, object: nil)
        }
    }

    private func loadAuthorizationStatus() {
        NotificationManager.shared.getAuthorizationStatus { status in
            DispatchQueue.main.async {
                authorizationStatus = status

                switch status {
                case .notDetermined:
                    authorizationText = settings.t("notifications.status.notRequested")
                case .denied:
                    authorizationText = settings.t("notifications.status.denied")
                case .authorized:
                    authorizationText = settings.t("notifications.status.allowed")
                case .provisional:
                    authorizationText = settings.t("notifications.status.provisional")
                case .ephemeral:
                    authorizationText = settings.t("notifications.status.temporary")
                @unknown default:
                    authorizationText = settings.t("notifications.status.unknown")
                }
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
