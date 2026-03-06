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
        NavigationStack {
            Form {
                Text("Saldo pendiente: $\(debt.remainingDebt, specifier: "%.2f")")
                    .fontWeight(.semibold)
                
                TextField("Monto del pago", text: $payment)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Registrar pago")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Aplicar") {
                        let value = Double(payment) ?? 0
                        debt.remainingDebt = max(debt.remainingDebt - value, 0)
                        dismiss()
                    }
                }
            }
        }
    }
}
