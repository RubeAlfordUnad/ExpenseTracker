//
//  ContentView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 26/02/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var expenses: [Expense] = []
    @State private var showAdd = false
    
    
    var total: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        TabView {
            
            NavigationView {
                VStack {
                    NavigationLink("View Monthly History") {
                        MonthlyExpensesView(expenses: expenses)
                    }
                    .padding(.bottom, 5)
                    Text("Total: $\(total, specifier: "%.2f")")
                        .font(.title2)
                        .padding()
                    
                    List {
                        ForEach(expenses) { expense in
                            VStack(alignment: .leading) {
                                Text(expense.title)
                                    .font(.headline)
                                
                                Text(expense.category.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                
                                Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                
                                Text("$\(expense.amount, specifier: "%.2f")")
                                    .fontWeight(.bold)
                            }
                        }
                        .onDelete { index in
                            expenses.remove(atOffsets: index)
                            DataManager.shared.saveExpenses(expenses)
                        }
                    }
                }
                .navigationTitle("My Expenses")
                .toolbar {
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Logout") {
                            auth.logout()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showAdd = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showAdd) {
                    AddExpenseView { newExpense in
                        expenses.append(newExpense)
                        DataManager.shared.saveExpenses(expenses)
                    }
                }
                .onAppear {
                    expenses = DataManager.shared.loadExpenses()
                }
            }
            .tabItem {
                Label("Expenses", systemImage: "list.bullet")
            }
            
            
            StatsView(expenses: expenses)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
            
            
            DebtsView()
                .tabItem {
                    Label("Debts", systemImage: "creditcard")
                }
        }
    }
}
