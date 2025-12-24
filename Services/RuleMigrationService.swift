//
//  RuleMigrationService.swift
//  Family Finance
//
//  Migration service for converting legacy CategorizationRule to EnhancedCategorizationRule
//  Provides smooth transition path with user review and approval
//
//  Migration Strategy:
//  1. Analyze existing rules and suggest enhanced equivalents
//  2. Present migration preview to user
//  3. Execute migration with rollback capability
//  4. Maintain both systems during transition period
//
//  Created: 2025-12-24
//

import Foundation
@preconcurrency import SwiftData

// MARK: - Migration Service

/// Service for migrating legacy categorization rules to the enhanced rule system.
/// Provides safe, reviewable migration with rollback capabilities.
@MainActor
class RuleMigrationService {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Migration State

    private var migrationInProgress = false
    private var migrationBackup: [CategorizationRule] = []

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Migration Analysis

    /// Analyze existing legacy rules and generate migration preview.
    func analyzeMigration() async throws -> MigrationAnalysis {
        let legacyRules = try await fetchLegacyRules()
        var analysis = MigrationAnalysis(
            totalLegacyRules: legacyRules.count,
            migratableToSimple: 0,
            requiresAdvanced: 0,
            hasConflicts: 0,
            suggestions: []
        )

        for rule in legacyRules {
            let suggestion = analyzeLegacyRule(rule)
            analysis.suggestions.append(suggestion)

            switch suggestion.recommendedTier {
            case .simple:
                analysis.migratableToSimple += 1
            case .advanced:
                analysis.requiresAdvanced += 1
            }

            if suggestion.hasConflicts {
                analysis.hasConflicts += 1
            }
        }

        // Check for existing enhanced rules that might conflict
        let existingEnhanced = try await fetchEnhancedRules()
        analysis.existingEnhancedRules = existingEnhanced.count

        return analysis
    }

    /// Analyze a single legacy rule and suggest enhanced equivalent.
    private func analyzeLegacyRule(_ legacyRule: CategorizationRule) -> RuleMigrationSuggestion {
        // Determine if rule can be migrated to simple or needs advanced
        let canMigrateToSimple = legacyRule.matchType != .regex &&
                               legacyRule.pattern.count < 100 &&
                               !legacyRule.pattern.contains("|") // No OR patterns

        var enhancedConfig: SimpleRuleConfig?
        var conflicts: [String] = []

        if canMigrateToSimple {
            // Map to enhanced simple rule
            let targetField: RuleTargetField = determineTargetField(from: legacyRule.pattern)

            enhancedConfig = SimpleRuleConfig(
                accountFilter: nil, // Legacy rules didn't support account filtering
                targetField: targetField,
                matchType: legacyRule.matchType,
                pattern: legacyRule.pattern,
                amountMin: nil, // Legacy rules didn't support amount filtering
                amountMax: nil,
                transactionTypeFilter: nil // Legacy rules didn't support type filtering
            )

            // Check for potential improvements
            if couldBenefitFromAccountFiltering(legacyRule) {
                conflicts.append("Could benefit from account-specific filtering")
            }

            if couldBenefitFromAmountFiltering(legacyRule) {
                conflicts.append("Could benefit from amount range filtering")
            }
        } else {
            conflicts.append("Complex pattern requires advanced rule builder")
        }

        return RuleMigrationSuggestion(
            legacyRule: legacyRule,
            recommendedTier: canMigrateToSimple ? .simple : .advanced,
            enhancedConfig: enhancedConfig,
            estimatedImprovement: calculateImprovementPotential(legacyRule),
            conflicts: conflicts,
            hasConflicts: !conflicts.isEmpty
        )
    }

    // MARK: - Migration Execution

    /// Execute migration based on user-approved suggestions.
    func executeMigration(_ approvedSuggestions: [RuleMigrationSuggestion]) async throws -> MigrationResult {
        guard !migrationInProgress else {
            throw MigrationError.migrationInProgress
        }

        migrationInProgress = true
        migrationBackup = try await fetchLegacyRules() // Backup before migration

        var result = MigrationResult(
            migratedCount: 0,
            skippedCount: 0,
            errorCount: 0,
            errors: []
        )

        do {
            for suggestion in approvedSuggestions {
                do {
                    try await migrateSingleRule(suggestion)
                    result.migratedCount += 1
                } catch {
                    result.errorCount += 1
                    result.errors.append("Failed to migrate '\(suggestion.legacyRule.pattern)': \(error.localizedDescription)")
                }
            }

            try modelContext.save()
            migrationInProgress = false

            return result
        } catch {
            // Rollback on failure
            try await rollbackMigration()
            throw error
        }
    }

