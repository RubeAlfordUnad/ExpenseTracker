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
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(settings.t("privacy.urlPending"))
                                .font(.footnote)
                                .foregroundColor(.secondary)

                            Text(
                                settings.language == .spanish
                                ? "Antes de publicar en App Store necesitas subir esta política a una URL pública."
                                : "Before publishing on the App Store, you need to host this policy at a public URL."
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: URL(string: "mailto:\(AppMetadata.supportEmail)")!) {
                        Label(
                            settings.language == .spanish ? "Contactar soporte" : "Contact support",
                            systemImage: "envelope"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
        .navigationTitle(settings.t("privacy.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var policyText: String {
        switch settings.language {
        case .spanish:
            return """
            Última actualización: 29 de marzo de 2026

            1. Quiénes somos
            Nexora es una aplicación de organización financiera personal diseñada para ayudarte a registrar gastos, deudas, pagos fijos y presupuesto desde tu propio dispositivo.

            2. Qué datos puedes guardar en la app
            La app puede almacenar información que tú introduces directamente, como:
            - nombre de usuario de tu cuenta local
            - contraseña local protegida en Keychain
            - gastos, deudas y pagos recurrentes
            - presupuesto mensual
            - preferencias de idioma, tema, país y moneda
            - foto de perfil
            - preferencias de notificaciones

            3. Cómo se usan esos datos
            Los datos se usan únicamente para que la app funcione, por ejemplo:
            - registrar movimientos
            - mostrar resúmenes y tendencias
            - organizar deudas y pagos fijos
            - personalizar la experiencia
            - programar recordatorios y alertas locales

            4. Dónde se almacenan los datos
            En la versión actual, la mayor parte de la información se almacena localmente en tu dispositivo.
            Nexora no vende tus datos personales ni los comparte con fines publicitarios.

            5. Servicios externos
            Si usas la función de tipo de cambio, la app puede consultar un servicio externo para obtener tasas entre monedas. En esa solicitud pueden enviarse la moneda base y la moneda destino seleccionadas por el usuario. Esa función no es necesaria para registrar tus gastos locales.

            6. Permisos del dispositivo
            Nexora puede solicitar:
            - acceso a Fotos, para elegir una imagen de perfil
            - acceso a Notificaciones, para recordatorios de pagos y alertas de presupuesto

            7. Cuenta y eliminación de datos
            Puedes eliminar tu cuenta local y los datos asociados desde la sección Perfil dentro de la app.
            Al eliminar la cuenta, se borran los datos locales asociados a ese usuario en este dispositivo, incluyendo gastos, deudas, pagos fijos, presupuesto, imagen de perfil y preferencias guardadas para esa cuenta.

            8. Menores de edad
            Nexora no está dirigida intencionalmente a menores de 13 años.

            9. Cambios a esta política
            Esta política puede actualizarse cuando cambien funciones, flujos de datos o requisitos legales.
            Cuando eso ocurra, la fecha de última actualización también cambiará.

            10. Contacto
            Si necesitas ayuda sobre privacidad, soporte o eliminación de datos, puedes escribir a:
            \(AppMetadata.supportEmail)
            """

        case .english:
            return """
            Last updated: March 29, 2026

            1. Who we are
            Nexora is a personal finance organization app designed to help you track expenses, debts, recurring payments, and budgets directly on your device.

            2. What data may be stored in the app
            The app may store information you provide directly, such as:
            - local account username
            - local password protected in Keychain
            - expenses, debts, and recurring payments
            - monthly budget
            - language, theme, country, and currency preferences
            - profile photo
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
            Nexora does not sell your personal data or share it for advertising purposes.

            5. External services
            If you use the exchange rate feature, the app may contact an external service to fetch currency conversion rates. That request may include the base currency and target currency selected by the user. This feature is optional and not required to track local expenses.

            6. Device permissions
            Nexora may request:
            - Photo Library access, to choose a profile image
            - Notification permission, for payment reminders and budget alerts

            7. Account and data deletion
            You can delete your local account and associated data from the Profile section inside the app.
            Deleting the account removes local data associated with that user on this device, including expenses, debts, recurring payments, budget, profile image, and saved preferences for that account.

            8. Children
            Nexora is not intentionally directed to children under 13.

            9. Changes to this policy
            This policy may be updated when app features, data flows, or legal requirements change.
            When that happens, the last updated date will also change.

            10. Contact
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
