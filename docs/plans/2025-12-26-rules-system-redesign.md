# Rules System Complete Redesign - Implementation Plan

**Date**: December 26, 2025
**Project**: FamilyFinance macOS App
**Goal**: Replace broken rules system with Firefly III-inspired, fully functional rule engine

## Executive Summary

Complete teardown and rebuild of the FamilyFinance rules system, removing unwanted Marketplace/AI features and implementing a clean, powerful rule engine based on Firefly III's proven trigger-action architecture.

**Key Features**:
- ✅ Clean trigger-action rule builder (IF this THEN that)
- ✅ Rule groups with execution order
- ✅ Advanced triggers (NOT logic, date keywords, expression engine)
- ✅ Comprehensive actions (categorization, account operations, transaction conversion)
- ✅ Bulk operations and manual rule application
- ✅ Native macOS interface (no marketing content, just functional tools)

## Current State Analysis

### Problems with Existing System
- ❌ Unwanted "Marketplace" and "AI Insights" tabs
- ❌ Marketing interface instead of functional tools
- ❌ Over-engineered complexity (4 tiers instead of 2)
- ❌ "Coming Soon" placeholders in production
- ❌ Broken compilation issues (recently fixed)

### What Works (Keep)
- ✅ Core transaction/account/category models
- ✅ SwiftData architecture
- ✅ CSV import system
- ✅ Performance optimizations
- ✅ Design token system

## Implementation Phases

---

## Phase 1: Demolition & Foundation (Day 1-2)

### Step 1: Remove Current Broken System

**Files to Delete Entirely**:
```bash
Views/EnhancedRulesWrapper.swift
Views/AIRuleInsightsView.swift
Services/AIRuleIntelligence.swift
```

**Clean up FamilyFinanceApp.swift**:
- Remove Marketplace toolbar buttons
- Remove AI Insights toolbar buttons
- Remove `showingMarketplace`, `showingAIInsights` state
- Remove all Marketplace/AI sheets and alerts
- Remove "Enhanced Rules Available" upgrade alerts

**Clean up Navigation**:
- Update sidebar to remove rules-related complexity
- Point "Rules" navigation to new RulesView

### Step 2: Create New Model Architecture

**File**: `Models/RulesModels.swift`

