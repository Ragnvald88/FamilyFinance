//
//  AIRuleInsightsView.swift
//  Family Finance
//
//  AI-powered rule insights dashboard providing smart suggestions,
//  conflict detection, and performance analytics
//
//  Features:
//  - Smart rule suggestions with confidence scoring
//  - Visual conflict detection and resolution
//  - Real-time rule performance analytics
//  - Machine learning feedback collection
//  - Actionable insights for rule optimization
//
//  Created: 2025-12-24
//

import SwiftUI
@preconcurrency import SwiftData

/// AI-powered insights dashboard for intelligent rule management
struct AIRuleInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var aiIntelligence: AIRuleIntelligence
    @State private var selectedTab: InsightTab = .suggestions
    @State private var showingAnalysisProgress = false

    init(modelContext: ModelContext) {
        self._aiIntelligence = StateObject(wrappedValue: AIRuleIntelligence(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with analysis controls
                headerSection

                Divider()

                // Tab selector
                tabSelector

                Divider()

                // Content based on selected tab
                contentSection
            }
            .navigationTitle("Rule Intelligence")
            .task {
                await aiIntelligence.performIntelligentAnalysis()
            }
            .refreshable {
                await aiIntelligence.performIntelligentAnalysis()
            }
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Rule Intelligence")
                    .font(.title2)
                    .fontWeight(.bold)

                if let lastAnalysis = aiIntelligence.lastAnalysis {
                    Text("Last analysis: \(lastAnalysis, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Analyzing your rules and transactions...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if aiIntelligence.isAnalyzing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Analyzing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button("Refresh Analysis") {
                    Task {
                        await aiIntelligence.performIntelligentAnalysis()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(aiIntelligence.isAnalyzing)
            }
        }
        .padding(20)
        .background(Color.blue.opacity(0.05))
    }

    private var tabSelector: some View {
        Picker("Insight Type", selection: $selectedTab) {
            ForEach(InsightTab.allCases, id: \.self) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var contentSection: some View {
        Group {
            switch selectedTab {
            case .suggestions:
                SmartSuggestionsView(
                    suggestions: aiIntelligence.suggestions,
                    onAccept: { suggestion in
                        aiIntelligence.acceptSuggestion(suggestion)
                    },
                    onDismiss: { suggestion, reason in
                        aiIntelligence.dismissSuggestion(suggestion, reason: reason)
                    }
                )

            case .conflicts:
                ConflictDetectionView(
                    conflicts: aiIntelligence.conflicts,
                    onResolve: { conflict, resolution in
                        Task {
                            await aiIntelligence.resolveConflict(conflict, resolution: resolution)
                        }
                    }
                )

            case .analytics:
                RuleAnalyticsView(analytics: aiIntelligence.analytics)

            case .performance:
                PerformanceInsightsView(analytics: aiIntelligence.analytics)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Smart Suggestions View

struct SmartSuggestionsView: View {
    let suggestions: [RuleSuggestion]
    let onAccept: (RuleSuggestion) -> Void
    let onDismiss: (RuleSuggestion, DismissalReason?) -> Void

    var body: some View {
        ScrollView {
            if suggestions.isEmpty {
                emptySuggestionsView
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(suggestions) { suggestion in
                        SuggestionCard(
                            suggestion: suggestion,
                            onAccept: { onAccept(suggestion) },
                            onDismiss: { reason in onDismiss(suggestion, reason) }
                        )
                    }
                }
                .padding(20)
            }
        }
    }

    private var emptySuggestionsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("No Suggestions Available")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Your rule system is optimally configured! We'll continue monitoring for new opportunities.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SuggestionCard: View {
    let suggestion: RuleSuggestion
    let onAccept: () -> Void
    let onDismiss: (DismissalReason?) -> Void

    @State private var showingDismissSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with confidence score
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.name)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Label(suggestion.complexity.rawValue, systemImage: complexityIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Confidence score
                ConfidenceIndicator(confidence: suggestion.confidence)
            }

            // Description and reasoning
            VStack(alignment: .leading, spacing: 8) {
                Text(suggestion.description)
                    .font(.body)

                Text(suggestion.reasoning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Rule details
            ruleDetailsSection

            // Actions
            HStack {
                Button("Accept Suggestion") {
                    withAnimation(.spring(response: 0.3)) {
                        onAccept()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Dismiss") {
                    showingDismissSheet = true
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("Priority: \(suggestion.priority)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .sheet(isPresented: $showingDismissSheet) {
            DismissalReasonSheet { reason in
                onDismiss(reason)
                showingDismissSheet = false
            }
        }
    }

    private var ruleDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rule Preview")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                Label(suggestion.targetCategory, systemImage: "tag.fill")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())

                if let field = suggestion.field {
                    Label(field.displayName, systemImage: field.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let matchType = suggestion.matchType {
                    Text(matchType.displayName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if !suggestion.pattern.isEmpty {
                Text("Pattern: '\(suggestion.pattern)'")
                    .font(.caption)
                    .fontFamily(.monospaced)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var complexityIcon: String {
        switch suggestion.complexity {
        case .simple: return "1.circle.fill"
        case .enhanced: return "2.circle.fill"
        case .advanced: return "3.circle.fill"
        }
    }
}

struct ConfidenceIndicator: View {
    let confidence: Double

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Int(confidence * 100))%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(confidenceColor)

            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
        }
        .help("AI Confidence Score")
    }

    private var confidenceColor: Color {
        switch confidence {
        case 0.8...: return .green
        case 0.6...: return .orange
        default: return .red
        }
    }
}

struct DismissalReasonSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onReasonSelected: (DismissalReason) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Why are you dismissing this suggestion?")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    ForEach(DismissalReason.allCases, id: \.self) { reason in
                        Button(action: { onReasonSelected(reason) }) {
                            HStack {
                                Text(reason.rawValue)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .navigationTitle("Dismissal Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Conflict Detection View

struct ConflictDetectionView: View {
    let conflicts: [RuleConflict]
    let onResolve: (RuleConflict, ConflictResolution) -> Void

    var body: some View {
        ScrollView {
            if conflicts.isEmpty {
                emptyConflictsView
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(conflicts) { conflict in
                        ConflictCard(
                            conflict: conflict,
                            onResolve: { resolution in
                                onResolve(conflict, resolution)
                            }
                        )
                    }
                }
                .padding(20)
            }
        }
    }

    private var emptyConflictsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("No Conflicts Detected")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Your rules are working harmoniously together without any conflicts or issues.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ConflictCard: View {
    let conflict: RuleConflict
    let onResolve: (ConflictResolution) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conflict.title)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Label(conflict.type.rawValue, systemImage: typeIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Severity indicator
                SeverityBadge(severity: conflict.severity)
            }

            Text(conflict.description)
                .font(.body)

            Text(conflict.suggestion)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
                .background(severityColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Actions
            HStack {
                if conflict.autoResolvable {
                    Button("Auto-Resolve") {
                        // Auto-resolve logic would go here
                        print("Auto-resolving conflict: \(conflict.type)")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Manual Review") {
                    // Open detailed resolution view
                    print("Manual review for conflict: \(conflict.id)")
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("Detected \(conflict.detectedAt, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(severityColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var typeIcon: String {
        switch conflict.type {
        case .priorityConflict: return "arrow.up.arrow.down"
        case .patternOverlap: return "arrow.triangle.merge"
        case .unusedRule: return "clock"
        case .performance: return "speedometer"
        }
    }

    private var severityColor: Color {
        switch conflict.severity {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }
}

struct SeverityBadge: View {
    let severity: ConflictSeverity

    var body: some View {
        Text(severity.rawValue.uppercased())
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(severityColor)
            .clipShape(Capsule())
    }

    private var severityColor: Color {
        switch severity {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - Rule Analytics View

struct RuleAnalyticsView: View {
    let analytics: RuleAnalytics

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Overview cards
                overviewCardsSection

                // Effectiveness chart
                effectivenessSection

                // Category distribution
                categoryDistributionSection

                // Performance metrics
                performanceSection
            }
            .padding(20)
        }
    }

    private var overviewCardsSection: some View {
        HStack(spacing: 16) {
            AnalyticsCard(
                title: "Total Rules",
                value: "\(analytics.totalRules)",
                subtitle: "\(analytics.activeRules) active",
                color: .blue,
                icon: "slider.horizontal.3"
            )

            AnalyticsCard(
                title: "Total Matches",
                value: "\(analytics.totalMatches)",
                subtitle: "lifetime",
                color: .green,
                icon: "target"
            )

            AnalyticsCard(
                title: "Avg Effectiveness",
                value: "\(Int(analytics.avgRuleEffectiveness * 100))%",
                subtitle: "across all rules",
                color: .orange,
                icon: "chart.line.uptrend.xyaxis"
            )
        }
    }

    private var effectivenessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rule Effectiveness")
                .font(.headline)
                .fontWeight(.semibold)

            if analytics.ruleEffectiveness.isEmpty {
                Text("No effectiveness data available")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(20)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(analytics.ruleEffectiveness.prefix(10)), id: \.key) { ruleId, effectiveness in
                        EffectivenessRow(
                            ruleName: "Rule \(ruleId.prefix(8))",
                            effectiveness: effectiveness
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var categoryDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Distribution")
                .font(.headline)
                .fontWeight(.semibold)

            if analytics.categoryDistribution.isEmpty {
                Text("No category data available")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(20)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(analytics.categoryDistribution.sorted { $0.value > $1.value }.prefix(8)), id: \.key) { category, count in
                        CategoryDistributionRow(
                            category: category,
                            count: count,
                            total: analytics.totalMatches
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Metrics")
                .font(.headline)
                .fontWeight(.semibold)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg Evaluation Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !analytics.avgEvaluationTime.isEmpty {
                        let avgTime = analytics.avgEvaluationTime.values.reduce(0, +) / Double(analytics.avgEvaluationTime.count)
                        Text("\(String(format: "%.3f", avgTime * 1000))ms")
                            .font(.title3)
                            .fontWeight(.bold)
                    } else {
                        Text("N/A")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last Updated")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(analytics.lastUpdated, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AnalyticsCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EffectivenessRow: View {
    let ruleName: String
    let effectiveness: Double

    var body: some View {
        HStack {
            Text(ruleName)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    Rectangle()
                        .fill(effectivenessColor)
                        .frame(width: geometry.size.width * effectiveness, height: 6)
                }
            }
            .frame(width: 60)
            .clipShape(Capsule())

            Text("\(Int(effectiveness * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(effectivenessColor)
                .frame(width: 35, alignment: .trailing)
        }
    }

    private var effectivenessColor: Color {
        switch effectiveness {
        case 0.8...: return .green
        case 0.6...: return .orange
        default: return .red
        }
    }
}

struct CategoryDistributionRow: View {
    let category: String
    let count: Int
    let total: Int

    var body: some View {
        HStack {
            Text(category)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * percentage, height: 6)
                }
            }
            .frame(width: 60)
            .clipShape(Capsule())

            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 35, alignment: .trailing)
        }
    }

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
}

// MARK: - Performance Insights View

struct PerformanceInsightsView: View {
    let analytics: RuleAnalytics

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Performance insights and optimization recommendations")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(40)

                // TODO: Add detailed performance insights, optimization suggestions,
                // memory usage analysis, and rule evaluation profiling
            }
        }
    }
}

// MARK: - Supporting Types

enum InsightTab: String, CaseIterable {
    case suggestions = "Suggestions"
    case conflicts = "Conflicts"
    case analytics = "Analytics"
    case performance = "Performance"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .suggestions: return "lightbulb"
        case .conflicts: return "exclamationmark.triangle"
        case .analytics: return "chart.bar"
        case .performance: return "speedometer"
        }
    }
}