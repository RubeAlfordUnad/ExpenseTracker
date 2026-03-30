//
//  NotificationPreferences.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 19/03/26.
//

import Foundation

struct NotificationPreferences: Codable, Equatable {
    var recurringPaymentsEnabled: Bool = true
    var budgetAlertsEnabled: Bool = true
    var budgetAlertThreshold: Double = 0.80
}