```swift
import SwiftData
import Foundation

// MARK: - Rule Group Model
@Model
final class RuleGroup {
    var name: String
    var executionOrder: Int
    var isActive: Bool
    var notes: String?

    // Relationships
    @Relationship(deleteRule: .cascade) var rules: [Rule]

    // Timestamps
    var createdAt: Date
    var modifiedAt: Date

    init(name: String, executionOrder: Int = 0) {
        self.name = name
        self.executionOrder = executionOrder
        self.isActive = true
        self.rules = []
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

// MARK: - Rule Model
@Model
final class Rule {
    var name: String
    var isActive: Bool
    var stopProcessing: Bool
    var triggerLogic: TriggerLogic
    var notes: String?

    // Relationships
    @Relationship(deleteRule: .cascade) var triggers: [RuleTrigger]
    @Relationship(deleteRule: .cascade) var actions: [RuleAction]
    var group: RuleGroup?

    // Statistics
    var matchCount: Int
    var lastMatchedAt: Date?

    // Timestamps
    var createdAt: Date
    var modifiedAt: Date

    init(name: String, group: RuleGroup? = nil) {
        self.name = name
        self.isActive = true
        self.stopProcessing = false
        self.triggerLogic = .all
        self.group = group
        self.triggers = []
        self.actions = []
        self.matchCount = 0
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

// MARK: - Rule Trigger Model
@Model
final class RuleTrigger {
    var field: TriggerField
    var operator: TriggerOperator
    var value: String
    var isInverted: Bool // NOT logic
    var sortOrder: Int

    // Relationship
    var rule: Rule?

    init(field: TriggerField, operator: TriggerOperator, value: String) {
        self.field = field
        self.operator = `operator`
        self.value = value
        self.isInverted = false
        self.sortOrder = 0
    }
}

// MARK: - Rule Action Model
@Model
final class RuleAction {
    var type: ActionType
    var value: String
    var stopProcessingAfter: Bool
    var sortOrder: Int

    // Relationship
    var rule: Rule?

    init(type: ActionType, value: String) {
        self.type = type
        self.value = value
        self.stopProcessingAfter = false
        self.sortOrder = 0
    }
}

// MARK: - Enums

enum TriggerLogic: String, CaseIterable, Codable, Sendable {
    case all = "all"
    case any = "any"

    var displayName: String {
        switch self {
        case .all: return "ALL triggers must match"
        case .any: return "ANY trigger can match"
        }
    }
}

enum TriggerField: String, CaseIterable, Codable, Sendable {
    // Basic fields
    case description = "description"
    case accountName = "account_name"
    case counterParty = "counter_party"
    case amount = "amount"
    case date = "date"

    // Advanced fields
    case iban = "iban"
    case counterIban = "counter_iban"
    case transactionType = "transaction_type"
    case category = "category"
    case notes = "notes"
    case externalId = "external_id"
    case internalReference = "internal_reference"
    case tags = "tags"

    var displayName: String {
        switch self {
        case .description: return "Description"
        case .accountName: return "Account Name"
        case .counterParty: return "Counter Party"
        case .amount: return "Amount"
        case .date: return "Date"
        case .iban: return "IBAN"
        case .counterIban: return "Counter IBAN"
        case .transactionType: return "Transaction Type"
        case .category: return "Category"
        case .notes: return "Notes"
        case .externalId: return "External ID"
        case .internalReference: return "Internal Reference"
        case .tags: return "Tags"
        }
    }

    var icon: String {
        switch self {
        case .description: return "text.quote"
        case .accountName: return "building.columns"
        case .counterParty: return "person.circle"
        case .amount: return "eurosign.circle"
        case .date: return "calendar"
        case .iban: return "number"
        case .counterIban: return "arrow.left.arrow.right"
        case .transactionType: return "arrow.up.arrow.down"
        case .category: return "folder"
        case .notes: return "note.text"
        case .externalId: return "link"
        case .internalReference: return "tag"
        case .tags: return "tag.circle"
        }
    }
}

enum TriggerOperator: String, CaseIterable, Codable, Sendable {
    // Text operators
    case contains = "contains"
    case startsWith = "starts_with"
    case endsWith = "ends_with"
    case equals = "equals"
    case matches = "matches" // regex

    // Numeric operators
    case greaterThan = "greater_than"
    case lessThan = "less_than"
    case greaterThanOrEqual = "greater_than_or_equal"
    case lessThanOrEqual = "less_than_or_equal"

    // Date operators
    case before = "before"
    case after = "after"
    case on = "on"
    case today = "today"
    case yesterday = "yesterday"
    case tomorrow = "tomorrow"

    var displayName: String {
        switch self {
        case .contains: return "contains"
        case .startsWith: return "starts with"
        case .endsWith: return "ends with"
        case .equals: return "equals"
        case .matches: return "matches pattern"
        case .greaterThan: return "greater than"
        case .lessThan: return "less than"
        case .greaterThanOrEqual: return "greater than or equal"
        case .lessThanOrEqual: return "less than or equal"
        case .before: return "before"
        case .after: return "after"
        case .on: return "on"
        case .today: return "is today"
        case .yesterday: return "was yesterday"
        case .tomorrow: return "is tomorrow"
        }
    }
}

enum ActionType: String, CaseIterable, Codable, Sendable {
    // Categorization
    case setCategory = "set_category"
    case clearCategory = "clear_category"
    case setNotes = "set_notes"
    case addTag = "add_tag"
    case removeTag = "remove_tag"
    case clearAllTags = "clear_all_tags"

    // Account operations
    case setCounterParty = "set_counter_party"
    case setSourceAccount = "set_source_account"
    case setDestinationAccount = "set_destination_account"
    case swapAccounts = "swap_accounts"

    // Transaction conversion
    case convertToDeposit = "convert_to_deposit"
    case convertToWithdrawal = "convert_to_withdrawal"
    case convertToTransfer = "convert_to_transfer"

    // Advanced
    case deleteTransaction = "delete_transaction"
    case setExternalId = "set_external_id"
    case setInternalReference = "set_internal_reference"

    var displayName: String {
        switch self {
        case .setCategory: return "Set Category"
        case .clearCategory: return "Clear Category"
        case .setNotes: return "Set Notes"
        case .addTag: return "Add Tag"
        case .removeTag: return "Remove Tag"
        case .clearAllTags: return "Clear All Tags"
        case .setCounterParty: return "Set Counter Party"
        case .setSourceAccount: return "Set Source Account"
        case .setDestinationAccount: return "Set Destination Account"
        case .swapAccounts: return "Swap Source/Destination"
        case .convertToDeposit: return "Convert to Deposit"
        case .convertToWithdrawal: return "Convert to Withdrawal"
        case .convertToTransfer: return "Convert to Transfer"
        case .deleteTransaction: return "Delete Transaction"
        case .setExternalId: return "Set External ID"
        case .setInternalReference: return "Set Internal Reference"
        }
    }

    var icon: String {
        switch self {
        case .setCategory: return "folder.badge.plus"
        case .clearCategory: return "folder.badge.minus"
        case .setNotes: return "note.text.badge.plus"
        case .addTag: return "tag.circle.fill"
        case .removeTag: return "tag.slash"
        case .clearAllTags: return "tag.slash.fill"
        case .setCounterParty: return "person.circle.fill"
        case .setSourceAccount: return "building.columns.circle.fill"
        case .setDestinationAccount: return "arrow.right.circle.fill"
        case .swapAccounts: return "arrow.left.arrow.right.circle.fill"
        case .convertToDeposit: return "arrow.down.circle.fill"
        case .convertToWithdrawal: return "arrow.up.circle.fill"
        case .convertToTransfer: return "arrow.left.arrow.right.circle.fill"
        case .deleteTransaction: return "trash.circle.fill"
        case .setExternalId: return "link.circle.fill"
        case .setInternalReference: return "tag.circle.fill"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .deleteTransaction, .clearCategory, .clearAllTags, .removeTag:
            return true
        default:
            return false
        }
    }
}
```

