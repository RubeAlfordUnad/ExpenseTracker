import SwiftUI

struct LanguageSettingsView: View {

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        List {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    settings.language = language
                } label: {
                    HStack {
                        Text(language.title)
                            .foregroundColor(.primary)

                        Spacer()

                        if language == settings.language {
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
        .navigationTitle(settings.t("language.title"))
    }
}
