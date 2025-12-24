//
//  EnhancedRulesWrapper.swift
//  Family Finance
//
//  Wrapper to integrate enhanced rule system with progressive complexity
//  Bridges legacy system to new enhanced capabilities
//
//  Created: 2025-12-24
//

import SwiftUI
@preconcurrency import SwiftData

/// Progressive complexity rule system wrapper
/// Starts with simple mode and allows progression to advanced features
struct EnhancedRulesWrapper: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var complexityMode: RuleComplexityMode = .simple
    @State private var showingMigrationAlert = false
    @State private var showingAdvancedFeatures = false

    // MARK: - Legacy Data for Migration

    @Query(sort: \CategorizationRule.priority) private var legacyRules: [CategorizationRule]
    @Query(sort: \EnhancedCategorizationRule.priority) private var enhancedRules: [EnhancedCategorizationRule]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with complexity selector
                headerSection

                // Progressive disclosure based on complexity
                contentSection
            }
            .navigationTitle("Categorization Rules")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
            .onAppear {
                checkForMigration()
            }
        }
        .alert("Enhanced Rules Available", isPresented: $showingMigrationAlert) {
            Button("Use Enhanced System") {
                withAnimation(.spring(response: 0.5)) {
                    complexityMode = .enhanced
                }
            }
            Button("Keep Simple") {
                complexityMode = .simple
            }
        } message: {
            Text("You can upgrade to the enhanced rule system with more powerful features like account filtering, amount ranges, and advanced logic.")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: DesignTokens.Spacing.m) {
            // Statistics overview
            HStack(spacing: DesignTokens.Spacing.xl) {
                StatisticView(
                    title: "Total Rules",
                    value: "\(legacyRules.count + enhancedRules.count)",
                    subtitle: "active rules",
                    color: .blue
                )

                StatisticView(
                    title: "Enhanced",
                    value: "\(enhancedRules.count)",
                    subtitle: "advanced rules",
                    color: .green
                )

                StatisticView(
                    title: "Legacy",
                    value: "\(legacyRules.count)",
                    subtitle: "basic rules",
                    color: .orange
                )
            }

            // Complexity Mode Selector
            Picker("Rule System", selection: $complexityMode) {
                Text("Simple Rules").tag(RuleComplexityMode.simple)
                Text("Enhanced Rules").tag(RuleComplexityMode.enhanced)
                Text("Advanced Logic").tag(RuleComplexityMode.advanced)
            }
            .pickerStyle(.segmented)
            .animation(.spring(response: 0.3), value: complexityMode)
        }
        .padding(DesignTokens.Spacing.l)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Content Section

    private var contentSection: some View {
        Group {
            switch complexityMode {
            case .simple:
                LegacyRulesView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))

            case .enhanced:
                if enhancedRules.isEmpty {
                    EnhancedRulesEmptyState {
                        // Create first enhanced rule
                    }
                } else {
                    RulesManagementView()
                }

            case .advanced:
                AdvancedRulesView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if complexityMode == .simple && !legacyRules.isEmpty {
                Button("Upgrade to Enhanced") {
                    withAnimation(.spring(response: 0.5)) {
                        complexityMode = .enhanced
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Menu {
                Button("Simple Rule") {
                    // Create simple rule
                }

                if complexityMode != .simple {
                    Button("Enhanced Rule") {
                        // Create enhanced rule
                    }
                }

                if complexityMode == .advanced {
                    Button("Advanced Logic Rule") {
                        // Create advanced rule
                    }
                }
            } label: {
                Image(systemName: "plus")
            }
        }
    }

    // MARK: - Methods

    private func checkForMigration() {
        // If user has legacy rules but no enhanced rules, suggest migration
        if !legacyRules.isEmpty && enhancedRules.isEmpty && complexityMode == .simple {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                showingMigrationAlert = true
            }
        }
    }
}

// MARK: - Supporting Types

enum RuleComplexityMode: String, CaseIterable {
    case simple = "Simple"
    case enhanced = "Enhanced"
    case advanced = "Advanced"

    var displayName: String { rawValue }

    var description: String {
        switch self {
        case .simple:
            return "Basic pattern matching with categories"
        case .enhanced:
            return "Account filtering, amount ranges, field targeting"
        case .advanced:
            return "Full Boolean logic with AND/OR/NOT operations"
        }
    }
}

// MARK: - Statistic View

private struct StatisticView: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.s)
    }
}

// MARK: - Legacy Rules View

