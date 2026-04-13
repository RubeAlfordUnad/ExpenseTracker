import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SettingsHeroCard(
                    title: settings.t("settings.title"),
                    subtitle: heroSubtitle,
                    icon: "slider.horizontal.3",
                    chips: heroChips
                )

                SettingsSectionTitleView(title: settings.t("settings.section.profile"))
                SettingsCard {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        SettingsNavigationTile(
                            icon: "person.crop.circle",
                            title: settings.t("settings.profile"),
                            subtitle: profileRowSubtitle
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.profile")
                }

                SettingsSectionTitleView(title: settings.t("settings.section.appearance"))
                SettingsCard {
                    NavigationLink {
                        ThemeSettingsView()
                    } label: {
                        SettingsNavigationTile(
                            icon: "circle.lefthalf.filled",
                            title: settings.t("settings.theme"),
                            subtitle: settings.theme.title(for: settings.language)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.theme")
                }

                SettingsSectionTitleView(title: settings.t("settings.section.app"))
                SettingsCard {
                    NavigationLink {
                        SecuritySettingsView()
                    } label: {
                        SettingsNavigationTile(
                            icon: "lock.shield",
                            title: settings.securitySectionTitle,
                            subtitle: settings.language == .spanish
                            ? "Oculta montos y protege la app al volver del fondo"
                            : "Hide amounts and protect the app when returning from background"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.security")

                    SettingsDivider()

                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsNavigationTile(
                            icon: "bell.badge",
                            title: settings.t("settings.notifications"),
                            subtitle: settings.t("settings.notificationsSubtitle")
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.notifications")

                    SettingsDivider()

                    NavigationLink {
                        LanguageSettingsView()
                    } label: {
                        SettingsNavigationTile(
                            icon: "globe",
                            title: settings.t("settings.language"),
                            subtitle: settings.language.title
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.language")

                    SettingsDivider()

                    NavigationLink {
                        RegionCurrencySettingsView()
                    } label: {
                        SettingsNavigationTile(
                            icon: "dollarsign.arrow.circlepath",
                            title: settings.t("settings.regionCurrency"),
                            subtitle: "\(settings.country.flag) \(settings.country.title(for: settings.language)) · \(settings.effectiveCurrency.rawValue)"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.regionCurrency")
                }

                SettingsSectionTitleView(title: settings.language == .spanish ? "Datos" : "Data")
                SettingsCard {
                    NavigationLink {
                        BackupRestoreView()
                    } label: {
                        SettingsNavigationTile(
                            icon: "externaldrive.badge.icloud",
                            title: settings.language == .spanish ? "Respaldo y restauración" : "Backup & restore",
                            subtitle: settings.language == .spanish
                            ? "Exporta o recupera un JSON completo de tu cuenta"
                            : "Export or recover a full JSON snapshot of your account"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.backupRestore")

                    SettingsDivider()

                    NavigationLink {
                        CustomCategoriesSettingsView(mode: .expense)
                    } label: {
                        SettingsNavigationTile(
                            icon: "arrow.up.circle",
                            title: settings.language == .spanish ? "Categorías personalizadas de gastos" : "Custom expense categories",
                            subtitle: settings.language == .spanish
                            ? "Gestiona nombres reutilizables para gastos"
                            : "Manage reusable names for expenses"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.customCategories.expense")

                    SettingsDivider()

                    NavigationLink {
                        CustomCategoriesSettingsView(mode: .income)
                    } label: {
                        SettingsNavigationTile(
                            icon: "arrow.down.circle",
                            title: settings.language == .spanish ? "Categorías personalizadas de ingresos" : "Custom income categories",
                            subtitle: settings.language == .spanish
                            ? "Gestiona nombres reutilizables para ingresos"
                            : "Manage reusable names for income"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.customCategories.income")

                    SettingsDivider()

                    NavigationLink {
                        CustomCategoriesSettingsView(mode: .moneyAccount)
                    } label: {
                        SettingsNavigationTile(
                            icon: "wallet.pass",
                            title: settings.language == .spanish ? "Categorías personalizadas de cuentas" : "Custom money account categories",
                            subtitle: settings.language == .spanish
                            ? "Gestiona nombres reutilizables para efectivo, ahorros y otras cuentas"
                            : "Manage reusable names for cash, savings, and other accounts"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.customCategories.moneyAccount")

                    SettingsDivider()

                    NavigationLink {
                        CustomCategoriesSettingsView(mode: .recurringPayment)
                    } label: {
                        SettingsNavigationTile(
                            icon: "calendar.badge.clock",
                            title: settings.language == .spanish ? "Categorías personalizadas de pagos fijos" : "Custom recurring payment categories",
                            subtitle: settings.language == .spanish
                            ? "Gestiona nombres reutilizables para pagos fijos"
                            : "Manage reusable names for recurring payments"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.customCategories.recurringPayment")
                }

                SettingsSectionTitleView(title: settings.language == .spanish ? "Legal y soporte" : "Legal and support")
                SettingsCard {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        SettingsNavigationTile(
                            icon: "hand.raised",
                            title: settings.t("settings.privacyPolicy"),
                            subtitle: settings.language == .spanish
                            ? "Datos locales, permisos y privacidad"
                            : "Local data, permissions and privacy"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.privacy")

                    SettingsDivider()

                    NavigationLink {
                        TermsView()
                    } label: {
                        SettingsNavigationTile(
                            icon: "doc.text",
                            title: settings.t("settings.terms"),
                            subtitle: settings.language == .spanish
                            ? "Uso, límites y responsabilidades"
                            : "Use, limits and responsibilities"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.terms")

                    if let supportEmailURL = AppMetadata.supportEmailURL {
                        SettingsDivider()

                        Link(destination: supportEmailURL) {
                            SettingsNavigationTile(
                                icon: "envelope",
                                title: settings.language == .spanish ? "Soporte" : "Support",
                                subtitle: AppMetadata.supportEmail,
                                showsChevron: false
                            )
                        }
                        .accessibilityIdentifier("settings.support")
                    }

                    if let publicWebsiteURL = AppMetadata.publicWebsiteURL {
                        SettingsDivider()

                        Link(destination: publicWebsiteURL) {
                            SettingsNavigationTile(
                                icon: "globe",
                                title: settings.language == .spanish ? "Sitio web" : "Website",
                                subtitle: publicWebsiteURL.absoluteString,
                                showsChevron: false
                            )
                        }
                        .accessibilityIdentifier("settings.website")
                    }
                }

                SettingsSectionTitleView(title: settings.language == .spanish ? "Acerca de" : "About")
                SettingsCard {
                    SettingsNavigationTile(
                        icon: "info.circle",
                        title: AppMetadata.displayName,
                        subtitle: AppMetadata.versionDescription(for: settings.language),
                        showsChevron: false
                    )
                    .accessibilityIdentifier("settings.version")
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .accessibilityIdentifier("settings.screen")
        .navigationTitle(settings.t("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSubtitle: String {
        switch settings.language {
        case .spanish:
            return "Personaliza seguridad, idioma, región, respaldo y datos reutilizables desde un solo lugar."
        case .english:
            return "Control security, language, region, backup, and reusable data from one place."
        }
    }

    private var heroChips: [String] {
        [
            settings.theme.title(for: settings.language),
            settings.language.title,
            "\(settings.country.flag) \(settings.effectiveCurrency.rawValue)"
        ]
    }

    private var profileRowSubtitle: String {
        let savedName = DataManager.shared.loadProfileDisplayName(user: auth.currentUser) ?? ""

        if !savedName.isEmpty {
            return savedName
        }

        if auth.isUsingLocalMode {
            return settings.language == .spanish ? "Modo local" : "Local mode"
        }

        return auth.currentUser.isEmpty ? settings.t("settings.profileSubtitle") : auth.currentUser
    }
}