---

## Phase 2: Core Rule Engine (Day 3-4)

### Step 3: Build Rule Evaluation Engine

**File**: `Services/RuleEngine.swift`

```swift
import SwiftData
import Foundation

@MainActor
class RuleEngine: ObservableObject {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Main Evaluation Method

    func evaluateTransaction(_ transaction: Transaction) async -> [RuleResult] {
        let ruleGroups = await fetchActiveRuleGroups()
        var results: [RuleResult] = []

        for group in ruleGroups.sorted(by: \.executionOrder) where group.isActive {
            for rule in group.rules where rule.isActive {
                if await evaluateRule(rule, against: transaction) {
                    let actionResults = await executeActions(rule.actions, on: transaction)
                    let result = RuleResult(rule: rule, actions: actionResults)
                    results.append(result)

                    // Update rule statistics
                    rule.matchCount += 1
                    rule.lastMatchedAt = Date()

                    if rule.stopProcessing {
                        try? modelContext.save()
                        return results
                    }
                }
            }
        }

        try? modelContext.save()
        return results
    }

    // MARK: - Rule Evaluation

    private func evaluateRule(_ rule: Rule, against transaction: Transaction) async -> Bool {
        let triggerResults = await withTaskGroup(of: Bool.self) { group in
            var results: [Bool] = []

            for trigger in rule.triggers.sorted(by: \.sortOrder) {
                group.addTask {
                    await self.evaluateTrigger(trigger, against: transaction)
                }
            }

            for await result in group {
                results.append(result)
            }

            return results
        }

        return rule.triggerLogic == .all ?
            triggerResults.allSatisfy { $0 } :
            triggerResults.contains { $0 }
    }

    private func evaluateTrigger(_ trigger: RuleTrigger, against transaction: Transaction) async -> Bool {
        let evaluator = TriggerEvaluator()
        let matches = await evaluator.evaluate(trigger, against: transaction)
        return trigger.isInverted ? !matches : matches
    }

    // MARK: - Action Execution

    private func executeActions(_ actions: [RuleAction], on transaction: Transaction) async -> [ActionResult] {
        var results: [ActionResult] = []

        for action in actions.sorted(by: \.sortOrder) {
            let executor = ActionExecutor(modelContext: modelContext)
            let result = await executor.execute(action, on: transaction)
            results.append(result)

            if action.stopProcessingAfter && result.success {
                break
            }
        }

        return results
    }

    // MARK: - Data Fetching

    private func fetchActiveRuleGroups() async -> [RuleGroup] {
        let descriptor = FetchDescriptor<RuleGroup>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.executionOrder)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch rule groups: \(error)")
            return []
        }
    }
}

// MARK: - Result Types

struct RuleResult {
    let rule: Rule
    let actions: [ActionResult]
    let timestamp: Date = Date()
}

struct ActionResult {
    let action: RuleAction
    let success: Bool
    let message: String?
    let timestamp: Date = Date()
}
```

### Step 4: Trigger Evaluation System

**File**: `Services/TriggerEvaluator.swift`

