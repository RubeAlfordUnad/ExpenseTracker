//
//  AddPaymentView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 2/03/26.
//

import SwiftUI

struct AddPaymentView: View {
    
    @Environment(\.dismiss) var dismiss
    
    @Binding var debt: Debt
    @State private var payment = ""
    
    var body: some View {
        NavigationView {
            Form {
                Text("Remaining: $\(debt.remainingAmount, specifier: "%.2f")")
                    .fontWeight(.semibold)
                
                TextField("Payment Amount", text: $payment)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Make Payment")
            .toolbar {
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        let value = Double(payment) ?? 0
                        
                        debt.remainingAmount -= value
                        
                        if debt.remainingAmount < 0 {
                            debt.remainingAmount = 0
                        }
                        
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
