//
//  DesignTokens.swift
//  Family Finance
//
//  Centralized design system for App Store-quality consistency
//  Defines spacing, colors, animations, typography, and reusable styles
//
//  Created: 2025-12-24
//

import SwiftUI

// MARK: - Design Tokens

struct DesignTokens {

    // MARK: - Spacing Scale

    struct Spacing {
        static let xs: CGFloat = 4      // Tight spacing (badges, icons)
        static let s: CGFloat = 8       // Small spacing (form fields, minor gaps)
        static let m: CGFloat = 12      // Medium spacing (section items)
        static let l: CGFloat = 16      // Large spacing (card grids, major sections)
        static let xl: CGFloat = 24     // Extra large (page sections, major containers)
        static let xxl: CGFloat = 32    // Maximum (top-level padding)
        static let xxxl: CGFloat = 40   // Exceptional (special containers)
    }

    // MARK: - Corner Radius Scale

    struct CornerRadius {
        static let small: CGFloat = 4   // Badges, small elements
        static let medium: CGFloat = 8  // Form fields, search boxes
        static let large: CGFloat = 12  // Cards, sheets, primary containers
        static let pill: CGFloat = 999  // Use with .capsule() for pills
    }

    // MARK: - Shadow System

    struct Shadow {
        // Primary card shadow (most common)
        static let primary = ShadowStyle(
            color: .black.opacity(0.08),
            radius: 4,
            x: 0,
            y: 2
        )

        // Secondary/lighter shadow
        static let secondary = ShadowStyle(
            color: .black.opacity(0.05),
            radius: 2,
            x: 0,
            y: 1
        )

        // Elevated elements (modals, popover)
        static let elevated = ShadowStyle(
            color: .black.opacity(0.12),
            radius: 8,
            x: 0,
            y: 4
        )
    }

    // MARK: - Animation System

    struct Animation {
        // Primary spring animation (0.3s response, 0.8 damping)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)

        // Fast spring for micro-interactions
        static let springFast = SwiftUI.Animation.spring(response: 0.2, dampingFraction: 0.8)

        // Slow spring for major transitions
        static let springSlow = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)

        // Easing curves for specific use cases
        static let easeOut = SwiftUI.Animation.easeOut(duration: 0.25)
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: 0.3)

        // Number ticker animation for KPI counters
        static let numberTicker = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.7)
    }

    // MARK: - Opacity Scale

    struct Opacity {
        static let light: Double = 0.1      // Very subtle backgrounds
        static let medium: Double = 0.2     // Subtle highlights
        static let strong: Double = 0.3     // Visible but not overpowering
        static let overlay: Double = 0.8    // Loading overlays
        static let disabled: Double = 0.6   // Disabled state
    }

    // MARK: - Typography Scale

    struct Typography {
        // Display text (dashboard headers, major titles)
        static let display = Font.system(size: 32, weight: .bold, design: .default)

        // Large title (page headers)
        static let largeTitle = Font.system(size: 28, weight: .bold)

        // Section titles
        static let title = Font.system(size: 24, weight: .semibold)

        // Subsection headers
        static let headline = Font.headline.weight(.semibold)

        // Body text variations
        static let body = Font.body
        static let bodyMedium = Font.body.weight(.medium)
        static let bodySemibold = Font.body.weight(.semibold)

        // Secondary text
        static let subheadline = Font.subheadline
        static let caption = Font.caption
        static let caption2 = Font.caption2

        // Monospaced (currency amounts)
        static let currency = Font.body.monospacedDigit().weight(.semibold)
        static let currencyLarge = Font.title2.monospacedDigit().weight(.bold)
    }

    // MARK: - Color System

    struct Colors {
        // Semantic colors
        static let income = Color.green
        static let expense = Color.red.opacity(0.85)
        static let transfer = Color.blue
        static let neutral = Color.gray

        // Background colors
        static let cardBackground = Color(nsColor: .controlBackgroundColor)
        static let windowBackground = Color(nsColor: .windowBackgroundColor)

        // State colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
    }
}

// MARK: - Shadow Style Helper

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Reusable Style Modifiers

extension View {

    // MARK: - Card Styles

