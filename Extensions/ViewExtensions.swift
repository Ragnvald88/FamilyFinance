//
//  ViewExtensions.swift
//  Florijn
//
//  Sophisticated Financial Design System
//  Premium materials, geometric flow icons, and financial precision
//
//  Created: 2025-12-30
//

import SwiftUI

// MARK: - Premium Financial Design System

extension Color {
    // MARK: - Premium Financial Color Palette

    // Primary Brand Colors - Professional Financial Authority
    static let florijnNavy = Color(red: 0.08, green: 0.12, blue: 0.20)        // Deep financial trust
    static let florijnBlue = Color(red: 0.15, green: 0.35, blue: 0.85)        // Confident action
    static let florijnLightBlue = Color(red: 0.25, green: 0.50, blue: 0.95)   // Interactive states

    // Success & Growth - Sophisticated Greens
    static let florijnGreen = Color(red: 0.10, green: 0.60, blue: 0.25)       // Wealth growth
    static let florijnLightGreen = Color(red: 0.20, green: 0.75, blue: 0.35)  // Positive momentum
    static let florijnMintAccent = Color(red: 0.30, green: 0.85, blue: 0.55)  // Achievement highlights

    // Warning & Attention - Refined Warmth
    static let florijnAmber = Color(red: 0.95, green: 0.65, blue: 0.15)       // Thoughtful warnings
    static let florijnRed = Color(red: 0.85, green: 0.25, blue: 0.25)         // Important alerts
    static let florijnOrange = Color(red: 0.95, green: 0.50, blue: 0.20)      // Spending focus

    // Financial Flow Semantic Colors (FIXED: Proper color psychology)
    static let expenseRed = Color(red: 0.82, green: 0.32, blue: 0.32)         // Expenses - mature red (not alarming)
    static let incomeGreen = Color(red: 0.10, green: 0.60, blue: 0.25)        // Income - standard financial green
    static let savingsWin = Color(red: 0.08, green: 0.75, blue: 0.35)         // Savings achievement - celebratory
    static let tealSecure = Color(red: 0.15, green: 0.65, blue: 0.70)         // Successful savings (secure feeling)

    // DEPRECATED: warmOrange for expenses breaks financial psychology
    @available(*, deprecated, message: "Use expenseRed instead - expenses should be red, not orange")
    static let warmOrange = Color(red: 0.95, green: 0.55, blue: 0.25)

    // Clean Professional Colors
    static let florijnCharcoal = Color(nsColor: .labelColor)                  // System text - perfect contrast
    static let florijnDarkGray = Color(nsColor: .secondaryLabelColor)         // System secondary text
    static let florijnMediumGray = Color(nsColor: .tertiaryLabelColor)        // System tertiary text
    static let florijnLightGray = Color(nsColor: .separatorColor)             // System separator
    static let florijnOffWhite = Color(nsColor: .windowBackgroundColor)      // System window background

    // Professional Clean Colors (Auto-Adaptive)
    static let cleanBackground = Color(nsColor: .windowBackgroundColor)      // System background
    static let cardBackground = Color(nsColor: .controlBackgroundColor)     // Adaptive card background
    static let subtleBorder = Color(nsColor: .separatorColor)               // Subtle borders

    // Adaptive System Colors (Perfect for light/dark mode)
    static let adaptivePrimary = Color(nsColor: .labelColor)                 // Main text
    static let adaptiveSecondary = Color(nsColor: .secondaryLabelColor)      // Secondary text
    static let adaptiveTertiary = Color(nsColor: .tertiaryLabelColor)        // Supporting text
    static let adaptiveBackground = Color(nsColor: .windowBackgroundColor)   // Window background
    static let adaptiveSurface = Color(nsColor: .controlBackgroundColor)     // Card/surface background
}

extension Font {
    // MARK: - Premium Financial Typography

