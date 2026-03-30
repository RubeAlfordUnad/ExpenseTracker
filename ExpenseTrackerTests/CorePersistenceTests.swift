//
//  CorePersistenceTests.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 23/03/26.
//

import Foundation
import Testing
@testable import ExpenseTracker

@Suite("Core persistence and auth", .serialized)
struct CorePersistenceTests {

    @Test("Auth registra, evita duplicados, mantiene sesión y cierra sesión")
    func auth_register_login_restore_logout() {
        let username = makeUniqueUsername("auth")
        let password = "superSecret123"

        clearAppStorage(for: [username])
        defer { clearAppStorage(for: [username]) }

        let auth = AuthManager()

        #expect(auth.register(username: username, password: password))
        #expect(!auth.register(username: username, password: "otra"))
        #expect(auth.login(username: username, password: password))
        #expect(auth.isLoggedIn)
        #expect(auth.currentUser == username)

        let restored = AuthManager()
        #expect(restored.isLoggedIn)
        #expect(restored.currentUser == username)

        restored.logout()
        #expect(!restored.isLoggedIn)
        #expect(restored.currentUser.isEmpty)
    }

    @Test("DataManager guarda y carga gastos por usuario sin mezclar datos")
    func dataManager_scopes_expenses_per_user() {
        let userA = makeUniqueUsername("expensesA")
        let userB = makeUniqueUsername("expensesB")

        clearAppStorage(for: [userA, userB])
        defer { clearAppStorage(for: [userA, userB]) }

        let userAExpenses = [
            Expense(title: "Uber", amount: 32000, date: makeDate(year: 2026, month: 3, day: 1), category: .transport),
            Expense(title: "Cena", amount: 54000, date: makeDate(year: 2026, month: 3, day: 2), category: .food)
        ]

        let userBExpenses = [
            Expense(title: "Netflix", amount: 28000, date: makeDate(year: 2026, month: 3, day: 3), category: .entertainment)
        ]

        DataManager.shared.saveExpenses(userAExpenses, user: userA)
        DataManager.shared.saveExpenses(userBExpenses, user: userB)

        let loadedA = DataManager.shared.loadExpenses(user: userA)
        let loadedB = DataManager.shared.loadExpenses(user: userB)

        #expect(loadedA.count == 2)
        #expect(loadedA.map(\.title) == ["Uber", "Cena"])
        #expect(loadedA.map(\.amount) == [32000, 54000])
        #expect(loadedB.count == 1)
        #expect(loadedB.first?.title == "Netflix")
        #expect(DataManager.shared.loadExpenses(user: makeUniqueUsername("empty")).isEmpty)
    }

    @Test("DataManager guarda deudas, pagos fijos y presupuesto")
    func dataManager_saves_wallet_and_budget_data() {
        let user = makeUniqueUsername("wallet")

        clearAppStorage(for: [user])
        defer { clearAppStorage(for: [user]) }

        let debts = [
            Debt(cardName: "Visa Gold", brand: .visa, totalLimit: 5000000, remainingDebt: 1250000),
            Debt(cardName: "Master Blue", brand: .mastercard, totalLimit: 3000000, remainingDebt: 500000)
        ]

        let recurring = [
            RecurringPayment(
                title: "Internet",
                amount: 95000,
                dueDay: 10,
                category: .utilities,
                isActive: true,
                lastPaidMonth: nil,
                lastPaidYear: nil
            ),
            RecurringPayment(
                title: "Gym",
                amount: 120000,
                dueDay: 5,
                category: .health,
                isActive: true,
                lastPaidMonth: nil,
                lastPaidYear: nil
            )
        ]

        let budget = MonthlyBudget(amount: 3500000)

        DataManager.shared.saveDebts(debts, user: user)
        DataManager.shared.saveRecurringPayments(recurring, user: user)
        DataManager.shared.saveMonthlyBudget(budget, user: user)

        let loadedDebts = DataManager.shared.loadDebts(user: user)
        let loadedRecurring = DataManager.shared.loadRecurringPayments(user: user)
        let loadedBudget = DataManager.shared.loadMonthlyBudget(user: user)

        #expect(loadedDebts.count == 2)
        #expect(loadedDebts.map(\.cardName) == ["Visa Gold", "Master Blue"])
        #expect(loadedRecurring.count == 2)
        #expect(loadedRecurring.map(\.title) == ["Internet", "Gym"])
        #expect(loadedBudget?.amount == 3500000)
    }

