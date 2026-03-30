import Foundation
import SwiftUI
import Combine

@MainActor
final class AppSettings: ObservableObject {

    private enum Keys {
        static let theme = "app_theme"
        static let language = "app_language"
        static let country = "app_country"
        static let useAutomaticCurrency = "use_automatic_currency"
        static let manualCurrency = "manual_currency"
        static let exchangeTargetCurrency = "exchange_target_currency"
    }

    private let defaults = UserDefaults.standard

    @Published var theme: AppTheme {
        didSet {
            defaults.set(theme.rawValue, forKey: Keys.theme)
        }
    }

    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
        }
    }

    @Published var country: AppCountry {
        didSet {
            defaults.set(country.rawValue, forKey: Keys.country)
            normalizeExchangeTargetIfNeeded()
        }
    }

    @Published var useAutomaticCurrency: Bool {
        didSet {
            defaults.set(useAutomaticCurrency, forKey: Keys.useAutomaticCurrency)
            normalizeExchangeTargetIfNeeded()
        }
    }

    @Published var manualCurrency: AppCurrency {
        didSet {
            defaults.set(manualCurrency.rawValue, forKey: Keys.manualCurrency)
            normalizeExchangeTargetIfNeeded()
        }
    }

    @Published var exchangeRateTargetCurrency: AppCurrency {
        didSet {
            defaults.set(exchangeRateTargetCurrency.rawValue, forKey: Keys.exchangeTargetCurrency)
        }
    }

    init() {
        theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system

        let savedLanguage = defaults.string(forKey: Keys.language) ?? ""
        switch savedLanguage {
        case AppLanguage.english.rawValue, "English":
            language = .english
        case AppLanguage.spanish.rawValue, "Español":
            language = .spanish
        default:
            language = .spanish
        }
        country = AppCountry(rawValue: defaults.string(forKey: Keys.country) ?? "") ?? .colombia
        useAutomaticCurrency = defaults.object(forKey: Keys.useAutomaticCurrency) as? Bool ?? true
        manualCurrency = AppCurrency(rawValue: defaults.string(forKey: Keys.manualCurrency) ?? "") ?? .cop
        exchangeRateTargetCurrency = AppCurrency(rawValue: defaults.string(forKey: Keys.exchangeTargetCurrency) ?? "") ?? .usd
        normalizeExchangeTargetIfNeeded()
    }

    var effectiveCurrency: AppCurrency {
        useAutomaticCurrency ? country.defaultCurrency : manualCurrency
    }

    var appLocale: Locale {
        Locale(identifier: "\(language.localeCode)_\(country.regionCode)")
    }

    var alternativeCurrencies: [AppCurrency] {
        AppCurrency.allCases.filter { $0 != effectiveCurrency }
    }
    
    var exchangeRateIsAvailable: Bool {
        effectiveCurrency.isSupportedByExchangeAPI
    }

    var exchangeCompatibleCurrencies: [AppCurrency] {
        AppCurrency.allCases.filter(\.isSupportedByExchangeAPI)
    }

    var alternativeExchangeCurrencies: [AppCurrency] {
        exchangeCompatibleCurrencies.filter { $0 != effectiveCurrency }
    }

    func formatCurrency(_ value: Double, decimals: Int = 0) -> String {
        value.asCurrency(
            code: effectiveCurrency.rawValue,
            locale: appLocale,
            minimumFractionDigits: decimals,
            maximumFractionDigits: decimals
        )
    }

    func formatCurrency(_ value: Double, currency: AppCurrency, decimals: Int = 0) -> String {
        value.asCurrency(
            code: currency.rawValue,
            locale: appLocale,
            minimumFractionDigits: decimals,
            maximumFractionDigits: decimals
        )
    }

    func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = appLocale
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date).capitalized
    }

    func shortDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = appLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func t(_ key: String) -> String {
        translations[language]?[key] ?? translations[.spanish]?[key] ?? key
    }

    func tr(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), locale: appLocale, arguments: args)
    }

    private func normalizeExchangeTargetIfNeeded() {
        if !effectiveCurrency.isSupportedByExchangeAPI {
            exchangeRateTargetCurrency = .usd
            return
        }

        if exchangeRateTargetCurrency == effectiveCurrency || !exchangeRateTargetCurrency.isSupportedByExchangeAPI {
            exchangeRateTargetCurrency = alternativeExchangeCurrencies.first ?? .usd
        }
    }
    private let translations: [AppLanguage: [String: String]] = [
        .spanish: [
            "common.cancel": "Cancelar",
            "common.save": "Guardar",
            "common.refresh": "Actualizar",
            "common.done": "Listo",
            "common.loading": "Cargando...",
            "common.none": "Ninguna",
            

            "login.appName": "Nexora",
            "login.subtitle": "Tu dinero bajo control",
            "login.mode.login": "Entrar",
            "login.mode.register": "Registro",
            "login.username": "Usuario",
            "login.password": "Contraseña",
            "login.action.enter": "Ingresar",
            "login.action.create": "Crear cuenta",
            "login.error.complete": "Completa todos los campos",
            "login.error.created": "Cuenta creada. Ahora inicia sesión.",
            "login.error.exists": "Ese nombre de usuario ya existe",
            "login.error.invalid": "Credenciales incorrectas",
            "login.footer.register": "Crea tu cuenta y empieza a organizar tus finanzas.",
            "login.footer.login": "Inicia sesión para seguir administrando tus gastos.",

            "tab.expenses": "Gastos",
            "tab.stats": "Estadísticas",
            "tab.debts": "Deudas",
            "tab.recurring": "Fijos",

            "main.logout": "Salir",
            "main.screenTitle": "Mis gastos",
            "main.monthlySummary": "Resumen mensual",
            "main.totalSpent": "Total gastado",
            "main.available": "Disponible",
            "main.editBudgetTitle": "Editar presupuesto mensual",
            "main.editBudgetPlaceholder": "Ej: 6000000",
            "main.editBudgetMessage": "Escribe el nuevo valor del presupuesto.",
            "main.progressTitle": "Uso del presupuesto",
            "main.progressHintSetBudget": "Define un presupuesto mensual para activar alertas y seguimiento.",
            "main.progressRemaining": "Te quedan %@ disponibles este mes.",
            "main.progressExceeded": "Te pasaste por %@.",
            "main.topCategory": "Categoría con más gasto",
            "main.recentExpenses": "Gastos recientes",
            "main.noExpensesTitle": "Aún no tienes gastos registrados",
            "main.noExpensesSubtitle": "Pulsa el botón + para agregar tu primer gasto.",
            "main.quickActions": "Accesos rápidos",
            "main.historyTitle": "Ver historial mensual",
            "main.historySubtitle": "Revisa todos tus movimientos",
            "main.settingsTitle": "Abrir ajustes",
            "main.settingsSubtitle": "Tema, idioma y preferencias",
            "main.movesCount": "%d movimientos",
            "main.goodMorning": "Buenos días, %@",
            "main.goodAfternoon": "Buenas tardes, %@",
            "main.goodEvening": "Buenas noches, %@",
            "main.header.noBudget": "Empieza definiendo tu presupuesto mensual para organizar mejor tus gastos.",
            "main.header.hasBudget": "Ya tienes presupuesto.",
            "main.header.over": "Vas por encima de tu presupuesto.",
            "main.header.near": "Vas cerca del límite mensual.",
            "main.header.ok": "Tu presupuesto y tus movimientos están bajo control.",

            "settings.title": "Configuración",
            "settings.section.profile": "Perfil",
            "settings.section.appearance": "Apariencia",
            "settings.section.app": "App",
            "settings.section.legal": "Legal",
            "settings.profile": "Perfil",
            "settings.notifications": "Notificaciones",
            "settings.language": "Idioma",
            "settings.theme": "Tema",
            "settings.regionCurrency": "País y moneda",
            "settings.exchangeRate": "Tipo de cambio",
            "settings.terms": "Términos y condiciones",
            "settings.profileSubtitle": "Foto de perfil y avatar",
            "settings.notificationsSubtitle": "Permisos y alertas del presupuesto",
            "settings.languageSubtitle": "Elige cómo se muestra el texto",
            "settings.themeSubtitle": "Sistema, claro u oscuro",
            "settings.regionSubtitle": "Región, moneda automática o manual",
            "settings.exchangeSubtitle": "Consulta la tasa actual entre monedas",

            "profile.title": "Perfil",
            "profile.changePhoto": "Cambiar foto",
            "profile.removePhoto": "Eliminar foto",
            "profile.helper": "La imagen que elijas se verá en el inicio de la app.",

            "theme.title": "Tema",

            "language.title": "Idioma",

            "region.title": "País y moneda",
            "region.country": "País o región",
            "region.currencyMode": "Moneda",
            "region.useAuto": "Usar moneda automática del país",
            "region.manualCurrency": "Moneda manual",
            "region.currentCurrency": "Moneda actual",
            "region.preview": "Vista previa",
            "region.note": "Si activas la moneda automática, la app usará la divisa sugerida por el país seleccionado.",

            "exchange.title": "Tipo de cambio",
            "exchange.baseCurrency": "Moneda base",
            "exchange.targetCurrency": "Comparar con",
            "exchange.currentRate": "Cambio actual",
            "exchange.lastUpdate": "Última actualización",
            "exchange.sample": "Ejemplo con 100 unidades",
            "exchange.error": "No se pudo obtener el tipo de cambio.",

            "notifications.title": "Notificaciones",
            "notifications.permissions": "Permisos",
            "notifications.state": "Estado",
            "notifications.request": "Solicitar permisos",
            "notifications.test": "Probar notificación",
            "notifications.recurring": "Pagos recurrentes",
            "notifications.recurringToggle": "Activar recordatorios",
            "notifications.budget": "Presupuesto",
            "notifications.budgetToggle": "Activar alertas",
            "notifications.threshold": "Umbral de alerta: %d%%",
            "notifications.status.notRequested": "No solicitadas",
            "notifications.status.denied": "Denegadas",
            "notifications.status.allowed": "Permitidas",
            "notifications.status.provisional": "Provisionales",
            "notifications.status.temporary": "Temporales",
            "notifications.status.unknown": "Desconocido",
            "notifications.status.unverified": "No verificado",

            "stats.title": "Estadísticas",
            "stats.totalSpent": "Total gastado",
            "stats.transactions": "Movimientos",
            "stats.average": "Promedio",
            "stats.topCategory": "Categoría top",
            "stats.noDataTitle": "Aún no hay datos",
            "stats.noDataSubtitle": "Agrega gastos para ver tus estadísticas",
            "stats.breakdown": "Desglose por categoría",
            "stats.ofTotal": "%.0f%% del total",

            "monthly.title": "Historial mensual",
            "monthly.overview": "Resumen mensual",
            "monthly.total": "Total",
            "monthly.average": "Promedio",
            "monthly.topCategory": "Categoría top: %@",
            "monthly.transactions": "Movimientos",

            "debts.title": "Tarjetas",
            "debts.totalOwed": "Total adeudado",
            "debts.noCards": "No tienes tarjetas registradas",
            "debts.newCard": "Nueva tarjeta",
            "debts.cardName": "Nombre de la tarjeta",
            "debts.brand": "Marca",
            "debts.totalLimit": "Cupo total",
            "debts.currentDebt": "Deuda actual",
            "debts.balancePending": "Saldo pendiente",
            "debts.creditLimit": "Cupo",
            "debts.used": "%d%% usado",
            "debts.registerPayment": "Registrar pago",
            "debts.paymentAmount": "Monto del pago",
            "debts.apply": "Aplicar",

            "expense.new": "Nuevo gasto",
            "expense.title": "Título",
            "expense.amount": "Monto",
            "expense.category": "Categoría",

            "terms.title": "Términos",
            
            "exchange.unavailableTitle": "No disponible para esta moneda",
            "exchange.unavailableMessage": "La fuente actual de tasas no soporta %@ como moneda base. Cambia la moneda manual a USD, EUR, MXN, BRL o GBP, o usa otra API para soportar COP.",
            
            "profile.dangerZone": "Zona de peligro",
            "profile.deleteAccount": "Eliminar cuenta",
            "profile.deleteAccountHelper": "Esta acción eliminará tu cuenta local y todos tus datos guardados en este dispositivo.",
            "profile.deleteAccountTitle": "Eliminar cuenta",
            "profile.deleteAccountMessage": "Esta acción no se puede deshacer. Se borrarán gastos, deudas, pagos fijos, presupuesto, foto de perfil y preferencias.",
            "profile.deleteAccountConfirm": "Sí, eliminar",
            "profile.deleteAccountErrorTitle": "No se pudo eliminar",
            "profile.deleteAccountErrorMessage": "No se encontró una sesión válida para eliminar la cuenta.",
            "settings.privacyPolicy": "Política de privacidad",

            "privacy.title": "Política de privacidad",
            "privacy.openWebsite": "Abrir política pública",
            "privacy.urlPending": "Antes de publicar, agrega la URL pública de tu política de privacidad.",
            "onboarding.skip": "Omitir",
            "onboarding.next": "Siguiente",
            "onboarding.getStarted": "Comenzar",
            "onboarding.footer": "Organiza tus finanzas personales de forma simple y clara.",

            "onboarding.page1.title": "Controla tus gastos",
            "onboarding.page1.description": "Registra cada gasto y entiende con claridad en qué se va tu dinero.",

            "onboarding.page2.title": "Cuida tu presupuesto",
            "onboarding.page2.description": "Define un presupuesto mensual, controla tus deudas y sigue tus pagos fijos.",

            "onboarding.page3.title": "Toma mejores decisiones",
            "onboarding.page3.description": "Consulta estadísticas y detecta patrones para mejorar tus finanzas.",
            "recurring.title": "Pagos fijos",
            "recurring.heroTitle": "Tu calendario de compromisos",
            "recurring.heroSubtitle": "Controla qué ya pagaste, qué viene en camino y qué se te puede atrasar este mes.",
            "recurring.monthlyCommitment": "Compromiso mensual",
            "recurring.pending": "Pendiente",
            "recurring.paid": "Pagados",
            "recurring.fixedItems": "Total fijos",
            "recurring.nextDay": "Próximo: día %d",
            "recurring.noUpcoming": "Sin próximos",
            "recurring.savedCount": "%d registrados",
            "recurring.emptyAll": "Todavía no tienes pagos fijos",
            "recurring.emptyFiltered": "No hay resultados para este filtro",
            "recurring.emptySubtitle": "Agrega servicios, suscripciones o cuotas para tener claro qué debes cubrir cada mes.",
            "recurring.addButton": "Agregar pago fijo",
            "recurring.form.name": "Nombre del pago",
            "recurring.form.day": "Día de pago: %d",
            "recurring.form.new": "Nuevo pago fijo",
        ],
        .english: [
            "common.cancel": "Cancel",
            "common.save": "Save",
            "common.refresh": "Refresh",
            "common.done": "Done",
            "common.loading": "Loading...",
            "common.none": "None",

            "login.appName": "Nexora",
            "login.subtitle": "Your money under control",
            "login.mode.login": "Login",
            "login.mode.register": "Register",
            "login.username": "Username",
            "login.password": "Password",
            "login.action.enter": "Enter",
            "login.action.create": "Create account",
            "login.error.complete": "Complete all fields",
            "login.error.created": "Account created. Now log in.",
            "login.error.exists": "That username already exists",
            "login.error.invalid": "Incorrect credentials",
            "login.footer.register": "Create your account and start organizing your finances.",
            "login.footer.login": "Log in to continue managing your expenses.",

            "tab.expenses": "Expenses",
            "tab.stats": "Stats",
            "tab.debts": "Debts",
            "tab.recurring": "Recurring",

            "main.logout": "Log out",
            "main.screenTitle": "My expenses",
            "main.monthlySummary": "Monthly summary",
            "main.totalSpent": "Total spent",
            "main.available": "Available",
            "main.editBudgetTitle": "Edit monthly budget",
            "main.editBudgetPlaceholder": "Ex: 6000000",
            "main.editBudgetMessage": "Type the new budget value.",
            "main.progressTitle": "Budget usage",
            "main.progressHintSetBudget": "Set a monthly budget to enable alerts and tracking.",
            "main.progressRemaining": "You still have %@ available this month.",
            "main.progressExceeded": "You are over budget by %@.",
            "main.topCategory": "Top spending category",
            "main.recentExpenses": "Recent expenses",
            "main.noExpensesTitle": "You have no expenses yet",
            "main.noExpensesSubtitle": "Tap the + button to add your first expense.",
            "main.quickActions": "Quick actions",
            "main.historyTitle": "Open monthly history",
            "main.historySubtitle": "Review all your movements",
            "main.settingsTitle": "Open settings",
            "main.settingsSubtitle": "Theme, language and preferences",
            "main.movesCount": "%d transactions",
            "main.goodMorning": "Good morning, %@",
            "main.goodAfternoon": "Good afternoon, %@",
            "main.goodEvening": "Good evening, %@",
            "main.header.noBudget": "Start by setting your monthly budget to organize your finances better.",
            "main.header.hasBudget": "You already have a budget.",
            "main.header.over": "You are above your budget.",
            "main.header.near": "You are close to your monthly limit.",
            "main.header.ok": "Your budget and movements are under control.",

            "settings.title": "Settings",
            "settings.section.profile": "Profile",
            "settings.section.appearance": "Appearance",
            "settings.section.app": "App",
            "settings.section.legal": "Legal",
            "settings.profile": "Profile",
            "settings.notifications": "Notifications",
            "settings.language": "Language",
            "settings.theme": "Theme",
            "settings.regionCurrency": "Country and currency",
            "settings.exchangeRate": "Exchange rate",
            "settings.terms": "Terms and conditions",
            "settings.profileSubtitle": "Profile photo and avatar",
            "settings.notificationsSubtitle": "Permissions and budget alerts",
            "settings.languageSubtitle": "Choose how text is displayed",
            "settings.themeSubtitle": "System, light or dark",
            "settings.regionSubtitle": "Region, auto currency or manual override",
            "settings.exchangeSubtitle": "Check the current rate between currencies",

            "profile.title": "Profile",
            "profile.changePhoto": "Change photo",
            "profile.removePhoto": "Remove photo",
            "profile.helper": "The selected image will be shown in the app home screen.",

            "theme.title": "Theme",

            "language.title": "Language",

            "region.title": "Country and currency",
            "region.country": "Country or region",
            "region.currencyMode": "Currency",
            "region.useAuto": "Use the country's automatic currency",
            "region.manualCurrency": "Manual currency",
            "region.currentCurrency": "Current currency",
            "region.preview": "Preview",
            "region.note": "When automatic currency is enabled, the app uses the currency suggested by the selected country.",

            "exchange.title": "Exchange rate",
            "exchange.baseCurrency": "Base currency",
            "exchange.targetCurrency": "Compare with",
            "exchange.currentRate": "Current rate",
            "exchange.lastUpdate": "Last update",
            "exchange.sample": "Example with 100 units",
            "exchange.error": "The exchange rate could not be loaded.",

            "notifications.title": "Notifications",
            "notifications.permissions": "Permissions",
            "notifications.state": "Status",
            "notifications.request": "Request permission",
            "notifications.test": "Send test notification",
            "notifications.recurring": "Recurring payments",
            "notifications.recurringToggle": "Enable reminders",
            "notifications.budget": "Budget",
            "notifications.budgetToggle": "Enable alerts",
            "notifications.threshold": "Alert threshold: %d%%",
            "notifications.status.notRequested": "Not requested",
            "notifications.status.denied": "Denied",
            "notifications.status.allowed": "Allowed",
            "notifications.status.provisional": "Provisional",
            "notifications.status.temporary": "Temporary",
            "notifications.status.unknown": "Unknown",
            "notifications.status.unverified": "Unverified",

            "stats.title": "Stats",
            "stats.totalSpent": "Total spent",
            "stats.transactions": "Transactions",
            "stats.average": "Average",
            "stats.topCategory": "Top category",
            "stats.noDataTitle": "No data yet",
            "stats.noDataSubtitle": "Add expenses to see your stats",
            "stats.breakdown": "Category breakdown",
            "stats.ofTotal": "%.0f%% of total",

            "monthly.title": "Monthly history",
            "monthly.overview": "Monthly overview",
            "monthly.total": "Total",
            "monthly.average": "Average",
            "monthly.topCategory": "Top category: %@",
            "monthly.transactions": "Transactions",

            "debts.title": "Cards",
            "debts.totalOwed": "Total owed",
            "debts.noCards": "You have no saved cards",
            "debts.newCard": "New card",
            "debts.cardName": "Card name",
            "debts.brand": "Brand",
            "debts.totalLimit": "Credit limit",
            "debts.currentDebt": "Current debt",
            "debts.balancePending": "Outstanding balance",
            "debts.creditLimit": "Limit",
            "debts.used": "%d%% used",
            "debts.registerPayment": "Add payment",
            "debts.paymentAmount": "Payment amount",
            "debts.apply": "Apply",

            "expense.new": "New expense",
            "expense.title": "Title",
            "expense.amount": "Amount",
            "expense.category": "Category",

            "terms.title": "Terms",
            "exchange.unavailableTitle": "Not available for this currency",
            "exchange.unavailableMessage": "The current rate source does not support %@ as a base currency. Switch the manual currency to USD, EUR, MXN, BRL or GBP, or use another API to support COP.",
            
            "profile.dangerZone": "Danger zone",
            "profile.deleteAccount": "Delete account",
            "profile.deleteAccountHelper": "This action will delete your local account and all data stored on this device.",
            "profile.deleteAccountTitle": "Delete account",
            "profile.deleteAccountMessage": "This action cannot be undone. Expenses, debts, recurring payments, budget, profile photo and preferences will be removed.",
            "profile.deleteAccountConfirm": "Yes, delete",
            "profile.deleteAccountErrorTitle": "Could not delete account",
            "profile.deleteAccountErrorMessage": "No valid session was found to delete the account.",
            "settings.privacyPolicy": "Privacy Policy",

            "privacy.title": "Privacy Policy",
            "privacy.openWebsite": "Open public policy",
            "privacy.urlPending": "Before publishing, add the public URL of your privacy policy.",
            "onboarding.skip": "Skip",
            "onboarding.next": "Next",
            "onboarding.getStarted": "Get Started",
            "onboarding.footer": "Organize your personal finances in a simple and clear way.",

            "onboarding.page1.title": "Track your spending",
            "onboarding.page1.description": "Record each expense and clearly understand where your money goes.",

            "onboarding.page2.title": "Protect your budget",
            "onboarding.page2.description": "Set a monthly budget, manage your debts and keep up with recurring payments.",

            "onboarding.page3.title": "Make smarter decisions",
            "onboarding.page3.description": "Review stats and spot patterns to improve your finances.",
            "recurring.title": "Recurring payments",
            "recurring.heroTitle": "Your commitment calendar",
            "recurring.heroSubtitle": "Track what is paid, what is coming next, and what may become overdue this month.",
            "recurring.monthlyCommitment": "Monthly commitment",
            "recurring.pending": "Pending",
            "recurring.paid": "Paid",
            "recurring.fixedItems": "Fixed items",
            "recurring.nextDay": "Next: day %d",
            "recurring.noUpcoming": "No upcoming",
            "recurring.savedCount": "%d saved",
            "recurring.emptyAll": "You do not have recurring payments yet",
            "recurring.emptyFiltered": "No results for this filter",
            "recurring.emptySubtitle": "Add services, subscriptions or installments to keep your monthly obligations under control.",
            "recurring.addButton": "Add recurring payment",
            "recurring.form.name": "Payment name",
            "recurring.form.day": "Payment day: %d",
            "recurring.form.new": "New recurring payment",
        ]
    ]
}
