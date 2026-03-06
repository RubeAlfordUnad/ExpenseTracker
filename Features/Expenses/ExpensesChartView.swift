//
//  ExpensesChartView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 2/03/26.
//

import SwiftUI
import Charts

struct ExpensesChartView: View {
    
    var expenses: [Expense]
    
    var categoryTotals: [(Category, Double)] {
        let grouped = Dictionary(grouping: expenses, by: { $0.category })
        
        return grouped.map { key, value in
            let total = value.reduce(0) { $0 + $1.amount }
            return (key, total)
        }
        .sorted { $0.1 > $1.1 }
    }
    
    var totalAmount: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spending Distribution")
                        .font(.headline)
                    
                    Text("By category")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            ZStack {
                Chart(categoryTotals, id: \.0) { item in
                    SectorMark(
                        angle: .value("Amount", item.1),
                        innerRadius: .ratio(0.58),
                        angularInset: 2
                    )
                    .foregroundStyle(item.0.color)
                }
                .frame(height: 260)
                
                VStack(spacing: 4) {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("$\(totalAmount, specifier: "%.0f")")
                        .font(.title2.bold())
                }
            }
            
            VStack(spacing: 10) {
                ForEach(categoryTotals, id: \.0) { item in
                    HStack {
                        Circle()
                            .fill(item.0.color)
                            .frame(width: 10, height: 10)
                        
                        Text(item.0.rawValue)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("$\(item.1, specifier: "%.2f")")
                            .font(.subheadline.bold())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(22)
        .padding(.horizontal)
    }
}