private struct LegacyRulesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CategorizationRule.priority) private var rules: [CategorizationRule]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var editingRule: CategorizationRule?

    private var filteredRules: [CategorizationRule] {
        if searchText.isEmpty {
            return rules
        }
        return rules.filter {
            $0.pattern.localizedCaseInsensitiveContains(searchText) ||
            $0.targetCategory.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.m) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search rules...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(DesignTokens.Spacing.m)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, DesignTokens.Spacing.l)

            // Rules list or empty state
            if rules.isEmpty {
                emptyStateView
            } else {
                rulesList
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.l) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: DesignTokens.Spacing.s) {
                Text("No Custom Rules")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create rules to automatically categorize your transactions based on patterns.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Create Your First Rule") {
                showingAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rulesList: some View {
        List {
            ForEach(filteredRules) { rule in
                SimplifiedRuleRow(rule: rule)
                    .onTapGesture {
                        editingRule = rule
                    }
            }
            .onDelete(perform: deleteRules)
        }
        .listStyle(.inset)
        .sheet(isPresented: $showingAddSheet) {
            BasicRuleEditorSheet(rule: nil, categories: categories)
        }
        .sheet(item: $editingRule) { rule in
            BasicRuleEditorSheet(rule: rule, categories: categories)
        }
    }

    private func deleteRules(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredRules[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Simplified Rule Row

private struct SimplifiedRuleRow: View {
    let rule: CategorizationRule

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.m) {
            // Priority indicator
            Circle()
                .fill(rule.isActive ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rule.pattern)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Text("#\(rule.priority)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }

                HStack {
                    Text(rule.targetCategory)
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())

                    Text(rule.matchType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if rule.matchCount > 0 {
                        Text("\(rule.matchCount) matches")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Enhanced Rules Empty State

private struct EnhancedRulesEmptyState: View {
    let onCreateRule: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: DesignTokens.Spacing.m) {
                Text("Welcome to Enhanced Rules")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Create sophisticated rules with account filtering, amount ranges, and advanced logic.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                    FeatureRow(icon: "building.columns", title: "Account Filtering", description: "Target specific accounts")
                    FeatureRow(icon: "eurosign.circle", title: "Amount Ranges", description: "Filter by transaction amounts")
                    FeatureRow(icon: "target", title: "Field Targeting", description: "Match descriptions, merchants, IBANs")
                    FeatureRow(icon: "gear.badge", title: "Advanced Logic", description: "AND/OR conditions for complex rules")
                }
                .padding(DesignTokens.Spacing.l)
                .background(Color.blue.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button("Create Enhanced Rule") {
                onCreateRule()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.m) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Advanced Rules View

private struct AdvancedRulesView: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Image(systemName: "brain")
                .font(.system(size: 64))
                .foregroundStyle(.purple)

            VStack(spacing: DesignTokens.Spacing.m) {
                Text("Advanced Rule Builder")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Create complex Boolean expressions with unlimited nesting and advanced logic operators.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Coming Soon...")
                    .font(.title2)
                    .foregroundStyle(.purple)
                    .padding(DesignTokens.Spacing.l)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Basic Rule Editor Sheet

private struct BasicRuleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let rule: CategorizationRule?
    let categories: [Category]

    @State private var pattern: String = ""
    @State private var targetCategory: String = ""
    @State private var matchType: RuleMatchType = .contains
    @State private var priority: Int = 50
    @State private var isActive: Bool = true

    private var isValid: Bool {
        !pattern.isEmpty && !targetCategory.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pattern Matching") {
                    TextField("Pattern", text: $pattern)

                    Picker("Match Type", selection: $matchType) {
                        ForEach(RuleMatchType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section("Categorization") {
                    Picker("Category", selection: $targetCategory) {
                        Text("Select Category").tag("")
                        ForEach(categories.map(\.name).sorted(), id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }

                Section("Options") {
                    Stepper("Priority: \(priority)", value: $priority, in: 1...1000)
                    Toggle("Active", isOn: $isActive)
                }
            }
            .navigationTitle(rule == nil ? "New Rule" : "Edit Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRule() }
                        .disabled(!isValid)
                }
            }
            .onAppear {
                if let rule = rule {
                    pattern = rule.pattern
                    targetCategory = rule.targetCategory
                    matchType = rule.matchType
                    priority = rule.priority
                    isActive = rule.isActive
                }
            }
        }
    }

    private func saveRule() {
        if let existingRule = rule {
            existingRule.pattern = pattern
            existingRule.targetCategory = targetCategory
            existingRule.matchType = matchType
            existingRule.priority = priority
            existingRule.isActive = isActive
            existingRule.modifiedAt = Date()
        } else {
            let newRule = CategorizationRule(
                pattern: pattern,
                matchType: matchType,
                targetCategory: targetCategory,
                priority: priority,
                isActive: isActive
            )
            modelContext.insert(newRule)
        }

        try? modelContext.save()
        dismiss()
    }
}