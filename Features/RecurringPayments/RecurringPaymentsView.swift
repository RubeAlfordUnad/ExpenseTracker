//
//  RecurringPaymentsView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 5/03/26.
//

import SwiftUI

struct RecurringPaymentsView: View {
    
    @EnvironmentObject var auth: AuthManager
    
    @State private var payments: [RecurringPayment] = []
    @State private var showAddPayment = false
    
    var totalMonthly: Double {
        payments
            .filter { $0.isActive }
            .reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pagos fijos del mes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("$\(totalMonthly, specifier: "%.2f")")
                        .font(.title.bold())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)
                .padding(.top, 8)
                
                List {
                    if payments.isEmpty {
                        Text("No tienes pagos fijos registrados")
                            .foregroundColor(.gray)
                    }
                    
                    ForEach($payments) { $payment in
                        VStack(alignment: .leading, spacing: 10) {
                            
                            HStack {
                                Text(payment.title)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("$\(payment.amount, specifier: "%.2f")")
                                    .font(.headline)
                            }
                            
                            HStack {
                                Text("Día \(payment.dueDay)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(payment.category.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Label(
                                    payment.isPaidForCurrentMonth ? "Pagado este mes" : "Pendiente",
                                    systemImage: payment.isPaidForCurrentMonth ? "checkmark.circle.fill" : "clock.fill"
                                )
                                .font(.caption)
                                .foregroundColor(payment.isPaidForCurrentMonth ? .green : .orange)
                                
                                Spacer()
                                
                                Button(payment.isPaidForCurrentMonth ? "Desmarcar" : "Marcar pagado") {
                                    togglePaymentStatus(for: &payment)
                                }
                                .font(.caption.bold())
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete(perform: deletePayment)
                }
            }
            .navigationTitle("Pagos fijos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddPayment = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddPayment) {
                AddRecurringPaymentView { newPayment in
                    payments.append(newPayment)
                    DataManager.shared.saveRecurringPayments(payments, user: auth.currentUser)
                }
            }
            .onAppear {
                payments = DataManager.shared.loadRecurringPayments(user: auth.currentUser)
            }
        }
    }
    
    private func deletePayment(at offsets: IndexSet) {
        payments.remove(atOffsets: offsets)
        DataManager.shared.saveRecurringPayments(payments, user: auth.currentUser)
    }
    
    private func togglePaymentStatus(for payment: inout RecurringPayment) {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        
        if payment.isPaidForCurrentMonth {
            payment.lastPaidMonth = nil
            payment.lastPaidYear = nil
        } else {
            payment.lastPaidMonth = currentMonth
            payment.lastPaidYear = currentYear
        }
        
        DataManager.shared.saveRecurringPayments(payments, user: auth.currentUser)
    }
}