```swift
import Foundation
import SwiftData

struct TriggerEvaluator {

    func evaluate(_ trigger: RuleTrigger, against transaction: Transaction) async -> Bool {
        let fieldValue = extractFieldValue(trigger.field, from: transaction)
        return evaluateOperator(trigger.operator, value: trigger.value, against: fieldValue)
    }

    // MARK: - Field Value Extraction

    private func extractFieldValue(_ field: TriggerField, from transaction: Transaction) -> String {
        switch field {
        case .description:
            return transaction.description1
        case .accountName:
            return transaction.account?.name ?? ""
        case .counterParty:
            return transaction.counterName ?? ""
        case .amount:
            return transaction.amount.description
        case .date:
            return ISO8601DateFormatter().string(from: transaction.date)
        case .iban:
            return transaction.iban
        case .counterIban:
            return transaction.counterIBAN ?? ""
        case .transactionType:
            return transaction.transactionType.rawValue
        case .category:
            return transaction.category ?? ""
        case .notes:
            return transaction.notes ?? ""
        case .externalId:
            return transaction.externalId ?? ""
        case .internalReference:
            return transaction.internalReference ?? ""
        case .tags:
            return transaction.tags?.joined(separator: ", ") ?? ""
        }
    }

    // MARK: - Operator Evaluation

    private func evaluateOperator(_ operator: TriggerOperator, value: String, against fieldValue: String) -> Bool {
        switch `operator` {
        // Text operators
        case .contains:
            return fieldValue.localizedCaseInsensitiveContains(value)
        case .startsWith:
            return fieldValue.localizedCaseInsensitiveHasPrefix(value)
        case .endsWith:
            return fieldValue.localizedCaseInsensitiveHasSuffix(value)
        case .equals:
            return fieldValue.localizedCaseInsensitiveCompare(value) == .orderedSame
        case .matches:
            return fieldValue.range(of: value, options: [.regularExpression, .caseInsensitive]) != nil

        // Numeric operators
        case .greaterThan:
            return compareNumeric(fieldValue, value, using: >)
        case .lessThan:
            return compareNumeric(fieldValue, value, using: <)
        case .greaterThanOrEqual:
            return compareNumeric(fieldValue, value, using: >=)
        case .lessThanOrEqual:
            return compareNumeric(fieldValue, value, using: <=)

        // Date operators
        case .before:
            return compareDate(fieldValue, value, using: <)
        case .after:
            return compareDate(fieldValue, value, using: >)
        case .on:
            return compareDate(fieldValue, value, using: ==)
        case .today:
            return Calendar.current.isDateInToday(parseDate(fieldValue) ?? Date.distantPast)
        case .yesterday:
            return Calendar.current.isDateInYesterday(parseDate(fieldValue) ?? Date.distantPast)
        case .tomorrow:
            return Calendar.current.isDateInTomorrow(parseDate(fieldValue) ?? Date.distantPast)
        }
    }

    // MARK: - Comparison Helpers

    private func compareNumeric(_ field: String, _ value: String, using comparator: (Decimal, Decimal) -> Bool) -> Bool {
        guard let fieldDecimal = Decimal(string: field),
              let valueDecimal = Decimal(string: value) else {
            return false
        }
        return comparator(fieldDecimal, valueDecimal)
    }

    private func compareDate(_ field: String, _ value: String, using comparator: (Date, Date) -> Bool) -> Bool {
        guard let fieldDate = parseDate(field),
              let valueDate = parseDate(value) else {
            return false
        }
        return comparator(fieldDate, valueDate)
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatters = [
            ISO8601DateFormatter(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd-MM-yyyy"
                return formatter
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        // Handle relative dates like "+3d", "-2w"
        if dateString.hasPrefix("+") || dateString.hasPrefix("-") {
            return parseRelativeDate(dateString)
        }

        return nil
    }

    private func parseRelativeDate(_ relativeString: String) -> Date? {
        let calendar = Calendar.current
        let today = Date()

        guard relativeString.count >= 3 else { return nil }

        let sign = relativeString.hasPrefix("+") ? 1 : -1
        let numberPart = String(relativeString.dropFirst().dropLast())
        let unitPart = String(relativeString.suffix(1))

        guard let number = Int(numberPart) else { return nil }

        let component: Calendar.Component
        switch unitPart.lowercased() {
        case "d": component = .day
        case "w": component = .weekOfYear
        case "m": component = .month
        case "y": component = .year
        default: return nil
        }

        return calendar.date(byAdding: component, value: sign * number, to: today)
    }
}
```

