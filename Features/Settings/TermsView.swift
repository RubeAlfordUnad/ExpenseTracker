import SwiftUI

struct TermsView: View {

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LegalHeroCard(
                    title: settings.t("terms.title"),
                    subtitle: heroSubtitle,
                    updatedText: AppMetadata.legalLastUpdatedLine(for: settings.language),
                    icon: "doc.text"
                )

                ForEach(termSections) { section in
                    LegalSectionCard(section: section)
                }

                supportCard
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
        .accessibilityIdentifier("terms.screen")
        .navigationTitle(settings.t("terms.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSubtitle: String {
        switch settings.language {
        case .spanish:
            return "Un resumen claro de uso, responsabilidad, propiedad intelectual y soporte dentro de la app."
        case .english:
            return "A clear summary of app usage, responsibility, intellectual property, and support."
        }
    }

    private var termSections: [LegalSectionContent] {
        switch settings.language {
        case .spanish:
            return [
                LegalSectionContent(
                    icon: "app.badge",
                    title: "Uso de la app",
                    summary: "Qué hace la app y para qué fue creada.",
                    paragraphs: [
                        "\(AppMetadata.displayName) es una herramienta de organización financiera personal diseñada para ayudarte a registrar y visualizar gastos, ingresos, deudas, pagos fijos, transferencias y presupuestos."
                    ]
                ),
                LegalSectionContent(
                    icon: "exclamationmark.shield",
                    title: "No es asesoría financiera",
                    summary: "La app te ayuda a organizarte, no reemplaza criterio profesional.",
                    paragraphs: [
                        "\(AppMetadata.displayName) no ofrece asesoría financiera, contable, tributaria, legal ni bancaria. La información mostrada sirve como apoyo personal y organizativo."
                    ]
                ),
                LegalSectionContent(
                    icon: "person.crop.circle.badge.checkmark",
                    title: "Responsabilidad del usuario",
                    summary: "Tú sigues teniendo el control y la responsabilidad sobre tus datos.",
                    paragraphs: [
                        "Debes revisar los datos que ingresas y verificar montos, fechas, categorías y movimientos antes de tomar decisiones con base en ellos.",
                        "Eres responsable del uso que des a la información mostrada por la app."
                    ]
                ),
                LegalSectionContent(
                    icon: "lock.shield",
                    title: "Cuenta local y acceso",
                    summary: "La seguridad del dispositivo también importa.",
                    paragraphs: [
                        "Si creas una cuenta local dentro de la app, eres responsable de conservar tus credenciales y de proteger el dispositivo donde usas \(AppMetadata.displayName)."
                    ]
                ),
                LegalSectionContent(
                    icon: "sparkles.rectangle.stack",
                    title: "Funciones y disponibilidad",
                    summary: "La app puede evolucionar con nuevas versiones.",
                    paragraphs: [
                        "Algunas funciones pueden cambiar, actualizarse o eliminarse en versiones futuras.",
                        "El desarrollador puede modificar la app para mejorar estabilidad, diseño, compatibilidad y seguridad."
                    ]
                ),
                LegalSectionContent(
                    icon: "crown",
                    title: "Propiedad intelectual",
                    summary: "El contenido y el código siguen protegidos.",
                    paragraphs: [
                        "El diseño, la marca, los textos, la iconografía y el código de \(AppMetadata.displayName) están protegidos por las normas aplicables de propiedad intelectual.",
                        "No se autoriza su copia, redistribución o explotación sin permiso del titular."
                    ]
                ),
                LegalSectionContent(
                    icon: "trash",
                    title: "Eliminación de cuenta",
                    summary: "Puedes borrar tus datos locales desde la app.",
                    paragraphs: [
                        "Puedes eliminar tu cuenta local desde la sección Perfil dentro de la app.",
                        "La eliminación borra los datos locales asociados a ese usuario en el dispositivo actual."
                    ]
                ),
                LegalSectionContent(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Cambios a estos términos",
                    summary: "Los términos pueden actualizarse con nuevas versiones.",
                    paragraphs: [
                        "Estos términos pueden cambiar en futuras versiones.",
                        "El uso continuado de la app después de una actualización implica aceptación de la versión vigente."
                    ]
                )
            ]

        case .english:
            return [
                LegalSectionContent(
                    icon: "app.badge",
                    title: "App usage",
                    summary: "What the app does and what it is meant for.",
                    paragraphs: [
                        "\(AppMetadata.displayName) is a personal finance organization tool designed to help you record and review expenses, income, debts, recurring payments, transfers, and budgets."
                    ]
                ),
                LegalSectionContent(
                    icon: "exclamationmark.shield",
                    title: "Not financial advice",
                    summary: "The app helps you organize information, not replace professional advice.",
                    paragraphs: [
                        "\(AppMetadata.displayName) does not provide financial, accounting, tax, legal, or banking advice. Information shown in the app is intended for personal organization and support only."
                    ]
                ),
                LegalSectionContent(
                    icon: "person.crop.circle.badge.checkmark",
                    title: "User responsibility",
                    summary: "You remain responsible for your own data and decisions.",
                    paragraphs: [
                        "You should review the information you enter and verify amounts, dates, categories, and transactions before relying on them.",
                        "You are responsible for any decisions you make based on the information displayed in the app."
                    ]
                ),
                LegalSectionContent(
                    icon: "lock.shield",
                    title: "Local account and access",
                    summary: "Device security also matters.",
                    paragraphs: [
                        "If you create a local account inside the app, you are responsible for protecting your credentials and access to the device where \(AppMetadata.displayName) is used."
                    ]
                ),
                LegalSectionContent(
                    icon: "sparkles.rectangle.stack",
                    title: "Features and availability",
                    summary: "The app may evolve in future releases.",
                    paragraphs: [
                        "Some features may change, be updated, or be removed in future versions.",
                        "The developer may modify the app to improve stability, design, compatibility, and security."
                    ]
                ),
                LegalSectionContent(
                    icon: "crown",
                    title: "Intellectual property",
                    summary: "The app’s content and code remain protected.",
                    paragraphs: [
                        "\(AppMetadata.displayName)’s design, brand, text, iconography, and code are protected by applicable intellectual property laws.",
                        "Copying, redistributing, or commercially exploiting them without permission is not allowed."
                    ]
                ),
                LegalSectionContent(
                    icon: "trash",
                    title: "Account deletion",
                    summary: "You can remove local data from within the app.",
                    paragraphs: [
                        "You can delete your local account from the Profile section inside the app.",
                        "Deletion removes local data associated with that user on the current device."
                    ]
                ),
                LegalSectionContent(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Changes to these terms",
                    summary: "Terms may be updated over time.",
                    paragraphs: [
                        "These terms may change in future versions.",
                        "Continued use of the app after an update means acceptance of the current version."
                    ]
                )
            ]
        }
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "envelope.badge")
                    .foregroundColor(BrandPalette.primary)

                Text(settings.language == .spanish ? "Soporte y contacto" : "Support and contact")
                    .font(.headline.weight(.semibold))
            }

            Text(
                settings.language == .spanish
                ? "Si necesitas soporte general relacionado con la app, puedes escribir a:"
                : "If you need general support related to the app, you can contact:"
            )
            .font(.subheadline)
            .foregroundColor(.secondary)

            if let supportEmailURL = AppMetadata.supportEmailURL {
                Link(destination: supportEmailURL) {
                    Label(AppMetadata.supportEmail, systemImage: "arrow.up.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text(AppMetadata.supportEmail)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
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
