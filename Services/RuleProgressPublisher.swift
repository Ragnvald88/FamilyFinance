//
//  RuleProgressPublisher.swift
//  Family Finance
//
//  Real-time progress reporting for rule processing
//
//  Features:
//  - Real-time rule match previews during processing
//  - Cooperative cancellation support
//  - Memory-efficient match preview management (max 100 matches, 50 errors)
//

import Foundation
import Combine
import SwiftUI

// MARK: - Progress Publisher

/// Thread-safe progress publisher that throttles UI updates to maintain 60fps
/// Implements UX Engineering Lead recommendations for responsive progress reporting
@MainActor
final class RuleProgressPublisher: ObservableObject {

    // MARK: - Published State (UI-bound)

    @Published private(set) var state: ProcessingState = .idle
    @Published private(set) var progress: RuleProcessingProgress = .initial
    @Published private(set) var recentMatches: [RuleMatchPreview] = []
    @Published private(set) var errors: [RuleProcessingError] = []

    // MARK: - Processing State

    enum ProcessingState: Equatable, Sendable {
        case idle
        case preparing
        case evaluatingRules
        case applyingActions
        case savingResults
        case complete
        case cancelled
        case failed(String)

        var displayName: String {
            switch self {
            case .idle: return "Ready"
            case .preparing: return "Preparing rules..."
            case .evaluatingRules: return "Evaluating rules..."
            case .applyingActions: return "Applying actions..."
            case .savingResults: return "Saving results..."
            case .complete: return "Complete"
            case .cancelled: return "Cancelled"
            case .failed(let message): return "Failed: \(message)"
            }
        }

        var icon: String {
            switch self {
            case .idle: return "circle"
            case .preparing: return "gear"
            case .evaluatingRules: return "slider.horizontal.3"
            case .applyingActions: return "bolt.fill"
            case .savingResults: return "square.and.arrow.down"
            case .complete: return "checkmark.circle.fill"
            case .cancelled: return "xmark.circle"
            case .failed: return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .idle: return .secondary
            case .preparing: return .orange
            case .evaluatingRules: return .blue
            case .applyingActions: return .purple
            case .savingResults: return .green
            case .complete: return .green
            case .cancelled: return .orange
            case .failed: return .red
            }
        }

        var isActive: Bool {
            switch self {
            case .preparing, .evaluatingRules, .applyingActions, .savingResults:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Private State

    /// Maximum matches to keep in memory (prevent memory growth during bulk operations)
    private let maxRecentMatches = 100

    /// Maximum errors to display (prevent UI overflow)
    private let maxDisplayErrors = 50

    // MARK: - Cancellation Support (UX Expert: Cooperative Cancellation)

    private var cancellationContinuation: CheckedContinuation<Void, Never>?
    private(set) var isCancelled = false

    // MARK: - Public Interface

    /// Update progress from background processing
    /// Thread-safe - can be called from any thread or actor
    nonisolated func updateProgress(_ newProgress: RuleProcessingProgress) {
        Task { @MainActor in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                self.progress = newProgress
            }
        }
    }

    /// Report a rule match for live preview during processing
    nonisolated func reportMatch(_ match: RuleMatchPreview) {
        Task { @MainActor in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                self.recentMatches.append(match)
                // Memory management: Keep only recent matches
                if self.recentMatches.count > self.maxRecentMatches {
                    self.recentMatches = Array(self.recentMatches.suffix(self.maxRecentMatches))
                }
            }
        }
    }

    /// Report an error encountered during processing
    nonisolated func reportError(_ error: RuleProcessingError) {
        Task { @MainActor in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                self.errors.append(error)
                // Memory management: Keep only recent errors
                if self.errors.count > self.maxDisplayErrors {
                    self.errors = Array(self.errors.suffix(self.maxDisplayErrors))
                }
            }
        }
    }

    /// Update processing state (state changes are immediate - low frequency)
    nonisolated func setState(_ newState: ProcessingState) {
        Task { @MainActor in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.state = newState
            }
        }
    }

    /// Request cancellation of current operation
    func requestCancellation() {
        isCancelled = true
        setState(.cancelled)
        cancellationContinuation?.resume()
        cancellationContinuation = nil
    }

    /// Wait for cancellation request - used for cooperative cancellation
    nonisolated func checkCancellation() async throws {
        try Task.checkCancellation()

        // Check internal cancellation flag
        let cancelled = await self.isCancelled
        if cancelled {
            throw CancellationError()
        }
    }

    /// Reset state for new operation
    func reset() {
        state = .idle
        progress = .initial
        recentMatches = []
        errors = []
        isCancelled = false
    }
}

// MARK: - Progress Data Model

/// Detailed progress information for rule processing operations
struct RuleProcessingProgress: Equatable, Sendable {
    let totalTransactions: Int
    let processedTransactions: Int
    let totalRuleGroups: Int
    let currentRuleGroupIndex: Int
    let totalRules: Int
    let currentRuleIndex: Int
    let totalMatches: Int
    let totalActions: Int
    let currentBatchStart: Int
    let currentBatchEnd: Int
    let estimatedTimeRemaining: TimeInterval?
    let throughputTPS: Double // Transactions per second
    let startTime: Date

