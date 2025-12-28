//
//  RulesModels.swift
//  Family Finance
//
//  New rule system models based on Firefly III architecture
//  Provides trigger-action rule engine with rule groups and advanced features
//
//  Features:
//  - Rule Groups with execution order
//  - Trigger-Action architecture (IF this THEN that)
//  - Advanced triggers (NOT logic, date keywords, regex)
//  - Comprehensive actions (categorization, account operations, conversion)
//  - Rule statistics and performance tracking
//  - Expression engine support for advanced string manipulation
//
//  Created: 2025-12-26
//

import SwiftData
import Foundation

// MARK: - Rule Group Model

@Model
final class RuleGroup {
    /// Stable UUID for UI identification (SwiftData's PersistentIdentifier changes)
    @Attribute(.unique) var uuid: UUID

    var name: String

    /// Execution order for rule groups - indexed for sorting performance
    @Attribute(.spotlight) var executionOrder: Int

    /// Active status - indexed for filtering active groups
    @Attribute(.spotlight) var isActive: Bool

    var notes: String?

    // Relationships
    @Relationship(deleteRule: .cascade) var rules: [Rule]

    // Timestamps
    var createdAt: Date
    var modifiedAt: Date

    init(name: String, executionOrder: Int = 0) {
        self.uuid = UUID()
        self.name = name
        self.executionOrder = executionOrder
        self.isActive = true
        self.notes = nil
        self.rules = []
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    /// Update modification timestamp
    func touch() {
        modifiedAt = Date()
    }

    /// Count of active rules in this group
    var activeRulesCount: Int {
        rules.filter(\.isActive).count
    }
}

// MARK: - Rule Model

@Model
final class Rule {
    /// Stable UUID for UI identification
    @Attribute(.unique) var uuid: UUID

    var name: String

    /// Active status - indexed for filtering in rule evaluation (queried every time)
    @Attribute(.spotlight) var isActive: Bool

    var stopProcessing: Bool

    /// How flat triggers combine (for simple mode without groups)
    var triggerLogic: TriggerLogic

    /// How trigger groups combine (for advanced mode with nested AND/OR)
    /// Only used when triggerGroups is not empty
    var groupMatchMode: TriggerLogic

    var notes: String?

    /// Denormalized group execution order for efficient sorting without joins
    /// Updated automatically when group changes - see syncGroupOrder()
    var groupExecutionOrder: Int

    // Relationships
    /// Direct triggers (simple mode - all evaluated with triggerLogic)
    @Relationship(deleteRule: .cascade) var triggers: [RuleTrigger]

    /// Trigger groups (advanced mode - each group has its own matchMode)
    /// When not empty, these are used instead of direct triggers
    @Relationship(deleteRule: .cascade, inverse: \TriggerGroup.rule)
    var triggerGroups: [TriggerGroup]

    @Relationship(deleteRule: .cascade) var actions: [RuleAction]
    var group: RuleGroup?

    // Statistics
    var matchCount: Int
    var lastMatchedAt: Date?

    // Timestamps
    var createdAt: Date
    var modifiedAt: Date

