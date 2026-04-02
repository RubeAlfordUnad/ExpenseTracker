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

    @Test("ExpensesTransferService importa CSV con ;, BOM y omite filas inválidas")
    func expensesTransferService_imports_semicolon_csv_and_skips_invalid_rows() throws {
        let csv = """
        \u{FEFF}title;amount;date;category
        Supermercado;12.345,67;2026-03-15;Comida
        Taxi;abc;2026-03-16;Transporte
        """

        let result = try ExpensesTransferService().importExpenses(
            from: Data(csv.utf8),
            contentType: .commaSeparatedText
        )

        #expect(result.totalRows == 2)
        #expect(result.importedRows == 1)
        #expect(result.skippedRows == 1)
        #expect(result.expenses.count == 1)

        let expense = try #require(result.expenses.first)
        #expect(expense.title == "Supermercado")
        #expect(abs(expense.amount - 12345.67) < 0.001)
        #expect(expense.category == .food)

        let components = Calendar.current.dateComponents([.year, .month, .day], from: expense.date)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 15)
    }

    @Test("ExpensesTransferService importa JSON ISO8601 correctamente")
    func expensesTransferService_imports_json_iso8601() throws {
        let json = """
        [
          {
            "id": "3A15A1E8-2A8E-4BAA-8E52-51A5C39B7D5A",
            "title": "Netflix",
            "amount": 38900,
            "date": "2026-03-01T00:00:00Z",
            "category": "Suscripciones"
          }
        ]
        """

        let result = try ExpensesTransferService().importExpenses(
            from: Data(json.utf8),
            contentType: .json
        )

        #expect(result.totalRows == 1)
        #expect(result.importedRows == 1)
        #expect(result.skippedRows == 0)
        #expect(result.expenses.count == 1)

        let expense = try #require(result.expenses.first)
        #expect(expense.title == "Netflix")
        #expect(expense.amount == 38900)
        #expect(expense.category == .subscriptions)
    }
}
