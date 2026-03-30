import Foundation
import SwiftData

@MainActor
final class PersistenceController {

    static let shared = PersistenceController()

    let container: ModelContainer

    private let schema = Schema([
        StoredExpense.self,
        StoredDebt.self,
        StoredRecurringPayment.self,
        StoredMonthlyBudget.self
    ])

    private init() {
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            assertionFailure("No se pudo crear el ModelContainer persistente de SwiftData: \(error)")

            do {
                let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                fatalError("No se pudo crear el ModelContainer de SwiftData ni el fallback en memoria: \(error)")
            }
        }
    }
}
