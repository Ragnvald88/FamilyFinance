//
//  DataIntegrityService.swift
//  Family Finance
//
//  Ensures data integrity across the application.
//  - Validates denormalized fields on app launch
//  - Refreshes account balances after manual edits
//  - Detects and fixes orphaned data
//
//  Created: 2025-12-23
//

import Foundation
import SwiftData

// MARK: - Data Integrity Service

/// Service responsible for maintaining data consistency.
/// Call `performStartupValidation()` on app launch.
@MainActor
class DataIntegrityService: ObservableObject {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Published State

    @Published var lastValidationDate: Date?
    @Published var issuesFound: Int = 0
    @Published var issuesFixed: Int = 0

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Startup Validation

    /// Performs all data integrity checks on app startup.
    /// This is a fast operation - only checks/fixes desync issues.
    func performStartupValidation() async throws -> ValidationReport {
        var report = ValidationReport()

        // 1. Migrate legacy uniqueKeys (v1.x → v2.x format)
        let keyMigrations = try await migrateUniqueKeys()
        report.uniqueKeyMigrations = keyMigrations

        // 2. Validate denormalized transaction fields (year/month/indexedCategory)
        let transactionFixes = try await validateTransactionDenormalizedFields()
        report.transactionFieldsFixes = transactionFixes

        // 3. Refresh account balances
        let accountFixes = try await refreshAllAccountBalances()
        report.accountBalanceFixes = accountFixes

        // 4. Check for orphaned splits (future enhancement)
        // let orphanedSplits = try await checkOrphanedSplits()
        // report.orphanedSplitsRemoved = orphanedSplits

        report.completedAt = Date()
        lastValidationDate = report.completedAt
        issuesFound = report.totalIssuesFound
        issuesFixed = report.totalIssuesFixed

        return report
    }

    // MARK: - Transaction Validation

    /// Validates that all transactions have correct denormalized fields.
    /// SwiftData may bypass `didSet` during internal operations, so we check on startup.
    private func validateTransactionDenormalizedFields() async throws -> Int {
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try modelContext.fetch(descriptor)

        let calendar = Calendar.current
        var fixedCount = 0

        for transaction in transactions {
            var needsFix = false

            // Check year
            let expectedYear = calendar.component(.year, from: transaction.date)
            if transaction.year != expectedYear {
                needsFix = true
            }

            // Check month
            let expectedMonth = calendar.component(.month, from: transaction.date)
            if transaction.month != expectedMonth {
                needsFix = true
            }

            // Check indexed category
            let expectedCategory = transaction.categoryOverride ?? transaction.autoCategory ?? "Niet Gecategoriseerd"
            if transaction.indexedCategory != expectedCategory {
                needsFix = true
            }

            if needsFix {
                transaction.syncDenormalizedFields()
                fixedCount += 1
            }
        }

        if fixedCount > 0 {
            try modelContext.save()
            print("DataIntegrity: Fixed \(fixedCount) transactions with desync'd fields")
        }

        return fixedCount
    }

    // MARK: - Account Balance Refresh

    /// Refreshes cached balances for all accounts.
    /// Call this after any transaction modification.
    private func refreshAllAccountBalances() async throws -> Int {
        let descriptor = FetchDescriptor<Account>()
        let accounts = try modelContext.fetch(descriptor)

        var refreshedCount = 0

        for account in accounts {
            let oldBalance = account.cachedBalance
            account.refreshBalance()

            if oldBalance != account.cachedBalance {
                refreshedCount += 1
            }
        }

        if refreshedCount > 0 {
            try modelContext.save()
            print("DataIntegrity: Refreshed \(refreshedCount) account balances")
        }

        return refreshedCount
    }

    /// Refresh balance for a specific account.
    /// Call this after modifying transactions for that account.
    func refreshAccountBalance(for iban: String) async throws {
        let predicate = #Predicate<Account> { $0.iban == iban }
        var descriptor = FetchDescriptor<Account>(predicate: predicate)
        descriptor.fetchLimit = 1

        if let account = try modelContext.fetch(descriptor).first {
            account.refreshBalance()
            try modelContext.save()
        }
    }

    /// Refresh balances for multiple accounts.
    /// More efficient than calling refreshAccountBalance multiple times.
    func refreshAccountBalances(for ibans: Set<String>) async throws {
        let descriptor = FetchDescriptor<Account>()
        let accounts = try modelContext.fetch(descriptor)

        for account in accounts where ibans.contains(account.iban) {
            account.refreshBalance()
        }

        try modelContext.save()
    }

