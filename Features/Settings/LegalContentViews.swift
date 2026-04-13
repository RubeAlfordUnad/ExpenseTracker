import SwiftUI

struct LegalSectionContent: Identifiable {
    let icon: String
    let title: String
    let summary: String?
    let paragraphs: [String]
    let bullets: [String]

    var id: String { title }

    init(
        icon: String,
        title: String,
        summary: String? = nil,
        paragraphs: [String] = [],
        bullets: [String] = []
    ) {
        self.icon = icon
        self.title = title
        self.summary = summary
        self.paragraphs = paragraphs
        self.bullets = bullets
    }
}

struct LegalHeroCard: View {
    let title: String
    let subtitle: String
    let updatedText: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(BrandPalette.primary.opacity(0.14))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(BrandPalette.primary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title2.bold())

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(BrandPalette.primary)

                Text(updatedText)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(BrandPalette.surfaceRaised)
            .clipShape(Capsule())
        }
        .padding(18)
        .background(BrandPalette.heroGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct LegalSectionCard: View {
    let section: LegalSectionContent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(BrandPalette.primary.opacity(0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: section.icon)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(BrandPalette.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)

                    if let summary = section.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }

            if !section.paragraphs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(section.paragraphs, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }

            if !section.bullets.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(section.bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(BrandPalette.primary)
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)

                            Text(bullet)
                                .font(.body)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)

                            Spacer(minLength: 0)
                        }
                    }
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
