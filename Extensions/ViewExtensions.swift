//
//  ViewExtensions.swift
//  Florijn
//
//  Reusable view modifiers and components
//  Extracted from FlorijnApp.swift for better organization
//
//  Created: 2025-12-30
//

import SwiftUI

// MARK: - View Extensions

extension View {
    /// Standard card style using native macOS appearance
    func primaryCard() -> some View {
        self
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    /// Staggered appearance animation for list items
    func staggeredAppearance(index: Int, totalItems: Int) -> some View {
        self
            .opacity(1)
            .offset(y: 0)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.8).delay(Double(index) * 0.05),
                value: true
            )
    }
}

// MARK: - Utility Components

/// Animated currency display with spring animation
struct AnimatedNumber: View {
    let value: Decimal
    let font: Font

    @State private var displayValue: Decimal = 0

    var body: some View {
        Text(displayValue.toCurrencyString())
            .font(font)
            .monospacedDigit()
            .onChange(of: value) { _, newValue in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    displayValue = newValue
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3)) {
                    displayValue = value
                }
            }
    }
}

/// Skeleton loading placeholder for cards
struct SkeletonCard: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(isAnimating ? 0.3 : 0.2))
                    .frame(width: 24, height: 24)

                Spacer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(isAnimating ? 0.2 : 0.1))
                    .frame(width: 60, height: 16)
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(isAnimating ? 0.4 : 0.3))
                .frame(height: 24)
                .frame(maxWidth: 120, alignment: .leading)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(isAnimating ? 0.2 : 0.1))
                .frame(height: 12)
                .frame(maxWidth: 80, alignment: .leading)
        }
        .padding(16)
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

