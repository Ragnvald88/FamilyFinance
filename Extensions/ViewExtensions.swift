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

    // Premium Neutrals - Sophisticated Hierarchy
    static let florijnCharcoal = Color(red: 0.12, green: 0.12, blue: 0.14)    // Primary text
    static let florijnDarkGray = Color(red: 0.25, green: 0.25, blue: 0.28)    // Secondary text
    static let florijnMediumGray = Color(red: 0.45, green: 0.45, blue: 0.48)  // Supporting text
    static let florijnLightGray = Color(red: 0.92, green: 0.92, blue: 0.94)   // Subtle backgrounds
    static let florijnOffWhite = Color(red: 0.98, green: 0.98, blue: 0.99)    // Pure backgrounds

    // Glass Morphism Colors
    static let glassSurface = Color.white.opacity(0.1)
    static let glassStroke = Color.white.opacity(0.2)
    static let glassBackground = Color.black.opacity(0.05)

    // Adaptive System Colors (for light/dark mode compatibility)
    static let adaptivePrimary = Color(nsColor: .labelColor)
    static let adaptiveSecondary = Color(nsColor: .secondaryLabelColor)
    static let adaptiveBackground = Color(nsColor: .windowBackgroundColor)
    static let adaptiveSurface = Color(nsColor: .controlBackgroundColor)
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

// MARK: - Geometric Flow Icons

struct GeometricFlowIcon: View {
    enum IconType {
        case income      // Upward flowing stream (clear directional)
        case expenses    // Downward flowing stream (clear directional)
        case saved       // Secure vault container (retention)
        case savingsRate // Progress arc with momentum (percentage)

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
    let color: Color?

    init(_ type: IconType, size: CGFloat = 24, color: Color? = nil) {
        self.type = type
        self.size = size
        self.color = color ?? type.semanticColor  // Use semantic color by default
    }

    var body: some View {
        switch type {
        case .income:
            incomeIcon
        case .expenses:
            expensesIcon
        case .saved:
            savedIcon
        case .savingsRate:
            savingsRateIcon
        }
    }

    // Income: Upward flowing stream (clearly directional inflow)
    private var incomeIcon: some View {
        VStack(spacing: 1) {
            // Top: Smallest (destination)
            Circle()
                .fill(color!)
                .frame(width: size * 0.15, height: size * 0.15)

            // Flow indicators
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color!.opacity(0.8 - Double(index) * 0.2))
                    .frame(width: size * (0.3 + Double(index) * 0.15), height: size * 0.12)
            }

