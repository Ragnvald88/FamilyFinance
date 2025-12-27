//
//  SwiftDataModels.swift
//  Family Finance
//
//  Production-grade SwiftData models for Dutch banking CSV import
//  Designed for 15,430+ transactions with optimal query performance
//
//  Version: 2.0 - Full Domain Model (Firefly III parity)
//  Created: 2025-12-22
//  Updated: 2025-12-22 - Added splits, recurring, audit trail
//

import Foundation
@preconcurrency import SwiftData

// MARK: - Transaction Model

/// Core transaction model representing a single bank transaction
/// Optimized for fast querying with strategic indexes
///
/// **IMPORTANT:** Do not modify `date` directly! Use `updateDate(_:)` to keep
/// denormalized year/month fields in sync. Direct modification causes stale indexes.
@Model
final class Transaction {

    // MARK: - Primary Identifiers

    /// Rabobank IBAN
    var iban: String

    /// Sequence number from CSV (Volgnr)
    var sequenceNumber: Int

    /// Transaction date
    /// ⚠️ WARNING: Use `updateDate(_:)` method to modify - never set directly!
    private(set) var date: Date

    /// Unique constraint: IBAN + date (YYYYMMDD) + sequence number
    /// This prevents collisions if bank resets sequence numbers.
    /// Format: "NL00BANK0123456001-20251223-42"
    ///
    /// **Migration Note:** If upgrading from v1.x where uniqueKey was "IBAN-sequence",
    /// run DataIntegrityService.migrateUniqueKeys() on first launch.
    @Attribute(.unique) var uniqueKey: String

    // MARK: - Financial Data

    /// Transaction amount (positive = income, negative = expense)
    var amount: Decimal

    /// Account balance after this transaction
    var balance: Decimal

    // MARK: - Counter Party Information

    /// Counter party IBAN (nullable)
    var counterIBAN: String?

    /// Original counter party name from CSV
    var counterName: String?

    /// Standardized merchant/party name (for merchant analysis)
    var standardizedName: String?

    // MARK: - Description Fields

    /// Description field 1 (Omschrijving-1)
    var description1: String?

    /// Description field 2 (Omschrijving-2)
    var description2: String?

    /// Description field 3 (Omschrijving-3)
    var description3: String?

