import Foundation
@preconcurrency import SwiftData

/// ModelActor for performing data operations on a background thread.
///
/// **Purpose:** Handle heavy import operations without blocking the main thread.
///
/// **Usage:**
/// ```swift
/// let handler = BackgroundDataHandler(modelContainer: container)
/// let result = await handler.importTransactions(from: csvData)
/// print("Imported \(result.imported), skipped \(result.duplicates) duplicates")
/// ```
///
/// **SwiftData Safety:**
/// - All operations run on a dedicated background context
/// - Never access modelContext from multiple threads
/// - Use async/await for all public methods
///
/// **Version 2.0:** Fixed race conditions, duplicate handling, and account relationships.
@ModelActor
actor BackgroundDataHandler {

    // MARK: - Account Cache (Race Condition Fix)

    /// In-memory cache of accounts by IBAN to prevent race conditions.
    /// This ensures fetchOrCreateAccount is atomic within a single import session.
    private var accountCache: [String: Account] = [:]

    // MARK: - Import Results

    /// Result of an import operation with detailed statistics.
    struct ImportResult: Sendable {
        let imported: Int
        let duplicates: Int
        let errors: Int
        let totalProcessed: Int

        var successRate: Double {
            guard totalProcessed > 0 else { return 0 }
            return Double(imported) / Double(totalProcessed) * 100
        }
    }

    /// Extended result including categorization statistics.
    /// Returned by importWithCategorization().
    struct ImportResultWithCategorization: Sendable {
        let imported: Int
        let duplicates: Int
        let errors: Int
        let totalProcessed: Int
        let categorized: Int
        let uncategorized: Int

        var successRate: Double {
            guard totalProcessed > 0 else { return 0 }
            return Double(imported) / Double(totalProcessed) * 100
        }

        var categorizationRate: Double {
            guard totalProcessed > 0 else { return 0 }
            return Double(categorized) / Double(totalProcessed) * 100
        }
    }

    // MARK: - Duplicate Detection Cache

    /// Pre-loaded unique keys for O(1) duplicate detection.
    /// Avoids O(n) database queries during import.
    private var existingUniqueKeys: Set<String> = []

    // MARK: - Transaction Import

    /// Import transactions from parsed CSV data with duplicate detection.
    /// - Parameter transactions: Array of transaction data to import
    /// - Returns: ImportResult with statistics on imported/skipped transactions
    /// - Throws: SwiftData errors if save fails
    func importTransactions(_ transactions: [TransactionImportData]) async throws -> ImportResult {
        var importedCount = 0
        var duplicateCount = 0
        var errorCount = 0

        // Adaptive batch size based on system resources (prevents OOM on large imports)
        let processorCount = ProcessInfo.processInfo.activeProcessorCount
        let batchSize = min(500, max(50, processorCount * 50))  // 50-500 range

        // Pre-load caches for O(1) lookups during import
        try await preloadAccountCache()
        try await preloadExistingUniqueKeys()

        // Ensure caches are cleared when we're done (prevents memory leak)
        defer {
            clearAccountCache()
            existingUniqueKeys.removeAll()
        }

        for batch in transactions.chunked(into: batchSize) {
            for data in batch {
                do {
                    // O(1) duplicate check using pre-loaded Set (critical performance fix)
                    // Uses new format: IBAN-YYYYMMDD-sequence
                    let uniqueKey = Transaction.generateUniqueKey(
                        iban: data.iban,
                        date: data.date,
                        sequenceNumber: data.sequenceNumber
                    )
                    if existingUniqueKeys.contains(uniqueKey) {
                        duplicateCount += 1
                        continue
                    }

                    // Get or create account (uses cache to prevent race condition)
                    let account = try await getOrCreateAccount(for: data.iban)

                    // Create transaction WITH account relationship (critical fix)
                    let transaction = Transaction(
                        iban: data.iban,
                        sequenceNumber: data.sequenceNumber,
                        date: data.date,
                        amount: data.amount,
                        balance: data.balance,
                        counterIBAN: data.counterIBAN,
                        counterName: data.counterName,
                        standardizedName: data.standardizedName,
                        description1: data.description1,
                        description2: data.description2,
                        description3: data.description3,
                        transactionCode: data.transactionCode,
                        valueDate: data.valueDate,
                        returnReason: data.returnReason,
                        mandateReference: data.mandateReference,
                        autoCategory: data.autoCategory,
                        transactionType: data.transactionType,
                        contributor: data.contributor,
                        sourceFile: data.sourceFile,
                        importBatchID: data.importBatchID,
                        account: account  // FIX: Set relationship!
                    )
                    modelContext.insert(transaction)
                    importedCount += 1

                    // Add to cache to catch duplicates within same import batch
                    existingUniqueKeys.insert(uniqueKey)
                } catch {
                    errorCount += 1
                    // Continue with next transaction, don't abort entire import
                }
            }

            // Save after each batch for memory efficiency
            try modelContext.save()
        }

        // Update cached balances for all affected accounts
        try await refreshAccountBalances()

        return ImportResult(
            imported: importedCount,
            duplicates: duplicateCount,
            errors: errorCount,
            totalProcessed: transactions.count
        )
    }

    /// Refreshes cached balance for all accounts after import
    private func refreshAccountBalances() async throws {
        let descriptor = FetchDescriptor<Account>()
        let accounts = try modelContext.fetch(descriptor)

        for account in accounts {
            account.refreshBalance()
        }
        try modelContext.save()
    }

    /// Pre-loads all existing accounts into cache to avoid N+1 queries.
    private func preloadAccountCache() async throws {
        let descriptor = FetchDescriptor<Account>()
        let accounts = try modelContext.fetch(descriptor)
        accountCache = Dictionary(uniqueKeysWithValues: accounts.map { ($0.iban, $0) })
    }

    /// Pre-loads existing transaction unique keys for O(1) duplicate detection.
    /// Uses batched loading to prevent memory exhaustion on large databases.
    /// This is critical for performance: converts O(n) queries to O(1) Set lookup.
    private func preloadExistingUniqueKeys() async throws {
        let batchSize = 5000
        var offset = 0
        existingUniqueKeys.removeAll()
        existingUniqueKeys.reserveCapacity(10000)  // Pre-allocate for typical database

        while true {
            var descriptor = FetchDescriptor<Transaction>()
            descriptor.fetchLimit = batchSize
            descriptor.fetchOffset = offset

            let batch = try modelContext.fetch(descriptor)
            if batch.isEmpty { break }

            // Extract unique keys and add to set
            existingUniqueKeys.formUnion(batch.map { $0.uniqueKey })

            offset += batchSize

            // Allow context to release batch from memory tracking
            // (SwiftData may still cache, but this signals we're done with this batch)
        }
    }

    /// Gets account from cache or creates new one. Thread-safe within actor.
    /// - Parameter iban: The IBAN to look up
    /// - Returns: Existing or newly created account
    private func getOrCreateAccount(for iban: String) async throws -> Account {
        // Check cache first (fast path)
        if let cached = accountCache[iban] {
            return cached
        }

        // Not in cache - check database
        let predicate = #Predicate<Account> { $0.iban == iban }
        var descriptor = FetchDescriptor<Account>(predicate: predicate)
        descriptor.fetchLimit = 1

        if let existing = try modelContext.fetch(descriptor).first {
            accountCache[iban] = existing
            return existing
        }

        // Create new account with default values
        let account = Account(
            iban: iban,
            name: "Imported Account \(iban.suffix(4))",
            accountType: .checking,
            owner: "Unknown"
        )
        modelContext.insert(account)
        try modelContext.save()

        // Add to cache to prevent duplicates in same import session
        accountCache[iban] = account
        return account
    }

    /// Check if a transaction already exists by unique key.
    /// - Parameter uniqueKey: The IBAN-SequenceNumber key to check
    /// - Returns: True if transaction exists
    func transactionExists(uniqueKey: String) async throws -> Bool {
        let predicate = #Predicate<Transaction> { $0.uniqueKey == uniqueKey }
        var descriptor = FetchDescriptor<Transaction>(predicate: predicate)
        descriptor.fetchLimit = 1
        let count = try modelContext.fetchCount(descriptor)
        return count > 0
    }

    /// Count total transactions in database.
    /// - Returns: Total transaction count
    func transactionCount() async throws -> Int {
        let descriptor = FetchDescriptor<Transaction>()
        return try modelContext.fetchCount(descriptor)
    }

    // MARK: - Account Operations

    /// Fetch or create an account by IBAN with atomic operation.
    /// Uses internal cache to prevent race conditions during bulk imports.
    /// - Parameters:
    ///   - iban: The account IBAN
    ///   - name: Account name if creating new
    ///   - type: Account type if creating new
    ///   - owner: Account owner if creating new
    /// - Returns: The existing or newly created account
    func fetchOrCreateAccount(
        iban: String,
        name: String,
        type: AccountType,
        owner: String
    ) async throws -> Account {
        // Check cache first
        if let cached = accountCache[iban] {
            return cached
        }

        // Check database
        let predicate = #Predicate<Account> { $0.iban == iban }
        var descriptor = FetchDescriptor<Account>(predicate: predicate)
        descriptor.fetchLimit = 1

        if let existing = try modelContext.fetch(descriptor).first {
            accountCache[iban] = existing
            return existing
        }

        // Create new - actor isolation ensures this is atomic
        let account = Account(
            iban: iban,
            name: name,
            accountType: type,
            owner: owner
        )
        modelContext.insert(account)
        try modelContext.save()

        // Cache the new account
        accountCache[iban] = account
        return account
    }

    /// Clears the account cache. Call this after a complete import session.
    func clearAccountCache() {
        accountCache.removeAll()
    }

    // MARK: - Category Operations

    /// Initialize default categories if none exist.
    func initializeDefaultCategoriesIfNeeded() async throws {
        let descriptor = FetchDescriptor<Category>()
        let count = try modelContext.fetchCount(descriptor)

        guard count == 0 else { return }

        // Expense categories with budgets
        let expenseCategories: [(String, Decimal)] = [
            ("Groceries", 800),
            ("Dining", 150),
            ("Shopping", 200),
            ("Transportation", 250),
            ("Utilities", 300),
            ("Housing", 1200),
            ("Insurance", 200),
            ("Healthcare", 100),
            ("Childcare", 500),
            ("Entertainment", 100),
            ("Home & Garden", 100),
            ("Taxes", 200),
            ("Debt Payments", 200),
            ("Bank Fees", 20),
            ("Subscriptions", 100),
            ("Uncategorized", 0)
        ]

        for (name, budget) in expenseCategories {
            let category = Category(
                name: name,
                type: .expense,
                monthlyBudget: budget
            )
            modelContext.insert(category)
        }

        // Income categories
        let incomeCategories = [
            "Salary",
            "Freelance",
            "Benefits",
            "Contribution Partner 1",
            "Contribution Partner 2",
            "Other Income"
        ]

        for name in incomeCategories {
            let category = Category(
                name: name,
                type: .income,
                monthlyBudget: 0
            )
            modelContext.insert(category)
        }

        // Transfer category
        let transfer = Category(
            name: "Internal Transfer",
            type: .transfer,
            monthlyBudget: 0
        )
        modelContext.insert(transfer)

        try modelContext.save()
    }

    // MARK: - Batch Delete

    /// Delete all transactions (for re-import).
    func deleteAllTransactions() async throws {
        try modelContext.delete(model: Transaction.self)
        try modelContext.save()
        clearAccountCache()
    }

    /// Delete transactions by import batch ID.
    /// - Parameter batchID: The batch ID to delete
    func deleteTransactionsBatch(_ batchID: UUID) async throws {
        let predicate = #Predicate<Transaction> { $0.importBatchID == batchID }
        try modelContext.delete(model: Transaction.self, where: predicate)
        try modelContext.save()
    }

    // MARK: - Recurring Transaction Detection

    /// Attempts to detect recurring transaction patterns from existing data.
    /// - Parameter minimumOccurrences: Minimum number of occurrences to consider recurring
    /// - Returns: Array of detected recurring patterns
    func detectRecurringPatterns(minimumOccurrences: Int = 3) async throws -> [RecurringTransactionCandidate] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\Transaction.date)]
        )
        let transactions = try modelContext.fetch(descriptor)

        // Group by counter party
        let grouped = Dictionary(grouping: transactions) { tx -> String in
            tx.standardizedName ?? tx.counterName ?? "Unknown"
        }

        var candidates: [RecurringTransactionCandidate] = []

        for (name, txList) in grouped {
            guard txList.count >= minimumOccurrences else { continue }

            // Calculate intervals between transactions
            let sortedDates = txList.map { $0.date }.sorted()
            var intervals: [Int] = []

            for i in 1..<sortedDates.count {
                let days = Calendar.current.dateComponents([.day], from: sortedDates[i-1], to: sortedDates[i]).day ?? 0
                intervals.append(days)
            }

            // Check if intervals are consistent (within 5 days tolerance)
            if let frequency = detectFrequency(from: intervals) {
                let amounts = txList.map { $0.amount }
                let avgAmount = amounts.reduce(Decimal.zero, +) / Decimal(amounts.count)

                candidates.append(RecurringTransactionCandidate(
                    name: name,
                    category: txList.first?.effectiveCategory ?? "Niet Gecategoriseerd",
                    averageAmount: avgAmount,
                    frequency: frequency,
                    occurrenceCount: txList.count,
                    counterIBAN: txList.first?.counterIBAN
                ))
            }
        }

        return candidates.sorted { $0.occurrenceCount > $1.occurrenceCount }
    }

    /// Detects the most likely frequency from a set of day intervals.
    private func detectFrequency(from intervals: [Int]) -> RecurrenceFrequency? {
        guard !intervals.isEmpty else { return nil }

        let _ = intervals.reduce(0, +) / intervals.count  // Average for potential future pattern analysis
        let tolerance = 5

        // Check for common patterns
        if intervals.allSatisfy({ abs($0 - 1) <= 1 }) { return .daily }
        if intervals.allSatisfy({ abs($0 - 7) <= tolerance }) { return .weekly }
        if intervals.allSatisfy({ abs($0 - 14) <= tolerance }) { return .biweekly }
        if intervals.allSatisfy({ abs($0 - 30) <= tolerance }) { return .monthly }
        if intervals.allSatisfy({ abs($0 - 91) <= tolerance * 2 }) { return .quarterly }
        if intervals.allSatisfy({ abs($0 - 365) <= tolerance * 3 }) { return .yearly }

        return nil
    }
}

// MARK: - Import Data Transfer Object

/// Data transfer object for importing transactions from CSV.
/// Used to pass data to BackgroundDataHandler without SwiftData dependencies.
struct TransactionImportData: Sendable {
    let iban: String
    let sequenceNumber: Int
    let date: Date
    let amount: Decimal
    let balance: Decimal
    let counterIBAN: String?
    let counterName: String?
    let standardizedName: String?
    let description1: String?
    let description2: String?
    let description3: String?
    let transactionCode: String?      // Rabobank code (bg, tb, bc, id, ei, cb, db, ba)
    let valueDate: Date?              // Rentedatum
    let returnReason: String?         // Reden retour
    let mandateReference: String?     // Machtigingskenmerk (SEPA mandate)
    let autoCategory: String?
    let transactionType: TransactionType
    let contributor: Contributor?
    let sourceFile: String?
    let importBatchID: UUID?
}

/// Candidate for a recurring transaction pattern.
struct RecurringTransactionCandidate: Sendable {
    let name: String
    let category: String
    let averageAmount: Decimal
    let frequency: RecurrenceFrequency
    let occurrenceCount: Int
    let counterIBAN: String?
}

// MARK: - Array Extension for Chunking

extension Array {
    /// Split array into chunks of specified size.
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
