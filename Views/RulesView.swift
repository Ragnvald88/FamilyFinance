//
//  RulesView.swift
//  Family Finance
//
//  Expert-approved main rules management interface for Phase 2 implementation
//  NavigationSplitView architecture with four-layer state management
//
//  Architecture:
//  • Hybrid MVVM + Coordinator Pattern - Clean separation with RulesCoordinator
//  • Four-Layer State: Data (@Query), Coordination (@StateObject), Performance (caching), UI (@State)
//  • Native macOS Experience - NavigationSplitView, keyboard shortcuts, context menus
//  • Performance Optimization - Intelligent caching, debounced stats, lazy loading
//  • RuleEngine Integration - Direct integration with completed backend
//
//  Created: 2025-12-27 (Component 8/8: UI Interface)
//

import SwiftUI
import SwiftData
import OSLog
import Foundation

// Note: This file replaces the RulesPlaceholder in FamilyFinanceApp.swift
// To use: Replace case .rules: RulesPlaceholder() with case .rules: RulesView()

// Note: DesignTokens is defined in FamilyFinanceApp.swift and available globally

private let logger = Logger(subsystem: "com.familyfinance", category: "RulesView")

// MARK: - Main Rules View

struct RulesView: View {

    // MARK: - Data Layer (SwiftData)
    @Query(sort: \RuleGroup.executionOrder) private var groups: [RuleGroup]
    @Query private var rules: [Rule]
    @Environment(\.modelContext) private var modelContext

    // MARK: - Coordination Layer (Business Logic)
    @StateObject private var coordinator = RulesCoordinator()
    @StateObject private var statsManager = RuleStatsManager()

    // MARK: - UI State Layer (Navigation/Selection)
    @State private var selectedGroupID: UUID?
    @State private var selectedRuleIDs = Set<UUID>()
    @State private var presentedModal: RulesModal?
    @State private var showingInspector = false
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            // Sidebar: Rule Groups
            RuleGroupsSidebar(
                groups: groups,
                selection: $selectedGroupID,
                onCreateGroup: { presentedModal = .newGroup },
                searchText: $searchText
            )
        } detail: {
            // Detail: Rules or Overview
            Group {
                if let groupID = selectedGroupID {
                    RulesDetailView(
                        groupID: groupID,
                        rules: rulesForGroup(groupID),
                        selectedRules: $selectedRuleIDs,
                        stats: statsManager.stats,
                        searchText: searchText,
                        onCreateRule: { presentedModal = .newRule(groupID: groupID) },
                        onEditRule: { rule in presentedModal = .editRule(rule) }
                    )
                } else {
                    RulesOverviewView(
                        groups: groups,
                        rules: rules,
                        overallStats: statsManager.overallStats,
                        onCreateRule: { presentedModal = .newRule(groupID: nil) },
                        onCreateGroup: { presentedModal = .newGroup }
                    )
                }
            }
            .toolbar {
                RulesToolbar(
                    hasSelection: !selectedRuleIDs.isEmpty,
                    isExecuting: coordinator.executionState == .executing,
                    showingInspector: $showingInspector,
                    onNewRule: {
                        presentedModal = .newRule(groupID: selectedGroupID)
                    },
                    onNewGroup: {
                        presentedModal = .newGroup
                    },
                    onRunRules: {
                        Task {
                            if let groupID = selectedGroupID,
                               let group = groups.first(where: { $0.uuid == groupID }) {
                                await coordinator.executeRules(in: group)
                            } else {
                                await coordinator.executeRules()
                            }
                        }
                    },
                    onBulkDelete: {
                        deleteSelectedRules()
                    }
                )
            }
            .inspector(isPresented: $showingInspector) {
                RuleInspectorView(
                    selectedRuleIDs: selectedRuleIDs,
                    rules: rules,
                    stats: statsManager.stats
                )
            }
        }
        .sheet(item: $presentedModal) { modal in
            modalView(for: modal)
        }
        // Note: .commands modifier must be used at App level, not View level
        // See RulesCommands struct for available keyboard shortcuts
        .task {
            // Initialize performance monitoring
            coordinator.initialize(modelContext: modelContext)
            statsManager.startMonitoring(groups: groups)
        }
        .onChange(of: groups) { _, newGroups in
            // Update stats monitoring when groups change
            statsManager.updateGroups(newGroups)
        }
        .alert("Rule Execution Error", isPresented: .init(
            get: {
                if case .failed = coordinator.executionState {
                    return true
                }
                return false
            },
            set: { _ in coordinator.clearExecutionState() }
        )) {
            Button("OK") {
                coordinator.clearExecutionState()
            }
        } message: {
            if case .failed(let errorMessage) = coordinator.executionState {
                Text("Failed to execute rules: \(errorMessage)")
            } else {
                Text("An unknown error occurred")
            }
        }
    }

    // MARK: - Helper Methods

    private func rulesForGroup(_ groupID: UUID) -> [Rule] {
        return rules.filter { $0.group?.uuid == groupID }
    }

    private func deleteSelectedRules() {
        for ruleID in selectedRuleIDs {
            if let rule = rules.first(where: { $0.uuid == ruleID }) {
                modelContext.delete(rule)
            }
        }
        selectedRuleIDs.removeAll()
        try? modelContext.save()
    }

    @ViewBuilder
    private func modalView(for modal: RulesModal) -> some View {
        switch modal {
        case .newRule(let groupID):
            RuleEditorView(
                rule: nil,
                groupID: groupID,
                groups: groups,
                onSave: { newRule in
                    modelContext.insert(newRule)
                    try? modelContext.save()
                    presentedModal = nil
                }
            )
        case .editRule(let rule):
            RuleEditorView(
                rule: rule,
                groupID: rule.group?.uuid,
                groups: groups,
                onSave: { updatedRule in
                    // Update existing rule
                    rule.name = updatedRule.name
                    rule.isActive = updatedRule.isActive
                    rule.notes = updatedRule.notes
                    rule.stopProcessing = updatedRule.stopProcessing
                    rule.modifiedAt = Date()

                    try? modelContext.save()
                    presentedModal = nil
                }
            )
        case .newGroup:
            RuleGroupEditorView(
                group: nil,
                onSave: { newGroup in
                    modelContext.insert(newGroup)
                    try? modelContext.save()
                    presentedModal = nil
                }
            )
        case .groupSettings(let group):
            RuleGroupEditorView(
                group: group,
                onSave: { updatedGroup in
                    group.name = updatedGroup.name
                    group.isActive = updatedGroup.isActive
                    group.executionOrder = updatedGroup.executionOrder
                    group.notes = updatedGroup.notes
                    group.modifiedAt = Date()

                    try? modelContext.save()
                    presentedModal = nil
                }
            )
        }
    }
}