    // Hero Display Fonts
    static let financialHero = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let displayLarge = Font.system(.title, design: .default, weight: .semibold)
    static let displayMedium = Font.system(.title2, design: .default, weight: .medium)

    // Content Hierarchy - Refined
    static let headingLarge = Font.system(.title2, design: .default, weight: .bold)
    static let headingMedium = Font.system(.title3, design: .default, weight: .bold)
    static let headingPrimary = Font.system(.headline, design: .default, weight: .bold)
    static let headingSecondary = Font.system(.headline, design: .default, weight: .semibold)
    static let bodyLarge = Font.system(.body, design: .default, weight: .medium)
    static let bodyRegular = Font.system(.callout, design: .default, weight: .regular)
    static let bodySmall = Font.system(.caption, design: .default, weight: .regular)
    static let caption = Font.system(.caption2, design: .default, weight: .medium)

    // Financial Data - Precision Typography
    static let currencyHero = Font.system(.largeTitle, design: .monospaced, weight: .bold)
    static let currencyLarge = Font.system(.title2, design: .monospaced, weight: .semibold)
    static let currencyMedium = Font.system(.title3, design: .monospaced, weight: .medium)
    static let currency = Font.system(.headline, design: .monospaced, weight: .medium)
    static let currencySmall = Font.system(.callout, design: .monospaced, weight: .medium)
}

// MARK: - Premium Spacing System

enum PremiumSpacing {
    // Base 8pt Grid System
    static let tiny: CGFloat = 4      // 0.5 unit
    static let small: CGFloat = 8     // 1 unit
    static let medium: CGFloat = 16   // 2 units
    static let large: CGFloat = 24    // 3 units
    static let xlarge: CGFloat = 32   // 4 units
    static let xxlarge: CGFloat = 48  // 6 units
    static let hero: CGFloat = 64     // 8 units

    // Component Specific
    static let cardCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 12
    static let iconSize: CGFloat = 24
    static let iconSizeSmall: CGFloat = 18
    static let buttonHeight: CGFloat = 48

    // Layout Constants
    static let sidebarWidth: CGFloat = 280
    static let maxContentWidth: CGFloat = 1200
}

// MARK: - Premium Animations

extension Animation {
    static let premiumSpring = Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.2)
    static let quickResponse = Animation.spring(response: 0.25, dampingFraction: 0.85)
    static let smoothEntry = Animation.spring(response: 0.6, dampingFraction: 0.75)
    static let subtleHover = Animation.easeInOut(duration: 0.2)
}

// MARK: - Financial Icons (SF Symbols)

struct FinancialIcon: View {
    enum IconType {
        case income      // Money coming in
        case expenses    // Money going out
        case saved       // Money saved
        case savingsRate // Savings percentage

        /// Clean SF Symbol for each type
        var sfSymbolName: String {
            switch self {
            case .income: return "arrow.up.circle.fill"
            case .expenses: return "arrow.down.circle.fill"
            case .saved: return "checkmark.circle.fill"  // Achievement/goal completion
            case .savingsRate: return "percent"
            }
        }

        /// Semantic color for financial flow logic
        var semanticColor: Color {
            switch self {
            case .income: return .incomeGreen         // Positive inflow
            case .expenses: return .expenseRed        // Outflow - proper red psychology
            case .saved: return .savingsWin           // Successful retention - celebratory
            case .savingsRate: return .florijnBlue   // Neutral metric
            }
        }
    }

    let type: IconType
    let size: CGFloat
    let color: Color

    init(_ type: IconType, size: CGFloat = 24, color: Color? = nil) {
        self.type = type
        self.size = size
        self.color = color ?? type.semanticColor  // Use semantic color by default
    }

    var body: some View {
        Image(systemName: type.sfSymbolName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(color)
    }
}

// MARK: - Financial Card Types & Semantic Backgrounds

enum FinancialCardType {
    case hero       // 60% larger, premium shadows - Net worth
    case primary    // Standard size, semantic colors - Income/Expenses
    case supporting // 75% size, muted styling - Percentages/metrics

