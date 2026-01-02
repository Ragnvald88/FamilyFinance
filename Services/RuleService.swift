//
//  RuleService.swift
//  Florijn
//
//  Unified rule service - ONE service for ALL rule operations
//  Used by both CSV import and manual rule execution
//
//  Created: 2025-01-02
//

import Foundation
@preconcurrency import SwiftData

// MARK: - Rule Service

/// Single source of truth for all rule operations.
/// Replaces the dual CategorizationEngine + RuleEngine architecture.
///
/// Usage:
/// ```swift
/// let service = RuleService(modelContext: context)
/// service.processTransactions(transactions)  // For import
/// service.processTransaction(transaction)    // For manual execution
/// ```
@MainActor
class RuleService {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Static Formatters (performance: avoid creating on every call)

    private static let iso8601Formatter = ISO8601DateFormatter()

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Process a single transaction through all active rules
    func processTransaction(_ transaction: Transaction) {
        let rules = getActiveRules()

        for rule in rules {
            if evaluate(rule: rule, against: transaction) {
                apply(rule: rule, to: transaction)
                rule.matchCount += 1
                rule.lastMatchedAt = Date()

                if rule.stopProcessing {
                    break
                }
            }
        }
    }

    /// Process multiple transactions (for CSV import)
    func processTransactions(_ transactions: [Transaction]) {
        let rules = getActiveRules()

        for transaction in transactions {
            for rule in rules {
                if evaluate(rule: rule, against: transaction) {
                    apply(rule: rule, to: transaction)
                    rule.matchCount += 1
                    rule.lastMatchedAt = Date()

                    if rule.stopProcessing {
                        break
                    }
                }
            }
        }

        // Save changes
        try? modelContext.save()
    }

    /// Categorize parsed transactions (for CSV import before they become Transaction objects)
    /// Returns category assignments that can be applied during import
    func categorizeParsedTransactions(_ parsed: [ParsedTransaction]) -> [CategorizationResult] {
        let rules = getActiveRules()

        return parsed.map { transaction in
            for rule in rules {
                if evaluateAgainstParsed(rule: rule, transaction: transaction) {
                    // Find the setCategory action
                    if let categoryAction = rule.actions.first(where: { $0.type == .setCategory }) {
                        return CategorizationResult(
                            category: categoryAction.value,
                            standardizedName: getStandardizedName(from: rule, transaction: transaction),
                            matchedRuleName: rule.name
                        )
                    }
                }
            }
            return .uncategorized
        }
    }

    /// Test a rule against a transaction (for live preview in UI)
    func testRule(_ rule: Rule, against transaction: Transaction) -> Bool {
        return evaluate(rule: rule, against: transaction)
    }

    // MARK: - Rule Fetching

    private func getActiveRules() -> [Rule] {
        // Always fetch fresh - caching caused bugs where new rules didn't apply
        let descriptor = FetchDescriptor<Rule>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.groupExecutionOrder)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Rule Evaluation

    /// Evaluate a rule against a Transaction object
    private func evaluate(rule: Rule, against transaction: Transaction) -> Bool {
        // Get all triggers (handles both simple and grouped)
        if rule.usesAdvancedTriggers {
            return evaluateTriggerGroups(rule.triggerGroups, groupMatchMode: rule.groupMatchMode, transaction: transaction)
        } else {
            return evaluateTriggers(rule.triggers, matchMode: rule.triggerLogic, transaction: transaction)
        }
    }

    /// Evaluate trigger groups with nested AND/OR logic
    private func evaluateTriggerGroups(_ groups: [TriggerGroup], groupMatchMode: TriggerLogic, transaction: Transaction) -> Bool {
        guard !groups.isEmpty else { return false }

        let sortedGroups = groups.sorted { $0.sortOrder < $1.sortOrder }

        for group in sortedGroups {
            let groupMatches = evaluateTriggers(group.triggers, matchMode: group.matchMode, transaction: transaction)

            switch groupMatchMode {
            case .any:
                if groupMatches { return true }
            case .all:
                if !groupMatches { return false }
            }
        }

        return groupMatchMode == .all
    }

    /// Evaluate flat triggers with AND/OR logic
    private func evaluateTriggers(_ triggers: [RuleTrigger], matchMode: TriggerLogic, transaction: Transaction) -> Bool {
        guard !triggers.isEmpty else { return false }

        let sortedTriggers = triggers.sorted { $0.sortOrder < $1.sortOrder }

        for trigger in sortedTriggers {
            let matches = evaluateTrigger(trigger, against: transaction)

            switch matchMode {
            case .any:
                if matches { return true }
            case .all:
                if !matches { return false }
            }
        }

        return matchMode == .all
    }

