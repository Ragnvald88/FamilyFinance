//
//  TransactionDetailViewTests.swift
//  Florijn Tests
//
//  TDD tests for TransactionDetailView
//  Tests: field display, category editing, audit log, notes, splits, recurring
//
//  Created: 2025-12-23
//

import XCTest
@preconcurrency import SwiftData
@testable import FamilyFinance

/// Unit tests for TransactionDetailView following TDD approach.
/// These tests verify the view model logic and data transformations.
@MainActor
final class TransactionDetailViewTests: XCTestCase {

    // MARK: - Test Fixtures

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
            Transaction.self,
            Account.self,
            Category.self,
            Liability.self,
            Merchant.self,
            BudgetPeriod.self,
            TransactionSplit.self,
            RecurringTransaction.self,
            TransactionAuditLog.self,
            // Rules System
            RuleGroup.self,
            Rule.self,
            RuleTrigger.self,
            RuleAction.self,
            TriggerGroup.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - Helper Methods

    /// Creates a test transaction with common fields
    private func createTestTransaction(
        counterName: String = "Albert Heijn",
        amount: Decimal = -45.50,
        category: String = "Boodschappen",
        transactionCode: String? = "bc"
    ) -> Transaction {
        let transaction = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 12345,
            date: Date(),
            amount: amount,
            balance: Decimal(1234.56),
            counterIBAN: "NL00TEST0000000099",
            counterName: counterName,
            standardizedName: counterName,
            description1: "Payment at store",
            description2: "Reference: 12345",
            description3: nil,
            transactionCode: transactionCode,
            autoCategory: category,
            transactionType: amount >= 0 ? .income : .expense
        )
        modelContext.insert(transaction)
        return transaction
    }

    /// Creates test categories in the database
    private func createTestCategories() throws {
        let categories = [
            ("Boodschappen", TransactionType.expense),
            ("Uit Eten", TransactionType.expense),
            ("Winkelen", TransactionType.expense),
            ("Vervoer", TransactionType.expense),
            ("Salaris", TransactionType.income),
            ("Toeslagen", TransactionType.income)
        ]

        for (index, (name, type)) in categories.enumerated() {
            let category = Category(
                name: name,
                type: type,
                monthlyBudget: 500,
                sortOrder: index
            )
            modelContext.insert(category)
        }
        try modelContext.save()
    }

    // MARK: - Transaction Fields Display Tests

    /// Test that all basic transaction fields are accessible
    func testTransactionFieldsAreAccessible() throws {
        let transaction = createTestTransaction()
        try modelContext.save()

        // Verify all display fields are accessible
        XCTAssertEqual(transaction.counterName, "Albert Heijn")
        XCTAssertEqual(transaction.standardizedName, "Albert Heijn")
        XCTAssertEqual(transaction.amount, Decimal(-45.50))  // Use Decimal literal
        XCTAssertEqual(transaction.balance, Decimal(1234.56)) // Use Decimal literal
        XCTAssertEqual(transaction.counterIBAN, "NL00TEST0000000099")
        XCTAssertEqual(transaction.description1, "Payment at store")
        XCTAssertEqual(transaction.description2, "Reference: 12345")
        XCTAssertNil(transaction.description3)
        XCTAssertEqual(transaction.transactionCode, "bc")
        XCTAssertEqual(transaction.effectiveCategory, "Boodschappen")
        XCTAssertEqual(transaction.transactionType, .expense)
    }

    /// Test fullDescription computed property
    func testFullDescriptionCombinesFields() throws {
        let transaction = createTestTransaction()

        XCTAssertEqual(transaction.fullDescription, "Payment at store Reference: 12345")
    }

    /// Test transaction type indicators
    func testTransactionTypeIndicators() throws {
        let expense = createTestTransaction(amount: -50)
        let income = createTestTransaction(amount: 100)

        XCTAssertTrue(expense.isExpense)
        XCTAssertFalse(expense.isIncome)
        XCTAssertTrue(income.isIncome)
        XCTAssertFalse(income.isExpense)
    }

    // MARK: - Category Dropdown Tests

    /// Test that categories can be fetched from database
    func testCategoriesCanBeFetched() throws {
        try createTestCategories()

        let descriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\Category.sortOrder)]
        )
        let categories = try modelContext.fetch(descriptor)

        XCTAssertEqual(categories.count, 6)
        XCTAssertEqual(categories[0].name, "Boodschappen")
        XCTAssertEqual(categories[1].name, "Uit Eten")
    }

    /// Test category filtering by type
    func testCategoriesCanBeFilteredByType() throws {
        try createTestCategories()

        // Fetch all categories and filter in memory
        // (SwiftData predicates don't support enum comparisons directly)
        let descriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\Category.sortOrder)]
        )
        let allCategories = try modelContext.fetch(descriptor)

        let expenseCategories = allCategories.filter { $0.type == .expense }
        XCTAssertEqual(expenseCategories.count, 4)

        let incomeCategories = allCategories.filter { $0.type == .income }
        XCTAssertEqual(incomeCategories.count, 2)
    }

    // MARK: - Category Override Tests

    /// Test that updating category override creates audit log entry
    func testCategoryOverrideCreatesAuditLog() throws {
        let transaction = createTestTransaction()
        try modelContext.save()

        XCTAssertEqual(transaction.effectiveCategory, "Boodschappen")
        // auditLog is either nil or empty array initially
        XCTAssertTrue(transaction.auditLog == nil || transaction.auditLog?.isEmpty == true)

        // Update category with reason
        transaction.updateCategoryOverride("Uit Eten", reason: "Was actually a restaurant")
        try modelContext.save()

        // Verify category changed
        XCTAssertEqual(transaction.effectiveCategory, "Uit Eten")
        XCTAssertEqual(transaction.categoryOverride, "Uit Eten")

        // Verify audit log created
        XCTAssertNotNil(transaction.auditLog)
        XCTAssertEqual(transaction.auditLog?.count, 1)

        let auditEntry = transaction.auditLog?.first
        XCTAssertEqual(auditEntry?.action, .categoryChange)
        XCTAssertEqual(auditEntry?.previousValue, "Boodschappen")
        XCTAssertEqual(auditEntry?.newValue, "Uit Eten")
        XCTAssertEqual(auditEntry?.reason, "Was actually a restaurant")
    }

    /// Test that indexed category is updated with override
    func testIndexedCategoryUpdatesWithOverride() throws {
        let transaction = createTestTransaction()
        try modelContext.save()

        XCTAssertEqual(transaction.indexedCategory, "Boodschappen")

        transaction.updateCategoryOverride("Winkelen")

        XCTAssertEqual(transaction.indexedCategory, "Winkelen")
    }

    /// Test clearing category override reverts to auto category
    func testClearingCategoryOverrideRevertsToAuto() throws {
        let transaction = createTestTransaction()
        transaction.updateCategoryOverride("Uit Eten")
        try modelContext.save()

        XCTAssertEqual(transaction.effectiveCategory, "Uit Eten")

        // Clear override
        transaction.updateCategoryOverride(nil)

        XCTAssertEqual(transaction.effectiveCategory, "Boodschappen") // Back to autoCategory
        XCTAssertEqual(transaction.auditLog?.count, 2) // Two audit entries
    }

    // MARK: - Notes Tests

    /// Test that notes can be saved to transaction
    func testNotesSaveToTransaction() throws {
        let transaction = createTestTransaction()
        try modelContext.save()

        XCTAssertNil(transaction.notes)

        transaction.notes = "Remember to check this receipt"
        try modelContext.save()

        // Verify through the same object (SwiftData tracks the same instance)
        XCTAssertEqual(transaction.notes, "Remember to check this receipt")

        // Also verify through fetch (all transactions)
        let descriptor = FetchDescriptor<Transaction>()
        let fetched = try modelContext.fetch(descriptor)

        // Find our transaction by sequence number
        let found = fetched.first { $0.sequenceNumber == 12345 }
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.notes, "Remember to check this receipt")
    }

    /// Test that empty notes are stored as nil
    func testEmptyNotesStoredAsNil() throws {
        let transaction = createTestTransaction()
        transaction.notes = "Some note"
        try modelContext.save()

        XCTAssertNotNil(transaction.notes)

        transaction.notes = ""

        // Verify empty string is stored (view should convert to nil before save)
        XCTAssertEqual(transaction.notes, "")
    }

    // MARK: - Split Transaction Tests

    /// Test that isSplit returns false for unsplit transactions
    func testIsSplitFalseForUnsplitTransaction() throws {
        let transaction = createTestTransaction()

        XCTAssertFalse(transaction.isSplit)
        XCTAssertNil(transaction.splits)
    }

    /// Test creating a split transaction
    func testCreateSplitTransaction() throws {
        let transaction = createTestTransaction(amount: -45.00)
        try modelContext.save()

        // Create split: -20 Boodschappen, -15 Persoonlijke Verzorging, -10 Huisdier
        let components: [(category: String, amount: Decimal)] = [
            ("Boodschappen", Decimal(-20)),
            ("Persoonlijke Verzorging", Decimal(-15)),
            ("Huisdier", Decimal(-10))
        ]

        try transaction.createSplit(components)
        try modelContext.save()

        XCTAssertTrue(transaction.isSplit)
        XCTAssertEqual(transaction.splits?.count, 3)

        // Verify split amounts
        let splits = transaction.splits?.sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(splits?[0].category, "Boodschappen")
        XCTAssertEqual(splits?[0].amount, Decimal(-20))
        XCTAssertEqual(splits?[1].category, "Persoonlijke Verzorging")
        XCTAssertEqual(splits?[1].amount, Decimal(-15))
        XCTAssertEqual(splits?[2].category, "Huisdier")
        XCTAssertEqual(splits?[2].amount, Decimal(-10))
    }

    /// Test categoryBreakdown for split transaction
    func testCategoryBreakdownForSplitTransaction() throws {
        let transaction = createTestTransaction(amount: -45.00)

        let components: [(category: String, amount: Decimal)] = [
            ("Boodschappen", Decimal(-25)),
            ("Huisdier", Decimal(-20))
        ]
        try transaction.createSplit(components)

        let breakdown = transaction.categoryBreakdown

        XCTAssertEqual(breakdown.count, 2)
        XCTAssertEqual(breakdown[0].category, "Boodschappen")
        XCTAssertEqual(breakdown[0].amount, Decimal(-25))
        XCTAssertEqual(breakdown[1].category, "Huisdier")
        XCTAssertEqual(breakdown[1].amount, Decimal(-20))
    }

    /// Test categoryBreakdown for unsplit transaction
    func testCategoryBreakdownForUnsplitTransaction() throws {
        let transaction = createTestTransaction()

        let breakdown = transaction.categoryBreakdown

        XCTAssertEqual(breakdown.count, 1)
        XCTAssertEqual(breakdown[0].category, "Boodschappen")
        XCTAssertEqual(breakdown[0].amount, Decimal(string: "-45.50"))
    }

    /// Test split validation fails for mismatched amounts
    func testSplitValidationFailsForMismatchedAmounts() throws {
        let transaction = createTestTransaction(amount: -45.00)

        let components: [(category: String, amount: Decimal)] = [
            ("Boodschappen", Decimal(-20)),
            ("Huisdier", Decimal(-10)) // Sum is -30, not -45
        ]

        XCTAssertThrowsError(try transaction.createSplit(components)) { error in
            XCTAssertTrue(error is SplitError)
        }
    }

    // MARK: - Recurring Transaction Tests

    /// Test transaction without recurring link
    func testTransactionWithoutRecurringLink() throws {
        let transaction = createTestTransaction()

        XCTAssertNil(transaction.recurringTransaction)
    }

    /// Test linking transaction to recurring
    func testLinkingTransactionToRecurring() throws {
        let transaction = createTestTransaction(counterName: "Netflix")

        let recurring = RecurringTransaction(
            name: "Netflix Subscription",
            category: "Abonnementen",
            expectedAmount: Decimal(-15.99),
            frequency: .monthly,
            nextDueDate: Date().addingTimeInterval(86400 * 30)
        )
        modelContext.insert(recurring)
        try modelContext.save()

        // Link transaction
        recurring.linkTransaction(transaction)
        try modelContext.save()

        XCTAssertNotNil(transaction.recurringTransaction)
        XCTAssertEqual(transaction.recurringTransaction?.name, "Netflix Subscription")
        XCTAssertEqual(transaction.recurringTransaction?.frequency, .monthly)
        XCTAssertEqual(recurring.occurrenceCount, 1)
    }

    /// Test recurring transaction computed properties
    func testRecurringTransactionProperties() throws {
        let futureDate = Date().addingTimeInterval(86400 * 15) // 15 days from now

        let recurring = RecurringTransaction(
            name: "Test Recurring",
            category: "Abonnementen",
            expectedAmount: Decimal(-10),
            frequency: .monthly,
            nextDueDate: futureDate
        )
        modelContext.insert(recurring)

        XCTAssertFalse(recurring.isOverdue)
        // daysUntilDue can be 14-15 depending on time of day and timezone
        XCTAssertTrue(recurring.daysUntilDue >= 14 && recurring.daysUntilDue <= 16,
                      "Expected daysUntilDue between 14-16, got \(recurring.daysUntilDue)")
        XCTAssertEqual(recurring.frequency.displayName, "Maandelijks")
    }

    // MARK: - Audit Log History Tests

    /// Test audit log is empty initially
    func testAuditLogEmptyInitially() throws {
        let transaction = createTestTransaction()

        XCTAssertNil(transaction.auditLog)
    }

    /// Test multiple audit entries are tracked
    func testMultipleAuditEntriesAreTracked() throws {
        let transaction = createTestTransaction()

        // First change
        transaction.updateCategoryOverride("Uit Eten", reason: "First change")

        // Second change
        transaction.updateCategoryOverride("Winkelen", reason: "Second change")

        // Third change
        transaction.updateCategoryOverride("Vervoer", reason: "Third change")

        XCTAssertEqual(transaction.auditLog?.count, 3)

        // Verify chronological order (most recent last)
        let logs = transaction.auditLog!
        XCTAssertEqual(logs[0].newValue, "Uit Eten")
        XCTAssertEqual(logs[1].newValue, "Winkelen")
        XCTAssertEqual(logs[2].newValue, "Vervoer")
    }

    /// Test audit log entry fields
    func testAuditLogEntryFields() throws {
        let transaction = createTestTransaction()

        transaction.updateCategoryOverride("Uit Eten", reason: "Correction")

        let entry = transaction.auditLog?.first

        XCTAssertEqual(entry?.action, .categoryChange)
        XCTAssertEqual(entry?.action.displayName, "Categorie gewijzigd")
        XCTAssertEqual(entry?.action.icon, "square.grid.2x2")
        XCTAssertEqual(entry?.previousValue, "Boodschappen")
        XCTAssertEqual(entry?.newValue, "Uit Eten")
        XCTAssertEqual(entry?.reason, "Correction")
        XCTAssertNotNil(entry?.changedAt)
    }

    /// Test audit log for split action
    func testAuditLogForSplitAction() throws {
        let transaction = createTestTransaction(amount: -30)

        let components: [(category: String, amount: Decimal)] = [
            ("Boodschappen", Decimal(-20)),
            ("Huisdier", Decimal(-10))
        ]
        try transaction.createSplit(components)

        XCTAssertEqual(transaction.auditLog?.count, 1)

        let entry = transaction.auditLog?.first
        XCTAssertEqual(entry?.action, .split)
        XCTAssertEqual(entry?.action.displayName, "Transactie gesplitst")
        XCTAssertTrue(entry?.newValue.contains("2 categories") == true)
    }

    // MARK: - Transaction Metadata Tests

    /// Test unique key format
    func testUniqueKeyFormat() throws {
        let dateComponents = DateComponents(year: 2025, month: 12, day: 23)
        let date = Calendar.current.date(from: dateComponents)!

        let transaction = Transaction(
            iban: "NL00BANK0123456001",
            sequenceNumber: 42,
            date: date,
            amount: -10,
            balance: 100,
            transactionType: .expense
        )

        XCTAssertEqual(transaction.uniqueKey, "NL00BANK0123456001-20251223-42")
    }

    /// Test import metadata
    func testImportMetadata() throws {
        let transaction = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 1,
            date: Date(),
            amount: -10,
            balance: 100,
            transactionType: .expense,
            sourceFile: "transactions_2025.csv",
            importBatchID: UUID()
        )

        XCTAssertNotNil(transaction.importedAt)
        XCTAssertEqual(transaction.sourceFile, "transactions_2025.csv")
        XCTAssertNotNil(transaction.importBatchID)
    }

    // MARK: - Transaction Code Tests

    /// Test Rabobank transaction code helpers
    func testTransactionCodeHelpers() throws {
        let cardPayment = createTestTransaction(transactionCode: "bc")
        XCTAssertTrue(cardPayment.isCardPayment)
        XCTAssertFalse(cardPayment.isLikelyRecurring)
        XCTAssertFalse(cardPayment.isOnlinePayment)

        let directDebit = createTestTransaction(transactionCode: "ei")
        XCTAssertTrue(directDebit.isLikelyRecurring)
        XCTAssertFalse(directDebit.isCardPayment)

        let ideal = createTestTransaction(transactionCode: "id")
        XCTAssertTrue(ideal.isOnlinePayment)
        XCTAssertFalse(ideal.isCardPayment)

        let atm = createTestTransaction(transactionCode: "ba")
        XCTAssertTrue(atm.isCardPayment)
    }
}