---

## Phase 3: User Interface (Day 5-7)

### Step 5: Main Rules Management View

**File**: `Views/RulesView.swift`

```swift
import SwiftUI
import SwiftData

struct RulesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \RuleGroup.executionOrder) private var ruleGroups: [RuleGroup]

    @State private var selectedGroup: RuleGroup?
    @State private var showingCreateRule = false
    @State private var showingCreateGroup = false
    @State private var editingRule: Rule?
    @State private var editingGroup: RuleGroup?

    var body: some View {
        NavigationSplitView {
            ruleGroupsSidebar
        } detail: {
            if let selectedGroup {
                rulesListView(for: selectedGroup)
            } else {
                rulesOverview
            }
        }
        .navigationTitle("Rules")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Rule") {
                        showingCreateRule = true
                    }

                    Button("New Group") {
                        showingCreateGroup = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .menuStyle(.borderlessButton)
            }
        }
        .sheet(item: $editingRule) { rule in
            RuleEditorView(rule: rule)
        }
        .sheet(isPresented: $showingCreateRule) {
            RuleEditorView(group: selectedGroup)
        }
        .sheet(item: $editingGroup) { group in
            GroupEditorView(group: group)
        }
        .sheet(isPresented: $showingCreateGroup) {
            GroupEditorView()
        }
    }

    // MARK: - Sidebar

    private var ruleGroupsSidebar: some View {
        List(selection: $selectedGroup) {
            Section("Rule Groups") {
                ForEach(ruleGroups) { group in
                    NavigationLink(value: group) {
                        HStack {
                            Image(systemName: group.isActive ? "folder.fill" : "folder")
                                .foregroundStyle(group.isActive ? .blue : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name)
                                    .fontWeight(.medium)

                                Text("\(group.rules.count) rules")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if !group.isActive {
                                Image(systemName: "pause.circle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                    .contextMenu {
                        Button("Edit Group") {
                            editingGroup = group
                        }

                        Button("New Rule in Group") {
                            selectedGroup = group
                            showingCreateRule = true
                        }

                        Divider()

                        Button("Duplicate Group") {
                            duplicateGroup(group)
                        }

                        Button("Delete Group", role: .destructive) {
                            deleteGroup(group)
                        }
                    }
                }
            }

            Section {
                Button("New Group") {
                    showingCreateGroup = true
                }
                .foregroundStyle(.blue)
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
    }

    // MARK: - Rules List

    private func rulesListView(for group: RuleGroup) -> some View {
        List {
            Section {
                ForEach(group.rules.sorted(by: { $0.createdAt < $1.createdAt })) { rule in
                    RuleRowView(rule: rule) {
                        editingRule = rule
                    }
                    .contextMenu {
                        Button("Edit") {
                            editingRule = rule
                        }

                        Button("Duplicate") {
                            duplicateRule(rule)
                        }

                        Button(rule.isActive ? "Disable" : "Enable") {
                            toggleRule(rule)
                        }

                        Divider()

                        Button("Test Rule") {
                            // TODO: Implement rule testing
                        }

                        Button("Delete", role: .destructive) {
                            deleteRule(rule)
                        }
                    }
                }
            } header: {
                HStack {
                    Text(group.name)
                    Spacer()
                    Button("Edit Group") {
                        editingGroup = group
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Rule") {
                    showingCreateRule = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Overview

    private var rulesOverview: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.l) {
                // Statistics Cards
                HStack(spacing: DesignTokens.Spacing.l) {
                    StatCard(
                        title: "Total Rules",
                        value: "\(totalRulesCount)",
                        icon: "list.bullet.rectangle"
                    )

                    StatCard(
                        title: "Active Groups",
                        value: "\(activeGroupsCount)",
                        icon: "folder.fill"
                    )

                    StatCard(
                        title: "Rules Processed Today",
                        value: "0", // TODO: Implement statistics
                        icon: "checkmark.circle.fill"
                    )
                }

                // Recent Activity
                GroupBox("Recent Rule Activity") {
                    Text("No recent activity")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                }
                .primaryCard()
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Computed Properties

    private var totalRulesCount: Int {
        ruleGroups.reduce(0) { $0 + $1.rules.count }
    }

    private var activeGroupsCount: Int {
        ruleGroups.filter(\.isActive).count
    }

    // MARK: - Actions

    private func duplicateGroup(_ group: RuleGroup) {
        let newGroup = RuleGroup(name: "\(group.name) Copy")
        newGroup.executionOrder = (ruleGroups.map(\.executionOrder).max() ?? 0) + 1

        modelContext.insert(newGroup)

        // Duplicate rules
        for rule in group.rules {
            let newRule = Rule(name: rule.name, group: newGroup)
            newRule.isActive = rule.isActive
            newRule.stopProcessing = rule.stopProcessing
            newRule.triggerLogic = rule.triggerLogic

            modelContext.insert(newRule)
        }

        try? modelContext.save()
    }

    private func deleteGroup(_ group: RuleGroup) {
        modelContext.delete(group)
        try? modelContext.save()
    }

    private func duplicateRule(_ rule: Rule) {
        let newRule = Rule(name: "\(rule.name) Copy", group: rule.group)
        newRule.isActive = rule.isActive
        newRule.stopProcessing = rule.stopProcessing
        newRule.triggerLogic = rule.triggerLogic

        modelContext.insert(newRule)
        try? modelContext.save()
    }

    private func toggleRule(_ rule: Rule) {
        rule.isActive.toggle()
        rule.modifiedAt = Date()
        try? modelContext.save()
    }

    private func deleteRule(_ rule: Rule) {
        modelContext.delete(rule)
        try? modelContext.save()
    }
}

// MARK: - Supporting Views

struct RuleRowView: View {
    let rule: Rule
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
            HStack {
                Image(systemName: rule.isActive ? "checkmark.circle.fill" : "pause.circle.fill")
                    .foregroundStyle(rule.isActive ? .green : .orange)

                Text(rule.name)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                Button("Edit") {
                    onEdit()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Rule summary
            Text(generateRuleSummary(rule))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(DesignTokens.Spacing.m)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func generateRuleSummary(_ rule: Rule) -> String {
        let triggerCount = rule.triggers.count
        let actionCount = rule.actions.count

        var summary = "IF "

        if triggerCount > 1 {
            summary += rule.triggerLogic == .all ? "\(triggerCount) conditions (ALL)" : "\(triggerCount) conditions (ANY)"
        } else if let firstTrigger = rule.triggers.first {
            summary += "\(firstTrigger.field.displayName) \(firstTrigger.operator.displayName) \"\(firstTrigger.value)\""
        } else {
            summary += "no conditions"
        }

        summary += " THEN "

        if actionCount > 1 {
            summary += "\(actionCount) actions"
        } else if let firstAction = rule.actions.first {
            summary += "\(firstAction.type.displayName) \"\(firstAction.value)\""
        } else {
            summary += "no actions"
        }

        return summary
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.s) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.l)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

---

## Phase 4: Advanced Features (Day 8-10)

### Step 6: Action Execution System

**File**: `Services/ActionExecutor.swift`

### Step 7: Expression Engine

**File**: `Services/ExpressionEngine.swift`

### Step 8: Bulk Operations

**File**: `Services/BulkRuleProcessor.swift`

---

## Phase 5: Integration & Testing (Day 11-12)

### Step 9: Transaction Processing Integration

### Step 10: Navigation Updates

### Step 11: Testing & Validation

---

## Success Criteria

### Functional Requirements
- ✅ Users can create/edit/delete rules and rule groups
- ✅ Rules process transactions automatically
- ✅ Advanced triggers support NOT logic, date keywords
- ✅ Actions support categorization, account operations, conversion
- ✅ Bulk rule application to existing transactions
- ✅ Rule statistics and performance tracking

### UX Requirements
- ✅ Clean, functional interface (no marketing content)
- ✅ Obvious primary actions (Create Rule button)
- ✅ No unwanted features (Marketplace/AI removed)
- ✅ Intuitive rule creation workflow
- ✅ Native macOS design patterns

### Performance Requirements
- ✅ Rule evaluation completes within 100ms per transaction
- ✅ Bulk operations handle 10k+ transactions efficiently
- ✅ UI remains responsive during rule processing
- ✅ Memory usage stays reasonable with 100+ rules

## Testing Plan

### Unit Tests
- Rule evaluation logic
- Trigger operators (all variants)
- Action execution
- Expression engine functions
- Date parsing and relative date handling

### Integration Tests
- End-to-end rule creation and execution
- Transaction processing with multiple rules
- Rule group execution order
- Stop processing behavior

### UI Tests
- Rule creation workflow
- Group management
- Bulk operations interface
- Error handling and user feedback

---

**Implementation Start Date**: December 26, 2025
**Target Completion**: January 6, 2026
**Estimated Effort**: 60-80 hours total development time