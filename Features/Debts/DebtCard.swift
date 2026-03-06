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
    
    var usageProgress: Double {
        guard debt.totalLimit > 0 else { return 0 }
        return debt.remainingDebt / debt.totalLimit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(debt.cardName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(debt.brand.rawValue)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                if debt.brand == .visa || debt.brand == .mastercard || debt.brand == .amex {
                    Text(debt.brand.rawValue.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(8)
                } else {
                    Image(systemName: "creditcard.fill")
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Saldo pendiente")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Text("$\(debt.remainingDebt, specifier: "%.2f")")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: usageProgress)
                    .tint(.white)
                
                HStack {
                    Text("Cupo: $\(debt.totalLimit, specifier: "%.2f")")
                    Spacer()
                    Text("\(Int(usageProgress * 100))% usado")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.85))
            }
            
            Button {
                showPayment = true
            } label: {
                Text("Registrar pago")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.black, Color.gray.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(22)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 5)
        .sheet(isPresented: $showPayment) {
            AddPaymentView(debt: $debt)
        }
    }
}
