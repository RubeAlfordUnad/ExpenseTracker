//
//  StatsView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 1/03/26.
//


import SwiftUI

struct StatsView: View {
    
    var expenses: [Expense]
    
    var totalSpent: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    var totalTransactions: Int {
        expenses.count
    }
    
    var categoryTotals: [(Category, Double)] {
        let grouped = Dictionary(grouping: expenses, by: { $0.category })
        
        return grouped.map { key, value in
            let total = value.reduce(0) { $0 + $1.amount }
            return (key, total)
        }
        .sorted { $0.1 > $1.1 }
    }
    
    var dominantCategory: Category? {
        categoryTotals.first?.0
    }
    
    var averageExpense: Double {
        guard !expenses.isEmpty else { return 0 }
        return totalSpent / Double(expenses.count)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    
                    HStack {
                        statsCard(
                            title: "Total spent",
                            value: String(format: "$%.2f", totalSpent),
                            color: .blue
                        )
                        
                        statsCard(
                            title: "Transactions",
                            value: "\(totalTransactions)",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    HStack {
                        statsCard(
                            title: "Average",
                            value: String(format: "$%.2f", averageExpense),
                            color: .orange
                        )
                        
                        statsCard(
                            title: "Top category",
                            value: dominantCategory?.rawValue ?? "None",
                            color: dominantCategory?.color ?? .gray
                        )
                    }
                    .padding(.horizontal)
                    
                    if expenses.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "chart.pie")
                                .font(.system(size: 42))
                                .foregroundColor(.gray)
                            
                            Text("No data yet")
                                .font(.headline)
                            
                            Text("Add expenses to see your stats")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 50)
                    } else {
                        ExpensesChartView(expenses: expenses)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category breakdown")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(categoryTotals, id: \.0) { item in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(item.0.color)
                                        .frame(width: 12, height: 12)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.0.rawValue)
                                            .font(.subheadline.bold())
                                        
                                        Text("\(percentage(for: item.1), specifier: "%.0f")% of total")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(String(format: "$%.2f", item.1))
                                        .font(.subheadline.bold())
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(18)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Stats")
        }
    }
    
    private func percentage(for amount: Double) -> Double {
        guard totalSpent > 0 else { return 0 }
        return (amount / totalSpent) * 100
    }
    
    @ViewBuilder
    private func statsCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline.bold())
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(18)
    }
}
