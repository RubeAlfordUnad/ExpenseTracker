import SwiftUI

struct TermsView: View {

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                legalCard(
                    title: settings.t("terms.title"),
                    body: termsText
                )
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
        .navigationTitle(settings.t("terms.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var termsText: String {
        switch settings.language {
        case .spanish:
            return """
            Última actualización: 29 de marzo de 2026

            1. Uso de la app
            Nexora es una herramienta de organización financiera personal. Su objetivo es ayudarte a registrar y visualizar gastos, deudas, pagos fijos y presupuestos.

            2. No es asesoría financiera
            Nexora no ofrece asesoría financiera, contable, tributaria, legal ni bancaria. La información mostrada por la app es únicamente de apoyo y organización personal.

            3. Responsabilidad del usuario
            Tú eres responsable de revisar la información que ingresas y de las decisiones que tomes con base en ella. Debes verificar montos, fechas, categorías y cualquier dato importante antes de usarlo para tus finanzas personales.

            4. Cuenta local
            Si creas una cuenta local dentro de la app, eres responsable de conservar tus credenciales y del acceso al dispositivo donde usas Nexora.

            5. Disponibilidad de funciones
            Algunas funciones pueden cambiar, actualizarse o eliminarse en versiones futuras. El desarrollador puede modificar la app para mejorar estabilidad, diseño, compatibilidad y seguridad.

            6. Servicios externos
            Algunas funciones opcionales, como tipo de cambio, pueden depender de servicios de terceros. Esas funciones pueden cambiar o dejar de estar disponibles sin previo aviso.

            7. Propiedad intelectual
            El diseño, marca, textos, iconografía y código de Nexora están protegidos por las normas aplicables de propiedad intelectual. No se autoriza su copia, redistribución o explotación sin permiso del titular.

            8. Eliminación de cuenta
            Puedes eliminar tu cuenta local desde la sección Perfil dentro de la app. La eliminación borra los datos locales asociados a ese usuario en el dispositivo actual.

            9. Cambios a estos términos
            Estos términos pueden actualizarse en futuras versiones. El uso continuado de la app después de una actualización implica aceptación de la versión vigente.

            10. Contacto
            Si necesitas soporte general relacionado con la app, puedes escribir a:
            motwd44011@outlook.com
            """

        case .english:
            return """
            Last updated: March 29, 2026

            1. App usage
            Nexora is a personal finance organization tool. Its purpose is to help you record and view expenses, debts, recurring payments, and budgets.

            2. Not financial advice
            Nexora does not provide financial, accounting, tax, legal, or banking advice. Information shown by the app is intended only for personal organization and support.

            3. User responsibility
            You are responsible for reviewing the information you enter and for any decisions you make based on it. You should verify amounts, dates, categories, and any important data before relying on it for your finances.

            4. Local account
            If you create a local account inside the app, you are responsible for keeping your credentials safe and for access to the device where Nexora is used.

            5. Feature availability
            Some features may change, be updated, or be removed in future versions. The developer may modify the app to improve stability, design, compatibility, and security.

            6. External services
            Some optional features, such as exchange rates, may depend on third-party services. These features may change or become unavailable without prior notice.

            7. Intellectual property
            Nexora’s design, brand, text, iconography, and code are protected by applicable intellectual property laws. Copying, redistributing, or commercially exploiting them without permission is not allowed.

            8. Account deletion
            You can delete your local account from the Profile section inside the app. Deletion removes local data associated with that user on the current device.

            9. Changes to these terms
            These terms may be updated in future versions. Continued use of the app after an update means acceptance of the current version.

            10. Contact
            If you need general app support, contact:
            motwd44011@outlook.com
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
