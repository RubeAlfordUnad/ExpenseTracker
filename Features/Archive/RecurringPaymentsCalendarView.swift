import SwiftUI

struct RecurringPaymentsCalendarView: View {

    @EnvironmentObject var settings: AppSettings

    var payments: [RecurringPayment]

    @State private var selectedDay: Int? = nil
    @State private var popupPayments: [RecurringPayment] = []
    @State private var showPopup = false

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 6),
        count: 7
    )

    var today: Int {
        Calendar.current.component(.day, from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(settings.language == .spanish ? "Calendario de pagos" : "Payment calendar")
                    .font(.headline)

                Spacer()

                legend
            }
            .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(1...31, id: \.self) { day in
                    let dayPayments = payments.filter { $0.dueDay == day }

                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(backgroundColor(for: day, payments: dayPayments))

                        Text("\(day)")
                            .font(.caption.bold())

                        if !dayPayments.isEmpty {
                            VStack {
                                Spacer()

                                HStack(spacing: 3) {
                                    ForEach(dayPayments.prefix(3)) { payment in
                                        Circle()
                                            .fill(colorForCategory(payment.category))
                                            .frame(width: 5, height: 5)
                                    }
                                }
                                .padding(.bottom, 3)
                            }
                        }
                    }
                    .frame(height: 32)
                    .onTapGesture {
                        selectedDay = day
                        popupPayments = dayPayments
                        showPopup = true
                    }
                    .onLongPressGesture {
                        selectedDay = day
                        popupPayments = dayPayments
                        showPopup = true
                    }
                }
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showPopup) {
            DayPaymentsPopup(
                day: selectedDay ?? 0,
                payments: popupPayments
            )
        }
    }

    private func backgroundColor(for day: Int, payments: [RecurringPayment]) -> Color {
        guard !payments.isEmpty else {
            return Color(.systemGray6)
        }

        let unpaid = payments.filter { !$0.isPaidForCurrentMonth }

        if unpaid.isEmpty {
            return Color.green.opacity(0.2)
        }

        if day == today {
            return Color.green.opacity(0.35)
        }

        if day < today {
            return Color.red.opacity(0.25)
        }

        if day <= today + 3 {
            return Color.yellow.opacity(0.25)
        }

        return Color.blue.opacity(0.15)
    }

    private func colorForCategory(_ category: RecurringPaymentCategory) -> Color {
        switch category {
        case .housing:
            return .blue
        case .transport:
            return .teal
        case .utilities:
            return .orange
        case .insurance:
            return .indigo
        case .health:
            return .red
        case .subscriptions:
            return .purple
        case .education:
            return .mint
        case .loans:
            return .pink
        case .other:
            return .gray
        }
    }

    var legend: some View {
        HStack(spacing: 8) {
            legendItem(color: .green, text: settings.language == .spanish ? "Hoy" : "Today")
            legendItem(color: .yellow, text: settings.language == .spanish ? "Pronto" : "Soon")
            legendItem(color: .red, text: settings.language == .spanish ? "Vencido" : "Overdue")
        }
    }

    func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(text)
                .font(.caption2)
        }
    }
}
