import SwiftUI

struct ExchangeRateView: View {

    @EnvironmentObject var settings: AppSettings
    @StateObject private var viewModel = ExchangeRateViewModel()

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(settings.t("exchange.baseCurrency"))
                    Spacer()
                    Text(settings.effectiveCurrency.rawValue)
                        .foregroundColor(.secondary)
                }

                if settings.exchangeRateIsAvailable {
                    Picker(settings.t("exchange.targetCurrency"), selection: $settings.exchangeRateTargetCurrency) {
                        ForEach(settings.alternativeExchangeCurrencies) { currency in
                            Text("\(currency.rawValue) · \(currency.title(for: settings.language))")
                                .tag(currency)
                        }
                    }
                    .onChange(of: settings.exchangeRateTargetCurrency) { _, _ in
                        Task {
                            await reloadRate()
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(settings.t("exchange.unavailableTitle"))
                            .font(.subheadline.weight(.semibold))

                        Text(settings.tr("exchange.unavailableMessage", settings.effectiveCurrency.rawValue))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                        Text(settings.t("common.loading"))
                            .foregroundColor(.secondary)
                    }
                } else {
                    infoRow(title: settings.t("exchange.currentRate"), value: viewModel.rateDescription)
                    infoRow(title: settings.t("exchange.sample"), value: viewModel.sampleDescription)
                    infoRow(title: settings.t("exchange.lastUpdate"), value: viewModel.lastUpdated)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button(settings.t("common.refresh")) {
                    Task {
                        await reloadRate()
                    }
                }
                .disabled(!settings.exchangeRateIsAvailable)
            }
        }
        .navigationTitle(settings.t("exchange.title"))
        .task {
            await reloadRate()
        }
    }

    private func reloadRate() async {
        await viewModel.refresh(
            base: settings.effectiveCurrency,
            target: settings.exchangeRateTargetCurrency,
            settings: settings
        )
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.secondary)
        }
    }
}
