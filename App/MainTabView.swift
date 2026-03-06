import SwiftUI

struct MainTabView: View {
    
    @EnvironmentObject var auth: AuthManager
    
    @State private var expenses: [Expense] = []
    @State private var showAddExpense = false
    @State private var showBudgetEditor = false
    @State private var monthlyBudget: MonthlyBudget = MonthlyBudget(amount: 0)
    
    var totalSpent: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    var remainingBudget: Double {
        max(monthlyBudget.amount - totalSpent, 0)
    }
    
    var budgetProgress: Double {
        guard monthlyBudget.amount > 0 else { return 0 }
        return min(totalSpent / monthlyBudget.amount, 1)
    }
    
    var topCategory: Category? {
        let grouped = Dictionary(grouping: expenses, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        
        return grouped.max(by: { $0.value < $1.value })?.key
    }
    
    var recentExpenses: [Expense] {
        Array(expenses.sorted { $0.date > $1.date }.prefix(5))
    }
    
    var body: some View {
        TabView {
            
            NavigationStack {
                ScrollView {
                    VStack(spacing: 18) {
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Monthly Budget")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("$\(monthlyBudget.amount, specifier: "%.2f")")
                                .font(.title.bold())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(18)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                summaryBlock(title: "Spent", value: String(format: "$%.2f", totalSpent), color: .red)
                                summaryBlock(title: "Remaining", value: String(format: "$%.2f", remainingBudget), color: .green)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Budget usage")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ProgressView(value: budgetProgress)
                                    .tint(budgetProgress > 0.85 ? .red : .blue)
                                
                                Text("\(Int(budgetProgress * 100))% used")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        if let topCategory {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(topCategory.color.opacity(0.18))
                                    .frame(width: 42, height: 42)
                                    .overlay(
                                        Image(systemName: topCategory.icon)
                                            .foregroundColor(topCategory.color)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Top category")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(topCategory.rawValue)
                                        .font(.headline)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(18)
                            .padding(.horizontal)
                        }
                        
                        NavigationLink {
                            MonthlyExpensesView(expenses: expenses)
                        } label: {
                            HStack {
                                Image(systemName: "calendar")
                                Text("View monthly history")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(18)
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recent expenses")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if recentExpenses.isEmpty {
                                Text("No expenses yet")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            } else {
                                ForEach(recentExpenses) { expense in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(expense.category.color.opacity(0.18))
                                            .frame(width: 42, height: 42)
                                            .overlay(
                                                Image(systemName: expense.category.icon)
                                                    .foregroundColor(expense.category.color)
                                            )
                                        
                                        VStack(alignment: .leading, spacing: 3) {
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
                    }
                    .padding(.bottom, 20)
                }
                .navigationTitle("My Expenses")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Logout") {
                            auth.logout()
                        }
                    }
                    
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            showBudgetEditor = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        
                        Button {
                            showAddExpense = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showAddExpense) {
                    AddExpenseView { newExpense in
                        expenses.append(newExpense)
                        DataManager.shared.saveExpenses(expenses, user: auth.currentUser)
                    }
                }
                .sheet(isPresented: $showBudgetEditor) {
                    BudgetEditorView(currentBudget: monthlyBudget.amount) { newValue in
                        monthlyBudget = MonthlyBudget(amount: newValue)
                        DataManager.shared.saveMonthlyBudget(monthlyBudget, user: auth.currentUser)
                    }
                }
                .onAppear {
                    expenses = DataManager.shared.loadExpenses(user: auth.currentUser)
                    monthlyBudget = DataManager.shared.loadMonthlyBudget(user: auth.currentUser) ?? MonthlyBudget(amount: 0)
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
            
            RecurringPaymentsView()
                .tabItem {
                    Label("Fijos", systemImage: "calendar.badge.clock")
                }
        }
    }
    
    @ViewBuilder
    private func summaryBlock(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
