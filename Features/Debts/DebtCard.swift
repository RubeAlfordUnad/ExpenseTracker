//
//  debtcard.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 2/03/26.
//

import SwiftUI

struct DebtCard: View {
    
    @Binding var debt: Debt
    @State private var showPayment = false
    
    var progress: Double {
        if debt.totalAmount == 0 { return 0 }
        return 1 - (debt.remainingAmount / debt.totalAmount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                Text(debt.name)
                    .font(.headline)
                
                Spacer()
                
                Text("$\(debt.remainingAmount, specifier: "%.2f")")
                    .fontWeight(.bold)
            }
            
            ProgressView(value: progress)
            
            Text("Total: $\(debt.totalAmount, specifier: "%.2f")")
                .font(.caption)
                .foregroundColor(.gray)
            
            Button {
                showPayment = true
            } label: {
                Text("Register Payment")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemGray6))
        )
        .sheet(isPresented: $showPayment) {
            AddPaymentView(debt: $debt)
        }
    }
}