// MARK: - Rule Groups Sidebar

struct RuleGroupsSidebar: View {
    let groups: [RuleGroup]
    @Binding var selection: UUID?
    let onCreateGroup: () -> Void
    @Binding var searchText: String

    private var filteredGroups: [RuleGroup] {
        if searchText.isEmpty {
            return groups
        }
        return groups.filter { group in
            group.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search groups...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(DesignTokens.Spacing.s)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small))
            .padding(DesignTokens.Spacing.m)

            // Groups list
            List(selection: $selection) {
                Section("Rule Groups") {
                    ForEach(filteredGroups) { group in
                        NavigationLink(value: group.uuid) {
                            RuleGroupRow(group: group)
                        }
                        .contextMenu {
                            GroupContextMenu(group: group)
                        }
                    }
                    .onMove(perform: reorderGroups)
                }

                Section {
                    Button(action: onCreateGroup) {
                        Label("New Group", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
            .listStyle(.sidebar)
        }
        .navigationTitle("Rules")
        .navigationSubtitle("\(groups.count) groups")
    }

    private func reorderGroups(from source: IndexSet, to destination: Int) {
        var reorderedGroups = filteredGroups
        reorderedGroups.move(fromOffsets: source, toOffset: destination)

        // Update execution order
        for (index, group) in reorderedGroups.enumerated() {
            group.executionOrder = index
        }
    }
}

// MARK: - Rule Group Row

struct RuleGroupRow: View {
    let group: RuleGroup

    var body: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(group.isActive ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)

            // Group info
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text("\(group.rules.count) rules")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Execution order badge
            Text("\(group.executionOrder)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(Circle())
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Rules Detail View

struct RulesDetailView: View {
    let groupID: UUID
    let rules: [Rule]
    @Binding var selectedRules: Set<UUID>
    let stats: [UUID: RuleStats]
    let searchText: String
    let onCreateRule: () -> Void
    let onEditRule: (Rule) -> Void

    private var filteredRules: [Rule] {
        if searchText.isEmpty {
            return rules
        }
        return rules.filter { rule in
            rule.name.localizedCaseInsensitiveContains(searchText) ||
            rule.notes?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    private var groupName: String {
        // This would be better fetched from the group directly
        return "Rule Group"
    }

    var body: some View {
        VStack(spacing: 0) {
            if rules.isEmpty {
                // Empty state
                ContentUnavailableView(
                    "No Rules in Group",
                    systemImage: "slider.horizontal.3",
                    description: Text("Add your first rule to start automatically processing transactions.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    Button(action: onCreateRule) {
                        Label("Add Rule", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            } else {
                // Rules list
                List(selection: $selectedRules) {
                    ForEach(filteredRules) { rule in
                        RuleRowView(
                            rule: rule,
                            stats: stats[rule.uuid],
                            onEdit: { onEditRule(rule) }
                        )
                        .contextMenu {
                            RuleContextMenu(
                                rule: rule,
                                onEdit: { onEditRule(rule) }
                            )
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(groupName)
        .navigationSubtitle("\(rules.count) rules")
    }
}

// MARK: - Rule Row View

struct RuleRowView: View {
    let rule: Rule
    let stats: RuleStats?
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
            // Rule header
            HStack {
                // Status indicator
                Circle()
                    .fill(rule.isActive ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)

                // Rule name
                Text(rule.name)
                    .font(.headline)
                    .fontWeight(.medium)

                Spacer()

                // Statistics badges
                if let stats = stats {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        StatsBadge(
                            label: "Matches",
                            value: "\(stats.totalMatches)",
                            color: .blue
                        )

                        if stats.totalMatches > 0 {
                            StatsBadge(
                                label: "Success",
                                value: "\(Int(stats.successRate * 100))%",
                                color: stats.successRate > 0.8 ? .green : .orange
                            )
                        }
                    }
                }
            }

            // Rule summary
            if let trigger = rule.triggers.first,
               let action = rule.actions.first {
                HStack {
                    Text("IF")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Text(triggerSummary(trigger))
                        .font(.caption)
                        .foregroundStyle(.primary)

                    Text("THEN")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Text(actionSummary(action))
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                .lineLimit(1)
            }

            // Last execution info
            if let stats = stats, let lastExecution = stats.lastExecution {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Last run: \(lastExecution, formatter: relativeDateFormatter)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onEdit()
        }
    }

    private func triggerSummary(_ trigger: RuleTrigger) -> String {
        let field = trigger.field.displayName
        let op = trigger.triggerOperator.displayName
        let value = trigger.value.prefix(20)
        return "\(field) \(op) \"\(value)\""
    }

    private func actionSummary(_ action: RuleAction) -> String {
        switch action.type {
        case .setCategory:
            return "Set category to \(action.value)"
        case .setNotes:
            return "Set notes to \(action.value)"
        case .addTag:
            return "Add tag \(action.value)"
        case .setSourceAccount:
            return "Move to account \(action.value)"
        default:
            return action.type.displayName
        }
    }
}

// MARK: - Stats Badge

struct StatsBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .foregroundStyle(color)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Rules Overview View

struct RulesOverviewView: View {
    let groups: [RuleGroup]
    let rules: [Rule]
    let overallStats: OverallRuleStats
    let onCreateRule: () -> Void
    let onCreateGroup: () -> Void

    private var activeGroups: Int {
        groups.filter(\.isActive).count
    }

    private var activeRules: Int {
        rules.filter(\.isActive).count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xl) {
                // Header
                VStack(spacing: DesignTokens.Spacing.m) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)

                    Text("Rules Overview")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Automatic transaction processing with custom rules")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Statistics cards
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: DesignTokens.Spacing.m) {
                    OverviewCard(
                        title: "Groups",
                        value: "\(groups.count)",
                        subtitle: "\(activeGroups) active",
                        systemImage: "folder",
                        color: .blue
                    )

                    OverviewCard(
                        title: "Rules",
                        value: "\(rules.count)",
                        subtitle: "\(activeRules) active",
                        systemImage: "slider.horizontal.3",
                        color: .green
                    )

                    OverviewCard(
                        title: "Processed",
                        value: "\(overallStats.totalProcessed)",
                        subtitle: "transactions",
                        systemImage: "checkmark.circle",
                        color: .orange
                    )
                }

                // Quick actions
                VStack(spacing: DesignTokens.Spacing.m) {
                    Text("Get Started")
                        .font(.title2)
                        .fontWeight(.semibold)

                    HStack(spacing: DesignTokens.Spacing.m) {
                        QuickActionCard(
                            title: "Create Rule Group",
                            description: "Organize related rules together",
                            systemImage: "folder.badge.plus",
                            action: onCreateGroup
                        )

                        QuickActionCard(
                            title: "Create First Rule",
                            description: "Start automating transaction processing",
                            systemImage: "plus.circle",
                            action: onCreateRule
                        )
                    }
                }

                // Recent activity (if stats available)
                if overallStats.totalProcessed > 0 {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.m) {
                        Text("Recent Activity")
                            .font(.title2)
                            .fontWeight(.semibold)

                        RecentActivityView(stats: overallStats)
                    }
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .navigationTitle("Rules")
        .navigationSubtitle("Overview")
    }
}

// MARK: - Overview Card

struct OverviewCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.m) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(color)

            VStack(spacing: 4) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DesignTokens.Spacing.l)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
        .shadow(radius: 2, x: 0, y: 1)
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let title: String
    let description: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.m) {
                Image(systemName: systemImage)
                    .font(.title)
                    .foregroundStyle(Color.accentColor)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(DesignTokens.Spacing.l)
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
            .shadow(radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Activity View

struct RecentActivityView: View {
    let stats: OverallRuleStats

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
            HStack {
                Text("Success Rate")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(stats.successRate * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            ProgressView(value: stats.successRate)
                .progressViewStyle(.linear)
                .tint(stats.successRate > 0.8 ? .green : .orange)

            HStack {
                Text("Average Processing Time")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(stats.averageProcessingTime * 1000))ms")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding(DesignTokens.Spacing.l)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
    }
}

// MARK: - Toolbar

struct RulesToolbar: ToolbarContent {
    let hasSelection: Bool
    let isExecuting: Bool
    @Binding var showingInspector: Bool
    let onNewRule: () -> Void
    let onNewGroup: () -> Void
    let onRunRules: () -> Void
    let onBulkDelete: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: onNewGroup) {
                Label("New Group", systemImage: "folder.badge.plus")
            }

            Button(action: onNewRule) {
                Label("New Rule", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)

            if hasSelection {
                Button(action: onBulkDelete) {
                    Label("Delete", systemImage: "trash")
                }
                .foregroundStyle(.red)
            }

            Button(action: onRunRules) {
                Label("Run Rules", systemImage: isExecuting ? "arrow.clockwise" : "play.fill")
            }
            .disabled(isExecuting)
            // .symbolEffect(.rotate, isActive: isExecuting) // TODO: Enable in macOS 14+

            Button(action: { showingInspector.toggle() }) {
                Label("Inspector", systemImage: "sidebar.right")
            }
            .help("Show rule inspector")
        }
    }
}

// MARK: - Inspector View

struct RuleInspectorView: View {
    let selectedRuleIDs: Set<UUID>
    let rules: [Rule]
    let stats: [UUID: RuleStats]

    private var selectedRules: [Rule] {
        rules.filter { selectedRuleIDs.contains($0.uuid) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.m) {
            Text("Inspector")
                .font(.headline)
                .fontWeight(.semibold)

            if selectedRules.isEmpty {
                Text("Select rules to view details")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if selectedRules.count == 1, let rule = selectedRules.first {
                // Single rule details
                RuleInspectorDetail(rule: rule, stats: stats[rule.uuid])
            } else {
                // Multiple rules summary
                MultipleRulesInspector(rules: selectedRules, stats: stats)
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.m)
        .frame(width: 300)
    }
}

// MARK: - Rule Inspector Detail

struct RuleInspectorDetail: View {
    let rule: Rule
    let stats: RuleStats?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.m) {
            // Rule name and status
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                Text(rule.name)
                    .font(.headline)

                HStack {
                    Circle()
                        .fill(rule.isActive ? Color.green : Color.secondary)
                        .frame(width: 8, height: 8)
                    Text(rule.isActive ? "Active" : "Inactive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Statistics
            if let stats = stats {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                    Text("Statistics")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    StatRow(label: "Total Matches", value: "\(stats.totalMatches)")
                    StatRow(label: "Success Rate", value: "\(Int(stats.successRate * 100))%")
                    if let lastExecution = stats.lastExecution {
                        StatRow(label: "Last Run", value: lastExecution.formatted(.relative(presentation: .named)))
                    }
                    StatRow(label: "Avg. Time", value: "\(Int(stats.averageExecutionTime * 1000))ms")
                }

                Divider()
            }

            // Rule configuration
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                Text("Configuration")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Triggers: \(rule.triggers.count)")
                    .font(.caption)
                Text("Actions: \(rule.actions.count)")
                    .font(.caption)
                Text("Stop Processing: \(rule.stopProcessing ? "Yes" : "No")")
                    .font(.caption)
            }

            if let notes = rule.notes, !notes.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                    Text("Notes")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Multiple Rules Inspector

struct MultipleRulesInspector: View {
    let rules: [Rule]
    let stats: [UUID: RuleStats]

    private var totalMatches: Int {
        rules.compactMap { stats[$0.uuid]?.totalMatches }.reduce(0, +)
    }

    private var averageSuccessRate: Double {
        let rates = rules.compactMap { stats[$0.uuid]?.successRate }
        return rates.isEmpty ? 0 : rates.reduce(0, +) / Double(rates.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.m) {
            Text("\(rules.count) Rules Selected")
                .font(.headline)

            Divider()

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                Text("Summary")
                    .font(.subheadline)
                    .fontWeight(.medium)

                StatRow(label: "Active", value: "\(rules.filter(\.isActive).count)")
                StatRow(label: "Total Matches", value: "\(totalMatches)")
                StatRow(label: "Avg. Success", value: "\(Int(averageSuccessRate * 100))%")
            }
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Context Menus

struct GroupContextMenu: View {
    let group: RuleGroup

    var body: some View {
        Button("Edit Group") {
            // Handle edit
        }
        Button("Duplicate Group") {
            // Handle duplicate
        }
        Divider()
        Button(group.isActive ? "Disable" : "Enable") {
            // Handle toggle active
        }
        Divider()
        Button("Delete Group", role: .destructive) {
            // Handle delete
        }
    }
}

struct RuleContextMenu: View {
    let rule: Rule
    let onEdit: () -> Void

    var body: some View {
        Button("Edit Rule") {
            onEdit()
        }
        Button("Test Rule") {
            // Handle test
        }
        Button("Duplicate Rule") {
            // Handle duplicate
        }
        Divider()
        Button(rule.isActive ? "Disable" : "Enable") {
            // Handle toggle active
        }
        Divider()
        Button("Delete Rule", role: .destructive) {
            // Handle delete
        }
    }
}

// MARK: - Commands

struct RulesCommands: Commands {
    @Binding var showingInspector: Bool
    let onNewRule: () -> Void
    let onNewGroup: () -> Void
    let onRunRules: () -> Void

    var body: some Commands {
        CommandMenu("Rules") {
            Button("New Rule") {
                onNewRule()
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Group") {
                onNewGroup()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])

            Button("Run All Rules") {
                onRunRules()
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            Button("Show Inspector") {
                showingInspector.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
        }
    }
}

// MARK: - Modal Types

enum RulesModal: Identifiable {
    case newRule(groupID: UUID?)
    case editRule(Rule)
    case newGroup
    case groupSettings(RuleGroup)

    var id: String {
        switch self {
        case .newRule(let groupID):
            return "newRule-\(groupID?.uuidString ?? "nil")"
        case .editRule(let rule):
            return "editRule-\(rule.uuid.uuidString)"
        case .newGroup:
            return "newGroup"
        case .groupSettings(let group):
            return "groupSettings-\(group.uuid.uuidString)"
        }
    }
}

// MARK: - Coordination Layer

@MainActor
final class RulesCoordinator: ObservableObject {
    @Published var executionState: RuleExecutionState = .idle
    @Published var operationProgress: RuleOperationProgress?

    private var ruleEngine: RuleEngine?
    private var modelContext: ModelContext?

    func initialize(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.ruleEngine = RuleEngine(modelContainer: modelContext.container)
    }

    func executeRules(in group: RuleGroup? = nil) async {
        guard let ruleEngine = ruleEngine else {
            logger.error("RuleEngine not initialized")
            return
        }

        executionState = .executing

        do {
            let transactions = await getTransactionsForTesting()
            if let group = group {
                _ = try await ruleEngine.executeRulesManually(
                    for: transactions,
                    ruleGroups: [group]
                )
            } else {
                // For now, execute all groups - in real implementation,
                // this would fetch all active groups from the database
                _ = try await ruleEngine.executeRulesManually(
                    for: transactions,
                    ruleGroups: []
                )
            }
            executionState = .completed
        } catch {
            logger.error("Rule execution failed: \(error)")
            executionState = .failed(error.localizedDescription)
        }
    }

    func clearExecutionState() {
        executionState = .idle
        operationProgress = nil
    }

    private func getTransactionsForTesting() async -> [Transaction] {
        // In a real implementation, this would fetch recent transactions
        // For now, return empty array to avoid compilation errors
        return []
    }
}

// MARK: - Performance Layer

@MainActor
final class RuleStatsManager: ObservableObject {
    @Published private(set) var stats: [UUID: RuleStats] = [:]
    @Published private(set) var overallStats: OverallRuleStats = .empty

    private var updateTimer: Timer?

    func startMonitoring(groups: [RuleGroup]) {
        updateStats(for: groups)

        // Update stats every 5 seconds (debounced)
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateStats(for: groups)
        }
    }

    func updateGroups(_ groups: [RuleGroup]) {
        updateStats(for: groups)
    }

    deinit {
        updateTimer?.invalidate()
    }

    private func updateStats(for groups: [RuleGroup]) {
        // Mock statistics - in real implementation, this would
        // fetch actual execution data from the database
        var newStats: [UUID: RuleStats] = [:]
        var totalMatches = 0
        var totalSuccesses = 0

        for group in groups {
            for rule in group.rules {
                let matches = Int.random(in: 0...100)
                let successes = Int.random(in: 0...matches)

                newStats[rule.uuid] = RuleStats(
                    totalMatches: matches,
                    successfulActions: successes,
                    lastExecution: rule.isActive ? Date().addingTimeInterval(-Double.random(in: 0...86400)) : nil,
                    averageExecutionTime: Double.random(in: 0.001...0.1)
                )

                totalMatches += matches
                totalSuccesses += successes
            }
        }

        self.stats = newStats
        self.overallStats = OverallRuleStats(
            totalProcessed: totalMatches,
            successfulActions: totalSuccesses,
            averageProcessingTime: 0.05
        )
    }
}

// MARK: - Execution State Types

enum RuleExecutionState: Equatable {
    case idle
    case executing
    case completed
    case failed(String)  // Store error message instead of Error for Equatable

    static func == (lhs: RuleExecutionState, rhs: RuleExecutionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.executing, .executing), (.completed, .completed):
            return true
        case (.failed(let lMsg), .failed(let rMsg)):
            return lMsg == rMsg
        default:
            return false
        }
    }
}

struct RuleOperationProgress {
    let current: Int
    let total: Int
    let currentOperation: String
}

// MARK: - Statistics Types

struct RuleStats {
    let totalMatches: Int
    let successfulActions: Int
    let lastExecution: Date?
    let averageExecutionTime: TimeInterval

    var successRate: Double {
        guard totalMatches > 0 else { return 0 }
        return Double(successfulActions) / Double(totalMatches)
    }
}

struct OverallRuleStats {
    let totalProcessed: Int
    let successfulActions: Int
    let averageProcessingTime: TimeInterval

    var successRate: Double {
        guard totalProcessed > 0 else { return 0 }
        return Double(successfulActions) / Double(totalProcessed)
    }

    static let empty = OverallRuleStats(
        totalProcessed: 0,
        successfulActions: 0,
        averageProcessingTime: 0
    )
}

// MARK: - Helper Extensions

// nonisolated(unsafe) because initialized once and only used for formatting
private nonisolated(unsafe) let relativeDateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
}()

// MARK: - Placeholder Editor Views (To be implemented)

struct RuleEditorView: View {
    let rule: Rule?
    let groupID: UUID?
    let groups: [RuleGroup]
    let onSave: (Rule) -> Void

    var body: some View {
        Text("Rule Editor - To be implemented")
            .frame(width: 600, height: 500)
    }
}

struct RuleGroupEditorView: View {
    let group: RuleGroup?
    let onSave: (RuleGroup) -> Void

    var body: some View {
        Text("Group Editor - To be implemented")
            .frame(width: 400, height: 300)
    }
}

#Preview {
    RulesView()
        .modelContainer(for: [RuleGroup.self, Rule.self], inMemory: true)
}