    /// Migrate a single rule based on suggestion.
    private func migrateSingleRule(_ suggestion: RuleMigrationSuggestion) async throws {
        let legacyRule = suggestion.legacyRule

        // Create enhanced rule name
        let enhancedName = generateRuleName(from: legacyRule)

        // Check for name conflicts
        let existingEnhanced = try await fetchEnhancedRules()
        let nameExists = existingEnhanced.contains { $0.name == enhancedName }
        let finalName = nameExists ? "\(enhancedName) (Migrated)" : enhancedName

        // Create enhanced rule
        let enhancedRule = EnhancedCategorizationRule(
            name: finalName,
            targetCategory: legacyRule.targetCategory,
            tier: suggestion.recommendedTier,
            priority: legacyRule.priority,
            isActive: legacyRule.isActive,
            notes: generateMigrationNotes(legacyRule, suggestion),
            createdBy: "Migration Service"
        )

        // Configure based on tier
        switch suggestion.recommendedTier {
        case .simple:
            if let config = suggestion.enhancedConfig {
                enhancedRule.simpleConfig = config
            } else {
                throw MigrationError.invalidConfiguration
            }

        case .advanced:
            // Create advanced conditions for complex patterns
            try await createAdvancedConditions(for: enhancedRule, from: legacyRule)
        }

        // Preserve statistics
        enhancedRule.matchCount = legacyRule.matchCount
        enhancedRule.lastMatchedAt = legacyRule.lastMatchedAt
        enhancedRule.createdAt = legacyRule.createdAt

        modelContext.insert(enhancedRule)

        // Optionally deactivate legacy rule instead of deleting
        legacyRule.isActive = false
        legacyRule.notes = (legacyRule.notes ?? "") + " [Migrated to Enhanced Rule: \(finalName)]"
    }

    /// Create advanced conditions for complex legacy patterns.
    private func createAdvancedConditions(for enhancedRule: EnhancedCategorizationRule, from legacyRule: CategorizationRule) async throws {
        // For now, create a single condition that mimics the legacy behavior
        // Future enhancement: Parse complex patterns into multiple conditions

        let condition = RuleCondition(
            field: .description, // Legacy rules primarily matched on description
            operator: mapLegacyOperator(legacyRule.matchType),
            value: legacyRule.pattern,
            logicalConnector: nil,
            sortOrder: 0
        )

        condition.parentRule = enhancedRule
        modelContext.insert(condition)
    }

    // MARK: - Rollback and Recovery

    /// Rollback migration in case of failure.
    func rollbackMigration() async throws {
        guard migrationInProgress else {
            throw MigrationError.noMigrationToRollback
        }

        // Remove all enhanced rules created during this migration
        let enhancedRules = try await fetchEnhancedRules()
        let migratedRules = enhancedRules.filter {
            $0.createdBy == "Migration Service" &&
            $0.createdAt > Date().addingTimeInterval(-3600) // Last hour
        }

        for rule in migratedRules {
            modelContext.delete(rule)
        }

        // Restore legacy rules from backup
        for backupRule in migrationBackup {
            backupRule.isActive = true
            if let notes = backupRule.notes {
                backupRule.notes = notes.replacingOccurrences(of: " [Migrated to Enhanced Rule:", with: "")
                    .components(separatedBy: "]").first
            }
        }

        try modelContext.save()
        migrationInProgress = false
        migrationBackup = []
    }

    // MARK: - Helper Methods