    case income     // Income-specific styling
    case expenses   // Expense-specific styling
    case savings    // Savings-specific styling
    case neutral    // General financial data

    var backgroundColor: Color {
        return Color.adaptiveSurface  // All cards use adaptive surface color
    }

    var borderColor: Color {
        return Color.subtleBorder  // All cards use adaptive border color
    }

    var shadowColor: Color {
        return Color.primary.opacity(0.1)  // Adaptive shadow that works in both modes
    }

    var scale: CGFloat {
        switch self {
        case .hero: return 1.6      // 60% larger
        case .primary: return 1.0   // Standard size
        case .supporting: return 0.75   // 75% size
        case .income, .expenses, .savings, .neutral: return 1.0
        }
    }
}

// MARK: - Premium Card Styles

extension View {
    /// Premium glass morphism card with sophisticated depth
    func premiumCard() -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius)
                            .stroke(LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.clear, Color.black.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius))
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
    }

    /// Elevated premium card for hero content
    func heroCard() -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius + 4)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius + 4)
                            .stroke(Color.subtleBorder, lineWidth: 1)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius + 4))
            .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    /// Standard adaptive card for light/dark compatibility
    func standardCard() -> some View {
        self
            .background(Color.adaptiveSurface)
            .clipShape(RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius)
                    .stroke(Color.adaptiveSecondary.opacity(0.1), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    /// Clean professional financial card
    func financialCard(type: FinancialCardType) -> some View {
        self
            .scaleEffect(type.scale)
            .padding(16)
            .background(type.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(type.borderColor, lineWidth: 1)
            }
            .shadow(color: type.shadowColor, radius: 4, x: 0, y: 2)
    }

    /// Sophisticated hover interaction with proper state tracking
    func withFinancialHover() -> some View {
        modifier(FinancialHoverModifier())
    }
}

struct FinancialHoverModifier: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHovered = hovering
                }
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(
                color: .black.opacity(isHovered ? 0.15 : 0.08),
                radius: isHovered ? 20 : 8,
                x: 0,
                y: isHovered ? 10 : 4
            )
            .overlay {
                if isHovered {
                    RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        .blendMode(.overlay)
                }
            }
    }
}

// MARK: - Premium Button Styles

