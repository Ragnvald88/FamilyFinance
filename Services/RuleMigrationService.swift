//
//  RuleMigrationService.swift
//  Family Finance
//
//  Migration service for upgrading to the new unified rule system
//  Safely converts legacy and enhanced rules to the new architecture
//
//  Migration Strategy:
//  1. Convert legacy CategorizationRule to new unified system
//  2. Convert EnhancedCategorizationRule to new unified system
//  3. Preserve all statistics and metadata
//  4. Provide rollback capability
//
//  Created: 2025-12-24
//

import Foundation
@preconcurrency import SwiftData

// MARK: - Migration Service

/// Service for migrating rules to the new unified categorization system.
/// Handles both legacy and enhanced rules with safe migration and rollback.
@MainActor
class RuleMigrationService {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Migration State

    private var migrationInProgress = false

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Migration Analysis

    /// Analyze all existing rules and prepare migration plan
    func analyzeMigration() async throws -> MigrationAnalysis {
        let legacyRules = try await fetchLegacyRules()
        let enhancedRules = try await fetchEnhancedRules()

        return MigrationAnalysis(
            legacyRulesCount: legacyRules.count,
            enhancedRulesCount: enhancedRules.count,
            totalRules: legacyRules.count + enhancedRules.count,
            canMigrateAll: true,
            warnings: []
        )
    }

    /// Execute the complete migration process
    func executeMigration() async throws -> MigrationResult {
        guard !migrationInProgress else {
            throw MigrationError.migrationInProgress
        }

        migrationInProgress = true
        defer { migrationInProgress = false }

        var results = MigrationResult()

        do {
            // Step 1: Migrate legacy CategorizationRules
            let legacyRules = try await fetchLegacyRules()
            for legacyRule in legacyRules {
                if let newRule = migrateLegacyRule(legacyRule) {
                    modelContext.insert(newRule)
                    results.migratedLegacy += 1
                } else {
                    results.failed.append("Failed to migrate legacy rule: \(legacyRule.pattern)")
                }
            }

            // Step 2: Migrate enhanced CategorizationRules
            let enhancedRules = try await fetchEnhancedRules()
            for enhancedRule in enhancedRules {
                if let newRule = migrateEnhancedRule(enhancedRule) {
                    modelContext.insert(newRule)
                    results.migratedEnhanced += 1
                } else {
                    results.failed.append("Failed to migrate enhanced rule: \(enhancedRule.name)")
                }
            }

            // Step 3: Save new rules
            try modelContext.save()
            results.success = true

            // Step 4: Remove old rules (only after successful save)
            for rule in legacyRules {
                modelContext.delete(rule)
            }
            for rule in enhancedRules {
                modelContext.delete(rule)
            }

            try modelContext.save()

            return results

        } catch {
            // Rollback on failure
            modelContext.rollback()
            throw MigrationError.migrationFailed(error)
        }
    }

    // MARK: - Legacy Rule Migration

    /// Convert old CategorizationRule to new unified system
    private func migrateLegacyRule(_ legacyRule: LegacyCategorizationRule) -> CategorizationRule? {
        // Create a condition from the legacy pattern
        let condition = RuleCondition(
            field: .description, // Legacy rules primarily matched description
            operatorType: mapLegacyMatchType(legacyRule.matchType),
            value: legacyRule.pattern
        )

        let newRule = CategorizationRule(
            name: generateRuleName(from: legacyRule.pattern),
            targetCategory: legacyRule.targetCategory,
            conditions: [condition],
            logicalOperator: .and,
            priority: legacyRule.priority,
            isActive: legacyRule.isActive,
            notes: legacyRule.notes,
            standardizedName: legacyRule.standardizedName
        )

        // Preserve statistics
        newRule.matchCount = legacyRule.matchCount
        newRule.lastMatchedAt = legacyRule.lastMatchedAt
        newRule.createdAt = legacyRule.createdAt
        newRule.modifiedAt = legacyRule.modifiedAt

        return newRule
    }

    /// Convert enhanced rule to new unified system
    private func migrateEnhancedRule(_ enhancedRule: EnhancedCategorizationRule) -> CategorizationRule? {
        var conditions: [RuleCondition] = []

        // Handle simple enhanced rules
        if enhancedRule.tier == .simple, let simpleConfig = enhancedRule.simpleConfig {
            let condition = RuleCondition(
                field: mapTargetField(simpleConfig.targetField),
                operator: mapMatchType(simpleConfig.matchType),
                value: simpleConfig.pattern
            )
            conditions.append(condition)

            // Add amount filters if present
            if let minAmount = simpleConfig.amountMin {
                let amountCondition = RuleCondition(
                    field: .amount,
                    operator: .greaterThan,
                    value: String(minAmount)
                )
                conditions.append(amountCondition)
            }

            if let maxAmount = simpleConfig.amountMax {
                let amountCondition = RuleCondition(
                    field: .amount,
                    operator: .lessThan,
                    value: String(maxAmount)
                )
                conditions.append(amountCondition)
            }

            // Add account filter if present
            if let accountFilter = simpleConfig.accountFilter {
                let accountCondition = RuleCondition(
                    field: .account,
                    operator: .equals,
                    value: accountFilter
                )
                conditions.append(accountCondition)
            }
        }

        // Handle advanced enhanced rules
        else if enhancedRule.tier == .advanced {
            // Convert existing RuleConditions to new format
            for existingCondition in enhancedRule.conditions {
                let newCondition = RuleCondition(
                    field: mapRuleField(existingCondition.field),
                    operatorType: mapRuleOperator(existingCondition.operator),
                    value: existingCondition.value,
                    sortOrder: existingCondition.sortOrder
                )
                conditions.append(newCondition)
            }
        }

        // Fallback: create a basic description condition
        if conditions.isEmpty {
            let condition = RuleCondition(
                field: .description,
                operator: .contains,
                value: enhancedRule.name.lowercased()
            )
            conditions.append(condition)
        }

        let newRule = CategorizationRule(
            name: enhancedRule.name,
            targetCategory: enhancedRule.targetCategory,
            conditions: conditions,
            logicalOperator: conditions.count > 1 ? .and : .and, // Default to AND
            priority: enhancedRule.priority,
            isActive: enhancedRule.isActive,
            notes: enhancedRule.notes
        )

        // Preserve statistics
        newRule.matchCount = enhancedRule.matchCount
        newRule.lastMatchedAt = enhancedRule.lastMatchedAt
        newRule.createdAt = enhancedRule.createdAt
        newRule.modifiedAt = enhancedRule.modifiedAt

        return newRule
    }

