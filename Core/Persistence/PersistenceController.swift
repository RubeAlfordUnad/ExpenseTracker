import Foundation
import SwiftData

enum PersistenceStartupState {
    case persistent
    case inMemoryFallback
}

@MainActor
final class PersistenceController {

    static let shared = PersistenceController()

    let container: ModelContainer
    let startupState: PersistenceStartupState

    private static let appSchema = Schema([
        StoredExpense.self,
        StoredIncome.self,
        StoredDebt.self,
        StoredRecurringPayment.self,
        StoredMonthlyBudget.self
    ])

    private init() {
        do {
            let configuration = ModelConfiguration(
                schema: Self.appSchema,
                isStoredInMemoryOnly: false
            )

            container = try ModelContainer(
                for: Self.appSchema,
                configurations: [configuration]
            )

            startupState = .persistent
        } catch {
            assertionFailure("No se pudo crear el ModelContainer persistente de SwiftData: \(error)")
            AppLogger.debug("Fallo SwiftData persistente. Se usará fallback en memoria. Error: \(error)")

            let fallbackConfiguration = ModelConfiguration(
                schema: Self.appSchema,
                isStoredInMemoryOnly: true
            )

            do {
                container = try ModelContainer(
                    for: Self.appSchema,
                    configurations: [fallbackConfiguration]
                )

                startupState = .inMemoryFallback
            } catch {
                assertionFailure("No se pudo crear tampoco el fallback en memoria de SwiftData: \(error)")
                AppLogger.debug("Fallo crítico SwiftData en memoria. Se intentará una última vez. Error: \(error)")

                container = try! ModelContainer(
                    for: Self.appSchema,
                    configurations: [fallbackConfiguration]
                )

                startupState = .inMemoryFallback
            }
        }
    }
}