    /// Combined full description (computed)
    var fullDescription: String {
        [description1, description2, description3]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Rabobank-Specific Fields (Phase 2.1)

    /// Rabobank transaction code (bg, tb, bc, id, ei, cb, db, ba)
    /// - bg: Betaalopdracht (Bank Transfer)
    /// - tb: Telebanking (Internal Transfer)
    /// - bc: Betaalkaart (Debit Card/PIN)
    /// - id: iDEAL (Online Payment)
    /// - ei: Euro Incasso (SEPA Direct Debit - subscriptions)
    /// - cb: Creditering Buitenland (International Incoming)
    /// - db: Debitering (Bank Charges)
    /// - ba: Betalen Automaat (ATM)
    var transactionCode: String?

    /// Value date (Rentedatum) - may differ from transaction date for interest
    var valueDate: Date?

    /// Return reason (Reden retour) - for refunds/chargebacks
    var returnReason: String?

    /// SEPA mandate reference for recurring payment matching
    var mandateReference: String?

    /// Helper: Is this likely a subscription/recurring (based on code)
    var isLikelyRecurring: Bool {
        transactionCode == "ei"  // Euro Incasso = SEPA Direct Debit
    }

    /// Helper: Is this a card/PIN payment
    var isCardPayment: Bool {
        transactionCode == "bc" || transactionCode == "ba"
    }

    /// Helper: Is this an online payment
    var isOnlinePayment: Bool {
        transactionCode == "id"  // iDEAL
    }

    // MARK: - Categorization

    /// Auto-detected category via rules engine
    var autoCategory: String?

    /// Manual category override (takes precedence)
    var categoryOverride: String?

    /// Computed effective category - returns override if set, else auto category, else default
    /// NOTE: Cannot use @Attribute on computed properties in SwiftData
    var effectiveCategory: String {
        if let override = categoryOverride, !override.isEmpty {
            return override
        }
        return autoCategory ?? "Uncategorized"
    }

    /// Stored category for queries (updated when autoCategory or categoryOverride changes)
    /// Use this for queries, use effectiveCategory for display
    var indexedCategory: String

    /// Transaction type for income/expense filtering
    var transactionType: TransactionType

    // MARK: - Inleg (Contribution) Tracking

    /// Detected contributor for family contribution tracking
    var contributor: Contributor?

    // MARK: - Denormalized Date Fields (for query performance)

    /// Year of transaction for efficient predicates
    /// Avoids Calendar.current.component() in queries which causes O(n) scans
    var year: Int

    /// Month of transaction (1-12) for efficient predicates
    var month: Int

    /// Is this an income transaction?
    var isIncome: Bool {
        transactionType == .income
    }

    /// Is this an expense transaction?
    var isExpense: Bool {
        transactionType == .expense
    }

    /// Absolute amount (always positive)
    var absoluteAmount: Decimal {
        abs(amount)
    }

    // MARK: - Relationships

    /// Owning account (with cascade delete)
    @Relationship(deleteRule: .nullify, inverse: \Account.transactions)
    var account: Account?

    /// Split components for multi-category transactions (e.g., grocery receipt with produce + toiletries)
    /// If empty, transaction is unsplit and uses effectiveCategory
    /// NOTE: Cascade deletes splits when transaction is deleted
    @Relationship(deleteRule: .cascade, inverse: \TransactionSplit.parentTransaction)
    var splits: [TransactionSplit]?

    /// Linked recurring transaction (if this is an instance of a recurring pattern)
    @Relationship(deleteRule: .nullify, inverse: \RecurringTransaction.linkedTransactions)
    var recurringTransaction: RecurringTransaction?

    /// Audit log entries for this transaction
    @Relationship(deleteRule: .cascade, inverse: \TransactionAuditLog.transaction)
    var auditLog: [TransactionAuditLog]?

    // MARK: - Split Transaction Support

    /// Returns true if this transaction has been split into multiple categories
    var isSplit: Bool {
        guard let splits = splits else { return false }
        return !splits.isEmpty
    }

    /// Returns split amounts by category, or single category if unsplit
    var categoryBreakdown: [(category: String, amount: Decimal)] {
        if let splits = splits, !splits.isEmpty {
            return splits.map { ($0.category, $0.amount) }
        }
        return [(effectiveCategory, amount)]
    }

    // MARK: - Import Metadata

    /// When this transaction was imported
    var importedAt: Date

    /// Source CSV filename
    var sourceFile: String?

    /// Import batch ID (for bulk operations)
    var importBatchID: UUID?

    // MARK: - Audit Trail

    /// When category override was last modified
    var categoryModifiedAt: Date?

    /// Notes/comments from user
    var notes: String?

    // MARK: - Initialization

    init(
        iban: String,
        sequenceNumber: Int,
        date: Date,
        amount: Decimal,
        balance: Decimal,
        counterIBAN: String? = nil,
        counterName: String? = nil,
        standardizedName: String? = nil,
        description1: String? = nil,
        description2: String? = nil,
        description3: String? = nil,
        transactionCode: String? = nil,
        valueDate: Date? = nil,
        returnReason: String? = nil,
        mandateReference: String? = nil,
        autoCategory: String? = nil,
        categoryOverride: String? = nil,
        transactionType: TransactionType,
        contributor: Contributor? = nil,
        sourceFile: String? = nil,
        importBatchID: UUID? = nil,
        account: Account? = nil
    ) {
        self.iban = iban
        self.sequenceNumber = sequenceNumber
        self.date = date
        // New format: IBAN-YYYYMMDD-sequence (prevents collision if bank resets sequence numbers)
        self.uniqueKey = Transaction.generateUniqueKey(iban: iban, date: date, sequenceNumber: sequenceNumber)
        self.amount = amount
        self.balance = balance
        self.counterIBAN = counterIBAN
        self.counterName = counterName
        self.standardizedName = standardizedName
        self.description1 = description1
        self.description2 = description2
        self.description3 = description3
        self.transactionCode = transactionCode
        self.valueDate = valueDate
        self.returnReason = returnReason
        self.mandateReference = mandateReference
        self.autoCategory = autoCategory
        self.categoryOverride = categoryOverride
        self.transactionType = transactionType
        self.contributor = contributor
        self.importedAt = Date()
        self.sourceFile = sourceFile
        self.importBatchID = importBatchID
        self.account = account

        // Denormalized fields for query performance
        let calendar = Calendar.current
        self.year = calendar.component(.year, from: date)
        self.month = calendar.component(.month, from: date)

        // Indexed category for fast queries
        self.indexedCategory = categoryOverride ?? autoCategory ?? "Uncategorized"
    }

    // MARK: - Update Helpers

    /// Updates category override and syncs the indexed category field.
    /// Also creates an audit log entry for tracking changes.
    func updateCategoryOverride(_ newCategory: String?, reason: String? = nil) {
        let oldCategory = effectiveCategory
        categoryOverride = newCategory
        categoryModifiedAt = Date()
        // Keep indexedCategory in sync for query performance
        indexedCategory = effectiveCategory

        // Create audit log entry (limited to last 50 entries to prevent memory bloat)
        let logEntry = TransactionAuditLog(
            action: .categoryChange,
            previousValue: oldCategory,
            newValue: effectiveCategory,
            reason: reason
        )
        if auditLog == nil {
            auditLog = []
        }
        auditLog?.append(logEntry)

        // Cap audit log at 50 entries (FIFO - keep most recent)
        let maxAuditLogSize = 50
        if let count = auditLog?.count, count > maxAuditLogSize {
            auditLog?.removeFirst(count - maxAuditLogSize)
        }
    }

    /// Safely updates the transaction date and syncs denormalized year/month fields.
    /// ALWAYS use this method instead of setting `date` directly to prevent stale data.
    func updateDate(_ newDate: Date) {
        date = newDate
        // Keep denormalized fields in sync
        let calendar = Calendar.current
        year = calendar.component(.year, from: newDate)
        month = calendar.component(.month, from: newDate)
    }

    /// Recalculates denormalized fields from current date.
    /// Use this if date was somehow modified directly (recovery method).
    func syncDenormalizedFields() {
        let calendar = Calendar.current
        year = calendar.component(.year, from: date)
        month = calendar.component(.month, from: date)
        indexedCategory = effectiveCategory
    }

    // MARK: - Static Helpers

    /// Generates a unique key for duplicate detection.
    /// Format: "IBAN-YYYYMMDD-sequence" (e.g., "NL00BANK0123456001-20251223-42")
    static func generateUniqueKey(iban: String, date: Date, sequenceNumber: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let dateStr = dateFormatter.string(from: date)
        return "\(iban)-\(dateStr)-\(sequenceNumber)"
    }

    /// Legacy unique key format (v1.x compatibility)
    static func generateLegacyUniqueKey(iban: String, sequenceNumber: Int) -> String {
        return "\(iban)-\(sequenceNumber)"
    }

    // MARK: - Split Management

    /// Creates a split for this transaction. Validates that split amounts sum to transaction amount.
    /// - Parameter components: Array of (category, amount) tuples
    /// - Throws: `SplitError` if amounts don't sum correctly (within ±0.01 tolerance for rounding)
    func createSplit(_ components: [(category: String, amount: Decimal)]) throws {
        // Validate sum matches transaction amount (with tolerance for decimal rounding)
        let sum = components.reduce(Decimal.zero) { $0 + $1.amount }
        // Safe Decimal literal: 0.01 = 1 * 10^-2
        let tolerance = Decimal(sign: .plus, exponent: -2, significand: 1)
        let difference = abs(sum - amount)
        guard difference <= tolerance else {
            throw SplitError.amountMismatch(expected: amount, actual: sum)
        }

        // Clear existing splits - SwiftData handles cascade deletion automatically
        splits = []

        // Create new splits
        for (index, component) in components.enumerated() {
            let split = TransactionSplit(
                category: component.category,
                amount: component.amount,
                sortOrder: index
            )
            splits?.append(split)
        }

        // Log the split action
        let logEntry = TransactionAuditLog(
            action: .split,
            previousValue: effectiveCategory,
            newValue: "Split into \(components.count) categories",
            reason: nil
        )
        if auditLog == nil {
            auditLog = []
        }
        auditLog?.append(logEntry)
    }

    /// Removes all splits and returns to single-category transaction
    func removeSplits() {
        splits = []
    }
}

/// Errors that can occur during transaction split operations
enum SplitError: Error, LocalizedError {
    case amountMismatch(expected: Decimal, actual: Decimal)

