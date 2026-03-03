//
//  DebtsView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 1/03/26.
//

import SwiftUI

struct DebtsView: View {
    
    @State private var debts: [Debt] = []
    @State private var showAdd = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach($debts) { $debt in
                        DebtCard(debt: $debt)
                    }
                }
                .padding()
            }
            .navigationTitle("My Debts")
            .toolbar {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showAdd) {
                AddDebtView { newDebt in
                    debts.append(newDebt)
                    DataManager.shared.saveDebts(debts)
                }
            }
            .onAppear {
                debts = DataManager.shared.loadDebts()
            }
        }
    }
}