    private func fetchLegacyRules() async throws -> [CategorizationRule] {
        let descriptor = FetchDescriptor<CategorizationRule>(
            sortBy: [SortDescriptor(\CategorizationRule.priority)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchEnhancedRules() async throws -> [EnhancedCategorizationRule] {
        let descriptor = FetchDescriptor<EnhancedCategorizationRule>(
            sortBy: [SortDescriptor(\EnhancedCategorizationRule.priority)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func determineTargetField(from pattern: String) -> RuleTargetField {
        // Analyze pattern to suggest best field target
        if pattern.contains("@") || pattern.contains("iban") {
            return .counterIBAN
        }

        if pattern.contains("ltd") || pattern.contains("bv") || pattern.contains("company") {
            return .counterName
        }

        // Default to any field (most flexible)
        return .anyField
    }

    private func couldBenefitFromAccountFiltering(_ rule: CategorizationRule) -> Bool {
        // Patterns that are very generic and could benefit from account-specific rules
        return rule.pattern.count < 5 ||
               ["ah", "bol", "ing"].contains(rule.pattern)
    }

    private func couldBenefitFromAmountFiltering(_ rule: CategorizationRule) -> Bool {
        // Categories that often have amount-based variations
        let amountSensitiveCategories = [
            "winkelen", "uit eten", "vervoer", "entertainment"
        ]
        return amountSensitiveCategories.contains {
            rule.targetCategory.lowercased().contains($0)
        }
    }

    private func calculateImprovementPotential(_ rule: CategorizationRule) -> Double {
        var score = 0.0

        // More specific patterns have higher improvement potential
        if rule.pattern.count > 10 {
            score += 0.3
        }

        // Frequently used rules benefit more from enhancement
        if rule.matchCount > 100 {
            score += 0.4
        }

        // Recent activity suggests active use
        if let lastMatch = rule.lastMatchedAt,
           lastMatch > Date().addingTimeInterval(-30 * 24 * 3600) { // Last 30 days
            score += 0.3
        }

        return min(1.0, score)
    }

    private func generateRuleName(from legacyRule: CategorizationRule) -> String {
        let category = legacyRule.targetCategory
        let pattern = legacyRule.pattern.prefix(20)

        if pattern.count <= 15 {
            return "\(category): \(pattern)"
        } else {
            return "\(category): \(pattern)..."
        }
    }

    private func generateMigrationNotes(_ legacyRule: CategorizationRule, _ suggestion: RuleMigrationSuggestion) -> String {
        var notes = "Migrated from legacy rule (Priority: \(legacyRule.priority))"

        if let originalNotes = legacyRule.notes {
            notes += "\nOriginal notes: \(originalNotes)"
        }

        if suggestion.hasConflicts {
            notes += "\nPotential improvements: \(suggestion.conflicts.joined(separator: ", "))"
        }

        return notes
    }

    private func mapLegacyOperator(_ matchType: RuleMatchType) -> RuleOperator {
        switch matchType {
        case .contains: return .contains
        case .startsWith: return .startsWith
        case .endsWith: return .endsWith
        case .exact: return .equals
        case .regex: return .matches
        }
    }
}

// MARK: - Migration Types

/// Analysis of legacy rules for migration planning.
struct MigrationAnalysis: Sendable {
    var totalLegacyRules: Int
    var migratableToSimple: Int
    var requiresAdvanced: Int
    var hasConflicts: Int
    var existingEnhancedRules: Int = 0
    var suggestions: [RuleMigrationSuggestion] = []

    /// Percentage of rules that can be easily migrated
    var simpleMigrationRate: Double {
        guard totalLegacyRules > 0 else { return 0 }
        return Double(migratableToSimple) / Double(totalLegacyRules)
    }

    /// Estimated migration effort
    var migrationComplexity: MigrationComplexity {
        let advancedRate = Double(requiresAdvanced) / Double(totalLegacyRules)

        if advancedRate > 0.5 {
            return .high
        } else if advancedRate > 0.2 {
            return .medium
        } else {
            return .low
        }
    }
}

/// Suggestion for migrating a single legacy rule.
struct RuleMigrationSuggestion: Sendable {
    let legacyRule: CategorizationRule
    let recommendedTier: RuleTier
    let enhancedConfig: SimpleRuleConfig?
    let estimatedImprovement: Double // 0.0 - 1.0
    let conflicts: [String]
    let hasConflicts: Bool

    /// User-friendly description of the migration
    var migrationDescription: String {
        switch recommendedTier {
        case .simple:
            if let config = enhancedConfig {
                return "Convert to simple rule with \(config.targetField.displayName) matching"
            } else {
                return "Convert to simple rule"
            }
        case .advanced:
            return "Convert to advanced rule (requires review)"
        }
    }

    /// Improvement benefits text
    var improvementDescription: String {
        if estimatedImprovement > 0.7 {
            return "High improvement potential"
        } else if estimatedImprovement > 0.4 {
            return "Moderate improvement potential"
        } else {
            return "Minor improvement potential"
        }
    }
}

/// Result of migration execution.
struct MigrationResult: Sendable {
    var migratedCount: Int
    var skippedCount: Int
    var errorCount: Int
    var errors: [String]

    var wasSuccessful: Bool {
        errorCount == 0
    }

    var successRate: Double {
        let total = migratedCount + skippedCount + errorCount
        guard total > 0 else { return 0 }
        return Double(migratedCount) / Double(total)
    }
}

/// Migration complexity assessment.
enum MigrationComplexity: String, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var displayName: String {
        switch self {
        case .low: return "Low (mostly automatic)"
        case .medium: return "Medium (some review required)"
        case .high: return "High (manual review recommended)"
        }
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}

/// Migration errors.
enum MigrationError: Error, LocalizedError {
    case migrationInProgress
    case noMigrationToRollback
    case invalidConfiguration
    case backupFailed

    var errorDescription: String? {
        switch self {
        case .migrationInProgress:
            return "A migration is already in progress"
        case .noMigrationToRollback:
            return "No migration in progress to rollback"
        case .invalidConfiguration:
            return "Invalid rule configuration during migration"
        case .backupFailed:
            return "Failed to create backup before migration"
        }
    }
}