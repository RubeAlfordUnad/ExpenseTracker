import SwiftUI
import UIKit

enum RecoveryCodeDisplayContext {
    case afterRegistration
    case regenerated
}

struct RecoveryCodeDisplayView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings

    @State private var didCopy = false

    let code: String
    let context: RecoveryCodeDisplayContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(title)
                            .font(.title2.bold())

                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text(settings.language == .spanish ? "Código de recuperación" : "Recovery code")
                            .font(.headline)

                        Text(code)
                            .font(.system(.title3, design: .monospaced).weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 18)
                            .padding(.horizontal, 12)
                            .background(BrandPalette.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .textSelection(.enabled)

                        Text(warningText)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            UIPasteboard.general.string = code
                            didCopy = true
                        } label: {
                            Label(
                                didCopy
                                ? (settings.language == .spanish ? "Copiado" : "Copied")
                                : (settings.language == .spanish ? "Copiar código" : "Copy code"),
                                systemImage: didCopy ? "checkmark.circle.fill" : "doc.on.doc"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(18)
                    .background(BrandPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(BrandPalette.stroke, lineWidth: 1)
                    )
                }
                .padding(20)
            }
            .navigationTitle(settings.language == .spanish ? "Recuperación" : "Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.t("common.done")) {
                        dismiss()
                    }
                }
            }
        }
        .accessibilityIdentifier("recovery.code.sheet")
    }

    private var title: String {
        switch (settings.language, context) {
        case (.spanish, .afterRegistration):
            return "Guarda este código antes de seguir"
        case (.english, .afterRegistration):
            return "Save this code before continuing"
        case (.spanish, .regenerated):
            return "Tu código fue regenerado"
        case (.english, .regenerated):
            return "Your code was regenerated"
        }
    }

    private var subtitle: String {
        switch (settings.language, context) {
        case (.spanish, .afterRegistration):
            return "Este código te permitirá restablecer la contraseña si la olvidas. La app no puede recuperarla de otra forma."
        case (.english, .afterRegistration):
            return "This code will let you reset your password if you forget it. The app cannot recover it any other way."
        case (.spanish, .regenerated):
            return "El código anterior deja de servir. Guarda este nuevo código en un lugar seguro."
        case (.english, .regenerated):
            return "The previous code is no longer valid. Save this new code in a safe place."
        }
    }

    private var warningText: String {
        switch settings.language {
        case .spanish:
            return "Guárdalo fuera de la app. Si pierdes la contraseña y este código, la única salida segura será borrar los datos locales de esa cuenta."
        case .english:
            return "Store it outside the app. If you lose both your password and this code, the only safe fallback will be deleting that account’s local data."
        }
    }
}
