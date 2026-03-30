//
//  ModelAndServiceTests.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 23/03/26.
//

import Foundation
import UniformTypeIdentifiers
import Testing
@testable import ExpenseTracker

@Suite("Models and services")
struct ModelAndServiceTests {

    @Test("Debt calcula crédito disponible y porcentaje de uso")
    func debt_computed_values_are_correct() {
        let debt = Debt(
            cardName: "Visa Platinum",
            brand: .visa,
            totalLimit: 4000000,
            remainingDebt: 1000000
        )

        #expect(debt.availableCredit == 3000000)
        #expect(debt.utilization == 0.25)
        #expect(debt.utilizationPercentage == 25)
    }

    @Test("RecurringPayment detecta si ya fue pagado en el mes actual")
    func recurringPayment_detects_current_month_payment() {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())

        let paid = RecurringPayment(
            title: "Spotify",
            amount: 23000,
            dueDay: 12,
            category: .subscriptions,
            isActive: true,
            lastPaidMonth: currentMonth,
            lastPaidYear: currentYear
        )

        let unpaid = RecurringPayment(
            title: "Rent",
            amount: 900000,
            dueDay: 5,
            category: .housing,
            isActive: true,
            lastPaidMonth: nil,
            lastPaidYear: nil
        )

        #expect(paid.isPaidForCurrentMonth)
        #expect(!unpaid.isPaidForCurrentMonth)
    }

    @Test("DebtsExportService genera JSON válido")
    func debtsExportService_generates_json() throws {
        let debt = Debt(
            cardName: "Visa Gold",
            brand: .visa,
            totalLimit: 5000000,
            remainingDebt: 1200000
        )

        let payload = try DebtsExportService().makeExport(from: [debt], format: .json)
        let decoded = try JSONDecoder().decode([Debt].self, from: payload.data)

        #expect(payload.contentType == .json)
        #expect(payload.fileName.hasSuffix(".json"))
        #expect(decoded.count == 1)
        #expect(decoded.first?.cardName == "Visa Gold")
        #expect(decoded.first?.remainingDebt == 1200000)
    }

    @Test("DebtsExportService genera CSV con encabezados y escapa comas")
    func debtsExportService_generates_csv() throws {
        let debt = Debt(
            cardName: "Visa Gold, Shared",
            brand: .visa,
            totalLimit: 5000000,
            remainingDebt: 1200000
        )

        let payload = try DebtsExportService().makeExport(from: [debt], format: .csv)
        let csv = String(decoding: payload.data, as: UTF8.self)

        #expect(payload.contentType == .commaSeparatedText)
        #expect(payload.fileName.hasSuffix(".csv"))
        #expect(csv.contains("card_name,brand,total_limit,remaining_debt,available_credit,utilization_percentage"))
        #expect(csv.contains("\"Visa Gold, Shared\""))
        #expect(csv.contains("Visa"))
        #expect(csv.contains("1200000.0"))
    }
}