    var errorDescription: String? {
        switch self {
        case .amountMismatch(let expected, let actual):
            return "Split amounts (\(actual)) must equal transaction amount (\(expected))"
        }
    }
}

// MARK: - Account Model

/// Bank account model with transaction relationships
@Model
final class Account {

    /// IBAN (unique identifier)
    @Attribute(.unique) var iban: String

    /// Display name
    var name: String

    /// Account type
    var accountType: AccountType

    /// Owner (Gezin, Partner1, Partner2)
    var owner: String

    /// Is account currently active?
    var isActive: Bool

    /// Display color (hex code)
    var color: String?

    /// Sort order for UI display
    var sortOrder: Int

    /// Cached current balance (updated by import process)
    /// Avoids O(n log n) sort on every access
    var cachedBalance: Decimal

    /// Date when cachedBalance was last updated
    var balanceUpdatedAt: Date?

    // MARK: - Relationships

    /// All transactions for this account
    @Relationship(deleteRule: .cascade)
    var transactions: [Transaction]?

    // MARK: - Computed Properties

    /// Current balance - uses cached value for performance.
    /// Call refreshBalance() if you need to recalculate from transactions.
    var currentBalance: Decimal {
        cachedBalance
    }

    /// Recalculates balance from transactions (O(n log n) - use sparingly)
    /// Call this after imports or when cache might be stale
    func refreshBalance() {
        guard let transactions = transactions,
              !transactions.isEmpty else {
            cachedBalance = 0
            balanceUpdatedAt = Date()
            return
        }

        // Find transaction with latest date
        let sorted = transactions.sorted { $0.date > $1.date }
        cachedBalance = sorted.first?.balance ?? 0
        balanceUpdatedAt = Date()
    }

    /// Total number of transactions
    var transactionCount: Int {
        transactions?.count ?? 0
    }

    /// Date of first transaction
    var firstTransactionDate: Date? {
        transactions?.map { $0.date }.min()
    }

    /// Date of last transaction
    var lastTransactionDate: Date? {
        transactions?.map { $0.date }.max()
    }

    // MARK: - Initialization