    /// Evaluate a single trigger against a transaction
    private func evaluateTrigger(_ trigger: RuleTrigger, against transaction: Transaction) -> Bool {
        let fieldValue = getFieldValue(trigger.field, from: transaction)
        let result = evaluateOperator(trigger.triggerOperator, fieldValue: fieldValue, triggerValue: trigger.value)
        return trigger.isInverted ? !result : result
    }

    /// Evaluate a rule against a ParsedTransaction (for import before DB insertion)
    private func evaluateAgainstParsed(rule: Rule, transaction: ParsedTransaction) -> Bool {
        let triggers = rule.allTriggers
        guard !triggers.isEmpty else { return false }

        let results = triggers.map { trigger -> Bool in
            let fieldValue = getFieldValueFromParsed(trigger.field, from: transaction)
            let result = evaluateOperator(trigger.triggerOperator, fieldValue: fieldValue, triggerValue: trigger.value)
            return trigger.isInverted ? !result : result
        }

        switch rule.triggerLogic {
        case .all: return results.allSatisfy { $0 }
        case .any: return results.contains { $0 }
        }
    }

    // MARK: - Field Value Extraction

    private func getFieldValue(_ field: TriggerField, from transaction: Transaction) -> String {
        switch field {
        case .description:
            return transaction.fullDescription.lowercased()
        case .counterParty:
            return (transaction.counterName ?? "").lowercased()
        case .counterIban:
            return (transaction.counterIBAN ?? "").lowercased()
        case .amount:
            return "\(transaction.amount)"
        case .accountName:
            return (transaction.account?.name ?? "").lowercased()
        case .iban:
            return transaction.iban.lowercased()
        case .transactionType:
            return transaction.transactionType.rawValue.lowercased()
        case .category:
            return transaction.effectiveCategory.lowercased()
        case .notes:
            return (transaction.notes ?? "").lowercased()
        case .date:
            return Self.iso8601Formatter.string(from: transaction.date)
        case .externalId, .internalReference, .tags:
            return ""
        }
    }

    private func getFieldValueFromParsed(_ field: TriggerField, from transaction: ParsedTransaction) -> String {
        switch field {
        case .description:
            return transaction.fullDescription.lowercased()
        case .counterParty:
            return (transaction.counterName ?? "").lowercased()
        case .counterIban:
            return (transaction.counterIBAN ?? "").lowercased()
        case .amount:
            return "\(transaction.amount)"
        case .accountName, .iban:
            return transaction.iban.lowercased()
        case .transactionType:
            return transaction.transactionType.rawValue.lowercased()
        case .date:
            return Self.iso8601Formatter.string(from: transaction.date)
        case .category, .notes, .externalId, .internalReference, .tags:
            return ""
        }
    }

    // MARK: - Operator Evaluation

    private func evaluateOperator(_ op: TriggerOperator, fieldValue: String, triggerValue: String) -> Bool {
        let value = triggerValue.lowercased()

        switch op {
        case .contains:
            return fieldValue.contains(value)
        case .equals:
            return fieldValue == value
        case .startsWith:
            return fieldValue.hasPrefix(value)
        case .endsWith:
            return fieldValue.hasSuffix(value)
        case .matches:
            return evaluateRegex(pattern: triggerValue, against: fieldValue)
        case .isEmpty:
            return fieldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .isNotEmpty, .hasValue:
            return !fieldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .greaterThan:
            guard let fieldNum = Double(fieldValue), let triggerNum = Double(triggerValue) else { return false }
            return fieldNum > triggerNum
        case .lessThan:
            guard let fieldNum = Double(fieldValue), let triggerNum = Double(triggerValue) else { return false }
            return fieldNum < triggerNum
        case .greaterThanOrEqual:
            guard let fieldNum = Double(fieldValue), let triggerNum = Double(triggerValue) else { return false }
            return fieldNum >= triggerNum
        case .lessThanOrEqual:
            guard let fieldNum = Double(fieldValue), let triggerNum = Double(triggerValue) else { return false }
            return fieldNum <= triggerNum
        case .before:
            return compareDates(fieldValue, isBefore: triggerValue)
        case .after:
            return compareDates(fieldValue, isAfter: triggerValue)
        case .on:
            return compareDates(fieldValue, isSameDay: triggerValue)
        case .today:
            return isToday(fieldValue)
        case .yesterday:
            return isYesterday(fieldValue)
        case .tomorrow:
            return isTomorrow(fieldValue)
        }
    }