struct PremiumPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, PremiumSpacing.large)
            .padding(.vertical, PremiumSpacing.medium)
            .frame(height: PremiumSpacing.buttonHeight)
            .background {
                LinearGradient(
                    colors: [
                        Color.florijnBlue.opacity(configuration.isPressed ? 0.9 : 1.0),
                        Color.florijnNavy.opacity(configuration.isPressed ? 0.9 : 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    RoundedRectangle(cornerRadius: PremiumSpacing.buttonCornerRadius)
                        .fill(.thinMaterial.opacity(0.3))
                        .blendMode(.overlay)
                }
            }
            .foregroundStyle(.white)
            .font(.bodyLarge)
            .fontWeight(.semibold)
            .clipShape(RoundedRectangle(cornerRadius: PremiumSpacing.buttonCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: PremiumSpacing.buttonCornerRadius)
                    .stroke(LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.clear, Color.black.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .shadow(color: Color.florijnBlue.opacity(0.4), radius: configuration.isPressed ? 6 : 12, x: 0, y: configuration.isPressed ? 3 : 6)
            .shadow(color: Color.florijnBlue.opacity(0.2), radius: configuration.isPressed ? 2 : 4, x: 0, y: configuration.isPressed ? 1 : 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct PremiumSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, PremiumSpacing.large)
            .padding(.vertical, PremiumSpacing.medium)
            .frame(height: PremiumSpacing.buttonHeight)
            .background(.ultraThinMaterial)
            .foregroundStyle(Color.florijnBlue)
            .font(.bodyLarge)
            .clipShape(RoundedRectangle(cornerRadius: PremiumSpacing.buttonCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: PremiumSpacing.buttonCornerRadius)
                    .stroke(Color.florijnBlue.opacity(0.3), lineWidth: 1.5)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.quickResponse, value: configuration.isPressed)
    }
}

// MARK: - Premium Typography Modifiers

extension View {
    func premiumHeading(_ color: Color = .adaptivePrimary) -> some View {
        self
            .font(.headingPrimary)
            .foregroundStyle(color)
    }

    func financialAmount(_ color: Color = .florijnCharcoal) -> some View {
        self
            .font(.currency)
            .foregroundStyle(color)
            .monospacedDigit()
    }

    func heroAmount(_ color: Color = .florijnNavy) -> some View {
        self
            .font(.currencyHero)
            .foregroundStyle(color)
            .monospacedDigit()
    }

    /// Value-based typography hierarchy for financial data
    func financialValue(_ amount: Decimal, color: Color = .florijnCharcoal) -> some View {
        self
            .font(fontForAmount(amount))
            .fontWeight(weightForAmount(amount))
            .foregroundStyle(color)
            .monospacedDigit()
    }

    /// Subtle labels that don't compete with financial data
    /// 2026 WCAG 2.2 AA Compliant - 4.5:1 contrast minimum
    func financialLabel() -> some View {
        self
            .font(.caption2)
            .fontWeight(.medium)                     // Better readability than .light
            .foregroundStyle(Color.adaptiveSecondary) // secondaryLabelColor (auto-adapts light/dark)
    }

    private func fontForAmount(_ amount: Decimal) -> Font {
        let value = abs(NSDecimalNumber(decimal: amount).doubleValue)

        if value >= 10_000 {
            return .system(.largeTitle, design: .monospaced)    // Major amounts (>$10K)
        } else if value >= 1_000 {
            return .system(.title, design: .monospaced)         // Significant amounts ($1K-$10K)
        } else {
            return .system(.title3, design: .monospaced)        // Standard amounts (<$1K)
        }
    }

    private func weightForAmount(_ amount: Decimal) -> Font.Weight {
        let value = abs(NSDecimalNumber(decimal: amount).doubleValue)

        if value >= 10_000 {
            return .heavy      // Hero treatment for major amounts
        } else if value >= 1_000 {
            return .bold       // Bold for significant amounts
        } else {
            return .medium     // Medium for standard amounts
        }
    }
}

// MARK: - Button Extensions

extension View {
    func premiumPrimaryButton() -> some View {
        self.buttonStyle(PremiumPrimaryButtonStyle())
    }

    func premiumSecondaryButton() -> some View {
        self.buttonStyle(PremiumSecondaryButtonStyle())
    }
}

// MARK: - Animated Financial Number Component

struct PremiumAnimatedNumber: View {
    let value: Decimal
    let font: Font
    let color: Color

    @State private var displayValue: Decimal = 0

    init(_ value: Decimal, font: Font = .currency, color: Color = .florijnCharcoal) {
        self.value = value
        self.font = font
        self.color = color
    }

    var body: some View {
        Text(displayValue.toCurrencyString())
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .onChange(of: value) { _, newValue in
                withAnimation(.quickResponse) {
                    displayValue = newValue
                }
            }
            .onAppear {
                displayValue = value
            }
    }
}

// MARK: - Premium KPI Card Component

struct PremiumKPICard: View {
    let title: String
    let value: Decimal?
    let percentage: Double?
    let icon: FinancialIcon.IconType
    let color: Color
    let trend: Double?
    let cardType: FinancialCardType

    @State private var isHovered = false

    init(
        title: String,
        value: Decimal? = nil,
        percentage: Double? = nil,
        icon: FinancialIcon.IconType,
        color: Color,
        trend: Double? = nil,
        cardType: FinancialCardType = .primary
    ) {
        self.title = title
        self.value = value
        self.percentage = percentage
        self.icon = icon
        self.color = color
        self.trend = trend
        self.cardType = cardType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PremiumSpacing.medium) {
            // Header with icon and trend
            HStack {
                FinancialIcon(icon, size: PremiumSpacing.iconSize, color: color)

                Spacer()

                if let trend = trend {
                    trendIndicator(trend)
                }
            }

            // Value section with proper hierarchy
            VStack(alignment: .leading, spacing: PremiumSpacing.tiny) {
                Text(title)
                    .financialLabel()  // Subtle label that doesn't compete

                if let value = value {
                    Text(value.toCurrencyString())
                        .financialValue(value, color: color)  // Dominant value
                } else if let percentage = percentage {
                    Text("\(percentage, specifier: "%.1f")%")
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .foregroundStyle(color)
                        .monospacedDigit()
                }
            }
        }
        .padding(PremiumSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .financialCard(type: cardType)  // Semantic financial styling
        .scaleEffect(isHovered ? 1.005 : 1.0)  // Subtle hover
        .animation(.subtleHover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func trendIndicator(_ trend: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            Text("\(abs(trend), specifier: "%.1f")%")
                .font(.caption2)
                .monospacedDigit()
        }
        .foregroundStyle(trend >= 0 ? Color.florijnGreen : Color.florijnRed)
        .padding(.horizontal, PremiumSpacing.small)
        .padding(.vertical, PremiumSpacing.tiny)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

// MARK: - Professional Trust Components

/// Premium app header with security indicators and professional branding
struct ProfessionalAppHeader: View {
    let title: String
    let subtitle: String?
    let showSecurityBadge: Bool

    init(_ title: String, subtitle: String? = nil, showSecurityBadge: Bool = true) {
        self.title = title
        self.subtitle = subtitle
        self.showSecurityBadge = showSecurityBadge
    }

    var body: some View {
        HStack(spacing: PremiumSpacing.medium) {
            // Professional app branding
            VStack(alignment: .leading, spacing: PremiumSpacing.tiny) {
                HStack(spacing: PremiumSpacing.small) {
                    // Sophisticated app icon representation
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [Color.florijnBlue, Color.florijnNavy],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Text("F")
                                .font(.system(.title3, weight: .bold))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(.title2, weight: .semibold))
                            .foregroundStyle(Color.florijnCharcoal)

                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(Color.florijnMediumGray)
                        }
                    }
                }
            }

            Spacer()

            if showSecurityBadge {
                securityIndicators
            }
        }
        .padding(.horizontal, PremiumSpacing.large)
        .padding(.vertical, PremiumSpacing.medium)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.florijnLightGray.opacity(0.3))
                .frame(height: 0.5)
        }
    }

    private var securityIndicators: some View {
        HStack(spacing: PremiumSpacing.small) {
            // Data security indicator
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.caption)
                    .foregroundStyle(Color.florijnGreen)
                Text("Secure")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.florijnDarkGray)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.florijnGreen.opacity(0.08))
            .clipShape(Capsule())

            // Local data indicator
            HStack(spacing: 6) {
                Image(systemName: "internaldrive.fill")
                    .font(.caption)
                    .foregroundStyle(Color.florijnBlue)
                Text("Local")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.florijnDarkGray)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.florijnBlue.opacity(0.08))
            .clipShape(Capsule())
        }
    }
}

