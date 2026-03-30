import SwiftUI

struct RegionCurrencySettingsView: View {

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker(settings.t("region.country"), selection: $settings.country) {
                    ForEach(AppCountry.allCases) { country in
                        Text("\(country.flag) \(country.title(for: settings.language))")
                            .tag(country)
                    }
                }
            } header: {
                Text(settings.t("region.country"))
            }

            Section {
                Toggle(settings.t("region.useAuto"), isOn: $settings.useAutomaticCurrency)

                if !settings.useAutomaticCurrency {
                    Picker(settings.t("region.manualCurrency"), selection: $settings.manualCurrency) {
                        ForEach(AppCurrency.allCases) { currency in
                            Text("\(currency.rawValue) · \(currency.title(for: settings.language))")
                                .tag(currency)
                        }
                    }
                }
            } header: {
                Text(settings.t("region.currencyMode"))
            } footer: {
                Text(settings.t("region.note"))
            }

            Section {
                HStack {
                    Text(settings.t("region.currentCurrency"))
                    Spacer()
                    Text(settings.effectiveCurrency.rawValue)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text(settings.t("region.preview"))
                    Spacer()
                    Text(settings.formatCurrency(1234567))
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(settings.t("region.title"))
    }
}