    init(
        iban: String,
        name: String,
        accountType: AccountType,
        owner: String,
        isActive: Bool = true,
        color: String? = nil,
        sortOrder: Int = 0,
        cachedBalance: Decimal = 0
    ) {
        self.iban = iban
        self.name = name
        self.accountType = accountType
        self.owner = owner
        self.isActive = isActive
        self.color = color
        self.sortOrder = sortOrder
        self.cachedBalance = cachedBalance
        self.balanceUpdatedAt = nil
    }
}

// MARK: - Category Model

/// Category for transaction classification with budget
@Model
final class Category {

    /// Category name (unique)
    @Attribute(.unique) var name: String

    /// Type (income or expense)
    var type: TransactionType

    /// Monthly budget amount
    var monthlyBudget: Decimal

    /// Yearly budget amount (optional)
    var yearlyBudget: Decimal?

    /// Display icon (SF Symbol name)
    var icon: String?

    /// Display color (hex code)
    var color: String?

    /// Sort order
    var sortOrder: Int

    /// Is category active/visible?
    var isActive: Bool

    /// Parent category (for subcategories)
    var parentCategory: String?

    /// Category description/notes
    var notes: String?

    // MARK: - Initialization

    init(
        name: String,
        type: TransactionType,
        monthlyBudget: Decimal = 0,
        yearlyBudget: Decimal? = nil,
        icon: String? = nil,
        color: String? = nil,
        sortOrder: Int = 0,
        isActive: Bool = true,
        parentCategory: String? = nil,
        notes: String? = nil
    ) {
        self.name = name
        self.type = type
        self.monthlyBudget = monthlyBudget
        self.yearlyBudget = yearlyBudget
        self.icon = icon
        self.color = color
        self.sortOrder = sortOrder
        self.isActive = isActive
        self.parentCategory = parentCategory
        self.notes = notes
    }
}

// MARK: - Categorization Rule Model

/// Modern unified categorization rule with flexible conditions
@Model
final class CategorizationRule {
    // MARK: - Core Identity

    /// User-friendly rule name for management
    var name: String

    /// Target category to assign when rule matches
    var targetCategory: String

    /// Rule priority (lower = higher priority)
    var priority: Int

    /// Is rule currently active?
    var isActive: Bool

    /// Optional description/notes for this rule
    var notes: String?

    // MARK: - Rule Configuration

    /// All conditions for this rule
    @Relationship(deleteRule: .cascade) var conditions: [RuleCondition]

    /// How multiple conditions are combined (AND/OR)
    var logicalOperator: LogicalOperator

    /// Standardized counter party name (for backward compatibility)
    var standardizedName: String?

    // MARK: - Statistics

    /// Number of times this rule has matched
    var matchCount: Int

    /// Last time rule matched
    var lastMatchedAt: Date?

    /// Created date
    var createdAt: Date

    /// Last modified date
    var modifiedAt: Date

    // MARK: - Initialization

    init(
        name: String,
        targetCategory: String,
        conditions: [RuleCondition] = [],
        logicalOperator: LogicalOperator = .and,
        priority: Int = 100,
        isActive: Bool = true,
        notes: String? = nil,
        standardizedName: String? = nil
    ) {
        self.name = name
        self.targetCategory = targetCategory
        self.conditions = conditions
        self.logicalOperator = logicalOperator
        self.priority = priority
        self.isActive = isActive
        self.notes = notes
        self.standardizedName = standardizedName
        self.matchCount = 0
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    // MARK: - Rule Properties

    /// True if this is a simple rule (single condition)
    var isSimple: Bool {
        conditions.count <= 1
    }

    /// True if this is an advanced rule (multiple conditions)
    var isAdvanced: Bool {
        conditions.count > 1
    }

    /// Human-readable summary of this rule
    var displaySummary: String {
        guard !conditions.isEmpty else { return "No conditions" }

        if conditions.count == 1 {
            return conditions[0].displayText
        } else {
            let connector = logicalOperator.displayName.uppercased()
            return "\(conditions.count) conditions (\(connector))"
        }
    }

    /// Record a successful match
    func recordMatch() {
        matchCount += 1
        lastMatchedAt = Date()
        modifiedAt = Date()
    }

    // MARK: - Legacy Compatibility Properties

    /// Computed pattern from first text-based condition for UI compatibility
    /// Falls back to rule name if no suitable condition exists
    var pattern: String {
        // Find first text-based condition (description, counterParty, etc.)
        guard let textCondition = conditions.first(where: { condition in
            switch condition.field {
            case .description, .counterParty, .counterIBAN, .account:
                return true
            case .amount, .date, .transactionType, .transactionCode:
                return false
            }
        }) else {
            // Fallback to rule name if no text conditions
            return name
        }

        return textCondition.value
    }

    /// Computed match type from first condition's operator
    /// Falls back to .contains if no conditions exist
    var matchType: RuleMatchType {
        guard let firstCondition = conditions.first else {
            return .contains
        }

        return firstCondition.operatorType.toRuleMatchType()
    }
}

// MARK: - Rule Condition Model

/// Individual condition within a categorization rule
@Model
final class RuleCondition {
    /// What field to check (description, amount, etc.)
    var field: ConditionField

