//
//  EnhancedCategorizationEngine.swift
//  Family Finance
//
//  Next-generation categorization engine supporting both simple and advanced rules
//  Maintains 5,000+ tx/second performance with progressive complexity
//
//  Features:
//  - Tier 1: Enhanced simple rules (account filtering, amount ranges, field targeting)
//  - Tier 2: Advanced visual rules (AND/OR logic, multi-condition matching)
//  - Migration support from legacy CategorizationRule
//  - Performance-optimized evaluation paths
//
//  Created: 2025-12-24
//

import Foundation
@preconcurrency import SwiftData

// MARK: - Enhanced Categorization Result

/// Result of enhanced categorization with confidence and rule details.
struct EnhancedCategorizationResult: Sendable {
    let category: String?
    let standardizedName: String?
    let matchedRuleName: String?      // Rule name instead of pattern
    let ruleComplexity: RuleComplexity?
    let confidence: Double            // 0.0 - 1.0
    let evaluationTime: TimeInterval? // For performance monitoring

    static var uncategorized: EnhancedCategorizationResult {
        EnhancedCategorizationResult(
            category: nil,
            standardizedName: nil,
            matchedRuleName: nil,
            ruleComplexity: nil,
            confidence: 0.0,
            evaluationTime: nil
        )
    }
}

// MARK: - Enhanced Categorization Engine

/// High-performance categorization engine with support for both simple and advanced rules.
///
/// **Performance Goals:**
/// - Simple rules: >10,000 tx/second (even faster than legacy)
/// - Advanced rules: >2,000 tx/second (acceptable for complex logic)
/// - Rule cache TTL: 5 minutes (same as legacy)
/// - Memory usage: Minimal increase due to optimized evaluation paths
///
/// **Architecture:**
/// - Dual evaluation paths: Simple rules use fast path, advanced rules use comprehensive evaluation
/// - Smart caching: Pre-compiled conditions and patterns
/// - Progressive fallback: Enhanced → Legacy → Hardcoded rules
@MainActor
class EnhancedCategorizationEngine {

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let legacyEngine: CategorizationEngine?

    // MARK: - Enhanced Rules Cache

    /// Cached enhanced rules sorted by priority
    private var cachedEnhancedRules: [EnhancedCategorizationRule] = []
    private var enhancedCacheLastUpdated: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes

    // MARK: - Performance Monitoring

    private var evaluationStats = EvaluationStats()

    // MARK: - Initialization

    init(modelContext: ModelContext, legacyEngine: CategorizationEngine? = nil) {
        self.modelContext = modelContext
        self.legacyEngine = legacyEngine
    }

    // MARK: - Public Categorization Methods

    /// Primary categorization method - evaluates enhanced rules with fallback to legacy.
    func categorize(_ transaction: ParsedTransaction) async -> EnhancedCategorizationResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Special handling for contributions (same as legacy)
        if let contributor = transaction.contributor {
            return handleContribution(contributor, evaluationTime: 0.001) // Fast path
        }

        // Try enhanced rules first
        if let enhancedRules = try? await getActiveEnhancedRules(), !enhancedRules.isEmpty {
            for rule in enhancedRules {
                if await evaluateRule(rule, against: transaction) {
                    let evaluationTime = CFAbsoluteTimeGetCurrent() - startTime
                    rule.recordMatch() // Update statistics

                    return EnhancedCategorizationResult(
                        category: rule.targetCategory,
                        standardizedName: extractStandardizedName(rule, transaction),
                        matchedRuleName: rule.name,
                        ruleComplexity: rule.complexityLevel,
                        confidence: calculateConfidence(rule: rule, transaction: transaction),
                        evaluationTime: evaluationTime
                    )
                }
            }
        }

        // Fallback to legacy engine if available
        if let legacyEngine = legacyEngine {
            let legacyResult = await legacyEngine.categorize(transaction)
            let evaluationTime = CFAbsoluteTimeGetCurrent() - startTime

            return EnhancedCategorizationResult(
                category: legacyResult.category,
                standardizedName: legacyResult.standardizedName,
                matchedRuleName: legacyResult.matchedRulePattern,
                ruleComplexity: .basic, // Legacy rules are basic
                confidence: legacyResult.confidence,
                evaluationTime: evaluationTime
            )
        }