/// Premium sidebar styling with professional polish
extension View {
    func professionalSidebar() -> some View {
        self
            .listStyle(SidebarListStyle())
            .background(.ultraThinMaterial)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.florijnLightGray.opacity(0.3))
                    .frame(width: 0.5)
            }
    }

    func professionalSidebarSection() -> some View {
        self
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(Color.florijnMediumGray)
            .textCase(.uppercase)
            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
    }

    func professionalSidebarItem(isSelected: Bool = false) -> some View {
        modifier(ProfessionalSidebarItemModifier(isSelected: isSelected))
    }
}

struct ProfessionalSidebarItemModifier: ViewModifier {
    let isSelected: Bool
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .font(.bodyLarge)
            .fontWeight(isSelected ? .bold : .medium)
            .foregroundStyle(isSelected ? Color.florijnBlue : (isHovered ? Color.florijnCharcoal : Color.florijnDarkGray))
            .listRowBackground(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: backgroundColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: isSelected ? 1.5 : 0.5)
                            .opacity(isSelected || isHovered ? 1.0 : 0.0)
                    )
                    .shadow(
                        color: shadowColor,
                        radius: isSelected ? 4 : (isHovered ? 2 : 0),
                        x: 0,
                        y: isSelected ? 2 : (isHovered ? 1 : 0)
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
            )
            .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
            .onHover { hovering in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isHovered = hovering
                }
            }
            .scaleEffect(isSelected ? 1.0 : (isHovered ? 1.01 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private var backgroundColors: [Color] {
        if isSelected {
            return [Color.florijnBlue.opacity(0.12), Color.florijnBlue.opacity(0.08)]
        } else if isHovered {
            return [Color.florijnLightGray.opacity(0.6), Color.florijnLightGray.opacity(0.3)]
        } else {
            return [Color.clear, Color.clear]
        }
    }

    private var borderColor: Color {
        isSelected ? Color.florijnBlue.opacity(0.3) : Color.florijnMediumGray.opacity(0.2)
    }

    private var shadowColor: Color {
        isSelected ? Color.florijnBlue.opacity(0.2) : Color.black.opacity(0.1)
    }
}

// MARK: - Enhanced KPI Card with Trust Elements

struct TrustEnhancedKPICard: View {
    let title: String
    let value: Decimal?
    let percentage: Double?
    let icon: FinancialIcon.IconType
    let color: Color
    let trend: Double?
    let cardType: FinancialCardType
    let isVerified: Bool

    @State private var isHovered = false

    init(
        title: String,
        value: Decimal? = nil,
        percentage: Double? = nil,
        icon: FinancialIcon.IconType,
        color: Color,
        trend: Double? = nil,
        cardType: FinancialCardType = .primary,
        isVerified: Bool = true
    ) {
        self.title = title
        self.value = value
        self.percentage = percentage
        self.icon = icon
        self.color = color
        self.trend = trend
        self.cardType = cardType
        self.isVerified = isVerified
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PremiumSpacing.medium) {
            // Enhanced header with trust indicators
            HStack {
                FinancialIcon(icon, size: PremiumSpacing.iconSize, color: color)

                Spacer()

                HStack(spacing: 8) {
                    if isVerified {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.florijnGreen.opacity(0.6))
                    }

                    if let trend = trend {
                        trendIndicator(trend)
                    }
                }
            }

            // Enhanced value section
            VStack(alignment: .leading, spacing: PremiumSpacing.small) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.florijnMediumGray.opacity(0.8))
                    .textCase(.uppercase)
                    .tracking(0.5)

                if let value = value {
                    Text(value.toCurrencyString())
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .foregroundStyle(color)
                        .monospacedDigit()
                } else if let percentage = percentage {
                    Text("\(percentage, specifier: "%.1f")%")
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .foregroundStyle(color)
                        .monospacedDigit()
                }
            }
        }
        .padding(PremiumSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius)
                        .strokeBorder(LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ), lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius))
        .shadow(color: color.opacity(0.15), radius: isHovered ? 12 : 8, x: 0, y: isHovered ? 6 : 4)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func trendIndicator(_ trend: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            Text("\(abs(trend), specifier: "%.1f")%")
                .font(.caption2)
                .monospacedDigit()
        }
        .foregroundStyle(trend >= 0 ? Color.florijnGreen : Color.florijnRed)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

// MARK: - Professional Window Background
extension View {
    func professionalWindowBackground() -> some View {
        self
            .background(Color.adaptiveBackground)
    }
}

// MARK: - Utility Extensions
// Note: toCurrencyString() extension already exists in TransactionQueryService.swift