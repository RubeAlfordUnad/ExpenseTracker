import Foundation

struct NotificationPreferences: Codable, Equatable {
    var recurringPaymentsEnabled: Bool = true
    var recurringReminderLeadDays: Int = 0
    var budgetAlertsEnabled: Bool = true
    var budgetAlertThreshold: Double = 0.80
    var dailySummaryEnabled: Bool = false

    init(
        recurringPaymentsEnabled: Bool = true,
        recurringReminderLeadDays: Int = 0,
        budgetAlertsEnabled: Bool = true,
        budgetAlertThreshold: Double = 0.80,
        dailySummaryEnabled: Bool = false
    ) {
        self.recurringPaymentsEnabled = recurringPaymentsEnabled
        self.recurringReminderLeadDays = recurringReminderLeadDays
        self.budgetAlertsEnabled = budgetAlertsEnabled
        self.budgetAlertThreshold = budgetAlertThreshold
        self.dailySummaryEnabled = dailySummaryEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case recurringPaymentsEnabled
        case recurringReminderLeadDays
        case budgetAlertsEnabled
        case budgetAlertThreshold
        case dailySummaryEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        recurringPaymentsEnabled = try container.decodeIfPresent(Bool.self, forKey: .recurringPaymentsEnabled) ?? true
        recurringReminderLeadDays = min(
            max(try container.decodeIfPresent(Int.self, forKey: .recurringReminderLeadDays) ?? 0, 0),
            3
        )
        budgetAlertsEnabled = try container.decodeIfPresent(Bool.self, forKey: .budgetAlertsEnabled) ?? true
        budgetAlertThreshold = try container.decodeIfPresent(Double.self, forKey: .budgetAlertThreshold) ?? 0.80
        dailySummaryEnabled = try container.decodeIfPresent(Bool.self, forKey: .dailySummaryEnabled) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recurringPaymentsEnabled, forKey: .recurringPaymentsEnabled)
        try container.encode(recurringReminderLeadDays, forKey: .recurringReminderLeadDays)
        try container.encode(budgetAlertsEnabled, forKey: .budgetAlertsEnabled)
        try container.encode(budgetAlertThreshold, forKey: .budgetAlertThreshold)
        try container.encode(dailySummaryEnabled, forKey: .dailySummaryEnabled)
    }
}
