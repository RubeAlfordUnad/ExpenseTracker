import SwiftUI

struct PrivacyPolicyView: View {

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                legalCard(
                    title: settings.language == .spanish ? "Política de privacidad" : "Privacy policy",
                    body: policyText
                )

                VStack(alignment: .leading, spacing: 12) {
                    if let url = AppMetadata.privacyPolicyURL {
                        Link(destination: url) {
                            Label(settings.t("privacy.openWebsite"), systemImage: "link")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("privacy.openWebsite")
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(settings.t("privacy.urlPending"))
                                .font(.footnote)
                                .foregroundColor(.secondary)

                            Text(
                                settings.language == .spanish
                                ? "Antes de publicar, reemplaza la URL vacía por la URL pública real de tu política."
                                : "Before publishing, replace the empty URL with the real public URL of your policy."
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
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
            .padding(20)
        }
        .background(Color(.systemBackground))
        .accessibilityIdentifier("privacy.screen")
        .navigationTitle(settings.t("privacy.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var policyText: String {
        switch settings.language {
        case .spanish:
            return """
            \(AppMetadata.legalLastUpdatedLine(for: .spanish))

            1. Quiénes somos
            \(AppMetadata.displayName) es una aplicación de organización financiera personal diseñada para ayudarte a registrar gastos, ingresos, deudas, pagos recurrentes y presupuestos desde tu propio dispositivo.

            2. Qué datos puede guardar la app
            La app puede almacenar información que tú introduces directamente, como:
            - nombre de usuario de tu cuenta local
            - contraseña local protegida en Keychain
            - gastos, ingresos, deudas y pagos recurrentes
            - presupuesto mensual
            - preferencias de idioma, tema, región y moneda
            - imagen y nombre de perfil
            - preferencias de notificaciones

            3. Para qué se usan los datos
            Los datos se usan únicamente para ofrecer las funciones principales de la app, incluyendo:
            - registrar movimientos
            - mostrar resúmenes y tendencias
            - organizar deudas y pagos recurrentes
            - personalizar la experiencia
            - programar recordatorios locales y alertas de presupuesto

            4. Dónde se guardan los datos
            En la versión actual, la mayor parte de la información se guarda localmente en tu dispositivo.
            \(AppMetadata.displayName) no vende tus datos personales ni los comparte con fines publicitarios.

            5. Permisos del dispositivo
            \(AppMetadata.displayName) puede solicitar:
            - acceso a notificaciones, para recordatorios de pagos y alertas de presupuesto
            - autenticación biométrica, para proteger el acceso a la app cuando lo habilitas
            - acceso a fotos, si eliges una imagen de perfil

            6. Eliminación de cuenta y datos
            Puedes eliminar tu cuenta local y sus datos asociados desde la sección Perfil dentro de la app.
            Al eliminar la cuenta se borran los datos locales asociados a ese usuario en ese dispositivo.

            7. Menores de edad
            \(AppMetadata.displayName) no está dirigida intencionalmente a menores de 13 años.

            8. Cambios a esta política
            Esta política puede actualizarse cuando cambien funciones, flujos de datos o requisitos legales.
            Cuando eso ocurra, la fecha de última actualización también cambiará.

            9. Contacto
            Si necesitas ayuda sobre privacidad, soporte o eliminación de datos, puedes escribir a:
            \(AppMetadata.supportEmail)
            """

        case .english:
            return """
            \(AppMetadata.legalLastUpdatedLine(for: .english))

            1. Who we are
            \(AppMetadata.displayName) is a personal finance organization app designed to help you track expenses, income, debts, recurring payments, and budgets directly on your device.

            2. What data may be stored in the app
            The app may store information you provide directly, such as:
            - local account username
            - local password protected in Keychain
            - expenses, income, debts, and recurring payments
            - monthly budget
            - language, theme, region, and currency preferences
            - profile image and display name
            - notification preferences

            3. How data is used
            Data is used only to provide the app’s core functionality, including:
            - recording transactions
            - showing summaries and trends
            - organizing debts and recurring payments
            - personalizing the experience
            - scheduling local reminders and budget alerts

            4. Where data is stored
            In the current version, most information is stored locally on your device.
            \(AppMetadata.displayName) does not sell your personal data or share it for advertising purposes.

            5. Device permissions
            \(AppMetadata.displayName) may request:
            - notification permission, for payment reminders and budget alerts
            - biometric authentication, to protect app access when you enable it
            - photo access, if you choose a profile image

            6. Account and data deletion
            You can delete your local account and associated data from the Profile section inside the app.
            Deleting the account removes local data associated with that user on that device.

            7. Children
            \(AppMetadata.displayName) is not intentionally directed to children under 13.

            8. Changes to this policy
            This policy may be updated when app features, data flows, or legal requirements change.
            When that happens, the last updated date will also change.

            9. Contact
            If you need help regarding privacy, support, or data deletion, contact:
            \(AppMetadata.supportEmail)
            """
        }
    }

    private func legalCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.bold())

            Text(body)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(18)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
