//
//  FinancialHealthIndicator.swift
//  Florijn
//
//  Accessible financial health indicator with visual gauge
//  and educational micro-tips for budget awareness
//
//  Created: 2026-02-10
//

import SwiftUI

// MARK: - Financial Health Indicator

/// Displays a category's financial health as a compact visual indicator.
/// Includes progress bar, rating badge, and optional micro-tip.
///
/// Usage:
/// ```swift
/// FinancialHealthIndicator(health: viewModel.calculateCategoryHealth(for: category, spent: amount))
/// ```
struct FinancialHealthIndicator: View {
    let health: CategoryManagementViewModel.CategoryHealth
    var showMicroTip: Bool = false
    var compact: Bool = false

    var body: some View {
        if compact {
            compactView
        } else {
            standardView
        }
    }

    // MARK: - Standard Layout

    private var standardView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Rating badge
                ratingBadge

                Spacer()

                // Percentage text
                Text("\(Int(health.percentage * 100))%")
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(health.rating.color)
                    .monospacedDigit()
            }

            // Progress bar
            progressBar

            // Micro-tip
            if showMicroTip {
                microTipView
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(health.rating.accessibilityLabel)
        .accessibilityValue("\(Int(health.percentage * 100)) percent of budget used")
    }

    // MARK: - Compact Layout

    private var compactView: some View {
        HStack(spacing: 6) {
            Image(systemName: health.rating.icon)
                .font(.caption)
                .foregroundStyle(health.rating.color)

            Text("\(Int(health.percentage * 100))%")
                .font(.system(.caption2, design: .monospaced, weight: .medium))
                .foregroundStyle(health.rating.color)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(health.rating.accessibilityLabel)
        .accessibilityValue("\(Int(health.percentage * 100)) percent of budget used")
    }

    // MARK: - Components

    private var ratingBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: health.rating.icon)
                .font(.caption2)
            Text(health.rating.rawValue)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(health.rating.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(health.rating.color.opacity(0.1))
        .clipShape(Capsule())
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.adaptiveSecondary.opacity(0.15))

                // Fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(health.rating.color)
                    .frame(width: min(geometry.size.width * CGFloat(health.percentage), geometry.size.width))
            }
        }
        .frame(height: 6)
    }

    private var microTipView: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "lightbulb.fill")
                .font(.caption2)
                .foregroundStyle(.orange)

            Text(health.microTip)
                .font(.caption2)
                .foregroundStyle(Color.adaptiveSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(Color.adaptiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Financial tip: \(health.microTip)")
    }
}

// MARK: - Preview

#Preview("Health Indicators") {
    VStack(spacing: 24) {
        Group {
            FinancialHealthIndicator(
                health: .init(percentage: 0.3, rating: .excellent, microTip: "Great job!"),
                showMicroTip: true
            )

            FinancialHealthIndicator(
                health: .init(percentage: 0.65, rating: .good, microTip: "On track."),
                showMicroTip: true
            )

            FinancialHealthIndicator(
                health: .init(percentage: 0.9, rating: .warning, microTip: "Approaching limit."),
                showMicroTip: true
            )

            FinancialHealthIndicator(
                health: .init(percentage: 1.3, rating: .critical, microTip: "Over budget!"),
                showMicroTip: true
            )
        }
        .padding()

        Divider()

        Text("Compact")
            .font(.headline)

        HStack(spacing: 16) {
            FinancialHealthIndicator(
                health: .init(percentage: 0.3, rating: .excellent, microTip: ""),
                compact: true
            )
            FinancialHealthIndicator(
                health: .init(percentage: 0.65, rating: .good, microTip: ""),
                compact: true
            )
            FinancialHealthIndicator(
                health: .init(percentage: 0.9, rating: .warning, microTip: ""),
                compact: true
            )
            FinancialHealthIndicator(
                health: .init(percentage: 1.3, rating: .critical, microTip: ""),
                compact: true
            )
        }
    }
    .padding()
    .frame(width: 400)
}
