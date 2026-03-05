//
//  AddDebtView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 2/03/26.
//

import SwiftUI

struct AddDebtView: View {
    
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var total = ""
    
    var onSave: (Debt) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Card / Loan Name", text: $name)
                
                TextField("Total Amount", text: $total)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Add Debt")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let totalValue = Double(total) ?? 0
                        
                        let debt = Debt(
                            name: name,
                            totalAmount: totalValue,
                            remainingAmount: totalValue
                        )
                        
                        onSave(debt)
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
