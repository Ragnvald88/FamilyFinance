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

    @State private var showingSimpleRuleBuilder = false
    @State private var showingAdvancedRuleBuilder = false

    // MARK: - Data Queries

    @Query(sort: \CategorizationRule.priority) private var legacyRules: [CategorizationRule]
    @Query(sort: \EnhancedCategorizationRule.priority) private var enhancedRules: [EnhancedCategorizationRule]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            // Direct access to rules management
            if enhancedRules.isEmpty {
                EnhancedRulesEmptyState {
                    showingSimpleRuleBuilder = true
                }
            } else {
                RulesManagementView()
            }
            .navigationTitle("Categorization Rules")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
            .onAppear {
                // Migration check removed - will implement in new system
            }
        }
        .sheet(isPresented: $showingSimpleRuleBuilder) {
            SimpleRuleBuilderView()
        }
        .sheet(isPresented: $showingAdvancedRuleBuilder) {
            AdvancedBooleanLogicBuilder()
        }
    }



    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Button("Create Rule") {
                    showingSimpleRuleBuilder = true
                }
            } label: {
                Image(systemName: "plus")
            }

        }
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
        Text("Advanced analytics coming soon...")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
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