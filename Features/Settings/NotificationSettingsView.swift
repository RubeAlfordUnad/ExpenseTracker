import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {

    private let notificationPreferencesDidChange = Notification.Name("notificationPreferencesDidChange")

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    @State private var recurringPayments = true
    @State private var budgetAlerts = true
    @State private var budgetThreshold = 0.80
    @State private var authorizationText = ""

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

                            guard granted else { return }

                            NotificationManager.shared.syncRecurringPaymentNotifications(for: auth.currentUser)
                            NotificationCenter.default.post(name: notificationPreferencesDidChange, object: nil)
                        }
                    }
                }

                Button(settings.t("notifications.test")) {
                    NotificationManager.shared.testNotification()
                }
            } header: {
                Text(settings.t("notifications.permissions"))
            }

            Section {
                Toggle(settings.t("notifications.recurringToggle"), isOn: $recurringPayments)
                    .onChange(of: recurringPayments) { _, newValue in
                        savePreferences(recurringPaymentsEnabled: newValue)
                    }
            } header: {
                Text(settings.t("notifications.recurring"))
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
        }
        .navigationTitle(settings.t("notifications.title"))
        .onAppear {
            authorizationText = settings.t("notifications.status.unverified")
            loadPreferences()
            loadAuthorizationStatus()
        }
    }

    private func loadPreferences() {
        let preferences = DataManager.shared.loadNotificationPreferences(user: auth.currentUser)
        recurringPayments = preferences.recurringPaymentsEnabled
        budgetAlerts = preferences.budgetAlertsEnabled
        budgetThreshold = preferences.budgetAlertThreshold
    }

    private func savePreferences(
        recurringPaymentsEnabled: Bool? = nil,
        budgetAlertsEnabled: Bool? = nil,
        budgetAlertThreshold: Double? = nil
    ) {
        var current = DataManager.shared.loadNotificationPreferences(user: auth.currentUser)

        if let recurringPaymentsEnabled {
            current.recurringPaymentsEnabled = recurringPaymentsEnabled
        }

        if let budgetAlertsEnabled {
            current.budgetAlertsEnabled = budgetAlertsEnabled
        }

        if let budgetAlertThreshold {
            current.budgetAlertThreshold = budgetAlertThreshold
        }

        DataManager.shared.saveNotificationPreferences(current, user: auth.currentUser)

        if recurringPaymentsEnabled != nil {
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
}
