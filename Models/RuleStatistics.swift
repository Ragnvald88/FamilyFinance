//
//  RuleStatistics.swift
//  Florijn
//
//  Separate statistics model to prevent write contention during rule processing
//  Data Engineering Lead recommendation for preventing performance issues
//
//  Features:
//  - Separate from Rule model to avoid write contention
//  - Tracks rule performance metrics
//  - Updated asynchronously to prevent blocking rule evaluation
//  - Supports rule optimization through hit rate analysis
//
//  Created: 2025-12-26
//

import SwiftData
import Foundation

// MARK: - Rule Statistics Model

@Model
final class RuleStatistics {

    /// Unique identifier matching Rule's persistentModelID hash
    /// Using @Attribute(.unique) for fast lookups and preventing duplicates
    @Attribute(.unique) var ruleIdentifier: String

    /// Total number of times this rule has matched transactions
    var matchCount: Int

    /// Last time this rule successfully matched a transaction
    var lastMatchedAt: Date?

    /// Average time to evaluate this rule in milliseconds
    /// Used for performance monitoring and optimization
    var averageEvaluationTimeMs: Double

    /// Last time this rule was processed during bulk operations
    /// Used to track rule usage patterns
    var lastBulkProcessedAt: Date?

    /// Total number of transactions this rule has been evaluated against
    /// Used to calculate match rate percentage
    var totalEvaluations: Int

    /// Number of errors encountered when executing this rule's actions
    /// Used for identifying problematic rules
    var errorCount: Int

    /// Timestamps for audit trail
    var createdAt: Date
    var modifiedAt: Date

    // MARK: - Computed Properties

    /// Match rate as a percentage (0-100)
    var matchRatePercentage: Double {
        guard totalEvaluations > 0 else { return 0 }
        return (Double(matchCount) / Double(totalEvaluations)) * 100
    }

    /// Error rate as a percentage (0-100)
    var errorRatePercentage: Double {
        guard matchCount > 0 else { return 0 }
        return (Double(errorCount) / Double(matchCount)) * 100
    }

    /// Is this rule performing well?
    var isPerformant: Bool {
        return averageEvaluationTimeMs < 10.0 && errorRatePercentage < 5.0
    }

    /// Is this rule frequently used?
    var isActivelyUsed: Bool {
        guard let lastMatch = lastMatchedAt else { return false }
        return Date().timeIntervalSince(lastMatch) < 7 * 24 * 3600 // Used in last 7 days
    }

    // MARK: - Initialization

    init(ruleIdentifier: String) {
        self.ruleIdentifier = ruleIdentifier
        self.matchCount = 0
        self.totalEvaluations = 0
        self.errorCount = 0
        self.averageEvaluationTimeMs = 0.0
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    // MARK: - Update Methods

    /// Record a successful match with evaluation timing
    func recordMatch(evaluationTimeMs: Double) {
        matchCount += 1
        lastMatchedAt = Date()
        modifiedAt = Date()

        // Update rolling average evaluation time
        let weight = 0.1 // Weight for exponential moving average
        averageEvaluationTimeMs = averageEvaluationTimeMs * (1 - weight) + evaluationTimeMs * weight
    }

    /// Record that this rule was evaluated (even if it didn't match)
    func recordEvaluation() {
        totalEvaluations += 1
        modifiedAt = Date()
    }

    /// Record an error during rule action execution
    func recordError() {
        errorCount += 1
        modifiedAt = Date()
    }

    /// Record bulk processing activity
    func recordBulkProcessing() {
        lastBulkProcessedAt = Date()
        modifiedAt = Date()
    }

    /// Reset statistics (useful for testing or rule optimization)
    func reset() {
        matchCount = 0
        totalEvaluations = 0
        errorCount = 0
        averageEvaluationTimeMs = 0.0
        lastMatchedAt = nil
        lastBulkProcessedAt = nil
        modifiedAt = Date()
    }
}

// MARK: - Extensions

extension RuleStatistics {

    /// Generate a summary string for debugging
    var debugSummary: String {
        return """
        Rule \(ruleIdentifier):
        - Matches: \(matchCount)/\(totalEvaluations) (\(String(format: "%.1f", matchRatePercentage))%)
        - Avg Time: \(String(format: "%.2f", averageEvaluationTimeMs))ms
        - Errors: \(errorCount) (\(String(format: "%.1f", errorRatePercentage))%)
        - Last Match: \(lastMatchedAt?.formatted() ?? "Never")
        """
    }
}