    /// How to compare the field value
    var operatorType: ConditionOperator

    /// Value to compare against
    var value: String

    /// Order for display and evaluation
    var sortOrder: Int

    /// Parent rule relationship
    var parentRule: CategorizationRule?

    /// Creation timestamp
    var createdAt: Date

    init(
        field: ConditionField,
        operatorType: ConditionOperator,
        value: String,
        sortOrder: Int = 0
    ) {
        self.field = field
        self.operatorType = operatorType
        self.value = value
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    /// Human-readable display of this condition
    var displayText: String {
        "\(field.displayName) \(operatorType.displayName) \(value)"
    }
}

// MARK: - Rule System Enums

/// Fields that can be checked in rule conditions
enum ConditionField: String, CaseIterable, Codable, Sendable {
    case description = "description"
    case counterParty = "counterParty"
    case counterIBAN = "counterIBAN"
    case amount = "amount"
    case account = "account"
    case transactionType = "transactionType"
    case date = "date"
    case transactionCode = "transactionCode"

    var displayName: String {
        switch self {
        case .description: return "Description"
        case .counterParty: return "Counter Party"
        case .counterIBAN: return "Counter IBAN"
        case .amount: return "Amount"
        case .account: return "Account"
        case .transactionType: return "Transaction Type"
        case .date: return "Date"
        case .transactionCode: return "Transaction Code"
        }
    }

    var isNumeric: Bool {
        switch self {
        case .amount: return true
        default: return false
        }
    }
}

/// Operators for comparing field values
enum ConditionOperator: String, CaseIterable, Codable, Sendable {
    case contains = "contains"
    case equals = "equals"
    case startsWith = "startsWith"
    case endsWith = "endsWith"
    case greaterThan = "greaterThan"
    case lessThan = "lessThan"
    case between = "between"
    case matches = "matches" // regex

    var displayName: String {
        switch self {
        case .contains: return "contains"
        case .equals: return "equals"
        case .startsWith: return "starts with"
        case .endsWith: return "ends with"
        case .greaterThan: return "greater than"
        case .lessThan: return "less than"
        case .between: return "between"
        case .matches: return "matches pattern"
        }
    }

    /// Valid operators for the given field
    static func validOperators(for field: ConditionField) -> [ConditionOperator] {
        switch field {
        case .amount:
            return [.equals, .greaterThan, .lessThan, .between]
        case .description, .counterParty, .counterIBAN, .transactionCode:
            return [.contains, .equals, .startsWith, .endsWith, .matches]
        case .account:
            return [.equals, .contains]
        case .transactionType:
            return [.equals]
        case .date:
            return [.equals, .greaterThan, .lessThan, .between]
        }
    }
}

// MARK: - ConditionOperator Extensions

extension ConditionOperator {
    /// Map ConditionOperator to RuleMatchType for legacy UI compatibility
    func toRuleMatchType() -> RuleMatchType {
        switch self {
        case .contains:
            return .contains
        case .equals:
            return .exact
        case .startsWith:
            return .startsWith
        case .endsWith:
            return .endsWith
        case .matches:
            return .regex
        case .greaterThan, .lessThan, .between:
            // Numeric operators fallback to contains for text-based UI
            return .contains
        }
    }
}

/// How multiple conditions are combined
enum LogicalOperator: String, CaseIterable, Codable, Sendable {
    case and = "AND"
    case or = "OR"

    var displayName: String {
        switch self {
        case .and: return "AND"
        case .or: return "OR"
        }
    }

    var description: String {
        switch self {
        case .and: return "All conditions must match"
        case .or: return "Any condition must match"
        }
    }
}

// MARK: - Liability Model

/// Debt/liability for net worth calculation
@Model
final class Liability {

    /// Liability name
    var name: String

    /// Type of liability
    var type: LiabilityType

    /// Current outstanding amount
    var amount: Decimal

    /// Original borrowed amount
    var originalAmount: Decimal?

    /// Interest rate (percentage)
    var interestRate: Decimal?

    /// Start date
    var startDate: Date

    /// Expected end date
    var endDate: Date?

    /// Monthly payment amount
    var monthlyPayment: Decimal?

    /// Creditor/lender name
    var creditor: String?

    /// Notes
    var notes: String?

    /// Is active?
    var isActive: Bool

    /// Created date
    var createdAt: Date

    /// Last modified date
    var modifiedAt: Date

    // MARK: - Computed Properties

    /// Amount paid off so far
    var amountPaid: Decimal {
        guard let original = originalAmount else { return 0 }
        return original - amount
    }

    /// Percentage paid off
    var percentagePaid: Double {
        guard let original = originalAmount,
              original > 0 else { return 0 }
        return Double(truncating: amountPaid as NSNumber) / Double(truncating: original as NSNumber) * 100
    }

    // MARK: - Initialization