    init(name: String, group: RuleGroup? = nil) {
        self.uuid = UUID()
        self.name = name
        self.isActive = true
        self.stopProcessing = false
        self.triggerLogic = .all
        self.groupMatchMode = .all
        self.notes = nil
        self.group = group
        self.groupExecutionOrder = group?.executionOrder ?? Int.max // Ungrouped rules last
        self.triggers = []
        self.triggerGroups = []
        self.actions = []
        self.matchCount = 0
        self.lastMatchedAt = nil
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    /// Update modification timestamp
    func touch() {
        modifiedAt = Date()
    }

    /// Synchronize denormalized groupExecutionOrder with actual group order
    /// Call this when rule's group changes for optimal query performance
    func syncGroupOrder() {
        groupExecutionOrder = group?.executionOrder ?? Int.max
        touch()
    }

    /// Record a successful rule match
    func recordMatch() {
        matchCount += 1
        lastMatchedAt = Date()
        touch()
    }

    /// Human-readable rule summary
    var displaySummary: String {
        let actionCount = actions.count

        var summary = "IF "

        // Handle advanced trigger groups
        if usesAdvancedTriggers {
            let groupCount = triggerGroups.count
            let totalCount = totalTriggerCount
            let groupConnector = groupMatchMode == .all ? "AND" : "OR"
            summary += "\(totalCount) conditions in \(groupCount) groups (\(groupConnector))"
        } else {
            // Handle simple flat triggers
            let triggerCount = triggers.count
            if triggerCount > 1 {
                summary += triggerLogic == .all ? "\(triggerCount) conditions (ALL)" : "\(triggerCount) conditions (ANY)"
            } else if let firstTrigger = triggers.first {
                let notPrefix = firstTrigger.isInverted ? "NOT " : ""
                let valueDisplay = firstTrigger.triggerOperator.requiresValue ? " \"\(firstTrigger.value)\"" : ""
                summary += "\(notPrefix)\(firstTrigger.field.displayName) \(firstTrigger.triggerOperator.displayName)\(valueDisplay)"
            } else {
                summary += "no conditions"
            }
        }

        summary += " THEN "

        if actionCount > 1 {
            summary += "\(actionCount) actions"
        } else if let firstAction = actions.first {
            summary += "\(firstAction.type.displayName)"
            if !firstAction.value.isEmpty {
                summary += " \"\(firstAction.value)\""
            }
        } else {
            summary += "no actions"
        }

        return summary
    }

    /// True if rule is ready for execution (has triggers and actions)
    var isValidForExecution: Bool {
        hasTriggers && !actions.isEmpty && isActive
    }

    /// True if rule uses advanced trigger groups (nested AND/OR)
    var usesAdvancedTriggers: Bool {
        !triggerGroups.isEmpty
    }

    /// True if rule has any triggers (simple or grouped)
    var hasTriggers: Bool {
        !triggers.isEmpty || triggerGroups.contains { !$0.triggers.isEmpty }
    }

    /// Total count of all triggers (simple + grouped)
    var totalTriggerCount: Int {
        if usesAdvancedTriggers {
            return triggerGroups.reduce(0) { $0 + $1.triggers.count }
        }
        return triggers.count
    }

    /// All triggers flattened (for simple iteration)
    var allTriggers: [RuleTrigger] {
        if usesAdvancedTriggers {
            return triggerGroups.flatMap(\.triggers)
        }
        return triggers
    }
}

// MARK: - Rule Trigger Model

@Model
final class RuleTrigger {
    /// Stable UUID for UI identification
    var uuid: UUID

    var field: TriggerField
    var triggerOperator: TriggerOperator
    var value: String
    var isInverted: Bool // NOT logic
    var sortOrder: Int

    // Relationships
    /// Direct rule relationship (for simple rules without groups)
    var rule: Rule?

    /// Group relationship (for advanced rules with nested AND/OR)
    var triggerGroup: TriggerGroup?

    init(field: TriggerField, triggerOperator: TriggerOperator, value: String, isInverted: Bool = false) {
        self.uuid = UUID()
        self.field = field
        self.triggerOperator = triggerOperator
        self.value = value
        self.isInverted = isInverted
        self.sortOrder = 0
    }

    /// Human-readable display text for this trigger
    var displayText: String {
        let notPrefix = isInverted ? "NOT " : ""
        return "\(notPrefix)\(field.displayName) \(triggerOperator.displayName) \"\(value)\""
    }

    /// Create a duplicate of this trigger
    func duplicate() -> RuleTrigger {
        return RuleTrigger(
            field: field,
            triggerOperator: triggerOperator,
            value: value,
            isInverted: isInverted
        )
    }
}

// MARK: - Trigger Group Model (for nested AND/OR logic)

/// Groups triggers together with their own match logic.
/// Enables complex conditions like: (A AND B) OR (C AND D)
///
/// Example:
/// - Group 1 (matchMode: .all): [description contains "spotify", amount > 10]
/// - Group 2 (matchMode: .all): [counterParty equals "Netflix"]
/// - Rule.groupMatchMode: .any → matches if EITHER group matches
@Model
final class TriggerGroup {
    /// Stable UUID for UI identification
    var uuid: UUID

    /// Optional name/label for the group (e.g., "Amount conditions")
    var name: String?

    /// How triggers within this group combine (all=AND, any=OR)
    var matchMode: TriggerLogic

    /// Display order within the rule
    var sortOrder: Int

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \RuleTrigger.triggerGroup)
    var triggers: [RuleTrigger]

    var rule: Rule?

    init(name: String? = nil, matchMode: TriggerLogic = .all, sortOrder: Int = 0) {
        self.uuid = UUID()
        self.name = name
        self.matchMode = matchMode
        self.sortOrder = sortOrder
        self.triggers = []
    }

