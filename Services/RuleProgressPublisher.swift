//
//  RuleProgressPublisher.swift
//  Family Finance
//
//  Real-time progress reporting with 30fps throttling
//  UX Engineering Lead recommendation for maintaining UI responsiveness
//
//  Features:
//  - Frame-rate aware progress updates (30fps = 33ms intervals)
//  - Batched updates to prevent UI thread saturation
//  - Real-time rule match previews during processing
//  - Cooperative cancellation support
//  - Progressive error disclosure with severity levels
//  - Memory-efficient match preview management
//
//  Architecture: Three-layer system:
//  • UI Layer: Observes lightweight progress models
//  • Aggregation Layer: Batches updates at controlled frequency
//  • Processing Layer: Emits raw progress events
//
//  Created: 2025-12-26
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

    private var pendingProgress: RuleProcessingProgress?
    private var pendingMatches: [RuleMatchPreview] = []
    private var pendingErrors: [RuleProcessingError] = []
    private var updateTask: Task<Void, Never>?
    private var lastUpdateTime: Date = .distantPast

    /// UX Expert: Minimum interval between UI updates (30fps = 33ms)
    /// Ensures smooth animations without overwhelming the main thread
    private let minimumUpdateInterval: TimeInterval = 0.033

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
            await self.scheduleProgressUpdate(newProgress)
        }
    }

    /// Report a rule match for live preview during processing
    nonisolated func reportMatch(_ match: RuleMatchPreview) {
        Task { @MainActor in
            await self.scheduleMatchUpdate(match)
        }
    }

    /// Report an error encountered during processing
    nonisolated func reportError(_ error: RuleProcessingError) {
        Task { @MainActor in
            await self.scheduleErrorUpdate(error)
        }
    }

    /// Update processing state (state changes are immediate - low frequency)
    nonisolated func setState(_ newState: ProcessingState) {
        Task { @MainActor in
            withAnimation(DesignTokens.Animation.spring) {
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
        pendingProgress = nil
        pendingMatches = []
        pendingErrors = []
        isCancelled = false
        updateTask?.cancel()
        updateTask = nil
    }

    // MARK: - Private Update Scheduling (UX Expert: Frame-Rate Aware Batching)

    private func scheduleProgressUpdate(_ newProgress: RuleProcessingProgress) async {
        pendingProgress = newProgress
        scheduleFlush()
    }

    private func scheduleMatchUpdate(_ match: RuleMatchPreview) async {
        pendingMatches.append(match)

        // Memory management: Keep only recent matches
        if pendingMatches.count > maxRecentMatches {
            pendingMatches.removeFirst(pendingMatches.count - maxRecentMatches)
        }
        scheduleFlush()
    }

    private func scheduleErrorUpdate(_ error: RuleProcessingError) async {
        pendingErrors.append(error)

        // Memory management: Keep only recent errors
        if pendingErrors.count > maxDisplayErrors {
            pendingErrors.removeFirst()
        }
        scheduleFlush()
    }

    /// Central scheduling logic for frame-rate aware updates
    private func scheduleFlush() {
        // Cancel existing scheduled update
        updateTask?.cancel()

        let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdateTime)

        if timeSinceLastUpdate >= minimumUpdateInterval {
            // Enough time has passed since last update
            flushPendingUpdates()
        } else {
            // Schedule update for next available frame
            let delay = minimumUpdateInterval - timeSinceLastUpdate
            updateTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if !Task.isCancelled {
                    await MainActor.run {
                        self.flushPendingUpdates()
                    }
                }
            }
        }
    }

    /// Flush all pending updates in a single animation frame
    private func flushPendingUpdates() {
        lastUpdateTime = Date()

        // Batch all pending updates into a single animation to prevent frame drops
        withAnimation(DesignTokens.Animation.springFast) {
            // Update progress
            if let newProgress = pendingProgress {
                self.progress = newProgress
                pendingProgress = nil
            }

            // Update matches feed
            if !pendingMatches.isEmpty {
                var allMatches = recentMatches + pendingMatches
                if allMatches.count > maxRecentMatches {
                    allMatches = Array(allMatches.suffix(maxRecentMatches))
                }
                self.recentMatches = allMatches
                pendingMatches = []
            }

            // Update errors list
            if !pendingErrors.isEmpty {
                var allErrors = errors + pendingErrors
                if allErrors.count > maxDisplayErrors {
                    allErrors = Array(allErrors.suffix(maxDisplayErrors))
                }
                self.errors = allErrors
                pendingErrors = []
            }
        }
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

// MARK: - Convenience Extensions

extension Decimal {
    /// Format as currency string
    func toCurrencyString() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: self as NSDecimalNumber) ?? "€0.00"
    }
}