            // Base: Widest (source)
            RoundedRectangle(cornerRadius: 3)
                .fill(color!.opacity(0.4))
                .frame(width: size * 0.75, height: size * 0.2)
        }
        .frame(width: size, height: size)
    }

    // Expenses: Downward flowing stream (clearly directional outflow)
    private var expensesIcon: some View {
        VStack(spacing: 1) {
            // Source: Widest (starting point)
            RoundedRectangle(cornerRadius: 3)
                .fill(color!.opacity(0.4))
                .frame(width: size * 0.75, height: size * 0.2)

            // Flow indicators (widening as money flows out)
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color!.opacity(0.6 + Double(index) * 0.15))
                    .frame(width: size * (0.45 + Double(index) * 0.1), height: size * 0.12)
            }

            // Bottom: Distribution points
            HStack(spacing: 2) {
                Circle()
                    .fill(color!)
                    .frame(width: size * 0.12, height: size * 0.12)
                Circle()
                    .fill(color!)
                    .frame(width: size * 0.12, height: size * 0.12)
                Circle()
                    .fill(color!)
                    .frame(width: size * 0.12, height: size * 0.12)
            }
        }
        .frame(width: size, height: size)
    }

    // Saved: Secure vault container (security & retention) - KEEP CURRENT, IT'S EXCELLENT
    private var savedIcon: some View {
        ZStack {
            // Outer security layer
            RoundedRectangle(cornerRadius: 6)
                .stroke(color!.opacity(0.4), lineWidth: 2)
                .frame(width: size * 0.9, height: size * 0.7)

            // Inner vault
            RoundedRectangle(cornerRadius: 4)
                .fill(color!)
                .frame(width: size * 0.6, height: size * 0.45)

            // Security indicator (small lock metaphor)
            Circle()
                .fill(color!.opacity(0.8))
                .frame(width: size * 0.15, height: size * 0.15)
                .offset(x: size * 0.2, y: -size * 0.15)
        }
        .frame(width: size, height: size)
    }

    // Savings Rate: Progress arc with momentum (percentage) - KEEP CURRENT, IT'S EXCELLENT
    private var savingsRateIcon: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(color!, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Momentum indicator (arrow tip)
            Circle()
                .fill(color!)
                .frame(width: 4, height: 4)
                .offset(x: size * 0.35, y: -size * 0.1)

            // Center progress dot
            Circle()
                .fill(color!.opacity(0.3))
                .frame(width: size * 0.2, height: size * 0.2)
        }
        .frame(width: size, height: size)
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
        switch self {
        case .hero: return Color.florijnBlue.opacity(0.04)
        case .primary: return Color.white
        case .supporting: return Color.florijnLightGray.opacity(0.3)
        case .income: return Color.incomeGreen.opacity(0.06)
        case .expenses: return Color.expenseRed.opacity(0.04)
        case .savings: return Color.savingsWin.opacity(0.05)
        case .neutral: return Color.florijnBlue.opacity(0.03)
        }
    }

    var borderColor: Color {
        switch self {
        case .hero: return Color.florijnBlue.opacity(0.15)
        case .primary: return Color.florijnLightGray
        case .supporting: return Color.florijnMediumGray.opacity(0.2)
        case .income: return Color.incomeGreen.opacity(0.12)
        case .expenses: return Color.expenseRed.opacity(0.08)
        case .savings: return Color.savingsWin.opacity(0.10)
        case .neutral: return Color.florijnBlue.opacity(0.08)
        }
    }

    var shadowColor: Color {
        switch self {
        case .hero: return Color.florijnBlue.opacity(0.15)
        case .primary: return Color.black.opacity(0.08)
        case .supporting: return Color.black.opacity(0.04)
        case .income: return Color.incomeGreen.opacity(0.08)
        case .expenses: return Color.expenseRed.opacity(0.06)
        case .savings: return Color.savingsWin.opacity(0.08)
        case .neutral: return Color.black.opacity(0.06)
        }
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
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius)
                            .stroke(Color.glassStroke, lineWidth: 0.5)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    /// Elevated premium card for hero content
    func heroCard() -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius + 4)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius + 4)
                            .stroke(LinearGradient(
                                colors: [Color.glassStroke, Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1)
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

    /// Semantic financial card with meaningful colors and hierarchy
    func financialCard(type: FinancialCardType) -> some View {
        self
            .scaleEffect(type.scale)
            .background {
                RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius)
                    .fill(type.backgroundColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius)
                            .stroke(type.borderColor, lineWidth: type == .hero ? 1.5 : 1)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius))
            .shadow(color: type.shadowColor, radius: type == .hero ? 12 : 6, x: 0, y: type == .hero ? 6 : 3)
            .shadow(color: type.shadowColor.opacity(0.5), radius: type == .hero ? 4 : 2, x: 0, y: 1)
    }

    /// Improved hover interaction for financial cards
    func withFinancialHover() -> some View {
        self
            .onHover { hovering in
                NSCursor.pointingHand.set()
            }
            .scaleEffect(1.01)
            .shadow(radius: 8)
            .animation(.subtleHover, value: false)
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
                    colors: [Color.florijnBlue, Color.florijnNavy],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .foregroundStyle(.white)
            .font(.bodyLarge)
            .fontWeight(.semibold)
            .clipShape(RoundedRectangle(cornerRadius: PremiumSpacing.buttonCornerRadius))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .shadow(color: Color.florijnBlue.opacity(0.3), radius: configuration.isPressed ? 4 : 8, x: 0, y: configuration.isPressed ? 2 : 4)
            .animation(.quickResponse, value: configuration.isPressed)
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
    func premiumHeading(_ color: Color = .florijnCharcoal) -> some View {
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
    func financialLabel() -> some View {
        self
            .font(.caption2)
            .fontWeight(.light)
            .foregroundStyle(Color.florijnMediumGray)
            .opacity(0.7)
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
    let icon: GeometricFlowIcon.IconType
    let color: Color
    let trend: Double?
    let cardType: FinancialCardType

    @State private var isHovered = false

    init(
        title: String,
        value: Decimal? = nil,
        percentage: Double? = nil,
        icon: GeometricFlowIcon.IconType,
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
                GeometricFlowIcon(icon, size: PremiumSpacing.iconSize, color: color)

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

// MARK: - Utility Extensions
// Note: toCurrencyString() extension already exists in TransactionQueryService.swift