    /// Human-readable display text for this group
    var displayText: String {
        let triggerTexts = triggers.sortedBySortOrder.map(\.displayText)
        let connector = matchMode == .all ? " AND " : " OR "
        return "(\(triggerTexts.joined(separator: connector)))"
    }

    /// Create a duplicate of this group with its triggers
    func duplicate() -> TriggerGroup {
        let newGroup = TriggerGroup(name: name, matchMode: matchMode, sortOrder: sortOrder)
        newGroup.triggers = triggers.map { $0.duplicate() }
        return newGroup
    }
}

// MARK: - Rule Action Model

@Model
final class RuleAction {
    /// Stable UUID for UI identification
    var uuid: UUID

    var type: ActionType
    var value: String
    var stopProcessingAfter: Bool
    var sortOrder: Int

    // Relationship
    var rule: Rule?

    init(type: ActionType, value: String, stopProcessingAfter: Bool = false) {
        self.uuid = UUID()
        self.type = type
        self.value = value
        self.stopProcessingAfter = stopProcessingAfter
        self.sortOrder = 0
    }

    /// Human-readable display text for this action
    var displayText: String {
        var text = type.displayName
        if !value.isEmpty && type.requiresValue {
            text += " \"\(value)\""
        }
        return text
    }

    /// Create a duplicate of this action
    func duplicate() -> RuleAction {
        return RuleAction(
            type: type,
            value: value,
            stopProcessingAfter: stopProcessingAfter
        )
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

    var shortDisplayName: String {
        switch self {
        case .all: return "ALL"
        case .any: return "ANY"
        }
    }
}

enum TriggerField: String, CaseIterable, Codable, Sendable {
    // Basic transaction fields
    case description = "description"
    case accountName = "account_name"
    case counterParty = "counter_party"
    case amount = "amount"
    case date = "date"

    // Extended transaction fields
    case iban = "iban"
    case counterIban = "counter_iban"
    case transactionType = "transaction_type"
    case category = "category"
    case notes = "notes"

    // Metadata fields
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

    /// True if this field expects numeric values
    var isNumeric: Bool {
        switch self {
        case .amount:
            return true
        default:
            return false
        }
    }

    /// True if this field expects date values
    var isDate: Bool {
        switch self {
        case .date:
            return true
        default:
            return false
        }
    }

