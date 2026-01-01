//
//  TriggerEvaluator.swift
//  Florijn
//
//  Trigger evaluation system with adaptive parallelization
//
//  Architecture:
//  • @ModelActor with TaskGroup for thread-safe parallel processing
//  • Adaptive strategy: sequential <10 triggers, batched parallel for larger sets
//  • Regex compilation cache for pattern matching
//  • Fast paths for common operations (equals, contains, numeric comparisons)
//
//  Performance:
//  • Single trigger evaluation: <1ms
//  • 100+ triggers in parallel: <10ms
//

@preconcurrency import SwiftData
import Foundation
import OSLog

private let logger = Logger(subsystem: "Florijn", category: "TriggerEvaluator")

@ModelActor
actor TriggerEvaluator {

    // MARK: - Performance Configuration

    /// Threshold for switching to parallel processing
    private static let PARALLEL_THRESHOLD = 10

    /// Batch size for parallel processing (optimize for CPU cores)
    private static let BATCH_SIZE = 25

    // MARK: - Shared Caches
    // Note: @ModelActor macro auto-generates init(modelContainer:)

    /// Compiled regex cache for pattern matching
    private static let regexCache = RegexCache()

    // MARK: - Public Interface

    /// Evaluate multiple triggers against a transaction with adaptive parallelization
    /// Uses sequential processing for <10 triggers, parallel batching for larger sets
    func evaluateParallel(
        _ triggers: [RuleTrigger],
        against transaction: Transaction,
        progressHandler: @Sendable (Int, Int) async -> Void = { _, _ in }
    ) async -> [Bool] {
        guard !triggers.isEmpty else { return [] }

        let startTime = CFAbsoluteTimeGetCurrent()

        let results: [Bool]
        if triggers.count < Self.PARALLEL_THRESHOLD {
            // Fast path: sequential evaluation for small sets
            results = await evaluateSequential(triggers, against: transaction, progressHandler: progressHandler)
        } else {
            // Parallel path: batched evaluation for large sets
            results = await evaluateBatched(triggers, against: transaction, progressHandler: progressHandler)
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        if elapsed > 10 && triggers.count > 50 {
            logger.warning("Trigger evaluation took \(elapsed, privacy: .public)ms for \(triggers.count) triggers")
        }

        return results
    }

    /// Validate a trigger for UI feedback with helpful error messages
    func validateTrigger(_ trigger: RuleTrigger) -> TriggerValidationResult {
        // Check if field and operator are compatible
        if !trigger.field.validOperators.contains(trigger.triggerOperator) {
            return .invalid(
                message: "\(trigger.triggerOperator.displayName) is not valid for \(trigger.field.displayName)",
                suggestion: "Try operators: \(trigger.field.validOperators.map(\.displayName).joined(separator: ", "))"
            )
        }

        // Check if value is required but missing
        if trigger.triggerOperator.requiresValue && trigger.value.trimmingCharacters(in: .whitespaces).isEmpty {
            return .invalid(
                message: "\(trigger.triggerOperator.displayName) requires a value",
                suggestion: trigger.triggerOperator.valuePlaceholder
            )
        }

        // Validate specific operator requirements
        switch trigger.triggerOperator {
        case .matches:
            // Validate regex pattern
            do {
                _ = try Regex(trigger.value)
            } catch {
                return .invalid(
                    message: "Invalid regular expression pattern",
                    suggestion: "Check your regex syntax. Example: '^[A-Z]+.*' for text starting with uppercase"
                )
            }

        case .greaterThan, .lessThan, .greaterThanOrEqual, .lessThanOrEqual:
            // Validate numeric value for amount operators
            if trigger.field.isNumeric && Decimal(string: trigger.value) == nil {
                return .invalid(
                    message: "Amount must be a valid number",
                    suggestion: "Examples: 100, 50.75, 1500"
                )
            }

        case .before, .after, .on:
            // Validate date format
            if trigger.field.isDate && Self.parseDate(trigger.value) == nil {
                return .invalid(
                    message: "Invalid date format",
                    suggestion: "Use YYYY-MM-DD format (e.g., 2025-12-31)"
                )
            }

        default:
            break
        }

        return .valid
    }

    // MARK: - Rule Trigger Group Evaluation

    /// Evaluate a complete rule (with trigger groups or flat triggers) against a transaction
    /// Returns true if the rule matches, according to its logic
    func evaluateRule(_ rule: Rule, against transaction: Transaction) async -> Bool {
        if rule.usesAdvancedTriggers {
            return await evaluateTriggerGroups(rule.triggerGroups, groupMatchMode: rule.groupMatchMode, against: transaction)
        } else {
            return await evaluateFlatTriggers(rule.triggers, matchMode: rule.triggerLogic, against: transaction)
        }
    }

    /// Evaluate trigger groups with nested AND/OR logic
    /// Each group's triggers are combined with the group's matchMode
    /// Groups are then combined with the rule's groupMatchMode
    func evaluateTriggerGroups(
        _ groups: [TriggerGroup],
        groupMatchMode: TriggerLogic,
        against transaction: Transaction
    ) async -> Bool {
        guard !groups.isEmpty else { return false }

        let sortedGroups = groups.sortedBySortOrder

        for group in sortedGroups {
            let groupMatches = await evaluateFlatTriggers(
                group.triggers,
                matchMode: group.matchMode,
                against: transaction
            )

            switch groupMatchMode {
            case .any:
                // Short-circuit: if any group matches, rule matches
                if groupMatches { return true }
            case .all:
                // Short-circuit: if any group fails, rule fails
                if !groupMatches { return false }
            }
        }

        // For .any mode: none matched = false
        // For .all mode: all matched = true
        return groupMatchMode == .all
    }

    /// Evaluate flat triggers with AND/OR logic
    func evaluateFlatTriggers(
        _ triggers: [RuleTrigger],
        matchMode: TriggerLogic,
        against transaction: Transaction
    ) async -> Bool {
        guard !triggers.isEmpty else { return false }

        let sortedTriggers = triggers.sortedBySortOrder

        for trigger in sortedTriggers {
            let matches = await evaluate(trigger, against: transaction)

            switch matchMode {
            case .any:
                // Short-circuit: if any trigger matches, group matches
                if matches { return true }
            case .all:
                // Short-circuit: if any trigger fails, group fails
                if !matches { return false }
            }
        }

        // For .any mode: none matched = false
        // For .all mode: all matched = true
        return matchMode == .all
    }

    // MARK: - Core Evaluation Logic

    /// Evaluate a single trigger against a transaction with fast paths
    private func evaluate(_ trigger: RuleTrigger, against transaction: Transaction) async -> Bool {
        let fieldValue = extractFieldValue(trigger.field, from: transaction)

        // Fast paths for common operations (no caching overhead)
        let result: Bool
        switch (trigger.triggerOperator, trigger.field) {
        case (.equals, .description):
            result = fieldValue.lowercased() == trigger.value.lowercased()
        case (.contains, .description):
            result = fieldValue.lowercased().contains(trigger.value.lowercased())
        case (.greaterThan, .amount), (.lessThan, .amount):
            if let triggerAmount = Decimal(string: trigger.value),
               let transactionAmount = Decimal(string: fieldValue) {
                result = trigger.triggerOperator == .greaterThan ?
                    transactionAmount > triggerAmount :
                    transactionAmount < triggerAmount
            } else {
                result = false
            }
        default:
            // Direct evaluation - simple string operations don't benefit from caching
            result = await evaluateOperator(trigger.triggerOperator, value: trigger.value, fieldValue: fieldValue)
        }

        // Apply NOT logic if inverted
        return trigger.isInverted ? !result : result
    }

    // MARK: - Field Extraction

    /// Extract field value from transaction with caching for computed properties
    private func extractFieldValue(_ field: TriggerField, from transaction: Transaction) -> String {
        switch field {
        case .description:
            return transaction.cachedFullDescription
        case .accountName:
            return transaction.account?.name ?? ""
        case .counterParty:
            return transaction.counterName ?? ""
        case .amount:
            return transaction.amount.description
        case .date:
            return DateFormatter.dateFormatter.string(from: transaction.date)
        case .iban:
            return transaction.iban
        case .counterIban:
            return transaction.counterIBAN ?? ""
        case .transactionType:
            return transaction.transactionType.rawValue
        case .category:
            return transaction.effectiveCategory
        case .notes:
            return transaction.notes ?? ""
        case .externalId:
            return "" // Not implemented in current Transaction model
        case .internalReference:
            return transaction.mandateReference ?? ""
        case .tags:
            return "" // Not implemented in current Transaction model
        }
    }

    // MARK: - Operator Evaluation

    /// Evaluate specific operator against field value
    private func evaluateOperator(_ triggerOp: TriggerOperator, value: String, fieldValue: String) async -> Bool {
        switch triggerOp {
        // String operators
        case .contains:
            return fieldValue.localizedCaseInsensitiveContains(value)
        case .startsWith:
            return fieldValue.lowercased().hasPrefix(value.lowercased())
        case .endsWith:
            return fieldValue.lowercased().hasSuffix(value.lowercased())
        case .equals:
            return fieldValue.lowercased() == value.lowercased()
        case .matches:
            return await evaluateRegex(pattern: value, against: fieldValue)

        // Presence operators (no value required)
        case .isEmpty:
            return fieldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .isNotEmpty, .hasValue:
            return !fieldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        // Numeric operators
        case .greaterThan, .lessThan, .greaterThanOrEqual, .lessThanOrEqual:
            return evaluateNumeric(triggerOp, triggerValue: value, fieldValue: fieldValue)

        // Date operators
        case .before, .after, .on:
            return evaluateDate(triggerOp, triggerValue: value, fieldValue: fieldValue)
        case .today:
            return Calendar.current.isDateInToday(Self.parseDate(fieldValue) ?? Date.distantPast)
        case .yesterday:
            return Calendar.current.isDateInYesterday(Self.parseDate(fieldValue) ?? Date.distantPast)
        case .tomorrow:
            return Calendar.current.isDateInTomorrow(Self.parseDate(fieldValue) ?? Date.distantPast)
        }
    }

    // MARK: - Specialized Evaluations

    /// Evaluate regex pattern with caching
    private func evaluateRegex(pattern: String, against text: String) async -> Bool {
        do {
            return try await Self.regexCache.evaluate(pattern: pattern, against: text)
        } catch {
            logger.warning("Invalid regex pattern '\(pattern)': \(error.localizedDescription)")
            return false
        }
    }

    /// Evaluate numeric comparison
    private func evaluateNumeric(_ triggerOp: TriggerOperator, triggerValue: String, fieldValue: String) -> Bool {
        guard let triggerAmount = Decimal(string: triggerValue),
              let fieldAmount = Decimal(string: fieldValue) else {
            return false
        }

        switch triggerOp {
        case .greaterThan:
            return fieldAmount > triggerAmount
        case .lessThan:
            return fieldAmount < triggerAmount
        case .greaterThanOrEqual:
            return fieldAmount >= triggerAmount
        case .lessThanOrEqual:
            return fieldAmount <= triggerAmount
        default:
            return false
        }
    }

    /// Evaluate date comparison
    private func evaluateDate(_ triggerOp: TriggerOperator, triggerValue: String, fieldValue: String) -> Bool {
        guard let triggerDate = Self.parseDate(triggerValue),
              let fieldDate = Self.parseDate(fieldValue) else {
            return false
        }

        switch triggerOp {
        case .before:
            return fieldDate < triggerDate
        case .after:
            return fieldDate > triggerDate
        case .on:
            return Calendar.current.isDate(fieldDate, inSameDayAs: triggerDate)
        default:
            return false
        }
    }

    // MARK: - Parallel Execution Strategies

    /// Sequential evaluation for small trigger sets (<10)
    private func evaluateSequential(
        _ triggers: [RuleTrigger],
        against transaction: Transaction,
        progressHandler: @Sendable (Int, Int) async -> Void
    ) async -> [Bool] {
        var results: [Bool] = []
        results.reserveCapacity(triggers.count)

        for (index, trigger) in triggers.enumerated() {
            let result = await evaluate(trigger, against: transaction)
            results.append(result)

            // Report progress for UI updates
            await progressHandler(index + 1, triggers.count)
        }

        return results
    }

    /// Batched parallel evaluation for large trigger sets (>=10)
    private func evaluateBatched(
        _ triggers: [RuleTrigger],
        against transaction: Transaction,
        progressHandler: @Sendable (Int, Int) async -> Void
    ) async -> [Bool] {
        let batches = triggers.chunked(into: Self.BATCH_SIZE)
        var allResults: [Bool] = []
        allResults.reserveCapacity(triggers.count)

        var processedCount = 0

        for batch in batches {
            // Process batch in parallel using TaskGroup
            let batchResults = await withTaskGroup(of: (Int, Bool).self) { group in
                // Add tasks for each trigger in the batch
                for (index, trigger) in batch.enumerated() {
                    group.addTask { @Sendable in
                        let result = await self.evaluate(trigger, against: transaction)
                        return (index, result)
                    }
                }

                // Collect results maintaining order
                var results: [(Int, Bool)] = []
                for await result in group {
                    results.append(result)
                }

                return results.sorted { $0.0 < $1.0 }.map { $0.1 }
            }

            allResults.append(contentsOf: batchResults)
            processedCount += batch.count

            // Report progress
            await progressHandler(processedCount, triggers.count)
        }

        return allResults
    }

    // MARK: - Date Parsing

    /// Parse date from string using multiple formats
    private static func parseDate(_ dateString: String) -> Date? {
        for formatter in [DateFormatter.dateFormatter, DateFormatter.dateFormatterSlash, DateFormatter.dateFormatterDash] {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }
}

// MARK: - Supporting Types

struct TriggerValidationResult: Sendable {
    let isValid: Bool
    let errorMessage: String?
    let suggestion: String?

    static let valid = TriggerValidationResult(isValid: true, errorMessage: nil, suggestion: nil)

    static func invalid(message: String, suggestion: String) -> TriggerValidationResult {
        TriggerValidationResult(isValid: false, errorMessage: message, suggestion: suggestion)
    }
}

// MARK: - Performance Support Classes

/// Thread-safe regex compilation cache
actor RegexCache {
    private var cache: [String: Regex<AnyRegexOutput>] = [:]
    private let maxSize = 1000

    /// Evaluate pattern against text (Swift 6 Sendable-compliant)
    func evaluate(pattern: String, against text: String) throws -> Bool {
        let regex = try getRegexInternal(for: pattern)
        return text.contains(regex)
    }

    /// Internal method to get regex (keeps non-Sendable Regex within actor boundary)
    private func getRegexInternal(for pattern: String) throws -> Regex<AnyRegexOutput> {
        if let cached = cache[pattern] {
            return cached
        }

        let regex = try Regex(pattern)

        // Simple cache eviction if at capacity
        if cache.count >= maxSize {
            cache.removeAll()
        }

        cache[pattern] = regex
        return regex
    }

    /// Legacy method for backward compatibility (still not Sendable-compliant)
    func getRegex(for pattern: String) throws -> Regex<AnyRegexOutput> {
        return try getRegexInternal(for: pattern)
    }
}

// MARK: - Extensions
// Note: Array.chunked(into:) extension is defined in BackgroundDataHandler.swift

extension DateFormatter {
    /// Pre-configured formatter for ISO date format (YYYY-MM-DD)
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Pre-configured formatter for slash date format (DD/MM/YYYY)
    static let dateFormatterSlash: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Pre-configured formatter for dash date format (DD-MM-YYYY)
    static let dateFormatterDash: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}

