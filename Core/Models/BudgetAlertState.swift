//
//  BudgetAlertState.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 19/03/26.
//

import Foundation

struct BudgetAlertState: Codable, Equatable {
    var monthIdentifier: String
    var didSend80PercentAlert: Bool
    var didSend100PercentAlert: Bool

    init(
        monthIdentifier: String = "",
        didSend80PercentAlert: Bool = false,
        didSend100PercentAlert: Bool = false
    ) {
        self.monthIdentifier = monthIdentifier
        self.didSend80PercentAlert = didSend80PercentAlert
        self.didSend100PercentAlert = didSend100PercentAlert
    }
}
