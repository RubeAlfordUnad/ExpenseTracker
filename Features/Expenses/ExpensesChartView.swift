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
    
    var categoryTotals: [(String, Double)] {
        let grouped = Dictionary(grouping: expenses) { $0.category.rawValue }
        
        return grouped.map { key, value in
            let total = value.reduce(0) { $0 + $1.amount }
            return (key, total)
        }
    }
    
    var totalAmount: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(spacing: 15) {
            
            Text("Expenses by Category")
                .font(.title2.bold())
            
            ZStack {
                
                Chart(categoryTotals, id: \.0) { item in
                    SectorMark(
                        angle: .value("Amount", item.1),
                        innerRadius: .ratio(0.55),
                        angularInset: 1
                    )
                    .foregroundStyle(by: .value("Category", item.0))
                }
                .frame(height: 280)
                .chartLegend(position: .bottom)
                
                VStack {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("$\(totalAmount, specifier: "%.2f")")
                        .font(.title.bold())
                }
            }
            .animation(.easeInOut, value: expenses.count)
        }
    }
}

