//
//  RulePreviewView.swift
//  Family Finance
//
//  Rule preview and testing interface showing which transactions match a rule
//  Provides confidence scores and explanations for rule testing
//
//  Features:
//  - Live transaction matching preview
//  - Confidence scoring and explanations
//  - Match/no-match breakdown with statistics
//  - Sample transaction display with highlighting
//  - Export preview results for analysis
//
//  Created: 2025-12-24
//

import SwiftUI

struct RulePreviewView: View {

    // MARK: - Properties

    let results: [RuleTestResult]

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var showingMatchedOnly = false
    @State private var sortOrder: SortOrder = .confidence

    // MARK: - Computed Properties

    private var filteredResults: [RuleTestResult] {
        let filtered = showingMatchedOnly ? results.filter { $0.matches } : results

        return filtered.sorted { first, second in
            switch sortOrder {
            case .confidence:
                return first.confidence > second.confidence
            case .date:
                return first.transaction.date > second.transaction.date
            case .amount:
                return abs(first.transaction.amount) > abs(second.transaction.amount)
            }
        }
    }

    private var statistics: PreviewStatistics {
        let matchCount = results.filter { $0.matches }.count
        let totalCount = results.count
        let averageConfidence = results.filter { $0.matches }.reduce(0.0) { $0 + $1.confidence } / Double(max(matchCount, 1))

        return PreviewStatistics(
            totalTransactions: totalCount,
            matchedTransactions: matchCount,
            matchRate: totalCount > 0 ? Double(matchCount) / Double(totalCount) : 0,
            averageConfidence: averageConfidence
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Statistics Header
                statisticsHeader

                // Filters and Controls
                filtersSection

                // Results List
                if filteredResults.isEmpty {
                    emptyStateView
                } else {
                    resultsList
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle("Rule Preview")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Export Results") {
                            exportResults()
                        }
                        Button("Copy Summary") {
                            copyToClipboard()
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    // MARK: - Statistics Header

    private var statisticsHeader: some View {
        VStack(spacing: DesignTokens.Spacing.m) {
            HStack(spacing: DesignTokens.Spacing.xl) {
                StatisticCard(
                    title: "Matches",
                    value: "\(statistics.matchedTransactions)",
                    subtitle: "of \(statistics.totalTransactions)",
                    color: .blue,
                    icon: "checkmark.circle.fill"
                )

                StatisticCard(
                    title: "Match Rate",
                    value: "\(Int(statistics.matchRate * 100))%",
                    subtitle: statistics.matchRate > 0.8 ? "High" : statistics.matchRate > 0.3 ? "Medium" : "Low",
                    color: statistics.matchRate > 0.8 ? .green : statistics.matchRate > 0.3 ? .orange : .red,
                    icon: "target"
                )

                StatisticCard(
                    title: "Avg Confidence",
                    value: String(format: "%.1f", statistics.averageConfidence * 100),
                    subtitle: "confidence",
                    color: statistics.averageConfidence > 0.8 ? .green : statistics.averageConfidence > 0.6 ? .orange : .red,
                    icon: "chart.bar.fill"
                )
            }
        }
        .padding(DesignTokens.Spacing.l)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        HStack(spacing: DesignTokens.Spacing.m) {
            // Show Matched Only Toggle
            Toggle("Matches Only", isOn: $showingMatchedOnly.animation(DesignTokens.Animation.spring))
                .toggleStyle(.button)

            Spacer()

            // Sort Menu
            Menu {
                Button("Sort by Confidence") {
                    withAnimation(DesignTokens.Animation.spring) {
                        sortOrder = .confidence
                    }
                }
                Button("Sort by Date") {
                    withAnimation(DesignTokens.Animation.spring) {
                        sortOrder = .date
                    }
                }
                Button("Sort by Amount") {
                    withAnimation(DesignTokens.Animation.spring) {
                        sortOrder = .amount
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Sort")
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, DesignTokens.Spacing.l)
        .padding(.vertical, DesignTokens.Spacing.m)
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            ForEach(Array(filteredResults.enumerated()), id: \.1.transaction.uniqueKey) { index, result in
                TransactionPreviewRow(
                    result: result,
                    index: index
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.l) {
            Image(systemName: showingMatchedOnly ? "magnifyingglass" : "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(showingMatchedOnly ? "No Matches Found" : "No Results")
                .font(DesignTokens.Typography.title2)
                .fontWeight(.semibold)

            Text(showingMatchedOnly ? "No transactions match this rule. Try adjusting the pattern or filters." : "No transactions available for testing.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if showingMatchedOnly {
                Button("Show All Results") {
                    withAnimation(DesignTokens.Animation.spring) {
                        showingMatchedOnly = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xl)
    }

    // MARK: - Methods

    private func exportResults() {
        // Implementation for exporting results
        // This could export to CSV or create a detailed report
    }

    private func copyToClipboard() {
        let summary = """
        Rule Preview Summary
        Total Transactions: \(statistics.totalTransactions)
        Matches: \(statistics.matchedTransactions) (\(Int(statistics.matchRate * 100))%)
        Average Confidence: \(String(format: "%.1f%%", statistics.averageConfidence * 100))
        """

        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
        #endif
    }
}

// MARK: - Statistic Card

private struct StatisticCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.s) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(DesignTokens.Typography.title)
                .fontWeight(.bold)
                .foregroundStyle(color)

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.m)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Transaction Preview Row

private struct TransactionPreviewRow: View {
    let result: RuleTestResult
    let index: Int

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.m) {
            // Match Indicator
            VStack {
                Image(systemName: result.matches ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(result.matches ? .green : .red)

                if result.matches {
                    Text("\(Int(result.confidence * 100))%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }

            // Transaction Details
            VStack(alignment: .leading, spacing: 4) {
                // Counter Party and Amount
                HStack {
                    Text(result.transaction.counterName ?? "Unknown")
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Text(CurrencyFormatter.shared.string(from: result.transaction.amount as NSDecimalNumber) ?? "€0.00")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(result.transaction.amount.doubleValue >= 0 ? DesignTokens.Colors.income : DesignTokens.Colors.expense)
                }

                // Description
                Text(result.transaction.fullDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Date and Account
                HStack {
                    Text(DateFormatter.shortDate.string(from: result.transaction.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    Text("****\(result.transaction.iban.suffix(4))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if result.matches {
                        Spacer()
                        Text(result.explanation)
                            .font(.caption)
                            .foregroundStyle(result.matches ? .green : .red)
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(result.matches ? Color.green.opacity(0.05) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(result.matches ? Color.green.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .animation(DesignTokens.Animation.spring, value: result.matches)
    }
}

// MARK: - Supporting Types

private struct PreviewStatistics {
    let totalTransactions: Int
    let matchedTransactions: Int
    let matchRate: Double
    let averageConfidence: Double
}

private enum SortOrder: CaseIterable {
    case confidence
    case date
    case amount

    var displayName: String {
        switch self {
        case .confidence: return "Confidence"
        case .date: return "Date"
        case .amount: return "Amount"
        }
    }
}

// MARK: - Extensions

extension CurrencyFormatter {
    static let shared: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter
    }()
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter
    }()
}