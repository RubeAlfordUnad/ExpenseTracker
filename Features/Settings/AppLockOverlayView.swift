import SwiftUI

struct AppLockOverlayView: View {

    @EnvironmentObject var settings: AppSettings

    let isAuthenticating: Bool
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.14)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(BrandPalette.primary)
                    .frame(width: 74, height: 74)
                    .background(BrandPalette.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(spacing: 8) {
                    Text(settings.language == .spanish ? "App bloqueada" : "App locked")
                        .font(.title3.bold())

                    Text(
                        settings.language == .spanish
                        ? "Confirma tu identidad para volver a ver tus datos financieros."
                        : "Confirm your identity to view your financial data again."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                }

                Button {
                    onUnlock()
                } label: {
                    HStack(spacing: 10) {
                        if isAuthenticating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "faceid")
                        }

                        Text(AppLockService.shared.unlockButtonTitle(language: settings.language))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(BrandPalette.primary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isAuthenticating)
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(BrandPalette.surfaceRaised)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(BrandPalette.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
            .padding(.horizontal, 24)
        }
    }
}