    /// Primary card style with consistent shadow and corner radius
    func primaryCard() -> some View {
        self
            .background(DesignTokens.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large))
            .shadow(
                color: DesignTokens.Shadow.primary.color,
                radius: DesignTokens.Shadow.primary.radius,
                x: DesignTokens.Shadow.primary.x,
                y: DesignTokens.Shadow.primary.y
            )
    }

    /// Secondary card style with lighter shadow
    func secondaryCard() -> some View {
        self
            .background(DesignTokens.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large))
            .shadow(
                color: DesignTokens.Shadow.secondary.color,
                radius: DesignTokens.Shadow.secondary.radius,
                x: DesignTokens.Shadow.secondary.x,
                y: DesignTokens.Shadow.secondary.y
            )
    }

    // MARK: - Interactive Animations

    /// Standard button press animation
    func buttonPressAnimation() -> some View {
        self
            .scaleEffect(1.0)
            .animation(DesignTokens.Animation.springFast, value: false)
    }

    /// Hover highlight for interactive elements (macOS-specific)
    func hoverHighlight() -> some View {
        self
            .onHover { isHovered in
                withAnimation(DesignTokens.Animation.springFast) {
                    // Hover effect handled by parent view
                }
            }
    }

    // MARK: - Loading States

    /// Loading overlay with consistent styling
    func loadingOverlay(isLoading: Bool, message: String = "Loading...") -> some View {
        self
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(DesignTokens.Opacity.medium)
                            .ignoresSafeArea()

                        VStack(spacing: DesignTokens.Spacing.m) {
                            ProgressView()
                                .scaleEffect(1.2)

                            Text(message)
                                .font(DesignTokens.Typography.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(DesignTokens.Spacing.xl)
                        .background(DesignTokens.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large))
                        .shadow(
                            color: DesignTokens.Shadow.elevated.color,
                            radius: DesignTokens.Shadow.elevated.radius,
                            x: DesignTokens.Shadow.elevated.x,
                            y: DesignTokens.Shadow.elevated.y
                        )
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .animation(DesignTokens.Animation.spring, value: isLoading)
                }
            }
    }

    // MARK: - List Item Animations

    /// Staggered animation for list items
    func staggeredAppearance(index: Int, totalItems: Int) -> some View {
        self
            .opacity(1)
            .offset(y: 0)
            .animation(
                DesignTokens.Animation.spring.delay(Double(index) * 0.05),
                value: true
            )
    }

    // MARK: - Number Animation

    /// Animate number changes with ticker effect
    func animatedNumber<T: Numeric & Comparable>(_ value: T) -> some View {
        self
            .animation(DesignTokens.Animation.numberTicker, value: value)
    }

    // MARK: - Sheet Transitions

    /// Enhanced sheet presentation transition
    func enhancedSheetTransition() -> some View {
        self
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
            .animation(DesignTokens.Animation.spring, value: true)
    }
}

// MARK: - Number Ticker Animation Helper

/// Animated number display with ticker effect
struct AnimatedNumber: View {
    let value: Decimal
    let formatter: NumberFormatter
    let font: Font

    @State private var displayValue: Decimal = 0

    init(
        value: Decimal,
        formatter: NumberFormatter = {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.locale = Locale(identifier: "nl_NL")
            return f
        }(),
        font: Font = DesignTokens.Typography.currencyLarge
    ) {
        self.value = value
        self.formatter = formatter
        self.font = font
    }

    var body: some View {
        Text(formatter.string(from: displayValue as NSNumber) ?? "€0,00")
            .font(font)
            .monospacedDigit()
            .onChange(of: value) { _, newValue in
                withAnimation(DesignTokens.Animation.numberTicker) {
                    displayValue = newValue
                }
            }
            .onAppear {
                withAnimation(DesignTokens.Animation.numberTicker.delay(0.3)) {
                    displayValue = value
                }
            }
    }
}

// MARK: - Skeleton Loading Components

struct SkeletonRow: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Title placeholder
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                .fill(Color.gray.opacity(isAnimating ? 0.3 : 0.2))
                .frame(height: 16)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Subtitle placeholder
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                .fill(Color.gray.opacity(isAnimating ? 0.2 : 0.1))
                .frame(height: 12)
                .frame(maxWidth: 200, alignment: .leading)
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
            ) {
                isAnimating.toggle()
            }
        }
    }
}

struct SkeletonCard: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.m) {
            // Header
            HStack {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                    .fill(Color.gray.opacity(isAnimating ? 0.3 : 0.2))
                    .frame(width: 24, height: 24)

                Spacer()

                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                    .fill(Color.gray.opacity(isAnimating ? 0.2 : 0.1))
                    .frame(width: 60, height: 16)
            }

            // Value placeholder
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                .fill(Color.gray.opacity(isAnimating ? 0.4 : 0.3))
                .frame(height: 24)
                .frame(maxWidth: 120, alignment: .leading)

            // Label placeholder
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                .fill(Color.gray.opacity(isAnimating ? 0.2 : 0.1))
                .frame(height: 12)
                .frame(maxWidth: 80, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.l)
        .primaryCard()
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
            ) {
                isAnimating.toggle()
            }
        }
    }
}