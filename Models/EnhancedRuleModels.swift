//
//  EnhancedRuleModels.swift
//  Family Finance
//
//  Advanced categorization rule system with progressive complexity
//  Tier 1: Enhanced simple rules (90% use case)
//  Tier 2: Advanced visual rule builder (10% power users)
//
//  Created: 2025-12-24
//

import Foundation
@preconcurrency import SwiftData

// MARK: - Enhanced Categorization Rule

/// Next-generation categorization rule supporting both simple and advanced logic.
///
/// **Tier 1 (Simple)**: Enhanced rules with account filtering, amount ranges, field targeting
/// **Tier 2 (Advanced)**: Visual rule builder with AND/OR logic like iOS Shortcuts
///
/// **Performance**: Optimized evaluation paths maintain 5,000+ tx/second throughput
@Model
final class EnhancedCategorizationRule {

    /// User-friendly rule name for management UI
    var name: String

    /// Target category to assign when rule matches
    var targetCategory: String

    /// Rule complexity tier (simple or advanced)
    var tier: RuleTier

    /// Rule priority (lower number = higher priority)
    var priority: Int

    /// Is this rule currently active?
    var isActive: Bool

    /// Optional description/notes for this rule
    var notes: String?

    // MARK: - Simple Rule Configuration (Tier 1)

    /// Simple rule configuration (encoded as Data for SwiftData compatibility)
    /// Only used when tier == .simple
    var simpleConfigData: Data?

    /// Decoded simple rule configuration
    var simpleConfig: SimpleRuleConfig? {
        get {
            guard let data = simpleConfigData else { return nil }
            return try? JSONDecoder().decode(SimpleRuleConfig.self, from: data)
        }
        set {
            simpleConfigData = try? JSONEncoder().encode(newValue)
            modifiedAt = Date()
        }
    }

    // MARK: - Advanced Rule Conditions (Tier 2)

    /// Advanced rule conditions (only used when tier == .advanced)
    @Relationship(deleteRule: .cascade, inverse: \RuleCondition.parentRule)
    var conditions: [RuleCondition]?

    /// Logical connector between condition groups (AND/OR at root level)
    var rootLogicalConnector: LogicalConnector?

    // MARK: - Statistics and Metadata

    /// Number of times this rule has successfully matched
    var matchCount: Int

    /// Last time this rule matched a transaction
    var lastMatchedAt: Date?

    /// When this rule was created
    var createdAt: Date

    /// When this rule was last modified
    var modifiedAt: Date

    /// Who created/modified this rule (future multi-user support)
    var createdBy: String?
    var modifiedBy: String?

    // MARK: - Computed Properties

    /// Rule complexity assessment for UI display
    var complexityLevel: RuleComplexity {
        switch tier {
        case .simple:
            guard let config = simpleConfig else { return .basic }
            let hasFilters = config.accountFilter != nil ||
                           config.amountMin != nil ||
                           config.amountMax != nil ||
                           config.transactionTypeFilter != nil
            return hasFilters ? .enhanced : .basic

        case .advanced:
            let conditionCount = conditions?.count ?? 0
            if conditionCount <= 2 {
                return .moderate
            } else if conditionCount <= 5 {
                return .complex
            } else {
                return .expert
            }
        }
    }

    /// Human-readable rule summary for display
    var displaySummary: String {
        switch tier {
        case .simple:
            guard let config = simpleConfig else { return "Invalid rule" }
            var summary = "If \(config.targetField.displayName) \(config.matchType.displayName) \"\(config.pattern)\""

            if let account = config.accountFilter {
                summary += " on \(account.suffix(4))"
            }

            if let min = config.amountMin, let max = config.amountMax {
                summary += " and amount between €\(min) - €\(max)"
            } else if let min = config.amountMin {
                summary += " and amount ≥ €\(min)"
            } else if let max = config.amountMax {
                summary += " and amount ≤ €\(max)"
            }

            if let type = config.transactionTypeFilter {
                summary += " (\(type.displayName))"
            }

            summary += " → \(targetCategory)"
            return summary

        case .advanced:
            let conditionCount = conditions?.count ?? 0
            return "Advanced rule with \(conditionCount) condition\(conditionCount == 1 ? "" : "s") → \(targetCategory)"
        }
    }

    // MARK: - Initialization

    init(
        name: String,
        targetCategory: String,
        tier: RuleTier,
        priority: Int,
        isActive: Bool = true,
        notes: String? = nil,
        createdBy: String? = nil
    ) {
        self.name = name
        self.targetCategory = targetCategory
        self.tier = tier
        self.priority = priority
        self.isActive = isActive
        self.notes = notes
        self.matchCount = 0
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.createdBy = createdBy
        self.modifiedBy = createdBy
    }

    // MARK: - Rule Management Methods

    /// Record a successful match for analytics
    func recordMatch() {
        matchCount += 1
        lastMatchedAt = Date()
        modifiedAt = Date()
    }

    /// Update rule priority and modification timestamp
    func updatePriority(_ newPriority: Int) {
        priority = newPriority
        modifiedAt = Date()
    }

