import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    private let recurringNotificationHour = 9
    private let recurringNotificationMinute = 0
    private let recurringMonthsAhead = 12

    private let dailySummaryHour = 20
    private let dailySummaryMinute = 30
    private let dailySummaryIdentifier = "daily_summary_notification"

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
        content.body = localizedText(
            spanish: "Todo listo. Nexora puede recordarte pagos próximos y tu revisión diaria.",
            english: "All set. Nexora can remind you about upcoming payments and your daily review."
        )
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
        scheduleRecurringPaymentNotifications(payment, leadDays: 0)
    }

    func cancelNotification(for payment: RecurringPayment) {
        removeRecurringNotifications(for: [payment.id])
    }

    func cancelNotifications(for payments: [RecurringPayment]) {
        removeRecurringNotifications(for: payments.map(\.id))
        cancelDailySummaryNotifications()
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
            isEnabled: preferences.recurringPaymentsEnabled,
            leadDays: preferences.recurringReminderLeadDays
        )

        syncDailySummaryNotification(isEnabled: preferences.dailySummaryEnabled)
    }

    func syncRecurringPaymentNotifications(
        _ payments: [RecurringPayment],
        isEnabled: Bool
    ) {
        syncRecurringPaymentNotifications(payments, isEnabled: isEnabled, leadDays: 0)
    }

    func cancelDailySummaryNotifications() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [dailySummaryIdentifier])

        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [dailySummaryIdentifier])
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
        [.banner, .sound, .badge]
    }

    private func syncRecurringPaymentNotifications(
        _ payments: [RecurringPayment],
        isEnabled: Bool,
        leadDays: Int
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
                let normalizedLeadDays = self.normalizedLeadDays(leadDays)

                for payment in activePayments {
                    self.scheduleRecurringPaymentNotifications(payment, leadDays: normalizedLeadDays)
                }
            }
        }
    }

    private func syncDailySummaryNotification(isEnabled: Bool) {
        cancelDailySummaryNotifications()

        guard isEnabled else {
            return
        }

        getAuthorizationStatus { [weak self] status in
            guard let self else { return }

            guard self.canScheduleNotifications(for: status) else {
                AppLogger.debug("No se programa resumen diario: permisos no concedidos (\(status.rawValue)).")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = self.localizedText(
                spanish: "Revisión rápida del día",
                english: "Quick daily review"
            )
            content.body = self.localizedText(
                spanish: "Abre Nexora y revisa ingresos, gastos y presupuesto antes de cerrar el día.",
                english: "Open Nexora and review income, expenses, and budget before ending the day."
            )
            content.sound = .default

            var components = DateComponents()
            components.hour = self.dailySummaryHour
            components.minute = self.dailySummaryMinute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: self.dailySummaryIdentifier,
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    AppLogger.debug("Error programando resumen diario: \(error.localizedDescription)")
                }
            }
        }
    }

    private func scheduleRecurringPaymentNotifications(_ payment: RecurringPayment, leadDays: Int) {
        guard payment.isActive else { return }

        let now = Date()
        let calendar = Calendar.current
        let center = UNUserNotificationCenter.current()
        let normalizedLeadDays = normalizedLeadDays(leadDays)

        for monthOffset in 0..<recurringMonthsAhead {
            guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: now),
                  let dueDate = payment.dueDate(
                    inMonthOf: monthDate,
                    hour: recurringNotificationHour,
                    minute: recurringNotificationMinute,
                    calendar: calendar
                  ),
                  let reminderDate = calendar.date(byAdding: .day, value: -normalizedLeadDays, to: dueDate) else {
                continue
            }

            guard reminderDate > now else { continue }

            let year = calendar.component(.year, from: dueDate)
            let month = calendar.component(.month, from: dueDate)

            let content = UNMutableNotificationContent()
            content.title = localizedText(spanish: "Recordatorio de pago", english: "Payment reminder")
            content.body = recurringNotificationBody(for: payment, leadDays: normalizedLeadDays)
            content.sound = .default

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate
            )

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: recurringNotificationIdentifier(
                    paymentID: payment.id,
                    year: year,
                    month: month,
                    leadDays: normalizedLeadDays
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

    private func normalizedLeadDays(_ value: Int) -> Int {
        min(max(value, 0), 3)
    }

    private func recurringNotificationBody(for payment: RecurringPayment, leadDays: Int) -> String {
        if leadDays == 0 {
            return localizedText(
                spanish: "\(payment.title) vence hoy.",
                english: "\(payment.title) is due today."
            )
        }

        if leadDays == 1 {
            return localizedText(
                spanish: "\(payment.title) vence mañana.",
                english: "\(payment.title) is due tomorrow."
            )
        }

        return localizedText(
            spanish: "\(payment.title) vence en \(leadDays) días.",
            english: "\(payment.title) is due in \(leadDays) days."
        )
    }

    private func recurringNotificationPrefix(for paymentID: UUID) -> String {
        "recurring_payment_\(paymentID.uuidString)_"
    }

    private func recurringNotificationIdentifier(paymentID: UUID, year: Int, month: Int, leadDays: Int) -> String {
        let monthString = String(format: "%02d", month)
        return "\(recurringNotificationPrefix(for: paymentID))\(year)_\(monthString)_\(leadDays)d"
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
