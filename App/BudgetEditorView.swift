//
//  BudgetEditorView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 6/03/26.
//

import SwiftUI

struct BudgetEditorView: View {
    
    @Environment(\.dismiss) var dismiss
    @State private var amount: String
    
    var onSave: (Double) -> Void
    
    init(currentBudget: Double, onSave: @escaping (Double) -> Void) {
        self._amount = State(initialValue: currentBudget == 0 ? "" : String(format: "%.2f", currentBudget))
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Monthly budget", text: $amount)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Set Budget")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(Double(amount) ?? 0)
                        dismiss()
                    }
                }
            }
        }
    }
}
