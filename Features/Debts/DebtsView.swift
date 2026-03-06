//
//  DebtsView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 1/03/26.
//

import SwiftUI

struct DebtsView: View {
    
    @EnvironmentObject var auth: AuthManager
    @State private var debts: [Debt] = []
    @State private var showAdd = false
    
    var totalDebt: Double {
        debts.reduce(0) { $0 + $1.remainingDebt }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total adeudado")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("$\(totalDebt, specifier: "%.2f")")
                        .font(.title.bold())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)
                .padding(.top, 8)
                
                ScrollView {
                    VStack(spacing: 16) {
                        if debts.isEmpty {
                            Text("No tienes tarjetas registradas")
                                .foregroundColor(.gray)
                                .padding(.top, 40)
                        } else {
                            ForEach($debts) { $debt in
                                DebtCard(debt: $debt)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Tarjetas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddDebtView { newDebt in
                    debts.append(newDebt)
                    DataManager.shared.saveDebts(debts, user: auth.currentUser)
                }
            }
            .onAppear {
                debts = DataManager.shared.loadDebts(user: auth.currentUser)
            }
            .onChange(of: debts) {
                DataManager.shared.saveDebts(debts, user: auth.currentUser)
            }
        }
    }
}
