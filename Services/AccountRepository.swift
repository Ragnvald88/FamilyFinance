//
//  AccountRepository.swift
//  Family Finance
//
//  Repository pattern for account data access
//  Provides caching and helper methods for transfer detection
//
//  Version 2.0: Complete family account list
//  Created: 2025-12-22
//

import Foundation
import SwiftData

/// Repository for account operations with caching.
///
/// **Features:**
/// - Lazy loading with caching
/// - Fast IBAN lookup for transfer detection
/// - Default account initialization
@MainActor
class AccountRepository: ObservableObject {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Cache

    @Published private(set) var accounts: [Account] = []
    private var knownIBANs: Set<String> = []

    // MARK: - Configuration
    // NOTE: Family IBANs are centralized in FamilyAccountsConfig.swift

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public Methods

    /// Fetch all accounts from database
    func fetchAccounts() throws {
        let descriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\Account.sortOrder)]
        )

        accounts = try modelContext.fetch(descriptor)
        knownIBANs = Set(accounts.map { $0.iban })

        // Also include static family IBANs in case not all are in database
        knownIBANs.formUnion(FamilyAccountsConfig.familyIBANs)
    }

    /// Check if IBAN belongs to a known family account.
    /// Checks both database accounts and static family IBAN list.
    func isKnownAccount(_ iban: String) -> Bool {
        // Fast path: check config first
        if FamilyAccountsConfig.isFamilyAccount(iban) {
            return true
        }
        // Then check cached database accounts
        return knownIBANs.contains(iban)
    }

    /// Get account by IBAN (database accounts only)
    func getAccount(iban: String) -> Account? {
        return accounts.first { $0.iban == iban }
    }

    /// Get account owner by IBAN
    func getAccountOwner(iban: String) -> String? {
        // Check database first
        if let account = getAccount(iban: iban) {
            return account.owner
        }

        // Fallback to centralized config
        return FamilyAccountsConfig.getOwner(for: iban)
    }

    /// Load default accounts if database is empty
    func loadDefaultAccountsIfNeeded() throws {
        let descriptor = FetchDescriptor<Account>()
        let existingCount = try modelContext.fetchCount(descriptor)

        guard existingCount == 0 else {
            print("✅ Accounts already loaded: \(existingCount) accounts")
            return
        }

        print("📦 Loading default accounts from config...")

        // Create accounts from centralized config
        for config in FamilyAccountsConfig.defaultAccounts {
            let accountType: AccountType = config.type == "savings" ? .savings : .checking
            let account = Account(
                iban: config.iban,
                name: config.name,
                accountType: accountType,
                owner: config.owner,
                isActive: true,
                color: config.color,
                sortOrder: config.sortOrder
            )
            modelContext.insert(account)
        }

        try modelContext.save()
        try fetchAccounts()

        print("✅ Loaded \(FamilyAccountsConfig.defaultAccounts.count) default accounts")
    }

    /// Refresh balances for all accounts (call after import)
    func refreshAllBalances() throws {
        for account in accounts {
            account.refreshBalance()
        }
        try modelContext.save()
    }
}
