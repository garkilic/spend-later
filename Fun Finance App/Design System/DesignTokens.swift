import SwiftUI

// MARK: - Color Tokens
extension Color {
    // Semantic colors with light/dark mode support using UIColor for reliability
    // Primary text: WHITE in dark mode, BLACK in light mode
    static let appPrimary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white  // Dark mode: white text
            : UIColor.black  // Light mode: black text
    })
    // Secondary text: Light gray in dark mode, dark gray in light mode
    static let appSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.7, alpha: 1.0)  // Dark mode: light gray
            : UIColor(white: 0.4, alpha: 1.0)  // Light mode: dark gray
    })
    static let appSuccess = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.2, green: 0.8, blue: 0.5, alpha: 1.0)
            : UIColor(red: 0.0, green: 0.6, blue: 0.35, alpha: 1.0)
    })
    static let appWarning = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1.0)
            : UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)
    })
    static let appSurface = Color(uiColor: .systemBackground)
    static let appSurfaceElevated = Color(uiColor: .secondarySystemBackground)
    static let appSeparator = Color(uiColor: .separator)
    static let appAccent = Color(uiColor: UIColor { traits in
        UIColor.appAccentColor(for: traits)
    })
    static let appAccentSurface = Color(uiColor: UIColor { traits in
        let accent = UIColor.appAccentColor(for: traits)
        let alpha: CGFloat = traits.userInterfaceStyle == .dark ? 0.24 : 0.14
        return accent.withAlphaComponent(alpha)
    })
    static let appOnAccent = Color(uiColor: UIColor { _ in
        UIColor.white
    })

    // Legacy fallback names for compatibility
    static let primaryFallback = appPrimary
    static let secondaryFallback = appSecondary
    static let successFallback = appSuccess
    static let warningFallback = appWarning
    static let surfaceFallback = appSurface
    static let surfaceElevatedFallback = appSurfaceElevated
    static let separatorFallback = appSeparator
    static let accentFallback = appAccent
    static let onAccentFallback = appOnAccent
    static let accentSurfaceFallback = appAccentSurface
}

// MARK: - Typography
enum AppTypography {
    static func largeTitle(_ text: String) -> Text {
        Text(text).font(.largeTitle).fontWeight(.bold)
    }

    static func title2(_ text: String) -> Text {
        Text(text).font(.title2).fontWeight(.semibold)
    }

    static func headline(_ text: String) -> Text {
        Text(text).font(.headline).fontWeight(.semibold)
    }

    static func body(_ text: String) -> Text {
        Text(text).font(.body)
    }

    static func footnote(_ text: String) -> Text {
        Text(text).font(.footnote)
    }

    static func caption2(_ text: String) -> Text {
        Text(text).font(.caption2)
    }

    static func monospacedTitle(_ value: Decimal) -> Text {
        Text(CurrencyFormatter.string(from: value))
            .font(.system(.largeTitle, design: .rounded))
            .fontWeight(.bold)
            .monospacedDigit()
    }

    static func monospacedBody(_ value: Decimal) -> Text {
        Text(CurrencyFormatter.string(from: value))
            .font(.body)
            .monospacedDigit()
    }
}

// MARK: - Spacing
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    // Semantic spacing
    static let cardPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 12
    static let sideGutter: CGFloat = 20
    static let sectionTop: CGFloat = 24
    static let safeAreaTop: CGFloat = 24
}

// MARK: - Corner Radius
enum CornerRadius {
    static let card: CGFloat = 16
    static let button: CGFloat = 14
    static let listRow: CGFloat = 12
}

// MARK: - Shadow
struct ShadowStyle {
    let radius: CGFloat
    let y: CGFloat
    let opacity: Double

    static let elevation1 = ShadowStyle(radius: 8, y: 2, opacity: 0.08)
}

// MARK: - Motion
enum Motion {
    static let quickEaseInOut = Animation.easeInOut(duration: 0.14)
    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.7)
}

// MARK: - View Modifiers
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(Spacing.cardPadding)
            .background(Color.surfaceElevatedFallback)
            .cornerRadius(CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Section Header Style
struct SectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.footnote)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .tracking(0.02 * 12) // 2% of footnote size ~12pt
            .foregroundColor(Color.secondaryFallback)
    }
}

extension View {
    func sectionHeaderStyle() -> some View {
        modifier(SectionHeaderStyle())
    }
}

// MARK: - Internal helpers
private extension UIColor {
    static func appAccentColor(for traits: UITraitCollection) -> UIColor {
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.18, green: 0.82, blue: 0.58, alpha: 1.0)
        } else {
            return UIColor(red: 0.02, green: 0.65, blue: 0.41, alpha: 1.0)
        }
    }
}
