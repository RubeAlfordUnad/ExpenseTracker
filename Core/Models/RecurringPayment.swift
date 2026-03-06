//
//  RecurringPayment.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 5/03/26.
//

import Foundation

enum RecurringPaymentCategory: String, CaseIterable, Codable {
    case gym = "Gimnasio"
    case streaming = "Streaming"
    case services = "Servicios"
    case health = "Salud"
    case education = "Educación"
    case other = "Otros"
}

struct RecurringPayment: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var amount: Double
    var dueDay: Int
    var category: RecurringPaymentCategory
    var lastPaidMonth: Int?
    var lastPaidYear: Int?
    var isActive: Bool
    
    var isPaidForCurrentMonth: Bool {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        
        return lastPaidMonth == currentMonth && lastPaidYear == currentYear
    }
}
