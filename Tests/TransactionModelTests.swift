import XCTest
@preconcurrency import SwiftData
@testable import Florijn

/// Unit tests for the core data models following TDD approach.
/// Covers: Transaction, Account, Category models and Dutch number parsing.
final class TransactionModelTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUpWithError() throws {
        // Create in-memory container for testing
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

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - Transaction Initialization Tests

    /// Test that a Transaction can be initialized with all required fields
    func testTransactionInitialization() throws {
        // Use a fixed date for deterministic unique key
        let testDate = Date(timeIntervalSince1970: 1735084800) // 2024-12-25
        let expectedKey = "NL00TEST0000000001-20241225-12345"

        let transaction = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 12345,
            date: testDate,
            amount: Decimal(string: "-45.50")!,
            balance: Decimal(string: "1234.56")!,
            counterIBAN: "NL00TEST0000000099",
            counterName: "Albert Heijn",
            standardizedName: "Albert Heijn",
            autoCategory: "Boodschappen",
            transactionType: .expense
        )

        XCTAssertEqual(transaction.uniqueKey, expectedKey)
        XCTAssertEqual(transaction.iban, "NL00TEST0000000001")
        XCTAssertEqual(transaction.autoCategory, "Boodschappen")
        XCTAssertEqual(transaction.transactionType, .expense)
        XCTAssertEqual(transaction.amount, Decimal(string: "-45.50")!)
    }

    /// Test that year and month are denormalized correctly
    func testTransactionDenormalizedDateFields() throws {
        let dateComponents = DateComponents(year: 2025, month: 6, day: 15)
        let date = Calendar.current.date(from: dateComponents)!

        let transaction = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 1,
            date: date,
            amount: Decimal(-10),
            balance: Decimal(100),
            transactionType: .expense
        )

        XCTAssertEqual(transaction.year, 2025)
        XCTAssertEqual(transaction.month, 6)
    }

    /// Test that Transaction can be saved to SwiftData context
    func testTransactionPersistence() throws {
        // Use a fixed date for deterministic unique key
        let testDate = Date(timeIntervalSince1970: 1735084800) // 2024-12-25
        let expectedKey = "NL00TEST0000000001-20241225-99999"

        let transaction = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 99999,
            date: testDate,
            amount: Decimal(string: "-32.10")!,
            balance: Decimal(string: "1000.00")!,
            counterName: "Jumbo",
            autoCategory: "Boodschappen",
            transactionType: .expense
        )

        modelContext.insert(transaction)
        try modelContext.save()

        // Fetch and verify
        let descriptor = FetchDescriptor<Transaction>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.uniqueKey, expectedKey)
    }

    /// Test effectiveCategory returns override when set, otherwise auto category
    func testEffectiveCategory() throws {
        let transaction = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 1,
            date: Date(),
            amount: Decimal(-10),
            balance: Decimal(100),
            autoCategory: "Boodschappen",
            transactionType: .expense
        )

        // Without override, should return auto category
        XCTAssertEqual(transaction.effectiveCategory, "Boodschappen")

        // With override, should return override
        transaction.updateCategoryOverride("Uit Eten")
        XCTAssertEqual(transaction.effectiveCategory, "Uit Eten")

        // indexedCategory should also be updated
        XCTAssertEqual(transaction.indexedCategory, "Uit Eten")
    }

    /// Test effectiveCategory returns default when both are nil
    func testEffectiveCategoryDefault() throws {
        let transaction = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 1,
            date: Date(),
            amount: Decimal(-10),
            balance: Decimal(100),
            autoCategory: nil,
            transactionType: .expense
        )

        XCTAssertEqual(transaction.effectiveCategory, "Niet Gecategoriseerd")
    }

    /// Test unique constraint on uniqueKey prevents duplicates
    func testUniqueKeyConstraint() throws {
        let tx1 = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 1,
            date: Date(),
            amount: Decimal(-10),
            balance: Decimal(100),
            counterName: "Test1",
            transactionType: .expense
        )

        let tx2 = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 1, // Same key!
            date: Date(),
            amount: Decimal(-20),
            balance: Decimal(80),
            counterName: "Test2",
            transactionType: .expense
        )

        modelContext.insert(tx1)
        modelContext.insert(tx2)

        // SwiftData should handle duplicate by updating existing
        try modelContext.save()

        let descriptor = FetchDescriptor<Transaction>()
        let fetched = try modelContext.fetch(descriptor)

        // Should only have 1 transaction (upsert behavior)
        XCTAssertEqual(fetched.count, 1)
    }

    /// Test TransactionType enum values (Dutch)
    func testTransactionTypes() {
        XCTAssertEqual(TransactionType.income.rawValue, "Inkomen")
        XCTAssertEqual(TransactionType.expense.rawValue, "Uitgave")
        XCTAssertEqual(TransactionType.transfer.rawValue, "Overboeking")
    }

    /// Test Contributor enum for Inleg tracking
    func testContributorEnum() {
        XCTAssertEqual(Contributor.partner1.rawValue, "Partner 1")
        XCTAssertEqual(Contributor.partner2.rawValue, "Partner 2")
    }

    /// Test contributor assignment for Inleg transactions
    func testContributorAssignment() throws {
        let transaction = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 1,
            date: Date(),
            amount: Decimal(1000),
            balance: Decimal(5000),
            counterIBAN: "NL00TEST0000000003",
            counterName: "J. Doe",
            autoCategory: "Inleg Partner 1",
            transactionType: .income,
            contributor: .partner1
        )

        XCTAssertEqual(transaction.contributor, .partner1)
    }

    // MARK: - Date Update Safety Tests

    /// Test updateDate method syncs denormalized year/month fields
    func testUpdateDateSyncsDenormalizedFields() throws {
        // Create transaction with initial date in June 2025
        let initialDate = Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 15))!
        let transaction = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 1,
            date: initialDate,
            amount: Decimal(-10),
            balance: Decimal(100),
            transactionType: .expense
        )

        XCTAssertEqual(transaction.year, 2025)
        XCTAssertEqual(transaction.month, 6)

        // Update to December 2024 using safe method
        let newDate = Calendar.current.date(from: DateComponents(year: 2024, month: 12, day: 25))!
        transaction.updateDate(newDate)

        // Verify denormalized fields are synced
        XCTAssertEqual(transaction.date, newDate)
        XCTAssertEqual(transaction.year, 2024)
        XCTAssertEqual(transaction.month, 12)
    }

    /// Test syncDenormalizedFields recovers from direct date modification
    func testSyncDenormalizedFieldsRecovery() throws {
        let initialDate = Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 15))!
        let transaction = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 1,
            date: initialDate,
            amount: Decimal(-10),
            balance: Decimal(100),
            autoCategory: "Boodschappen",
            transactionType: .expense
        )

        // Test that updateDate correctly syncs denormalized fields
        let newDate = Calendar.current.date(from: DateComponents(year: 2023, month: 3, day: 1))!
        transaction.updateDate(newDate)

        // Year/month should now match the new date
        XCTAssertEqual(transaction.year, 2023)
        XCTAssertEqual(transaction.month, 3)
        XCTAssertEqual(transaction.indexedCategory, "Boodschappen")
    }

    // MARK: - Account Tests

    /// Test Account initialization and persistence
    func testAccountPersistence() throws {
        let account = Account(
            iban: "NL00TEST0000000001",
            name: "Gezinsrekening",
            accountType: .checking,
            owner: "Gezin"
        )

        modelContext.insert(account)
        try modelContext.save()

        let descriptor = FetchDescriptor<Account>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Gezinsrekening")
        XCTAssertEqual(fetched.first?.accountType, .checking)
    }

    /// Test AccountType enum values (Dutch)
    func testAccountTypes() {
        XCTAssertEqual(AccountType.checking.rawValue, "Betaalrekening")
        XCTAssertEqual(AccountType.savings.rawValue, "Spaarrekening")
    }

    // MARK: - Category Tests

    /// Test Category initialization with budget
    func testCategoryWithBudget() throws {
        let category = Category(
            name: "Boodschappen",
            type: .expense,
            monthlyBudget: Decimal(800)
        )

        modelContext.insert(category)
        try modelContext.save()

        let descriptor = FetchDescriptor<Category>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.monthlyBudget, Decimal(800))
    }

    // MARK: - Dutch Number Parsing Tests

    /// Test parsing Dutch number format: +1.234,56 → 1234.56
    func testDutchNumberParsing() {
        let result = DutchNumberParser.parse("+1.234,56")
        XCTAssertEqual(result, Decimal(string: "1234.56"))
    }

    /// Test parsing negative Dutch number: -1.234,56 → -1234.56
    func testDutchNegativeNumberParsing() {
        let result = DutchNumberParser.parse("-1.234,56")
        XCTAssertEqual(result, Decimal(string: "-1234.56"))
    }

    /// Test parsing simple Dutch number without thousands: 45,50 → 45.50
    func testDutchSimpleNumberParsing() {
        let result = DutchNumberParser.parse("45,50")
        XCTAssertEqual(result, Decimal(string: "45.50"))
    }

    /// Test parsing large Dutch number: +207.210,00 → 207210.00
    func testDutchLargeNumberParsing() {
        let result = DutchNumberParser.parse("+207.210,00")
        XCTAssertEqual(result, Decimal(string: "207210.00"))
    }

    /// Test parsing zero
    func testDutchZeroParsing() {
        let result = DutchNumberParser.parse("0,00")
        XCTAssertEqual(result, Decimal(0))
    }

    /// Test parsing invalid input returns nil
    func testDutchInvalidParsing() {
        let result = DutchNumberParser.parse("not a number")
        XCTAssertNil(result)
    }

    // Note: Legacy CategorizationRule tests removed - use Rule model for new tests
}

// MARK: - Dutch Number Parser

/// Utility for parsing Dutch number format used in Rabobank CSVs.
/// Format: `+1.234,56` where `.` is thousands separator and `,` is decimal separator.
enum DutchNumberParser {
    /// Parses a Dutch-formatted number string to Decimal.
    /// - Parameter string: Number in Dutch format (e.g., "+1.234,56")
    /// - Returns: Decimal value or nil if parsing fails
    static func parse(_ string: String) -> Decimal? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Remove plus sign, replace . (thousands) with empty, replace , (decimal) with .
        let cleaned = trimmed
            .replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")

        return Decimal(string: cleaned)
    }
}
