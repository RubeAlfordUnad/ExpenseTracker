//
//  AddRecurringPaymentView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 5/03/26.
//

import SwiftUI

struct AddRecurringPaymentView: View {
    
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var amount = ""
    @State private var dueDay = 1
    @State private var category: RecurringPaymentCategory = .other
    
    var onSave: (RecurringPayment) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre", text: $title)
                
                TextField("Valor mensual", text: $amount)
                    .keyboardType(.decimalPad)
                
                Stepper("Día de pago: \(dueDay)", value: $dueDay, in: 1...31)
                
                Picker("Categoría", selection: $category) {
                    ForEach(RecurringPaymentCategory.allCases, id: \.self) { item in
                        Text(item.rawValue)
                    }
                }
            }
            .navigationTitle("Nuevo pago fijo")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        let newPayment = RecurringPayment(
                            title: title,
                            amount: Double(amount) ?? 0,
                            dueDay: dueDay,
                            category: category,
                            lastPaidMonth: nil,
                            lastPaidYear: nil,
                            isActive: true
                        )
                        
                        onSave(newPayment)
                        dismiss()
                    }
                    .disabled(title.isEmpty || amount.isEmpty)
                }
            }
        }
    }
}
