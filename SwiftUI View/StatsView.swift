//
//  StatsView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 1/03/26.
//


import SwiftUI
import Charts

struct StatsView: View {
    
    var expenses: [Expense]
    
    var grouped: [String: Double] {
        Dictionary(grouping: expenses, by: { $0.category.rawValue })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }
    
    var body: some View {
        VStack {
            Text("Statistics")
                .font(.largeTitle.bold())
            
            Chart {
                ForEach(grouped.keys.sorted(), id: \.self) { key in
                    BarMark(
                        x: .value("Category", key),
                        y: .value("Amount", grouped[key] ?? 0)
                    )
                }
            }
            .frame(height: 300)
            
            Spacer()
        }
        .padding()
    }
}
