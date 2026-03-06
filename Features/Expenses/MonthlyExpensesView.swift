//
//  MonthlyExpensesView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 2/03/26.
//

import SwiftUI

struct MonthlyExpensesView: View {
    
    var expenses: [Expense]
    
    var totalAmount: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    var dominantCategory: Category? {
        let grouped = Dictionary(grouping: expenses, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        
        return grouped.max(by: { $0.value < $1.value })?.key
    }
    
    var averageExpense: Double {
        guard !expenses.isEmpty else { return 0 }
        return totalAmount / Double(expenses.count)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                
                VStack(alignment: .leading, spacing: 14) {
                    Text("Monthly Overview")
                        .font(.headline)
                    
                    HStack {
                        summaryCard(
                            title: "Total",
                            value: String(format: "$%.2f", totalAmount),
                            color: .blue
                        )
                        
                        summaryCard(
                            title: "Average",
                            value: String(format: "$%.2f", averageExpense),
                            color: .purple
                        )
                    }
                    
                    if let dominantCategory {
                        HStack(spacing: 10) {
                            Image(systemName: dominantCategory.icon)
                                .foregroundColor(dominantCategory.color)
                            
                            Text("Top category: \(dominantCategory.rawValue)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                if !expenses.isEmpty {
                    ExpensesChartView(expenses: expenses)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transactions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(expenses) { expense in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(expense.category.color.opacity(0.15))
                                    .frame(width: 42, height: 42)
                                
                                Image(systemName: expense.category.icon)
                                    .foregroundColor(expense.category.color)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expense.title)
                                    .font(.subheadline.bold())
                                
                                Text(expense.category.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("$\(expense.amount, specifier: "%.2f")")
                                .font(.subheadline.bold())
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(18)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Monthly History")
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private func summaryCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(18)
    }
}