    init(
        name: String,
        type: LiabilityType,
        amount: Decimal,
        originalAmount: Decimal? = nil,
        interestRate: Decimal? = nil,
        startDate: Date,
        endDate: Date? = nil,
        monthlyPayment: Decimal? = nil,
        creditor: String? = nil,
        notes: String? = nil,
        isActive: Bool = true
    ) {
        self.name = name
        self.type = type
        self.amount = amount
        self.originalAmount = originalAmount
        self.interestRate = interestRate
        self.startDate = startDate
        self.endDate = endDate
        self.monthlyPayment = monthlyPayment
        self.creditor = creditor
        self.notes = notes
        self.isActive = isActive
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

// MARK: - Merchant Model

/// Merchant/counter party statistics for analysis
@Model
final class Merchant {

    /// Merchant name (unique)
    @Attribute(.unique) var name: String

    /// Standardized display name
    var standardizedName: String

    /// Primary category
    var primaryCategory: String?

    /// Total amount spent
    var totalSpent: Decimal

    /// Number of transactions
    var transactionCount: Int

    /// Date of first transaction
    var firstTransactionDate: Date?

    /// Date of last transaction
    var lastTransactionDate: Date?

    /// Merchant logo URL (optional)
    var logoURL: String?

    /// Notes
    var notes: String?

    // MARK: - Computed Properties

    /// Average transaction amount
    var averageTransaction: Decimal {
        guard transactionCount > 0 else { return 0 }
        return totalSpent / Decimal(transactionCount)
    }

    // MARK: - Initialization

    init(
        name: String,
        standardizedName: String? = nil,
        primaryCategory: String? = nil
    ) {
        self.name = name
        self.standardizedName = standardizedName ?? name
        self.primaryCategory = primaryCategory
        self.totalSpent = 0
        self.transactionCount = 0
    }

    // MARK: - Update Methods

    /// Add a transaction to merchant statistics
    func addTransaction(amount: Decimal, date: Date, category: String?) {
        totalSpent += amount
        transactionCount += 1

        // Update date range
        if firstTransactionDate == nil || date < firstTransactionDate! {
            firstTransactionDate = date
        }
        if lastTransactionDate == nil || date > lastTransactionDate! {
            lastTransactionDate = date
        }

        // Update primary category if not set
        if primaryCategory == nil, let category = category {
            primaryCategory = category
        }
    }
}

// MARK: - Budget Period Model

/// Budget for a specific period and category
@Model
final class BudgetPeriod {

    /// Year
    var year: Int

    /// Month (1-12, or 0 for yearly)
    var month: Int

    /// Category name
    var category: String

    /// Budgeted amount
    var budgetAmount: Decimal

    /// Notes
    var notes: String?

    /// Created date
    var createdAt: Date

    /// Modified date
    var modifiedAt: Date

    // MARK: - Computed Properties

    /// Period identifier (e.g., "2025-03" or "2025")
    var periodKey: String {
        if month > 0 {
            return String(format: "%04d-%02d", year, month)
        } else {
            return String(format: "%04d", year)
        }
    }

    /// Is this a yearly budget?
    var isYearly: Bool {
        month == 0
    }

    // MARK: - Initialization

    init(
        year: Int,
        month: Int = 0,
        category: String,
        budgetAmount: Decimal,
        notes: String? = nil
    ) {
        self.year = year
        self.month = month
        self.category = category
        self.budgetAmount = budgetAmount
        self.notes = notes
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

// MARK: - Transaction Split Model

/// Represents one category portion of a split transaction.
/// Example: A €45 grocery receipt split into €20 produce + €15 toiletries + €10 pet food.
@Model
final class TransactionSplit {

    /// The category this split portion belongs to
    var category: String

    /// The amount allocated to this category (should be negative for expenses)
    var amount: Decimal

    /// Optional notes for this split portion
    var notes: String?

    /// Sort order for display
    var sortOrder: Int

    /// When this split was created
    var createdAt: Date

    // MARK: - Relationships

    /// The parent transaction this split belongs to
    @Relationship(deleteRule: .nullify)
    var parentTransaction: Transaction?

    // MARK: - Computed Properties

    /// Absolute amount (always positive)
    var absoluteAmount: Decimal {
        abs(amount)
    }

    /// Percentage of parent transaction (0-100)
    var percentageOfParent: Double {
        guard let parent = parentTransaction, parent.amount != 0 else { return 0 }
        return Double(truncating: (amount / parent.amount * 100) as NSNumber)
    }

    // MARK: - Initialization

    init(
        category: String,
        amount: Decimal,
        notes: String? = nil,
        sortOrder: Int = 0
    ) {
        self.category = category
        self.amount = amount
        self.notes = notes
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

// MARK: - Recurring Transaction Model

/// Represents a recurring transaction pattern (subscription, salary, regular bill).
/// Links to actual bank transactions when they occur.
@Model
final class RecurringTransaction {

    /// Display name for this recurring transaction
    var name: String

    /// Expected category
    var category: String

    /// Expected amount (positive for income, negative for expenses)
    var expectedAmount: Decimal

    /// How often this recurs
    var frequency: RecurrenceFrequency

    /// Day of month/week when expected (1-31 for monthly, 1-7 for weekly)
    var expectedDay: Int?

    /// Next expected date
    var nextDueDate: Date

    /// Is this recurring transaction still active?
    var isActive: Bool

    /// Counter party name pattern (for auto-matching)
    var counterNamePattern: String?

    /// Counter IBAN (for auto-matching)
    var counterIBAN: String?

    /// Notes
    var notes: String?

    /// When this was created
    var createdAt: Date

    /// Last modified
    var modifiedAt: Date

    // MARK: - Relationships

    /// Actual transactions linked to this recurring pattern
    @Relationship(deleteRule: .nullify)
    var linkedTransactions: [Transaction]?

    // MARK: - Computed Properties

    /// Number of times this has occurred
    var occurrenceCount: Int {
        linkedTransactions?.count ?? 0
    }

    /// Last actual occurrence date
    var lastOccurrence: Date? {
        linkedTransactions?.compactMap { $0.date }.max()
    }

    /// Average actual amount (may differ from expected)
    var averageActualAmount: Decimal {
        guard let transactions = linkedTransactions, !transactions.isEmpty else {
            return expectedAmount
        }
        let sum = transactions.reduce(Decimal.zero) { $0 + $1.amount }
        return sum / Decimal(transactions.count)
    }

    /// Is this transaction overdue?
    var isOverdue: Bool {
        nextDueDate < Date() && isActive
    }

    /// Days until next occurrence
    var daysUntilDue: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: nextDueDate)
        return components.day ?? 0
    }

    // MARK: - Initialization

    init(
        name: String,
        category: String,
        expectedAmount: Decimal,
        frequency: RecurrenceFrequency,
        expectedDay: Int? = nil,
        nextDueDate: Date,
        isActive: Bool = true,
        counterNamePattern: String? = nil,
        counterIBAN: String? = nil,
        notes: String? = nil
    ) {
        self.name = name
        self.category = category
        self.expectedAmount = expectedAmount
        self.frequency = frequency
        self.expectedDay = expectedDay
        self.nextDueDate = nextDueDate
        self.isActive = isActive
        self.counterNamePattern = counterNamePattern
        self.counterIBAN = counterIBAN
        self.notes = notes
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    // MARK: - Methods

    /// Advances the next due date by one period
    func advanceNextDueDate() {
        let calendar = Calendar.current
        switch frequency {
        case .daily:
            nextDueDate = calendar.date(byAdding: .day, value: 1, to: nextDueDate) ?? nextDueDate
        case .weekly:
            nextDueDate = calendar.date(byAdding: .weekOfYear, value: 1, to: nextDueDate) ?? nextDueDate
        case .biweekly:
            nextDueDate = calendar.date(byAdding: .weekOfYear, value: 2, to: nextDueDate) ?? nextDueDate
        case .monthly:
            nextDueDate = calendar.date(byAdding: .month, value: 1, to: nextDueDate) ?? nextDueDate
        case .quarterly:
            nextDueDate = calendar.date(byAdding: .month, value: 3, to: nextDueDate) ?? nextDueDate
        case .yearly:
            nextDueDate = calendar.date(byAdding: .year, value: 1, to: nextDueDate) ?? nextDueDate
        }
        modifiedAt = Date()
    }

    /// Links a transaction to this recurring pattern
    func linkTransaction(_ transaction: Transaction) {
        if linkedTransactions == nil {
            linkedTransactions = []
        }
        linkedTransactions?.append(transaction)
        transaction.recurringTransaction = self
        modifiedAt = Date()
    }
}

// MARK: - Transaction Audit Log Model

/// Audit trail for transaction changes. Enables undo and tracks who changed what.
@Model
final class TransactionAuditLog {

    /// Type of action performed
    var action: AuditAction

    /// Previous value before the change
    var previousValue: String?

    /// New value after the change
    var newValue: String

    /// Optional reason/explanation for the change
    var reason: String?

    /// When this change was made
    var changedAt: Date

    /// Who made this change (for multi-user future support)
    var changedBy: String?

    // MARK: - Relationships

    /// The transaction this audit entry belongs to
    @Relationship(deleteRule: .nullify)
    var transaction: Transaction?

    // MARK: - Initialization

    init(
        action: AuditAction,
        previousValue: String? = nil,
        newValue: String,
        reason: String? = nil,
        changedBy: String? = nil
    ) {
        self.action = action
        self.previousValue = previousValue
        self.newValue = newValue
        self.reason = reason
        self.changedAt = Date()
        self.changedBy = changedBy
    }
}

// MARK: - Enums (All Sendable for Swift 6 strict concurrency)

/// Transaction type classification
enum TransactionType: String, Codable, CaseIterable, Sendable {
    case income = "Inkomen"
    case expense = "Uitgave"
    case transfer = "Overboeking"
    case unknown = "Onbekend"

    var displayName: String {
        switch self {
        case .income: return "Income"
        case .expense: return "Expense"
        case .transfer: return "Transfer"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

/// Account type classification
enum AccountType: String, Codable, CaseIterable, Sendable {
    case checking = "Betaalrekening"
    case savings = "Spaarrekening"
    case creditCard = "Creditcard"
    case investment = "Beleggingsrekening"

    var displayName: String {
        switch self {
        case .checking: return "Checking Account"
        case .savings: return "Savings Account"
        case .creditCard: return "Credit Card"
        case .investment: return "Investment Account"
        }
    }

    var icon: String {
        switch self {
        case .checking: return "creditcard.fill"
        case .savings: return "banknote.fill"
        case .creditCard: return "creditcard.and.123"
        case .investment: return "chart.line.uptrend.xyaxis"
        }
    }
}

/// Family member contributor for tracking contributions to joint account.
/// Customize display names as needed for your family.
enum Contributor: String, Codable, CaseIterable, Sendable {
    case partner1 = "Partner 1"
    case partner2 = "Partner 2"

    var displayName: String { rawValue }
}

/// Rule matching type
enum RuleMatchType: String, Codable, CaseIterable, Sendable {
    case contains
    case startsWith
    case endsWith
    case exact
    case regex

    var displayName: String {
        switch self {
        case .contains: return "Contains"
        case .startsWith: return "Starts With"
        case .endsWith: return "Ends With"
        case .exact: return "Exact Match"
        case .regex: return "Regular Expression"
        }
    }
}

// MARK: - RuleMatchType Extensions

extension RuleMatchType {
    /// Map RuleMatchType back to ConditionOperator for creating conditions
    func toConditionOperator() -> ConditionOperator {
        switch self {
        case .contains:
            return .contains
        case .exact:
            return .equals
        case .startsWith:
            return .startsWith
        case .endsWith:
            return .endsWith
        case .regex:
            return .matches
        }
    }
}

/// Liability type classification
enum LiabilityType: String, Codable, CaseIterable, Sendable {
    case mortgage = "Hypotheek"
    case studentLoan = "Studielening"
    case creditCard = "Creditcard"
    case personalLoan = "Persoonlijke Lening"
    case carLoan = "Autolening"
    case other = "Overig"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .mortgage: return "house.fill"
        case .studentLoan: return "graduationcap.fill"
        case .creditCard: return "creditcard.fill"
        case .personalLoan: return "person.fill"
        case .carLoan: return "car.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

/// Recurrence frequency for recurring transactions
enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable {
    case daily = "Dagelijks"
    case weekly = "Wekelijks"
    case biweekly = "Tweewekelijks"
    case monthly = "Maandelijks"
    case quarterly = "Driemaandelijks"
    case yearly = "Jaarlijks"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar.badge.clock"
        case .biweekly: return "calendar.badge.plus"
        case .monthly: return "calendar"
        case .quarterly: return "calendar.badge.exclamationmark"
        case .yearly: return "calendar.circle.fill"
        }
    }

    /// Number of days between occurrences (approximate)
    var approximateDays: Int {
        switch self {
        case .daily: return 1
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        case .quarterly: return 91
        case .yearly: return 365
        }
    }
}

/// Audit action types for transaction history tracking
enum AuditAction: String, Codable, CaseIterable, Sendable {
    case categoryChange = "category_change"
    case split = "split"
    case unsplit = "unsplit"
    case noteAdded = "note_added"
    case dateCorrection = "date_correction"
    case amountCorrection = "amount_correction"
    case linkedToRecurring = "linked_to_recurring"
    case manualReview = "manual_review"

    var displayName: String {
        switch self {
        case .categoryChange: return "Categorie gewijzigd"
        case .split: return "Transactie gesplitst"
        case .unsplit: return "Splitsing verwijderd"
        case .noteAdded: return "Notitie toegevoegd"
        case .dateCorrection: return "Datum gecorrigeerd"
        case .amountCorrection: return "Bedrag gecorrigeerd"
        case .linkedToRecurring: return "Gekoppeld aan terugkerend"
        case .manualReview: return "Handmatig beoordeeld"
        }
    }

    var icon: String {
        switch self {
        case .categoryChange: return "square.grid.2x2"
        case .split: return "divide"
        case .unsplit: return "arrow.triangle.merge"
        case .noteAdded: return "note.text"
        case .dateCorrection: return "calendar.badge.clock"
        case .amountCorrection: return "eurosign.circle"
        case .linkedToRecurring: return "repeat"
        case .manualReview: return "checkmark.circle"
        }
    }
}

// MARK: - Transaction Extensions for Rules System

// Required for objc_getAssociatedObject
import ObjectiveC

extension Transaction {
    /// Cached full description combining all description fields
    var cachedFullDescription: String {
        // Use objc associated objects for caching
        let cacheKey = "cachedFullDescription"
        if let cached = objc_getAssociatedObject(self, cacheKey) as? String {
            return cached
        }

        // Compute full description
        let components = [
            description1,
            description2,
            description3,
            notes
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
         .filter { !$0.isEmpty }

        let fullDescription = components.joined(separator: " ")

        // Cache the result
        objc_setAssociatedObject(self, cacheKey, fullDescription, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        return fullDescription
    }
}