    @Test("BudgetAlertState se marca y se reinicia cuando cambia el mes")
    func budgetAlertState_marks_and_resets() {
        let user = makeUniqueUsername("budget")

        clearAppStorage(for: [user])
        defer { clearAppStorage(for: [user]) }

        let manager = DataManager.shared

        manager.markBudget80AlertSent(user: user)
        var state = manager.loadBudgetAlertState(user: user)
        #expect(state.didSend80PercentAlert)
        #expect(!state.didSend100PercentAlert)

        manager.markBudget100AlertSent(user: user)
        state = manager.loadBudgetAlertState(user: user)
        #expect(state.didSend80PercentAlert)
        #expect(state.didSend100PercentAlert)

        let oldState = BudgetAlertState(
            monthIdentifier: "1999-1",
            didSend80PercentAlert: true,
            didSend100PercentAlert: true
        )
        manager.saveBudgetAlertState(oldState, user: user)
        manager.resetBudgetAlertStateIfNeeded(user: user)

        let resetState = manager.loadBudgetAlertState(user: user)
        #expect(resetState.monthIdentifier != "1999-1")
        #expect(!resetState.didSend80PercentAlert)
        #expect(!resetState.didSend100PercentAlert)
    }

    @Test("DataManager guarda y limpia la foto de perfil")
    func profileImage_roundTrip_and_delete() {
        let user = makeUniqueUsername("photo")

        clearAppStorage(for: [user])
        defer { clearAppStorage(for: [user]) }

        let imageData = Data([0x01, 0x02, 0x03, 0x04])

        DataManager.shared.saveProfileImageData(imageData, user: user)
        #expect(DataManager.shared.loadProfileImageData(user: user) == imageData)

        DataManager.shared.saveProfileImageData(nil, user: user)
        #expect(DataManager.shared.loadProfileImageData(user: user) == nil)
    }


    @Test("La foto de perfil migra desde UserDefaults legado al almacenamiento en archivo")
    func profileImage_legacy_storage_migrates_to_file_storage() {
        let user = makeUniqueUsername("photoMigration")

        clearAppStorage(for: [user])
        defer { clearAppStorage(for: [user]) }

        let legacyKey = "profileImage_\(user)"
        let legacyData = Data([0xAA, 0xBB, 0xCC])
        UserDefaults.standard.set(legacyData, forKey: legacyKey)

        let loaded = DataManager.shared.loadProfileImageData(user: user)

        #expect(loaded == legacyData)
        #expect(UserDefaults.standard.data(forKey: legacyKey) == nil)
    }

    @Test("Eliminar cuenta limpia sesión, datos financieros y foto de perfil")
    func deleteAccount_clears_local_data_and_session() {
        let username = makeUniqueUsername("delete")
        let password = "superSecret123"

        clearAppStorage(for: [username])
        defer { clearAppStorage(for: [username]) }

        let auth = AuthManager()
        #expect(auth.register(username: username, password: password))
        #expect(auth.login(username: username, password: password))

        DataManager.shared.saveExpenses([
            Expense(title: "Taxi", amount: 12000, date: makeDate(year: 2026, month: 3, day: 4), category: .transport)
        ], user: username)
        DataManager.shared.saveMonthlyBudget(MonthlyBudget(amount: 300000), user: username)
        DataManager.shared.saveProfileImageData(Data([0x10, 0x20, 0x30]), user: username)
        DataManager.shared.saveNotificationPreferences(
            NotificationPreferences(
                recurringPaymentsEnabled: true,
                budgetAlertsEnabled: true,
                budgetThresholdPercent: 80
            ),
            user: username
        )

        #expect(auth.deleteCurrentAccount())
        #expect(!auth.isLoggedIn)
        #expect(auth.currentUser.isEmpty)
        #expect(DataManager.shared.loadExpenses(user: username).isEmpty)
        #expect(DataManager.shared.loadMonthlyBudget(user: username) == nil)
        #expect(DataManager.shared.loadProfileImageData(user: username) == nil)
        #expect(UserDefaults.standard.string(forKey: "session_key") == nil)
        #expect(!((UserDefaults.standard.stringArray(forKey: "registered_usernames_key") ?? []).contains(username)))
        #expect(KeychainManager.shared.readPassword(for: username) == nil)
    }

}
