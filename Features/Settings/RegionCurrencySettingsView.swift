import SwiftUI

struct RegionCurrencySettingsView: View {

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SettingsHeroCard(
                    title: settings.t("region.title"),
                    subtitle: heroSubtitle,
                    icon: "dollarsign.arrow.circlepath",
                    chips: [
                        "\(settings.country.flag) \(settings.country.title(for: settings.language))",
                        settings.effectiveCurrency.rawValue
                    ]
                )

                SettingsSectionTitleView(title: settings.t("region.country"))
                SettingsCard {
                    Menu {
                        ForEach(AppCountry.allCases) { country in
                            Button {
                                settings.country = country
                            } label: {
                                if settings.country == country {
                                    Label("\(country.flag) \(country.title(for: settings.language))", systemImage: "checkmark")
                                } else {
                                    Text("\(country.flag) \(country.title(for: settings.language))")
                                }
                            }
                        }
                    } label: {
                        SettingsNavigationTile(
                            icon: "flag",
                            title: settings.t("region.country"),
                            subtitle: "\(settings.country.flag) \(settings.country.title(for: settings.language))"
                        )
                    }
                    .buttonStyle(.plain)
                }

                SettingsSectionTitleView(title: settings.t("region.currencyMode"))
                SettingsCard {
                    Toggle(isOn: $settings.useAutomaticCurrency) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(settings.t("region.useAuto"))
                                .foregroundColor(.primary)

                            Text(settings.t("region.note"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)

                    if !settings.useAutomaticCurrency {
                        SettingsDivider()

                        Menu {
                            ForEach(AppCurrency.allCases) { currency in
                                Button {
                                    settings.manualCurrency = currency
                                } label: {
                                    if settings.manualCurrency == currency {
                                        Label("\(currency.rawValue) · \(currency.title(for: settings.language))", systemImage: "checkmark")
                                    } else {
                                        Text("\(currency.rawValue) · \(currency.title(for: settings.language))")
                                    }
                                }
                            }
                        } label: {
                            SettingsNavigationTile(
                                icon: "banknote",
                                title: settings.t("region.manualCurrency"),
                                subtitle: "\(settings.manualCurrency.rawValue) · \(settings.manualCurrency.title(for: settings.language))"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                SettingsSectionTitleView(title: settings.language == .spanish ? "Vista previa" : "Preview")
                SettingsCard {
                    SettingsInfoRow(
                        title: settings.t("region.currentCurrency"),
                        value: settings.effectiveCurrency.rawValue
                    )

                    SettingsDivider()

                    SettingsInfoRow(
                        title: settings.t("region.preview"),
                        value: settings.formatCurrency(1234567)
                    )
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationTitle(settings.t("region.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSubtitle: String {
        settings.language == .spanish
        ? "Controla cómo la app interpreta tu región y cómo muestra el dinero."
        : "Control how the app interprets your region and displays money."
    }
}