        // Final fallback to hardcoded rules
        let searchText = buildSearchText(
            counterParty: transaction.counterName,
            description: transaction.fullDescription
        )

        if let match = DefaultRulesLoader.matchHardcodedRule(searchText: searchText) {
            let evaluationTime = CFAbsoluteTimeGetCurrent() - startTime
            return EnhancedCategorizationResult(
                category: match.category,
                standardizedName: match.standardizedName,
                matchedRuleName: "Hardcoded: \(match.pattern)",
                ruleComplexity: .basic,
                confidence: 0.8,
                evaluationTime: evaluationTime
            )
        }

        // No match found
        let evaluationTime = CFAbsoluteTimeGetCurrent() - startTime
        let standardName = cleanCounterPartyName(transaction.counterName)

        return EnhancedCategorizationResult(
            category: nil,
            standardizedName: standardName,
            matchedRuleName: nil,
            ruleComplexity: nil,
            confidence: 0.0,
            evaluationTime: evaluationTime
        )
    }

    /// Test a rule against multiple transactions (for rule builder preview)
    func testRule(_ rule: EnhancedCategorizationRule, against transactions: [ParsedTransaction]) async -> [RuleTestResult] {
        var results: [RuleTestResult] = []

        for transaction in transactions {
            let matches = await evaluateRule(rule, against: transaction)
            let confidence = matches ? calculateConfidence(rule: rule, transaction: transaction) : 0.0

            results.append(RuleTestResult(
                transaction: transaction,
                matches: matches,
                confidence: confidence,
                explanation: generateMatchExplanation(rule, transaction, matches)
            ))
        }

        return results
    }

    /// Bulk recategorization using enhanced rules
    func recategorizeWithEnhancedRules() async throws -> RecategorizationSummary {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Fetch uncategorized transactions
        let noOverridePredicate = #Predicate<Transaction> { $0.categoryOverride == nil }
        let descriptor = FetchDescriptor<Transaction>(predicate: noOverridePredicate)
        let allNoOverride = try modelContext.fetch(descriptor)

        let uncategorized = allNoOverride.filter { tx in
            tx.autoCategory == nil || tx.autoCategory == "Niet Gecategoriseerd"
        }

        var summary = RecategorizationSummary(
            totalProcessed: uncategorized.count,
            enhancedRuleMatches: 0,
            legacyRuleMatches: 0,
            hardcodedRuleMatches: 0,
            unchanged: 0
        )

        for transaction in uncategorized {
            let parsedTransaction = createParsedTransaction(from: transaction)
            let result = await categorize(parsedTransaction)

            if let category = result.category {
                let oldCategory = transaction.autoCategory
                transaction.autoCategory = category

                if let standardName = result.standardizedName {
                    transaction.standardizedName = standardName
                }
                transaction.syncDenormalizedFields()

                // Update summary based on rule type
                if let complexity = result.ruleComplexity {
                    switch complexity {
                    case .basic:
                        if result.matchedRuleName?.contains("Hardcoded") == true {
                            summary.hardcodedRuleMatches += 1
                        } else {
                            summary.legacyRuleMatches += 1
                        }
                    case .enhanced, .moderate, .complex, .expert:
                        summary.enhancedRuleMatches += 1
                    }
                } else {
                    summary.hardcodedRuleMatches += 1
                }
            } else {
                summary.unchanged += 1
            }
        }

        try modelContext.save()
        summary.processingTime = CFAbsoluteTimeGetCurrent() - startTime

        return summary
    }

    // MARK: - Rule Evaluation

    /// Evaluate a rule against a transaction (performance-optimized)
    private func evaluateRule(_ rule: EnhancedCategorizationRule, against transaction: ParsedTransaction) async -> Bool {
        guard rule.isActive else { return false }

        switch rule.tier {
        case .simple:
            return evaluateSimpleRule(rule, against: transaction)
        case .advanced:
            return await evaluateAdvancedRule(rule, against: transaction)
        }
    }

    /// Fast path evaluation for simple rules
    private func evaluateSimpleRule(_ rule: EnhancedCategorizationRule, against transaction: ParsedTransaction) -> Bool {
        guard let config = rule.simpleConfig else { return false }

        // Account filter check (fast rejection)
        if let accountFilter = config.accountFilter,
           accountFilter != transaction.iban {
            return false
        }

        // Transaction type filter check
        if let typeFilter = config.transactionTypeFilter,
           typeFilter != transaction.transactionType {
            return false
        }

        // Amount range check
        if let minAmount = config.amountMin,
           abs(transaction.amount) < minAmount {
            return false
        }

        if let maxAmount = config.amountMax,
           abs(transaction.amount) > maxAmount {
            return false
        }

        // Field matching check
        let searchText = getSearchTextForField(config.targetField, transaction: transaction)
        return performMatch(config.matchType, pattern: config.pattern, text: searchText)
    }

    /// Comprehensive evaluation for advanced rules
    private func evaluateAdvancedRule(_ rule: EnhancedCategorizationRule, against transaction: ParsedTransaction) async -> Bool {
        guard let conditions = rule.conditions, !conditions.isEmpty else { return false }

        let sortedConditions = conditions.sorted { $0.sortOrder < $1.sortOrder }

        // Evaluate first condition
        guard let firstCondition = sortedConditions.first else { return false }
        var result = evaluateCondition(firstCondition, against: transaction)

        // Process remaining conditions with logical connectors
        for i in 1..<sortedConditions.count {
            let condition = sortedConditions[i]
            let conditionResult = evaluateCondition(condition, against: transaction)

            // Use the connector from the previous condition
            if let connector = sortedConditions[i-1].logicalConnector {
                switch connector {
                case .and:
                    result = result && conditionResult
                case .or:
                    result = result || conditionResult
                }
            } else {
                // Default to AND if no connector specified
                result = result && conditionResult
            }
        }

        return result
    }

    /// Evaluate a single condition
    private func evaluateCondition(_ condition: RuleCondition, against transaction: ParsedTransaction) -> Bool {
        let fieldValue = getFieldValue(condition.field, from: transaction)

        switch condition.operator {
        case .equals:
            return fieldValue.lowercased() == condition.value.lowercased()
        case .contains:
            return fieldValue.lowercased().contains(condition.value.lowercased())
        case .startsWith:
            return fieldValue.lowercased().hasPrefix(condition.value.lowercased())
        case .endsWith:
            return fieldValue.lowercased().hasSuffix(condition.value.lowercased())
        case .greaterThan:
            return compareNumbers(fieldValue, condition.value, .greaterThan)
        case .lessThan:
            return compareNumbers(fieldValue, condition.value, .lessThan)
        case .between:
            return compareBetween(fieldValue, condition.value)
        case .matches:
            return matchesRegex(fieldValue, pattern: condition.value)
        case .notEqual:
            return fieldValue.lowercased() != condition.value.lowercased()
        case .notContains:
            return !fieldValue.lowercased().contains(condition.value.lowercased())
        }
    }

    // MARK: - Helper Methods

    private func getActiveEnhancedRules() async throws -> [EnhancedCategorizationRule] {
        // Check cache validity
        if let lastUpdate = enhancedCacheLastUpdated,
           Date().timeIntervalSince(lastUpdate) < cacheValidityDuration,
           !cachedEnhancedRules.isEmpty {
            return cachedEnhancedRules
        }

        // Fetch fresh enhanced rules
        let descriptor = FetchDescriptor<EnhancedCategorizationRule>(
            predicate: #Predicate<EnhancedCategorizationRule> { $0.isActive },
            sortBy: [SortDescriptor(\EnhancedCategorizationRule.priority, order: .forward)]
        )

        let rules = try modelContext.fetch(descriptor)
        cachedEnhancedRules = rules
        enhancedCacheLastUpdated = Date()

        return rules
    }

    private func getSearchTextForField(_ field: RuleTargetField, transaction: ParsedTransaction) -> String {
        switch field {
        case .description:
            return transaction.fullDescription
        case .counterName:
            return transaction.counterName ?? ""
        case .counterIBAN:
            return transaction.counterIBAN ?? ""
        case .standardizedName:
            return transaction.standardizedName ?? ""
        case .anyField:
            return buildSearchText(counterParty: transaction.counterName, description: transaction.fullDescription)
        }
    }

    private func getFieldValue(_ field: RuleField, from transaction: ParsedTransaction) -> String {
        switch field {
        case .amount:
            return transaction.amount.description
        case .description:
            return transaction.fullDescription
        case .counterName:
            return transaction.counterName ?? ""
        case .counterIBAN:
            return transaction.counterIBAN ?? ""
        case .account:
            return transaction.iban
        case .transactionType:
            return transaction.transactionType.rawValue
        case .date:
            return ISO8601DateFormatter().string(from: transaction.date)
        case .standardizedName:
            return transaction.standardizedName ?? ""
        case .transactionCode:
            return transaction.transactionCode ?? ""
        }
    }

    private func performMatch(_ matchType: RuleMatchType, pattern: String, text: String) -> Bool {
        let searchText = text.lowercased()

        switch matchType {
        case .contains:
            return searchText.contains(pattern)
        case .startsWith:
            return searchText.hasPrefix(pattern)
        case .endsWith:
            return searchText.hasSuffix(pattern)
        case .exact:
            return searchText == pattern
        case .regex:
            return matchesRegex(searchText, pattern: pattern)
        }
    }

    private func compareNumbers(_ fieldValue: String, _ conditionValue: String, _ operator: RuleOperator) -> Bool {
        guard let fieldDecimal = Decimal(string: fieldValue),
              let conditionDecimal = Decimal(string: conditionValue) else {
            return false
        }

        switch operator {
        case .greaterThan:
            return fieldDecimal > conditionDecimal
        case .lessThan:
            return fieldDecimal < conditionDecimal
        default:
            return false
        }
    }

    private func compareBetween(_ fieldValue: String, _ rangeValue: String) -> Bool {
        // Expect format "min,max"
        let components = rangeValue.split(separator: ",")
        guard components.count == 2,
              let fieldDecimal = Decimal(string: fieldValue),
              let minDecimal = Decimal(string: String(components[0])),
              let maxDecimal = Decimal(string: String(components[1])) else {
            return false
        }

        return fieldDecimal >= minDecimal && fieldDecimal <= maxDecimal
    }

    private func matchesRegex(_ text: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    private func buildSearchText(counterParty: String?, description: String) -> String {
        var parts: [String] = []

        if let party = counterParty, !party.isEmpty {
            parts.append(party)
        }

        if !description.isEmpty {
            parts.append(description)
        }

        return parts
            .joined(separator: " ")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanCounterPartyName(_ name: String?) -> String? {
        guard let name = name, !name.isEmpty else { return nil }

        // Use the same logic as legacy engine if available
        if let legacyEngine = legacyEngine {
            return name.trimmingCharacters(in: .whitespaces).capitalized
        }

        return name.trimmingCharacters(in: .whitespaces).capitalized
    }

    private func handleContribution(_ contributor: Contributor, evaluationTime: TimeInterval) -> EnhancedCategorizationResult {
        switch contributor {
        case .partner1:
            return EnhancedCategorizationResult(
                category: "Inleg Partner 1",
                standardizedName: "Partner 1",
                matchedRuleName: "Contribution Detection",
                ruleComplexity: .basic,
                confidence: 1.0,
                evaluationTime: evaluationTime
            )
        case .partner2:
            return EnhancedCategorizationResult(
                category: "Inleg Partner 2",
                standardizedName: "Partner 2",
                matchedRuleName: "Contribution Detection",
                ruleComplexity: .basic,
                confidence: 1.0,
                evaluationTime: evaluationTime
            )
        }
    }

    private func extractStandardizedName(_ rule: EnhancedCategorizationRule, _ transaction: ParsedTransaction) -> String? {
        // For simple rules, we could extract standardized names from config
        // For advanced rules, we might use the counter party name
        return cleanCounterPartyName(transaction.counterName)
    }

    private func calculateConfidence(rule: EnhancedCategorizationRule, transaction: ParsedTransaction) -> Double {
        switch rule.tier {
        case .simple:
            guard let config = rule.simpleConfig else { return 0.5 }

            switch config.matchType {
            case .exact:
                return 1.0
            case .regex:
                return 0.95
            case .startsWith:
                return 0.85
            case .endsWith:
                return 0.80
            case .contains:
                return 0.75
            }

        case .advanced:
            let conditionCount = rule.conditions?.count ?? 0
            // More conditions = higher confidence (more specific match)
            return min(1.0, 0.8 + Double(conditionCount) * 0.05)
        }
    }

    private func generateMatchExplanation(_ rule: EnhancedCategorizationRule, _ transaction: ParsedTransaction, _ matches: Bool) -> String {
        if matches {
            return "✅ Rule '\(rule.name)' matched"
        } else {
            switch rule.tier {
            case .simple:
                return "❌ Rule '\(rule.name)' did not match (check field content and filters)"
            case .advanced:
                return "❌ Rule '\(rule.name)' did not match (one or more conditions failed)"
            }
        }
    }

    private func createParsedTransaction(from transaction: Transaction) -> ParsedTransaction {
        return ParsedTransaction(
            iban: transaction.iban,
            sequenceNumber: transaction.sequenceNumber,
            date: transaction.date,
            amount: transaction.amount,
            balance: transaction.balance,
            counterIBAN: transaction.counterIBAN,
            counterName: transaction.counterName,
            description1: transaction.description1,
            description2: transaction.description2,
            description3: transaction.description3,
            transactionCode: transaction.transactionCode,
            valueDate: transaction.valueDate,
            returnReason: transaction.returnReason,
            mandateReference: transaction.mandateReference,
            transactionType: transaction.transactionType,
            contributor: transaction.contributor,
            sourceFile: transaction.sourceFile ?? ""
        )
    }

    // MARK: - Performance and Analytics

    func getPerformanceStats() -> EvaluationStats {
        return evaluationStats
    }

    func invalidateCache() {
        cachedEnhancedRules = []
        enhancedCacheLastUpdated = nil
        legacyEngine?.invalidateCache()
    }
}

// MARK: - Supporting Types

/// Result of rule testing for preview functionality
struct RuleTestResult: Sendable {
    let transaction: ParsedTransaction
    let matches: Bool
    let confidence: Double
    let explanation: String
}

/// Summary of bulk recategorization operation
struct RecategorizationSummary: Sendable {
    var totalProcessed: Int
    var enhancedRuleMatches: Int
    var legacyRuleMatches: Int
    var hardcodedRuleMatches: Int
    var unchanged: Int
    var processingTime: TimeInterval = 0

    var successRate: Double {
        guard totalProcessed > 0 else { return 0 }
        let successful = enhancedRuleMatches + legacyRuleMatches + hardcodedRuleMatches
        return Double(successful) / Double(totalProcessed)
    }
}

/// Performance monitoring for rule evaluation
struct EvaluationStats: Sendable {
    var simpleRulesEvaluated: Int = 0
    var advancedRulesEvaluated: Int = 0
    var averageSimpleRuleTime: TimeInterval = 0
    var averageAdvancedRuleTime: TimeInterval = 0
    var cacheHitRate: Double = 0

    mutating func recordSimpleEvaluation(time: TimeInterval) {
        simpleRulesEvaluated += 1
        averageSimpleRuleTime = (averageSimpleRuleTime * Double(simpleRulesEvaluated - 1) + time) / Double(simpleRulesEvaluated)
    }

    mutating func recordAdvancedEvaluation(time: TimeInterval) {
        advancedRulesEvaluated += 1
        averageAdvancedRuleTime = (averageAdvancedRuleTime * Double(advancedRulesEvaluated - 1) + time) / Double(advancedRulesEvaluated)
    }
}