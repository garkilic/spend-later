import SwiftUI

// MARK: - Color Tokens
extension Color {
    // Semantic colors with light/dark mode support
    static let appPrimary = Color(light: .black, dark: .white)
    static let appSecondary = Color(light: Color(white: 0.4), dark: Color(white: 0.6))
    static let appSuccess = Color(light: Color(red: 0.0, green: 0.6, blue: 0.35), dark: Color(red: 0.2, green: 0.8, blue: 0.5))
    static let appWarning = Color(light: Color(red: 1.0, green: 0.6, blue: 0.0), dark: Color(red: 1.0, green: 0.7, blue: 0.2))
    static let appSurface = Color(light: .white, dark: Color(white: 0.1))
    static let appSurfaceElevated = Color(light: Color(white: 0.98), dark: Color(white: 0.15))
    static let appSeparator = Color(light: Color(white: 0.85), dark: Color(white: 0.3))
    static let appAccent = Color(red: 0.02, green: 0.65, blue: 0.41)

    // Legacy fallback names for compatibility
    static let primaryFallback = appPrimary
    static let secondaryFallback = appSecondary
    static let successFallback = appSuccess
    static let warningFallback = appWarning
    static let surfaceFallback = appSurface
    static let surfaceElevatedFallback = appSurfaceElevated
    static let separatorFallback = appSeparator
    static let accentFallback = appAccent

    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor(dynamicProvider: { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        }))
    }
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
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1)
            )
            .shadow(
                color: colorScheme == .light ? Color.black.opacity(ShadowStyle.elevation1.opacity) : .clear,
                radius: ShadowStyle.elevation1.radius,
                y: ShadowStyle.elevation1.y
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
            .textCase(.uppercase)
            .tracking(0.02 * 12) // 2% of footnote size ~12pt
            .foregroundColor(Color.secondaryFallback)
            .padding(.top, Spacing.sectionTop)
            .padding(.horizontal, Spacing.sideGutter)
    }
}

extension View {
    func sectionHeaderStyle() -> some View {
        modifier(SectionHeaderStyle())
    }
}
