import SwiftUI

struct PrivacyPolicyView: View {

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LegalHeroCard(
                    title: settings.t("privacy.title"),
                    subtitle: heroSubtitle,
                    updatedText: AppMetadata.legalLastUpdatedLine(for: settings.language),
                    icon: "lock.doc"
                )

                ForEach(policySections) { section in
                    LegalSectionCard(section: section)
                }

                resourcesCard
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
        .accessibilityIdentifier("privacy.screen")
        .navigationTitle(settings.t("privacy.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSubtitle: String {
        switch settings.language {
        case .spanish:
            return "Qué datos guarda la app, cómo se usan, dónde viven y cómo puedes eliminarlos."
        case .english:
            return "What data the app stores, how it is used, where it lives, and how you can delete it."
        }
    }

    private var policySections: [LegalSectionContent] {
        switch settings.language {
        case .spanish:
            return [
                LegalSectionContent(
                    icon: "person.text.rectangle",
                    title: "Quiénes somos",
                    summary: "Contexto general sobre la app.",
                    paragraphs: [
                        "\(AppMetadata.displayName) es una app de organización financiera personal diseñada para ayudarte a registrar gastos, ingresos, deudas, pagos recurrentes, presupuestos y movimientos desde tu propio dispositivo."
                    ]
                ),
                LegalSectionContent(
                    icon: "externaldrive",
                    title: "Qué datos puede guardar la app",
                    summary: "La información depende de lo que tú configures y registres.",
                    bullets: [
                        "nombre de usuario de tu cuenta local",
                        "contraseña local protegida en Keychain",
                        "gastos, ingresos, deudas y pagos recurrentes",
                        "presupuesto mensual",
                        "preferencias de idioma, tema, región y moneda",
                        "imagen y nombre de perfil",
                        "preferencias de notificaciones"
                    ]
                ),
                LegalSectionContent(
                    icon: "gearshape.2",
                    title: "Para qué se usan los datos",
                    summary: "Se usan para que la app funcione como herramienta personal.",
                    bullets: [
                        "registrar movimientos",
                        "mostrar resúmenes y tendencias",
                        "organizar deudas y pagos recurrentes",
                        "personalizar la experiencia",
                        "programar recordatorios locales y alertas de presupuesto"
                    ]
                ),
                LegalSectionContent(
                    icon: "internaldrive",
                    title: "Dónde se guardan los datos",
                    summary: "La app prioriza almacenamiento local.",
                    paragraphs: [
                        "En la versión actual, la mayor parte de la información se guarda localmente en tu dispositivo.",
                        "\(AppMetadata.displayName) no vende tus datos personales ni los comparte con fines publicitarios."
                    ]
                ),
                LegalSectionContent(
                    icon: "hand.raised",
                    title: "Permisos del dispositivo",
                    summary: "Solo se piden cuando la función lo necesita.",
                    bullets: [
                        "notificaciones, para recordatorios de pagos y alertas de presupuesto",
                        "autenticación biométrica, para proteger el acceso a la app cuando lo habilitas",
                        "acceso a fotos, si eliges una imagen de perfil"
                    ]
                ),
                LegalSectionContent(
                    icon: "trash",
                    title: "Eliminación de cuenta y datos",
                    summary: "Puedes borrar tus datos locales desde la app.",
                    paragraphs: [
                        "Puedes eliminar tu cuenta local y sus datos asociados desde la sección Perfil dentro de la app.",
                        "Al eliminar la cuenta se borran los datos locales asociados a ese usuario en ese dispositivo."
                    ]
                ),
                LegalSectionContent(
                    icon: "figure.and.child.holdinghands",
                    title: "Menores de edad",
                    summary: "La app no está dirigida intencionalmente a menores de 13 años.",
                    paragraphs: []
                ),
                LegalSectionContent(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Cambios a esta política",
                    summary: "La política puede actualizarse con nuevas versiones o cambios de flujo.",
                    paragraphs: [
                        "Esta política puede actualizarse cuando cambien funciones, flujos de datos o requisitos legales.",
                        "Cuando eso ocurra, la fecha de última actualización también cambiará."
                    ]
                )
            ]

        case .english:
            return [
                LegalSectionContent(
                    icon: "person.text.rectangle",
                    title: "Who we are",
                    summary: "General context about the app.",
                    paragraphs: [
                        "\(AppMetadata.displayName) is a personal finance organization app designed to help you track expenses, income, debts, recurring payments, budgets, and transactions directly on your device."
                    ]
                ),
                LegalSectionContent(
                    icon: "externaldrive",
                    title: "What data the app may store",
                    summary: "Stored information depends on what you configure and enter.",
                    bullets: [
                        "local account username",
                        "local password protected in Keychain",
                        "expenses, income, debts, and recurring payments",
                        "monthly budget",
                        "language, theme, region, and currency preferences",
                        "profile image and display name",
                        "notification preferences"
                    ]
                ),
                LegalSectionContent(
                    icon: "gearshape.2",
                    title: "How data is used",
                    summary: "Data is used to make the app work as a personal tool.",
                    bullets: [
                        "recording transactions",
                        "showing summaries and trends",
                        "organizing debts and recurring payments",
                        "personalizing the experience",
                        "scheduling local reminders and budget alerts"
                    ]
                ),
                LegalSectionContent(
                    icon: "internaldrive",
                    title: "Where data is stored",
                    summary: "The app prioritizes local storage.",
                    paragraphs: [
                        "In the current version, most information is stored locally on your device.",
                        "\(AppMetadata.displayName) does not sell your personal data or share it for advertising purposes."
                    ]
                ),
                LegalSectionContent(
                    icon: "hand.raised",
                    title: "Device permissions",
                    summary: "Permissions are requested only when needed for a feature.",
                    bullets: [
                        "notifications, for payment reminders and budget alerts",
                        "biometric authentication, to protect app access when enabled",
                        "photo access, if you choose a profile image"
                    ]
                ),
                LegalSectionContent(
                    icon: "trash",
                    title: "Account and data deletion",
                    summary: "You can remove local data from within the app.",
                    paragraphs: [
                        "You can delete your local account and associated data from the Profile section inside the app.",
                        "Deleting the account removes local data associated with that user on that device."
                    ]
                ),
                LegalSectionContent(
                    icon: "figure.and.child.holdinghands",
                    title: "Children",
                    summary: "The app is not intentionally directed to children under 13.",
                    paragraphs: []
                ),
                LegalSectionContent(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Changes to this policy",
                    summary: "This policy may change in future releases or legal updates.",
                    paragraphs: [
                        "This policy may be updated when app features, data flows, or legal requirements change.",
                        "When that happens, the last updated date will also change."
                    ]
                )
            ]
        }
    }

    private var resourcesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "link.badge.plus")
                    .foregroundColor(BrandPalette.primary)

                Text(settings.language == .spanish ? "Recursos y contacto" : "Resources and contact")
                    .font(.headline.weight(.semibold))
            }

            Text(
                settings.language == .spanish
                ? "Desde aquí puedes abrir la política publicada o contactar soporte."
                : "From here you can open the published policy or contact support."
            )
            .font(.subheadline)
            .foregroundColor(.secondary)

            VStack(spacing: 10) {
                if let url = AppMetadata.privacyPolicyURL {
                    Link(destination: url) {
                        Label(settings.t("privacy.openWebsite"), systemImage: "globe")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("privacy.openWebsite")
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(settings.t("privacy.urlPending"))
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.secondary)

                        Text(
                            settings.language == .spanish
                            ? "Antes de publicar, reemplaza la URL vacía por la URL pública real de tu política."
                            : "Before publishing, replace the empty URL with the real public URL of your policy."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(BrandPalette.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                if let supportEmailURL = AppMetadata.supportEmailURL {
                    Link(destination: supportEmailURL) {
                        Label(
                            settings.language == .spanish ? "Contactar soporte" : "Contact support",
                            systemImage: "envelope"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("privacy.contactSupport")
                }
            }
        }
        .padding(18)
        .background(BrandPalette.cardGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