    /// Create a simple rule configuration
    func configureAsSimpleRule(
        accountFilter: String? = nil,
        targetField: RuleTargetField,
        matchType: RuleMatchType,
        pattern: String,
        amountMin: Decimal? = nil,
        amountMax: Decimal? = nil,
        transactionTypeFilter: TransactionType? = nil
    ) {
        tier = .simple
        simpleConfig = SimpleRuleConfig(
            accountFilter: accountFilter,
            targetField: targetField,
            matchType: matchType,
            pattern: pattern.lowercased(),
            amountMin: amountMin,
            amountMax: amountMax,
            transactionTypeFilter: transactionTypeFilter
        )
    }
}

// MARK: - Simple Rule Configuration

/// Configuration for Tier 1 (Simple) enhanced rules.
/// Provides powerful filtering while maintaining ease of use.
struct SimpleRuleConfig: Codable, Sendable {

    /// Filter by specific account (IBAN) or nil for all accounts
    var accountFilter: String?

    /// Which field to match against
    var targetField: RuleTargetField

    /// How to perform the match
    var matchType: RuleMatchType

    /// Pattern to match (stored lowercase for performance)
    var pattern: String

    /// Optional amount range filtering (minimum)
    var amountMin: Decimal?

    /// Optional amount range filtering (maximum)
    var amountMax: Decimal?

    /// Filter by transaction type (income/expense/transfer)
    var transactionTypeFilter: TransactionType?

    /// Initialize with pattern automatically lowercased
    init(
        accountFilter: String? = nil,
        targetField: RuleTargetField,
        matchType: RuleMatchType,
        pattern: String,
        amountMin: Decimal? = nil,
        amountMax: Decimal? = nil,
        transactionTypeFilter: TransactionType? = nil
    ) {
        self.accountFilter = accountFilter
        self.targetField = targetField
        self.matchType = matchType
        self.pattern = pattern.lowercased()
        self.amountMin = amountMin
        self.amountMax = amountMax
        self.transactionTypeFilter = transactionTypeFilter
    }
}

// MARK: - Advanced Rule Condition

/// Individual condition in an advanced rule (Tier 2).
/// Multiple conditions can be combined with AND/OR logic.
@Model
final class RuleCondition {

    /// Which field to evaluate
    var field: RuleField

    /// Comparison operator to apply
    var operator: RuleOperator

    /// Value to compare against (serialized as string for flexibility)
    var value: String

    /// How this condition connects to the next one (AND/OR)
    var logicalConnector: LogicalConnector?

    /// Display order in the condition list
    var sortOrder: Int

    /// When this condition was created
    var createdAt: Date

    // MARK: - Relationships

    /// The parent rule this condition belongs to
    @Relationship(deleteRule: .nullify)
    var parentRule: EnhancedCategorizationRule?

    // MARK: - Computed Properties

    /// Human-readable condition description
    var displayText: String {
        let fieldName = field.displayName
        let operatorText = `operator`.displayName
        let displayValue = formatValueForDisplay()

        return "\(fieldName) \(operatorText) \(displayValue)"
    }

    /// Format value for UI display based on field type
    private func formatValueForDisplay() -> String {
        switch field {
        case .amount:
            if let decimal = Decimal(string: value) {
                return "€\(decimal)"
            }
            return value
        case .date:
            if let date = ISO8601DateFormatter().date(from: value) {
                return DateFormatter.mediumDateFormatter.string(from: date)
            }
            return value
        default:
            return "\"\(value)\""
        }
    }

    // MARK: - Initialization

    init(
        field: RuleField,
        operator: RuleOperator,
        value: String,
        logicalConnector: LogicalConnector? = nil,
        sortOrder: Int = 0
    ) {
        self.field = field
        self.operator = `operator`
        self.value = value
        self.logicalConnector = logicalConnector
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    // MARK: - Value Conversion Helpers

    /// Get value as Decimal for amount comparisons
    var decimalValue: Decimal? {
        Decimal(string: value)
    }

    /// Get value as Date for date comparisons
    var dateValue: Date? {
        ISO8601DateFormatter().date(from: value)
    }

    /// Get value as boolean for boolean fields
    var boolValue: Bool {
        value.lowercased() == "true"
    }
}

// MARK: - Enums

/// Rule complexity tier
enum RuleTier: String, Codable, CaseIterable, Sendable {
    case simple = "simple"
    case advanced = "advanced"

    var displayName: String {
        switch self {
        case .simple: return "Simple Rule"
        case .advanced: return "Advanced Rule"
        }
    }

    var icon: String {
        switch self {
        case .simple: return "slider.horizontal.3"
        case .advanced: return "gear.badge"
        }
    }
}

/// Rule complexity level for UI hints
enum RuleComplexity: String, CaseIterable, Sendable {
    case basic = "basic"
    case enhanced = "enhanced"
    case moderate = "moderate"
    case complex = "complex"
    case expert = "expert"

