import Foundation

struct CreditCardExpenseSourceFilter {

    static func eligibleCards(
        from debts: [Debt],
        existingExpense: Expense? = nil,
        preselectedCreditCardId: UUID? = nil
    ) -> [Debt] {
        let preservedCardIds = Set(
            [
                existingExpense?.creditCardId,
                preselectedCreditCardId
            ].compactMap { $0 }
        )

        return debts
            .filter { debt in
                guard debt.isCreditCard else {
                    return false
                }

                return debt.isActive || preservedCardIds.contains(debt.id)
            }
            .sorted {
                $0.cardName.localizedCaseInsensitiveCompare($1.cardName) == .orderedAscending
            }
    }

    static func containsValidCard(_ cardId: UUID?, in cards: [Debt]) -> Bool {
        guard let cardId else {
            return false
        }

        return cards.contains { $0.id == cardId }
    }
}
