//
//  HistoryMonthStripView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 21/03/26.
//

import SwiftUI

struct HistoryMonthData: Identifiable, Hashable {
    let id: Int
    let month: Int
    let label: String
    let total: Double
    let hasExpenses: Bool
}

struct HistoryMonthStripView: View {

    @EnvironmentObject var settings: AppSettings

    let months: [HistoryMonthData]
    let selectedMonth: Int
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.language == .spanish ? "Explora por mes" : "Explore by month")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(months) { item in
                        Button {
                            onSelect(item.month)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.label)
                                    .font(.subheadline.bold())

                                Text(settings.formatCurrency(item.total, decimals: 0))
                                    .font(.caption)
                                    .foregroundColor(
                                        item.month == selectedMonth
                                        ? .white.opacity(0.88)
                                        : .secondary
                                    )

                                if item.hasExpenses {
                                    Text(settings.language == .spanish ? "Con movimientos" : "With activity")
                                        .font(.caption2.weight(.medium))
                                        .foregroundColor(
                                            item.month == selectedMonth
                                            ? .white.opacity(0.78)
                                            : .blue
                                        )
                                } else {
                                    Text(settings.language == .spanish ? "Sin datos" : "No data")
                                        .font(.caption2.weight(.medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(width: 118, alignment: .leading)
                            .padding(14)
                            .background(background(for: item))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(
                                        item.month == selectedMonth
                                        ? Color.blue.opacity(0.35)
                                        : Color.white.opacity(0.05),
                                        lineWidth: 1
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    @ViewBuilder
    private func background(for item: HistoryMonthData) -> some View {
        if item.month == selectedMonth {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.95),
                    Color.blue.opacity(0.60),
                    Color.indigo.opacity(0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color(.secondarySystemBackground)
        }
    }
}