    // MARK: - Helper Methods

    /// Map legacy match types to new operators
    private func mapLegacyMatchType(_ matchType: RuleMatchType) -> ConditionOperator {
        switch matchType {
        case .contains: return .contains
        case .startsWith: return .startsWith
        case .endsWith: return .endsWith
        case .exact: return .equals
        case .regex: return .matches
        }
    }

    /// Map target fields from enhanced to new system
    private func mapTargetField(_ targetField: RuleTargetField) -> ConditionField {
        switch targetField {
        case .description: return .description
        case .counterName: return .counterParty
        case .counterIBAN: return .counterIBAN
        case .standardizedName: return .description // Map to description as fallback
        case .anyField: return .description // Default to description
        }
    }

    /// Map match types from enhanced to new system
    private func mapMatchType(_ matchType: RuleMatchType) -> ConditionOperator {
        return mapLegacyMatchType(matchType) // Same mapping
    }

    /// Map rule fields from enhanced to new system
    private func mapRuleField(_ field: RuleField) -> ConditionField {
        switch field {
        case .amount: return .amount
        case .description: return .description
        case .counterName: return .counterParty
        case .counterIBAN: return .counterIBAN
        case .account: return .account
        case .transactionType: return .transactionType
        case .date: return .date
        case .standardizedName: return .description
        case .transactionCode: return .transactionCode
        }
    }

    /// Map rule operators from enhanced to new system
    private func mapRuleOperator(_ operator: RuleOperator) -> ConditionOperator {
        switch `operator` {
        case .equals: return .equals
        case .contains: return .contains
        case .startsWith: return .startsWith
        case .endsWith: return .endsWith
        case .greaterThan: return .greaterThan
        case .lessThan: return .lessThan
        case .between: return .between
        case .matches: return .matches
        case .notEqual: return .equals // Map to equals and handle negation differently
        case .notContains: return .contains // Map to contains and handle negation differently
        }
    }

    /// Generate a friendly rule name from a pattern
    private func generateRuleName(from pattern: String) -> String {
        // Clean up the pattern for a user-friendly name
        let cleaned = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count <= 30 {
            return "Rule: \(cleaned)"
        } else {
            return "Rule: \(String(cleaned.prefix(27)))..."
        }
    }

    /// Fetch legacy rules from database
    private func fetchLegacyRules() async throws -> [LegacyCategorizationRule] {
        let descriptor = FetchDescriptor<LegacyCategorizationRule>()
        return try modelContext.fetch(descriptor)
    }

    /// Fetch enhanced rules from database
    private func fetchEnhancedRules() async throws -> [EnhancedCategorizationRule] {
        let descriptor = FetchDescriptor<EnhancedCategorizationRule>()
        return try modelContext.fetch(descriptor)
    }
}

// MARK: - Migration Data Types

/// Analysis of rules ready for migration
struct MigrationAnalysis {
    let legacyRulesCount: Int
    let enhancedRulesCount: Int
    let totalRules: Int
    let canMigrateAll: Bool
    let warnings: [String]
}

/// Results of migration execution
struct MigrationResult {
    var success = false
    var migratedLegacy = 0
    var migratedEnhanced = 0
    var failed: [String] = []

    var totalMigrated: Int {
        migratedLegacy + migratedEnhanced
    }
}

/// Errors that can occur during migration
enum MigrationError: Error, LocalizedError {
    case migrationInProgress
    case migrationFailed(Error)
    case noRulesToMigrate

    var errorDescription: String? {
        switch self {
        case .migrationInProgress:
            return "Migration is already in progress"
        case .migrationFailed(let error):
            return "Migration failed: \(error.localizedDescription)"
        case .noRulesToMigrate:
            return "No rules found to migrate"
        }
    }
}

// MARK: - Type Aliases for Legacy Models

/// Type alias to distinguish old CategorizationRule from new one during migration
typealias LegacyCategorizationRule = OldCategorizationRule

/// Temporary model representing the old CategorizationRule structure
struct OldCategorizationRule {
    let pattern: String
    let matchType: RuleMatchType
    let standardizedName: String?
    let targetCategory: String
    let priority: Int
    let isActive: Bool
    let notes: String?
    let matchCount: Int
    let lastMatchedAt: Date?
    let createdAt: Date
    let modifiedAt: Date
}
