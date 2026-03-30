//
//  YearlyTrendChartCard.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 21/03/26.
//

import SwiftUI
import Charts

struct HistoryYearPoint: Identifiable {
    let id: Int
    let month: Int
    let label: String
    let total: Double
}

struct YearlyTrendChartCard: View {

    @EnvironmentObject var settings: AppSettings

    let points: [HistoryYearPoint]
    let selectedMonth: Int
    let annualTotal: Double

    private var peakPoint: HistoryYearPoint? {
        points.max(by: { $0.total < $1.total })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.language == .spanish ? "Ritmo del año" : "Year rhythm")
                        .font(.headline)

                    Text(settings.language == .spanish ? "Tu gasto mes a mes" : "Your month-by-month spend")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(settings.formatCurrency(annualTotal, decimals: 0))
                    .font(.subheadline.bold())
            }

            Chart(points) { point in
                BarMark(
                    x: .value("Month", point.label),
                    y: .value("Total", point.total)
                )
                .foregroundStyle(
                    point.month == selectedMonth
                    ? Color.blue
                    : Color.gray.opacity(0.28)
                )
                .cornerRadius(8)
            }
            .frame(height: 220)

            if let peakPoint, peakPoint.total > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)

                    Text(
                        settings.language == .spanish
                        ? "Mes más alto: \(peakPoint.label) con \(settings.formatCurrency(peakPoint.total, decimals: 0))"
                        : "Highest month: \(peakPoint.label) with \(settings.formatCurrency(peakPoint.total, decimals: 0))"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    Spacer()
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