    private func evaluateRegex(pattern: String, against text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    // MARK: - Date Helpers

    private func compareDates(_ fieldValue: String, isBefore triggerValue: String) -> Bool {
        guard let fieldDate = parseDate(fieldValue),
              let triggerDate = parseDate(triggerValue) else { return false }
        return fieldDate < triggerDate
    }

    private func compareDates(_ fieldValue: String, isAfter triggerValue: String) -> Bool {
        guard let fieldDate = parseDate(fieldValue),
              let triggerDate = parseDate(triggerValue) else { return false }
        return fieldDate > triggerDate
    }

    private func compareDates(_ fieldValue: String, isSameDay triggerValue: String) -> Bool {
        guard let fieldDate = parseDate(fieldValue),
              let triggerDate = parseDate(triggerValue) else { return false }
        return Calendar.current.isDate(fieldDate, inSameDayAs: triggerDate)
    }

    private func isToday(_ fieldValue: String) -> Bool {
        guard let date = parseDate(fieldValue) else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private func isYesterday(_ fieldValue: String) -> Bool {
        guard let date = parseDate(fieldValue) else { return false }
        return Calendar.current.isDateInYesterday(date)
    }

    private func isTomorrow(_ fieldValue: String) -> Bool {
        guard let date = parseDate(fieldValue) else { return false }
        return Calendar.current.isDateInTomorrow(date)
    }

    private func parseDate(_ string: String) -> Date? {
        let formatters = [
            ISO8601DateFormatter(),
        ]
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let formats = ["yyyy-MM-dd", "dd/MM/yyyy", "dd-MM-yyyy"]
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: string) {
                return date
            }
        }

        return nil
    }

    // MARK: - Action Execution

    /// Apply a rule's actions to a transaction
    private func apply(rule: Rule, to transaction: Transaction) {
        for action in rule.actions.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            applyAction(action, to: transaction)

            if action.stopProcessingAfter {
                break
            }
        }
    }

    private func applyAction(_ action: RuleAction, to transaction: Transaction) {
        switch action.type {
        // Categorization actions
        case .setCategory:
            transaction.autoCategory = action.value
            transaction.indexedCategory = transaction.effectiveCategory

        case .clearCategory:
            transaction.autoCategory = nil
            transaction.indexedCategory = transaction.effectiveCategory

        case .setNotes:
            transaction.notes = action.value

        case .setDescription:
            transaction.description1 = action.value

        case .appendDescription:
            transaction.description1 = (transaction.description1 ?? "") + " " + action.value

        case .prependDescription:
            transaction.description1 = action.value + " " + (transaction.description1 ?? "")

        case .setCounterParty:
            transaction.counterName = action.value
            transaction.standardizedName = action.value

        // Tag actions (stored in notes for now)
        case .addTag:
            let currentTags = transaction.notes?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
            if !currentTags.contains(action.value) {
                var newTags = currentTags
                newTags.append(action.value)
                transaction.notes = newTags.joined(separator: ", ")
            }

        case .removeTag:
            var tags = transaction.notes?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
            tags.removeAll { $0 == action.value }
            transaction.notes = tags.isEmpty ? nil : tags.joined(separator: ", ")

        case .clearAllTags:
            transaction.notes = nil

        // Account operations
        case .setSourceAccount, .setDestinationAccount, .swapAccounts:
            // These require account lookup - skip for now
            break

        // Transaction type conversion
        case .convertToDeposit:
            transaction.transactionType = .income
            if transaction.amount < 0 {
                transaction.amount = -transaction.amount
            }

        case .convertToWithdrawal:
            transaction.transactionType = .expense
            if transaction.amount > 0 {
                transaction.amount = -transaction.amount
            }

        case .convertToTransfer:
            transaction.transactionType = .transfer

        // Advanced actions
        case .deleteTransaction:
            // Skip - dangerous action
            break

        case .setExternalId:
            let info = "External ID: \(action.value)"
            transaction.notes = [transaction.notes, info].compactMap { $0 }.joined(separator: " | ")

        case .setInternalReference:
            let info = "Ref: \(action.value)"
            transaction.notes = [transaction.notes, info].compactMap { $0 }.joined(separator: " | ")
        }
    }

    // MARK: - Helpers

    private func getStandardizedName(from rule: Rule, transaction: ParsedTransaction) -> String? {
        // Check if rule has a setCounterParty action
        if let action = rule.actions.first(where: { $0.type == .setCounterParty }) {
            return action.value
        }
        return nil
    }
}

// MARK: - Categorization Result

/// Result of categorizing a transaction
struct CategorizationResult: Sendable {
    let category: String?
    let standardizedName: String?
    let matchedRuleName: String?

    static var uncategorized: CategorizationResult {
        CategorizationResult(category: nil, standardizedName: nil, matchedRuleName: nil)
    }
}
