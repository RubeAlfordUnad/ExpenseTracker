import SwiftUI

struct ThemeSettingsView: View {

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        List {
            ForEach(AppTheme.allCases) { theme in
                Button {
                    settings.theme = theme
                } label: {
                    HStack {
                        Text(theme.title(for: settings.language))
                            .foregroundColor(.primary)

                        Spacer()

                        if settings.theme == theme {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(settings.t("theme.title"))
    }
}
