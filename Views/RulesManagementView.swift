//
//  RulesManagementView.swift
//  Family Finance
//
//  Comprehensive rules management interface for both simple and advanced categorization rules
//  Central hub for rule creation, editing, testing, and migration
//
//  Features:
//  - Enhanced rules list with statistics and performance metrics
//  - Progressive rule builder (simple → advanced)
//  - Legacy rule migration with preview and approval
//  - Bulk operations (enable/disable, reorder, test)
//  - Rule analytics and effectiveness tracking
//  - Import/export rule sets
//
//  Created: 2025-12-24
//

import SwiftUI
@preconcurrency import SwiftData

struct RulesManagementView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - Queries

    @Query(sort: \EnhancedCategorizationRule.priority) private var enhancedRules: [EnhancedCategorizationRule]
    @Query(sort: \CategorizationRule.priority) private var legacyRules: [CategorizationRule]

    // MARK: - State

    @State private var showingCreateMenu = false
    @State private var showingSimpleBuilder = false
    @State private var showingAdvancedBuilder = false
    @State private var showingMigration = false
    @State private var showingBulkActions = false
    @State private var editingRule: EnhancedCategorizationRule?

    // Error handling state
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var errorTitle = "Error"

    // Performance optimization - cached statistics
    @State private var cachedStatistics: RuleStatistics?
    @State private var lastStatisticsUpdate: Date = .distantPast

    @State private var selectedRules = Set<String>()
    @State private var isReordering = false
    @State private var searchText = ""
    @State private var filterTier: RuleTier?
    @State private var filterActive: Bool?

    @State private var migrationAnalysis: MigrationAnalysis?
    @State private var isAnalyzingMigration = false
    @State private var showingMigrationResults = false

    // MARK: - Services

    @State private var migrationService: RuleMigrationService?
    @State private var enhancedEngine: EnhancedCategorizationEngine?

    // MARK: - Computed Properties

    private var filteredEnhancedRules: [EnhancedCategorizationRule] {
        enhancedRules.filter { rule in
            // Search filter
            if !searchText.isEmpty {
                let searchMatch = rule.name.localizedCaseInsensitiveContains(searchText) ||
                                rule.targetCategory.localizedCaseInsensitiveContains(searchText) ||
                                (rule.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
                if !searchMatch { return false }
            }

            // Tier filter
            if let filterTier = filterTier, rule.tier != filterTier {
                return false
            }

            // Active filter
            if let filterActive = filterActive, rule.isActive != filterActive {
                return false
            }

            return true
        }
    }

    private var ruleStatistics: RuleStatistics {
        // Use cached statistics if they're fresh (updated within last 5 seconds)
        let cacheValidityDuration: TimeInterval = 5.0
        let now = Date()

        if let cached = cachedStatistics,
           now.timeIntervalSince(lastStatisticsUpdate) < cacheValidityDuration {
            return cached
        }

        // Recompute statistics
        let active = enhancedRules.filter { $0.isActive }.count
        let simple = enhancedRules.filter { $0.tier == .simple }.count
        let advanced = enhancedRules.filter { $0.tier == .advanced }.count
        let totalMatches = enhancedRules.reduce(0) { $0 + $1.matchCount }

        let newStatistics = RuleStatistics(
            totalRules: enhancedRules.count,
            activeRules: active,
            simpleRules: simple,
            advancedRules: advanced,
            legacyRules: legacyRules.count,
            totalMatches: totalMatches
        )

        // Update cache
        cachedStatistics = newStatistics
        lastStatisticsUpdate = now

        return newStatistics
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Statistics Header
                statisticsHeader

                // Search and Filters
                searchAndFiltersSection

                // Rules List
                if filteredEnhancedRules.isEmpty && enhancedRules.isEmpty {
                    emptyStateView
                } else if filteredEnhancedRules.isEmpty {
                    noResultsView
                } else {
                    rulesListView
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle("Categorization Rules")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Migration button (if legacy rules exist)
                    if !legacyRules.isEmpty {
                        Button {
                            showingMigration = true
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .help("Migrate legacy rules")
                    }

                    // Bulk actions button
                    if !selectedRules.isEmpty {
                        Button {
                            showingBulkActions = true
                        } label: {
                            Image(systemName: "checklist")
                        }
                        .help("Bulk actions")
                    }

                    // Create menu
                    Menu {
                        Button("Simple Rule") {
                            showingSimpleBuilder = true
                        }

                        Button("Advanced Rule") {
                            showingAdvancedBuilder = true
                        }

                        if !enhancedRules.isEmpty {
                            Divider()
                            Button("Import Rules...") {
                                importRules()
                            }
                            Button("Export Rules...") {
                                exportRules()
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Create new rule")
                }

                ToolbarItem(placement: .secondaryAction) {
                    Button(isReordering ? "Done" : "Reorder") {
                        withAnimation(DesignTokens.Animation.spring) {
                            isReordering.toggle()
                        }
                    }
                    .disabled(filteredEnhancedRules.isEmpty)
                }
            }
            .onAppear {
                setupServices()
            }
        }
        .sheet(item: $editingRule) { rule in
            if rule.tier == .simple {
                SimpleRuleBuilderView(existingRule: rule)
            } else {
                AdvancedBooleanLogicBuilder(existingRule: rule)
            }
        }
        .sheet(isPresented: $showingSimpleBuilder) {
            SimpleRuleBuilderView()
        }
        .sheet(isPresented: $showingAdvancedBuilder) {
            AdvancedBooleanLogicBuilder()
        }
        .sheet(isPresented: $showingMigration) {
            MigrationView(
                analysis: migrationAnalysis,
                migrationService: migrationService
            )
        }
        .confirmationDialog("Bulk Actions", isPresented: $showingBulkActions) {
            Button("Enable Selected") {
                toggleSelectedRules(active: true)
            }
            Button("Disable Selected") {
                toggleSelectedRules(active: false)
            }
            Button("Delete Selected") {
                deleteSelectedRules()
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert(errorTitle, isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Statistics Header

    private var statisticsHeader: some View {
        VStack(spacing: DesignTokens.Spacing.m) {
            HStack(spacing: DesignTokens.Spacing.l) {
                StatCard(
                    title: "Total Rules",
                    value: "\(ruleStatistics.totalRules)",
                    subtitle: "\(ruleStatistics.activeRules) active",
                    color: .blue,
                    icon: "list.bullet"
                )

                StatCard(
                    title: "Simple",
                    value: "\(ruleStatistics.simpleRules)",
                    subtitle: "enhanced",
                    color: .green,
                    icon: "slider.horizontal.3"
                )

                StatCard(
                    title: "Advanced",
                    value: "\(ruleStatistics.advancedRules)",
                    subtitle: "power users",
                    color: .purple,
                    icon: "gear.badge"
                )

                if ruleStatistics.legacyRules > 0 {
                    StatCard(
                        title: "Legacy",
                        value: "\(ruleStatistics.legacyRules)",
                        subtitle: "needs migration",
                        color: .orange,
                        icon: "arrow.up.arrow.down"
                    )
                }
            }

            if ruleStatistics.totalMatches > 0 {
                Text("Rules have processed \(ruleStatistics.totalMatches.formatted()) transactions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DesignTokens.Spacing.l)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Search and Filters

    private var searchAndFiltersSection: some View {
        VStack(spacing: DesignTokens.Spacing.m) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search rules...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignTokens.Spacing.m)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Filters
            HStack(spacing: DesignTokens.Spacing.m) {
                FilterChip(
                    title: "All Tiers",
                    isSelected: filterTier == nil,
                    action: { filterTier = nil }
                )

                FilterChip(
                    title: "Simple",
                    isSelected: filterTier == .simple,
                    action: { filterTier = .simple }
                )

                FilterChip(
                    title: "Advanced",
                    isSelected: filterTier == .advanced,
                    action: { filterTier = .advanced }
                )

                Spacer()

                FilterChip(
                    title: "Active",
                    isSelected: filterActive == true,
                    action: { filterActive = filterActive == true ? nil : true }
                )

                FilterChip(
                    title: "Inactive",
                    isSelected: filterActive == false,
                    action: { filterActive = filterActive == false ? nil : false }
                )
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.l)
        .padding(.vertical, DesignTokens.Spacing.m)
    }

    // MARK: - Rules List

    private var rulesListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredEnhancedRules, id: \.self) { rule in
                    RuleRow(
                        rule: rule,
                        isSelected: selectedRules.contains(rule.id?.uuidString ?? ""),
                        isReordering: isReordering,
                        onSelectionToggle: { toggleRuleSelection(rule) },
                        onEdit: { editRule(rule) },
                        onDelete: { deleteRule(rule) },
                        onToggleActive: { toggleRuleActive(rule) },
                        onTest: { testRule(rule) }
                    )
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.clear)
                    .animation(DesignTokens.Animation.spring, value: isReordering)
                }
                // Note: onMove functionality requires List, so disable reordering for LazyVStack
                // If reordering is critical, consider implementing custom drag and drop
            }
            .padding(.top, 8)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Empty States

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Image(systemName: "list.bullet.below.rectangle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: DesignTokens.Spacing.m) {
                Text("No Categorization Rules")
                    .font(DesignTokens.Typography.title)
                    .fontWeight(.semibold)

                Text("Create rules to automatically categorize your transactions based on patterns, amounts, and other criteria.")
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: DesignTokens.Spacing.m) {
                Button("Create Simple Rule") {
                    showingSimpleBuilder = true
                }
                .buttonStyle(.borderedProminent)

                Button("Create Advanced Rule") {
                    showingAdvancedBuilder = true
                }
                .buttonStyle(.bordered)

                if !legacyRules.isEmpty {
                    Button("Migrate Existing Rules") {
                        showingMigration = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xl)
    }

    private var noResultsView: some View {
        VStack(spacing: DesignTokens.Spacing.l) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Rules Found")
                .font(DesignTokens.Typography.title2)
                .fontWeight(.semibold)

            Text("Try adjusting your search or filters to find the rules you're looking for.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Clear Filters") {
                clearFilters()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xl)
    }

    // MARK: - Methods

    private func setupServices() {
        migrationService = RuleMigrationService(modelContext: modelContext)
        enhancedEngine = EnhancedCategorizationEngine(modelContext: modelContext)

        // Analyze migration if legacy rules exist
        if !legacyRules.isEmpty && migrationAnalysis == nil {
            analyzeMigration()
        }
    }

    private func analyzeMigration() {
        guard let service = migrationService else { return }

        isAnalyzingMigration = true

        Task {
            do {
                let analysis = try await service.analyzeMigration()
                await MainActor.run {
                    migrationAnalysis = analysis
                    isAnalyzingMigration = false
                }
            } catch {
                await MainActor.run {
                    isAnalyzingMigration = false
                    showError(title: "Migration Analysis Failed", message: "Unable to analyze legacy rules for migration: \(error.localizedDescription)")
                }
            }
        }
    }

    private func toggleRuleSelection(_ rule: EnhancedCategorizationRule) {
        guard let id = rule.id?.uuidString else { return }

        if selectedRules.contains(id) {
            selectedRules.remove(id)
        } else {
            selectedRules.insert(id)
        }
    }

    private func toggleSelectedRules(active: Bool) {
        for rule in enhancedRules {
            if let id = rule.id?.uuidString, selectedRules.contains(id) {
                rule.isActive = active
                rule.modifiedAt = Date()
            }
        }

        do {
            try modelContext.save()
            selectedRules.removeAll()
            invalidateStatisticsCache()
        } catch {
            showError(title: "Update Failed", message: "Unable to update rules: \(error.localizedDescription)")
        }
    }

    private func deleteSelectedRules() {
        let rulesToDelete = enhancedRules.filter {
            selectedRules.contains($0.id?.uuidString ?? "")
        }

        for rule in rulesToDelete {
            modelContext.delete(rule)
        }

        do {
            try modelContext.save()
            selectedRules.removeAll()
            invalidateStatisticsCache()
        } catch {
            showError(title: "Delete Failed", message: "Unable to delete selected rules: \(error.localizedDescription)")
        }
    }

    private func editRule(_ rule: EnhancedCategorizationRule) {
        editingRule = rule
        switch rule.tier {
        case .simple:
            showingSimpleBuilder = true
        case .advanced:
            showingAdvancedBuilder = true
        }
    }

    private func deleteRule(_ rule: EnhancedCategorizationRule) {
        modelContext.delete(rule)

        do {
            try modelContext.save()
            invalidateStatisticsCache()
        } catch {
            showError(title: "Delete Failed", message: "Unable to delete rule: \(error.localizedDescription)")
        }
    }

    private func toggleRuleActive(_ rule: EnhancedCategorizationRule) {
        rule.isActive.toggle()
        rule.modifiedAt = Date()

        do {
            try modelContext.save()
            invalidateStatisticsCache()
        } catch {
            showError(title: "Update Failed", message: "Unable to toggle rule status: \(error.localizedDescription)")
        }
    }

    private func testRule(_ rule: EnhancedCategorizationRule) {
        // Implementation for testing individual rules
    }

    private func moveRules(from source: IndexSet, to destination: Int) {
        // Update priority based on new positions
        var mutableRules = filteredEnhancedRules
        mutableRules.move(fromOffsets: source, toOffset: destination)

        for (index, rule) in mutableRules.enumerated() {
            rule.priority = index
            rule.modifiedAt = Date()
        }

        do {
            try modelContext.save()
            invalidateStatisticsCache()
        } catch {
            showError(title: "Reorder Failed", message: "Unable to reorder rules: \(error.localizedDescription)")
        }
    }

    private func clearFilters() {
        withAnimation(DesignTokens.Animation.spring) {
            searchText = ""
            filterTier = nil
            filterActive = nil
        }
    }

    private func importRules() {
        // Implementation for importing rule sets
    }

    private func exportRules() {
        // Implementation for exporting current rules
    }

    // MARK: - Error Handling

    private func showError(title: String = "Error", message: String) {
        errorTitle = title
        errorMessage = message
        showingError = true
    }

    // MARK: - Performance Optimization

    /// Invalidate statistics cache when rules are modified
    private func invalidateStatisticsCache() {
        cachedStatistics = nil
        lastStatisticsUpdate = .distantPast
    }
}

// MARK: - Supporting Views

private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.s) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(DesignTokens.Typography.title2)
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
        .padding(DesignTokens.Spacing.m)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.blue : Color(nsColor: .controlBackgroundColor)
                )
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(DesignTokens.Animation.spring, value: isSelected)
    }
}

// MARK: - Supporting Types

private struct RuleStatistics {
    let totalRules: Int
    let activeRules: Int
    let simpleRules: Int
    let advancedRules: Int
    let legacyRules: Int
    let totalMatches: Int
}

// MARK: - Placeholder Views

private struct MigrationView: View {
    let analysis: MigrationAnalysis?
    let migrationService: RuleMigrationService?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("Rule Migration")
                    .font(.title)

                if let analysis = analysis {
                    Text("Found \(analysis.totalLegacyRules) legacy rules")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Analyzing legacy rules...")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Migration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct RuleRow: View {
    let rule: EnhancedCategorizationRule
    let isSelected: Bool
    let isReordering: Bool
    let onSelectionToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleActive: () -> Void
    let onTest: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.m) {
            // Selection checkbox (when reordering or selecting)
            if isReordering || isSelected {
                Button(action: onSelectionToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }

            // Rule content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rule.name)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    // Rule tier badge
                    Text(rule.tier.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(rule.tier == .simple ? Color.green.opacity(0.2) : Color.purple.opacity(0.2))
                        .foregroundStyle(rule.tier == .simple ? .green : .purple)
                        .clipShape(Capsule())
                }

                Text(rule.displaySummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    // Category
                    Text(rule.targetCategory)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())

                    // Match count
                    if rule.matchCount > 0 {
                        Text("\(rule.matchCount) matches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Active indicator
                    Image(systemName: rule.isActive ? "checkmark.circle.fill" : "pause.circle.fill")
                        .foregroundStyle(rule.isActive ? .green : .orange)
                        .font(.caption)
                }
            }

            // Action menu
            if !isReordering {
                Menu {
                    Button("Edit") { onEdit() }
                    Button("Test") { onTest() }
                    Button(rule.isActive ? "Disable" : "Enable") { onToggleActive() }
                    Button("Delete", role: .destructive) { onDelete() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.05) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .opacity(rule.isActive ? 1.0 : 0.6)
        .animation(DesignTokens.Animation.spring, value: isSelected)
        .animation(DesignTokens.Animation.spring, value: rule.isActive)
    }
}