    static let initial = RuleProcessingProgress(
        totalTransactions: 0,
        processedTransactions: 0,
        totalRuleGroups: 0,
        currentRuleGroupIndex: 0,
        totalRules: 0,
        currentRuleIndex: 0,
        totalMatches: 0,
        totalActions: 0,
        currentBatchStart: 0,
        currentBatchEnd: 0,
        estimatedTimeRemaining: nil,
        throughputTPS: 0,
        startTime: Date()
    )

    /// Overall completion percentage (0-100)
    var percentageComplete: Double {
        guard totalTransactions > 0 else { return 0 }
        return Double(processedTransactions) / Double(totalTransactions) * 100
    }

    /// Current rule group completion percentage (0-100)
    var currentGroupPercentage: Double {
        guard totalRuleGroups > 0 else { return 0 }
        return Double(currentRuleGroupIndex) / Double(totalRuleGroups) * 100
    }

    /// Is processing complete?
    var isComplete: Bool {
        processedTransactions >= totalTransactions && totalTransactions > 0
    }

    /// Match rate as percentage
    var matchRatePercentage: Double {
        guard processedTransactions > 0 else { return 0 }
        return Double(totalMatches) / Double(processedTransactions) * 100
    }

    /// Elapsed processing time
    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
}

// MARK: - Rule Match Preview

/// Preview of a rule match for live display during processing
struct RuleMatchPreview: Identifiable, Equatable, Sendable {
    let id = UUID()
    let transactionDescription: String
    let transactionAmount: Decimal
    let ruleName: String
    let ruleGroupName: String?
    let actionTypes: [ActionType]
    let actionsSummary: String
    let timestamp: Date
    let matchConfidence: Double // 0.0 - 1.0

    static func == (lhs: RuleMatchPreview, rhs: RuleMatchPreview) -> Bool {
        lhs.id == rhs.id
    }

    /// Create from rule action result
    static func from(
        result: RuleActionResult,
        transaction: (description: String, amount: Decimal),
        ruleGroup: String? = nil,
        confidence: Double = 1.0
    ) -> RuleMatchPreview {
        return RuleMatchPreview(
            transactionDescription: transaction.description,
            transactionAmount: transaction.amount,
            ruleName: result.ruleName,
            ruleGroupName: ruleGroup,
            actionTypes: [result.actionType],
            actionsSummary: "\(result.actionType.displayName): \(result.actionValue)",
            timestamp: Date(),
            matchConfidence: confidence
        )
    }
}

// MARK: - Processing Error

/// Error encountered during rule processing with severity levels
struct RuleProcessingError: Identifiable, Equatable, Sendable {
    let id = UUID()
    let ruleName: String
    let ruleGroupName: String?
    let transactionDescription: String
    let errorMessage: String
    let errorCode: String?
    let timestamp: Date
    let severity: Severity
    let isRecoverable: Bool

    enum Severity: String, Sendable {
        case warning = "warning"
        case error = "error"
        case critical = "critical"

        var displayName: String {
            switch self {
            case .warning: return "Warning"
            case .error: return "Error"
            case .critical: return "Critical"
            }
        }

        var icon: String {
            switch self {
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            case .critical: return "exclamationmark.octagon"
            }
        }

        var color: Color {
            switch self {
            case .warning: return .orange
            case .error: return .red
            case .critical: return .red
            }
        }
    }

    static func == (lhs: RuleProcessingError, rhs: RuleProcessingError) -> Bool {
        lhs.id == rhs.id
    }

    /// Create a warning error
    static func warning(
        rule: String,
        ruleGroup: String? = nil,
        transaction: String,
        message: String,
        code: String? = nil
    ) -> RuleProcessingError {
        return RuleProcessingError(
            ruleName: rule,
            ruleGroupName: ruleGroup,
            transactionDescription: transaction,
            errorMessage: message,
            errorCode: code,
            timestamp: Date(),
            severity: .warning,
            isRecoverable: true
        )
    }

    /// Create an error
    static func error(
        rule: String,
        ruleGroup: String? = nil,
        transaction: String,
        message: String,
        code: String? = nil,
        recoverable: Bool = true
    ) -> RuleProcessingError {
        return RuleProcessingError(
            ruleName: rule,
            ruleGroupName: ruleGroup,
            transactionDescription: transaction,
            errorMessage: message,
            errorCode: code,
            timestamp: Date(),
            severity: .error,
            isRecoverable: recoverable
        )
    }

    /// Create a critical error
    static func critical(
        rule: String,
        ruleGroup: String? = nil,
        transaction: String,
        message: String,
        code: String? = nil
    ) -> RuleProcessingError {
        return RuleProcessingError(
            ruleName: rule,
            ruleGroupName: ruleGroup,
            transactionDescription: transaction,
            errorMessage: message,
            errorCode: code,
            timestamp: Date(),
            severity: .critical,
            isRecoverable: false
        )
    }
}

// Note: toCurrencyString() extension is defined in TransactionQueryService.swift