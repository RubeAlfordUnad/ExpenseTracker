//
//  AddDebtView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 2/03/26.
//

import SwiftUI

struct AddDebtView: View {
    
    @Environment(\.dismiss) var dismiss
    
    @State private var cardName = ""
    @State private var selectedBrand: CardBrand = .visa
    @State private var totalLimit = ""
    @State private var currentDebt = ""
    
    var onSave: (Debt) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre de la tarjeta", text: $cardName)
                
                Picker("Marca", selection: $selectedBrand) {
                    ForEach(CardBrand.allCases, id: \.self) { brand in
                        Text(brand.rawValue)
                    }
                }
                
                TextField("Cupo total", text: $totalLimit)
                    .keyboardType(.decimalPad)
                
                TextField("Deuda actual", text: $currentDebt)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Nueva tarjeta")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        let newDebt = Debt(
                            cardName: cardName,
                            brand: selectedBrand,
                            totalLimit: Double(totalLimit) ?? 0,
                            remainingDebt: Double(currentDebt) ?? 0
                        )
                        
                        onSave(newDebt)
                        dismiss()
                    }
                    .disabled(cardName.isEmpty || totalLimit.isEmpty || currentDebt.isEmpty)
                }
            }
        }
    }
}