    // MARK: - Unique Key Migration

    /// Migrates transactions from legacy uniqueKey format to new format.
    /// Legacy: "IBAN-sequence" (e.g., "NL00BANK0123456001-42")
    /// New: "IBAN-YYYYMMDD-sequence" (e.g., "NL00BANK0123456001-20251223-42")
    ///
    /// This is safe to run multiple times - already-migrated transactions are skipped.
    func migrateUniqueKeys() async throws -> Int {
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try modelContext.fetch(descriptor)

        var migratedCount = 0

        for transaction in transactions {
            let expectedKey = Transaction.generateUniqueKey(
                iban: transaction.iban,
                date: transaction.date,
                sequenceNumber: transaction.sequenceNumber
            )

            // Check if migration is needed (key doesn't match expected format)
            if transaction.uniqueKey != expectedKey {
                // Check if this is a legacy format (IBAN-sequence only)
                let legacyKey = Transaction.generateLegacyUniqueKey(
                    iban: transaction.iban,
                    sequenceNumber: transaction.sequenceNumber
                )

                if transaction.uniqueKey == legacyKey {
                    // This is a legacy key, migrate it
                    transaction.uniqueKey = expectedKey
                    migratedCount += 1
                }
                // If it's neither legacy nor expected, leave it alone (manual data)
            }
        }

        if migratedCount > 0 {
            try modelContext.save()
            print("DataIntegrity: Migrated \(migratedCount) transactions to new uniqueKey format")
        }

        return migratedCount
    }

    // MARK: - Transaction Edit Support

    /// Call this after manually editing a transaction.
    /// Handles all necessary updates (balance, category sync, etc.)
    func transactionDidUpdate(_ transaction: Transaction) async throws {
        // Ensure denormalized fields are synced
        transaction.syncDenormalizedFields()

        // Refresh the account balance
        if let account = transaction.account {
            account.refreshBalance()
        } else if !transaction.iban.isEmpty {
            try await refreshAccountBalance(for: transaction.iban)
        }

        try modelContext.save()
    }

    /// Call this after deleting a transaction.
    /// Updates account balance for the affected account.
    func transactionDidDelete(iban: String) async throws {
        try await refreshAccountBalance(for: iban)
    }

    /// Call this after bulk transaction modifications.
    /// More efficient than individual updates.
    func transactionsDidChange(affectedIBANs: Set<String>) async throws {
        try await refreshAccountBalances(for: affectedIBANs)
    }
}

// MARK: - Validation Report

/// Report of data integrity validation results.
struct ValidationReport {
    var uniqueKeyMigrations: Int = 0
    var transactionFieldsFixes: Int = 0
    var accountBalanceFixes: Int = 0
    var orphanedSplitsRemoved: Int = 0
    var completedAt: Date?

    var totalIssuesFound: Int {
        uniqueKeyMigrations + transactionFieldsFixes + accountBalanceFixes + orphanedSplitsRemoved
    }

    var totalIssuesFixed: Int {
        totalIssuesFound  // Currently all issues are fixed
    }

    var hasIssues: Bool {
        totalIssuesFound > 0
    }

    var summary: String {
        if !hasIssues {
            return "All data is consistent"
        }
        var parts: [String] = []
        if uniqueKeyMigrations > 0 {
            parts.append("\(uniqueKeyMigrations) unique key(s) migrated to new format")
        }
        if transactionFieldsFixes > 0 {
            parts.append("\(transactionFieldsFixes) transaction field(s) synced")
        }
        if accountBalanceFixes > 0 {
            parts.append("\(accountBalanceFixes) account balance(s) refreshed")
        }
        if orphanedSplitsRemoved > 0 {
            parts.append("\(orphanedSplitsRemoved) orphaned split(s) removed")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Transaction Extension for Edit Support

extension Transaction {
    /// Convenience method to update a transaction with automatic integrity handling.
    /// Use this instead of direct property modification when editing through UI.
    @MainActor
    func updateWithIntegrity(
        in context: ModelContext,
        categoryOverride: String? = nil,
        notes: String? = nil
    ) async throws {
        if let newCategory = categoryOverride {
            updateCategoryOverride(newCategory, reason: "Manual edit")
        }

        if let newNotes = notes {
            self.notes = newNotes
        }

        // Ensure all denormalized fields are synced
        syncDenormalizedFields()

        // Refresh account balance if we have an account
        if let account = account {
            account.refreshBalance()
        }

        try context.save()
    }
}
