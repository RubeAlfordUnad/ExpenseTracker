import SwiftUI

struct InsightPopupView: View {

    @EnvironmentObject var settings: AppSettings

    let insight: InsightResult
    @Binding var show: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text(insight.title)
                .font(.headline)

            Text(insight.message)
                .font(.subheadline)
                .multilineTextAlignment(.center)

            Button(settings.language == .spanish ? "Ok" : "OK") {
                show = false
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding()
    }
}
