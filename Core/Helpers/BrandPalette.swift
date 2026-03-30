import SwiftUI

enum BrandPalette {
    static let primary = Color.green
    static let secondary = Color.yellow

    static let surface = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
        ? UIColor.secondarySystemBackground
        : UIColor.systemGray6
    })

    static let surfaceRaised = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
        ? UIColor.tertiarySystemBackground
        : UIColor.systemGray5
    })

    static let softSurface = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
        ? UIColor.systemGray6
        : UIColor.secondarySystemBackground
    })

    static let stroke = Color(uiColor: .separator).opacity(0.12)

    static let heroGradient = LinearGradient(
        colors: [
            surface,
            primary.opacity(0.10),
            secondary.opacity(0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [
            surface,
            surfaceRaised
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