    /// Valid operators for this field type
    var validOperators: [TriggerOperator] {
        if isNumeric {
            return [.equals, .greaterThan, .lessThan, .greaterThanOrEqual, .lessThanOrEqual]
        } else if isDate {
            return [.equals, .before, .after, .on, .today, .yesterday, .tomorrow]
        } else {
            // Text fields support text matching + presence checks
            return [.contains, .startsWith, .endsWith, .equals, .matches,
                    .isEmpty, .isNotEmpty, .hasValue]
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

    // Presence operators (NEW)
    case isEmpty = "is_empty"
    case isNotEmpty = "is_not_empty"
    case hasValue = "has_value"  // Same as isNotEmpty, clearer for "has category"

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
        case .isEmpty: return "is empty"
        case .isNotEmpty: return "is not empty"
        case .hasValue: return "has value"
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

    /// True if this operator requires a value input
    var requiresValue: Bool {
        switch self {
        case .today, .yesterday, .tomorrow, .isEmpty, .isNotEmpty, .hasValue:
            return false
        default:
            return true
        }
    }

    /// Placeholder text for value input field
    var valuePlaceholder: String {
        switch self {
        case .contains, .startsWith, .endsWith: return "Text to find..."
        case .equals: return "Exact value..."
        case .matches: return "Regular expression..."
        case .greaterThan: return "Minimum amount..."
        case .lessThan: return "Maximum amount..."
        case .greaterThanOrEqual: return "At least..."
        case .lessThanOrEqual: return "At most..."
        case .before, .after, .on: return "Date (YYYY-MM-DD)"
        case .today, .yesterday, .tomorrow, .isEmpty, .isNotEmpty, .hasValue: return ""
        }
    }
}

enum ActionType: String, CaseIterable, Codable, Sendable {
    // Categorization actions
    case setCategory = "set_category"
    case clearCategory = "clear_category"
    case setNotes = "set_notes"
    case setDescription = "set_description"
    case appendDescription = "append_description"
    case prependDescription = "prepend_description"
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

    // Advanced operations
    case deleteTransaction = "delete_transaction"
    case setExternalId = "set_external_id"
    case setInternalReference = "set_internal_reference"

    var displayName: String {
        switch self {
        case .setCategory: return "Set Category"
        case .clearCategory: return "Clear Category"
        case .setNotes: return "Set Notes"
        case .setDescription: return "Set Description"
        case .appendDescription: return "Append to Description"
        case .prependDescription: return "Prepend to Description"
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
        case .setDescription: return "text.badge.plus"
        case .appendDescription: return "text.append"
        case .prependDescription: return "text.insert"
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

    /// True if this action is destructive and requires confirmation
    var isDestructive: Bool {
        switch self {
        case .deleteTransaction, .clearCategory, .clearAllTags, .removeTag, .swapAccounts:
            return true
        default:
            return false
        }
    }

    /// True if this action requires a value input
    var requiresValue: Bool {
        switch self {
        case .clearCategory, .clearAllTags, .swapAccounts, .deleteTransaction:
            return false
        default:
            return true
        }
    }

    /// Placeholder text for value input field
    var valuePlaceholder: String {
        switch self {
        case .setCategory: return "Category name..."
        case .setNotes: return "Note text..."
        case .setDescription: return "New description..."
        case .appendDescription: return "Text to append..."
        case .prependDescription: return "Text to prepend..."
        case .addTag, .removeTag: return "Tag name..."
        case .setCounterParty: return "Counter party name..."
        case .setSourceAccount: return "Source account..."
        case .setDestinationAccount: return "Destination account..."
        case .convertToDeposit, .convertToWithdrawal, .convertToTransfer: return "Account name..."
        case .setExternalId: return "External ID..."
        case .setInternalReference: return "Internal reference..."
        case .clearCategory, .clearAllTags, .swapAccounts, .deleteTransaction: return ""
        }
    }

    /// Categories of actions for organizing the UI
    static var categorized: [ActionCategory: [ActionType]] {
        return [
            .categorization: [.setCategory, .clearCategory, .addTag, .removeTag, .clearAllTags],
            .content: [.setDescription, .appendDescription, .prependDescription, .setNotes, .setCounterParty],
            .accounts: [.setSourceAccount, .setDestinationAccount, .swapAccounts],
            .conversion: [.convertToDeposit, .convertToWithdrawal, .convertToTransfer],
            .metadata: [.setExternalId, .setInternalReference],
            .destructive: [.deleteTransaction]
        ]
    }
}

enum ActionCategory: String, CaseIterable {
    case categorization = "Categorization"
    case content = "Content"
    case accounts = "Accounts"
    case conversion = "Conversion"
    case metadata = "Metadata"
    case destructive = "Destructive"

    var icon: String {
        switch self {
        case .categorization: return "folder"
        case .content: return "note.text"
        case .accounts: return "building.columns"
        case .conversion: return "arrow.triangle.2.circlepath"
        case .metadata: return "tag"
        case .destructive: return "trash"
        }
    }
}

// MARK: - Helper Extensions

extension Array where Element == RuleGroup {
    /// Sort groups by execution order
    var sortedByExecutionOrder: [RuleGroup] {
        sorted { $0.executionOrder < $1.executionOrder }
    }

    /// Get next available execution order number
    var nextExecutionOrder: Int {
        (map(\.executionOrder).max() ?? 0) + 1
    }
}

extension Array where Element == Rule {
    /// Filter for active rules only
    var activeRules: [Rule] {
        filter(\.isActive)
    }

    /// Filter for rules ready for execution
    var executableRules: [Rule] {
        filter(\.isValidForExecution)
    }
}

extension Array where Element == RuleTrigger {
    /// Sort triggers by sort order
    var sortedBySortOrder: [RuleTrigger] {
        sorted { $0.sortOrder < $1.sortOrder }
    }
}

extension Array where Element == RuleAction {
    /// Sort actions by sort order
    var sortedBySortOrder: [RuleAction] {
        sorted { $0.sortOrder < $1.sortOrder }
    }
}

extension Array where Element == TriggerGroup {
    /// Sort trigger groups by sort order
    var sortedBySortOrder: [TriggerGroup] {
        sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Get next available sort order number
    var nextSortOrder: Int {
        (map(\.sortOrder).max() ?? -1) + 1
    }
}