    var displayName: String {
        switch self {
        case .basic: return "Basic"
        case .enhanced: return "Enhanced"
        case .moderate: return "Moderate"
        case .complex: return "Complex"
        case .expert: return "Expert"
        }
    }

    var color: String {
        switch self {
        case .basic: return "green"
        case .enhanced: return "blue"
        case .moderate: return "orange"
        case .complex: return "red"
        case .expert: return "purple"
        }
    }
}

/// Fields available for rule conditions
enum RuleTargetField: String, Codable, CaseIterable, Sendable {
    case description = "description"
    case counterName = "counter_name"
    case counterIBAN = "counter_iban"
    case standardizedName = "standardized_name"
    case anyField = "any_field"

    var displayName: String {
        switch self {
        case .description: return "Description"
        case .counterName: return "Counter Party"
        case .counterIBAN: return "Counter IBAN"
        case .standardizedName: return "Standardized Name"
        case .anyField: return "Any Field"
        }
    }

    var icon: String {
        switch self {
        case .description: return "text.alignleft"
        case .counterName: return "person.fill"
        case .counterIBAN: return "creditcard.fill"
        case .standardizedName: return "tag.fill"
        case .anyField: return "magnifyingglass"
        }
    }
}

/// Advanced rule fields (superset of RuleTargetField)
enum RuleField: String, Codable, CaseIterable, Sendable {
    case amount = "amount"
    case description = "description"
    case counterName = "counter_name"
    case counterIBAN = "counter_iban"
    case account = "account"
    case transactionType = "transaction_type"
    case date = "date"
    case standardizedName = "standardized_name"
    case transactionCode = "transaction_code"

    var displayName: String {
        switch self {
        case .amount: return "Amount"
        case .description: return "Description"
        case .counterName: return "Counter Party"
        case .counterIBAN: return "Counter IBAN"
        case .account: return "Account"
        case .transactionType: return "Transaction Type"
        case .date: return "Date"
        case .standardizedName: return "Standardized Name"
        case .transactionCode: return "Transaction Code"
        }
    }

    var icon: String {
        switch self {
        case .amount: return "eurosign.circle"
        case .description: return "text.alignleft"
        case .counterName: return "person.fill"
        case .counterIBAN: return "creditcard.fill"
        case .account: return "building.columns.fill"
        case .transactionType: return "arrow.up.arrow.down"
        case .date: return "calendar"
        case .standardizedName: return "tag.fill"
        case .transactionCode: return "barcode"
        }
    }

    /// Data type for value validation
    var valueType: RuleValueType {
        switch self {
        case .amount: return .decimal
        case .date: return .date
        case .transactionType: return .enum
        case .account: return .string
        default: return .string
        }
    }
}

/// Rule comparison operators
enum RuleOperator: String, Codable, CaseIterable, Sendable {
    case equals = "equals"
    case contains = "contains"
    case startsWith = "starts_with"
    case endsWith = "ends_with"
    case greaterThan = "greater_than"
    case lessThan = "less_than"
    case between = "between"
    case matches = "regex_matches"
    case notEqual = "not_equal"
    case notContains = "not_contains"

    var displayName: String {
        switch self {
        case .equals: return "equals"
        case .contains: return "contains"
        case .startsWith: return "starts with"
        case .endsWith: return "ends with"
        case .greaterThan: return "is greater than"
        case .lessThan: return "is less than"
        case .between: return "is between"
        case .matches: return "matches pattern"
        case .notEqual: return "does not equal"
        case .notContains: return "does not contain"
        }
    }

    var icon: String {
        switch self {
        case .equals: return "equal"
        case .contains: return "magnifyingglass"
        case .startsWith: return "text.alignleft"
        case .endsWith: return "text.alignright"
        case .greaterThan: return "greaterthan"
        case .lessThan: return "lessthan"
        case .between: return "arrow.left.arrow.right"
        case .matches: return "asterisk"
        case .notEqual: return "equal.slash"
        case .notContains: return "magnifyingglass.slash"
        }
    }

    /// Which operators are valid for which value types
    static func validOperators(for valueType: RuleValueType) -> [RuleOperator] {
        switch valueType {
        case .string:
            return [.equals, .contains, .startsWith, .endsWith, .matches, .notEqual, .notContains]
        case .decimal:
            return [.equals, .greaterThan, .lessThan, .between, .notEqual]
        case .date:
            return [.equals, .greaterThan, .lessThan, .between, .notEqual]
        case .enum:
            return [.equals, .notEqual]
        }
    }
}

/// Logical connectors for combining conditions
enum LogicalConnector: String, Codable, CaseIterable, Sendable {
    case and = "and"
    case or = "or"

    var displayName: String {
        switch self {
        case .and: return "AND"
        case .or: return "OR"
        }
    }

    var icon: String {
        switch self {
        case .and: return "plus"
        case .or: return "questionmark"
        }
    }
}

/// Value types for validation
enum RuleValueType: String, CaseIterable, Sendable {
    case string = "string"
    case decimal = "decimal"
    case date = "date"
    case `enum` = "enum"
}

// MARK: - Extensions

extension DateFormatter {
    static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}