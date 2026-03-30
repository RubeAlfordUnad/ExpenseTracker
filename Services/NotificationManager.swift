import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    private let recurringNotificationHour = 9
    private let recurringNotificationMinute = 0
    private let recurringMonthsAhead = 12

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error {
                AppLogger.debug("Error solicitando permisos: \(error.localizedDescription)")
                completion?(false)
                return
            }

            AppLogger.debug("Permisos de notificación: \(granted)")
            completion?(granted)
        }
    }

    func getAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    func testNotification() {
        let content = UNMutableNotificationContent()
        content.title = AppMetadata.displayName
        content.body = localizedText(spanish: "Esta es una notificación de prueba.", english: "This is a test notification.")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                AppLogger.debug("Error enviando notificación de prueba: \(error.localizedDescription)")
            } else {
                AppLogger.debug("Notificación de prueba programada")
            }
        }
    }

    func notifyBudgetThresholdReached(progress: Double) {
        let percentage = Int(progress * 100)

        let content = UNMutableNotificationContent()
        content.title = localizedText(spanish: "Alerta de presupuesto", english: "Budget alert")
        content.body = localizedText(
            spanish: "Ya alcanzaste el \(percentage)% de tu presupuesto mensual.",
            english: "You already reached \(percentage)% of your monthly budget."
        )
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "budget_threshold_notification",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func notifyBudgetExceeded() {
        let content = UNMutableNotificationContent()
        content.title = localizedText(spanish: "Presupuesto superado", english: "Budget exceeded")
        content.body = localizedText(
            spanish: "Ya superaste el 100% de tu presupuesto mensual.",
            english: "You already exceeded 100% of your monthly budget."
        )
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "budget_exceeded_notification",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func scheduleRecurringPaymentNotifications(_ payment: RecurringPayment) {
        guard payment.isActive else { return }

        let now = Date()
        let calendar = Calendar.current
        let center = UNUserNotificationCenter.current()

        for monthOffset in 0..<recurringMonthsAhead {
            guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: now),
                  let dueDate = payment.dueDate(
                    inMonthOf: monthDate,
                    hour: recurringNotificationHour,
                    minute: recurringNotificationMinute,
                    calendar: calendar
                  ) else {
                continue
            }

            guard dueDate > now else { continue }

            let year = calendar.component(.year, from: dueDate)
            let month = calendar.component(.month, from: dueDate)

            let content = UNMutableNotificationContent()
            content.title = localizedText(spanish: "Pago pendiente", english: "Payment due")
            content.body = localizedText(
                spanish: "\(payment.title) vence hoy.",
                english: "\(payment.title) is due today."
            )
            content.sound = .default

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: recurringNotificationIdentifier(
                    paymentID: payment.id,
                    year: year,
                    month: month
                ),
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error {
                    AppLogger.debug("Error programando recurrente \(payment.title): \(error.localizedDescription)")
                }
            }
        }
    }

    func cancelNotification(for payment: RecurringPayment) {
        removeRecurringNotifications(for: [payment.id])
    }

    func cancelNotifications(for payments: [RecurringPayment]) {
        removeRecurringNotifications(for: payments.map(\.id))
    }

    func syncRecurringPaymentNotifications(for user: String) {
        let cleanUser = user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUser.isEmpty else {
            AppLogger.debug("syncRecurringPaymentNotifications: usuario vacío")
            return
        }

        let preferences = DataManager.shared.loadNotificationPreferences(user: cleanUser)
        let payments = DataManager.shared.loadRecurringPayments(user: cleanUser)

        syncRecurringPaymentNotifications(
            payments,
            isEnabled: preferences.recurringPaymentsEnabled
        )
    }

    func syncRecurringPaymentNotifications(
        _ payments: [RecurringPayment],
        isEnabled: Bool
    ) {
        removeRecurringNotifications(for: payments.map(\.id)) { [weak self] in
            guard let self else { return }

            guard isEnabled else {
                AppLogger.debug("Notificaciones recurrentes desactivadas. No se reprograma nada.")
                return
            }

            self.getAuthorizationStatus { status in
                guard self.canScheduleNotifications(for: status) else {
                    AppLogger.debug("No se programan recurrentes: permisos no concedidos (\(status.rawValue)).")
                    return
                }

                let activePayments = payments.filter(\.isActive)

                for payment in activePayments {
                    self.scheduleRecurringPaymentNotifications(payment)
                }
            }
        }
    }

    func cancelBudgetNotifications() {
        let identifiers = [
            "budget_threshold_notification",
            "budget_exceeded_notification"
        ]

        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)

        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func debugPrintPendingRequests() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            AppLogger.debug("=== PENDING NOTIFICATIONS ===")
            AppLogger.debug("Total pendientes: \(requests.count)")

            for request in requests {
                AppLogger.debug("- id: \(request.identifier)")
                AppLogger.debug("  title: \(request.content.title)")
                AppLogger.debug("  body: \(request.content.body)")
            }

            if requests.isEmpty {
                AppLogger.debug("No hay notificaciones pendientes.")
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }


    private var notificationLanguage: AppLanguage {
        if let rawValue = UserDefaults.standard.string(forKey: "app_language"),
           let language = AppLanguage(rawValue: rawValue) {
            return language
        }

        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferredLanguage.hasPrefix("en") ? .english : .spanish
    }

    private func localizedText(spanish: String, english: String) -> String {
        notificationLanguage == .english ? english : spanish
    }

    private func canScheduleNotifications(for status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func recurringNotificationPrefix(for paymentID: UUID) -> String {
        "recurring_payment_\(paymentID.uuidString)_"
    }

    private func recurringNotificationIdentifier(paymentID: UUID, year: Int, month: Int) -> String {
        let monthString = String(format: "%02d", month)
        return "\(recurringNotificationPrefix(for: paymentID))\(year)_\(monthString)"
    }

    private func removeRecurringNotifications(for paymentIDs: [UUID], completion: (() -> Void)? = nil) {
        let prefixes = paymentIDs.map { recurringNotificationPrefix(for: $0) }

        guard !prefixes.isEmpty else {
            completion?()
            return
        }

        let center = UNUserNotificationCenter.current()

        center.getPendingNotificationRequests { requests in
            let pendingIdentifiers = requests
                .map(\.identifier)
                .filter { identifier in
                    prefixes.contains { identifier.hasPrefix($0) }
                }

            center.getDeliveredNotifications { notifications in
                let deliveredIdentifiers = notifications
                    .map(\.request.identifier)
                    .filter { identifier in
                        prefixes.contains { identifier.hasPrefix($0) }
                    }

                if !pendingIdentifiers.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)
                }

                if !deliveredIdentifiers.isEmpty {
                    center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
                }

                completion?()
            }
        }
    }
}
