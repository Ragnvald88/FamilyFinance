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
    static let headingPrimary = Font.system(.title3, design: .default, weight: .bold)
    static let headingSecondary = Font.system(.headline, design: .default, weight: .semibold)
    static let bodyLarge = Font.system(.body, design: .default, weight: .medium)
    static let bodyRegular = Font.system(.callout, design: .default, weight: .regular)
    static let bodySmall = Font.system(.caption, design: .default, weight: .regular)
    static let caption = Font.system(.caption2, design: .default, weight: .medium)

    // Financial Data - Precision Typography
    static let currencyHero = Font.system(.largeTitle, design: .monospaced, weight: .bold)
    static let currencyLarge = Font.system(.title2, design: .monospaced, weight: .semibold)
    static let currency = Font.system(.title3, design: .monospaced, weight: .medium)
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
        case income    // Ascending geometric blocks
        case expenses  // Radiating flow pattern
        case saved     // Nested protection layers
        case savingsRate // Curved momentum arc
    }

    let type: IconType
    let size: CGFloat
    let color: Color

    init(_ type: IconType, size: CGFloat = 24, color: Color = .florijnBlue) {
        self.type = type
        self.size = size
        self.color = color
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

    // Income: Ascending geometric blocks (building wealth)
    private var incomeIcon: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: size * 0.4, height: size * 0.2)
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.8))
                .frame(width: size * 0.6, height: size * 0.25)
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.6))
                .frame(width: size * 0.8, height: size * 0.3)
        }
        .frame(width: size, height: size)
    }

    // Expenses: Radiating flow pattern (purposeful distribution)
    private var expensesIcon: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size * 0.2, height: size * 0.2)

            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color.opacity(0.7))
                    .frame(width: size * 0.3, height: 2)
                    .offset(x: size * 0.25)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
        }
        .frame(width: size, height: size)
    }

    // Saved: Nested protection layers (security & accumulation)
    private var savedIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.4), lineWidth: 2)
                .frame(width: size * 0.9, height: size * 0.7)

            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: size * 0.6, height: size * 0.45)
        }
        .frame(width: size, height: size)
    }

    // Savings Rate: Curved momentum arc (trajectory & progress)
    private var savingsRateIcon: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Arrow tip
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)
                .offset(x: size * 0.35, y: -size * 0.1)
        }
        .frame(width: size, height: size)
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
    @State private var hasAppeared = false

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
            .opacity(hasAppeared ? 1 : 0)
            .scaleEffect(hasAppeared ? 1 : 0.8)
            .onChange(of: value) { _, newValue in
                withAnimation(.premiumSpring) {
                    displayValue = newValue
                }
            }
            .onAppear {
                withAnimation(.smoothEntry.delay(0.3)) {
                    hasAppeared = true
                    displayValue = value
                }
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
    let index: Int

    @State private var isHovered = false
    @State private var hasAppeared = false

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

            // Value section
            VStack(alignment: .leading, spacing: PremiumSpacing.tiny) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.florijnMediumGray)

                if let value = value {
                    PremiumAnimatedNumber(value, font: .currencyLarge, color: color)
                } else if let percentage = percentage {
                    Text("\(percentage, specifier: "%.1f")%")
                        .font(.currencyLarge)
                        .foregroundStyle(color)
                        .monospacedDigit()
                }
            }
        }
        .padding(PremiumSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard()
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.subtleHover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .onAppear {
            withAnimation(.smoothEntry.delay(Double(index) * 0.1)) {
                hasAppeared = true
            }
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

extension Decimal {
    func toCurrencyString() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber) ?? "€0.00"
    }
}