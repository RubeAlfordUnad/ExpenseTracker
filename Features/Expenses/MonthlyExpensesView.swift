//
//  MonthlyExpensesView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 2/03/26.
//

import SwiftUI
import Charts

struct MonthlyExpensesView: View {
    
    var expenses: [Expense]
    @State private var selectedMonth: String = ""
    
    var grouped: [String: [Expense]] {
        Dictionary(grouping: expenses) { expense in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: expense.date)
        }
    }
    
    var months: [String] {
        grouped.keys.sorted().reversed()
    }
    
    var filteredExpenses: [Expense] {
        guard !selectedMonth.isEmpty else { return expenses }
        return grouped[selectedMonth] ?? []
    }
    
    var body: some View {
        VStack(spacing: 15) {
            
            if !months.isEmpty {
                Picker("Month", selection: $selectedMonth.animation(.easeInOut)) {
                    Text("All").tag("")
                    
                    ForEach(months, id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }
            
            ExpensesChartView(expenses: filteredExpenses)
            
            List {
                ForEach(filteredExpenses) { expense in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(expense.title)
                            Text(expense.category.rawValue)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Text("$\(expense.amount, specifier: "%.2f")")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .navigationTitle("Monthly History")
    }
}
