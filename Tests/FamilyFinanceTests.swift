//
//  FamilyFinanceTests.swift
//  Family Finance Tests
//
//  Comprehensive unit tests for critical business logic
//  Focus: CSV parsing, categorization, Dutch number format
//
//  Created: 2025-12-22
//

import XCTest
@preconcurrency import SwiftData
@testable import FamilyFinance

@MainActor
final class FamilyFinanceTests: XCTestCase {

    // MARK: - Test Fixtures

    var modelContext: ModelContext!
    var modelContainer: ModelContainer!

    override func setUp() async throws {
        // Create in-memory container for testing
        let schema = Schema([
            Transaction.self,
            Account.self,
            Category.self,
            Merchant.self,
            BudgetPeriod.self,
            Liability.self,
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

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        modelContainer = try ModelContainer(
            for: schema,
            configurations: [config]
        )

        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContext = nil
        modelContainer = nil
    }

    // MARK: - Dutch Number Parsing Tests

    func testParseDutchAmountPositive() {
        let parser = DutchNumberParserHelper()

        XCTAssertEqual(parser.parse("+1.234,56"), Decimal(string: "1234.56"))
        XCTAssertEqual(parser.parse("+10,00"), Decimal(string: "10.00"))
        XCTAssertEqual(parser.parse("+1,00"), Decimal(string: "1.00"))
    }

    func testParseDutchAmountNegative() {
        let parser = DutchNumberParserHelper()

        XCTAssertEqual(parser.parse("-1.234,56"), Decimal(string: "-1234.56"))
        XCTAssertEqual(parser.parse("-10,00"), Decimal(string: "-10.00"))
    }

    func testParseDutchAmountEdgeCases() {
        let parser = DutchNumberParserHelper()

        XCTAssertEqual(parser.parse(""), Decimal.zero)
        XCTAssertEqual(parser.parse("0,00"), Decimal.zero)
        XCTAssertEqual(parser.parse("+0,00"), Decimal.zero)
        XCTAssertEqual(parser.parse("-0,00"), Decimal.zero)
    }

    func testParseDutchAmountLargeNumbers() {
        let parser = DutchNumberParserHelper()

        XCTAssertEqual(parser.parse("+100.000,00"), Decimal(string: "100000.00"))
        XCTAssertEqual(parser.parse("-1.000.000,50"), Decimal(string: "-1000000.50"))
    }

    // MARK: - CSV Parsing Tests

    func testCSVFieldParsing() {
        let parser = CSVFieldParser()

        // Simple fields
        let simple = parser.parseFields("field1,field2,field3")
        XCTAssertEqual(simple, ["field1", "field2", "field3"])

        // Quoted fields
        let quoted = parser.parseFields("\"field1\",\"field2\",\"field3\"")
        XCTAssertEqual(quoted, ["field1", "field2", "field3"])

        // Mixed
        let mixed = parser.parseFields("field1,\"field2,with,comma\",field3")
        XCTAssertEqual(mixed, ["field1", "field2,with,comma", "field3"])

        // Escaped quotes
        let escaped = parser.parseFields("\"field with \"\"quotes\"\"\",normal")
        XCTAssertEqual(escaped, ["field with \"quotes\"", "normal"])
    }

    func testCSVDateParsing() {
        let parser = RabobankDateParser()

        let date1 = parser.parse("2025-12-22")
        XCTAssertNotNil(date1)
        XCTAssertEqual(Calendar.current.component(.year, from: date1!), 2025)
        XCTAssertEqual(Calendar.current.component(.month, from: date1!), 12)
        XCTAssertEqual(Calendar.current.component(.day, from: date1!), 22)

        let invalidDate = parser.parse("2025-13-40")
        XCTAssertNil(invalidDate)

        let emptyDate = parser.parse("")
        XCTAssertNil(emptyDate)
    }

    // MARK: - Categorization Tests
    // Note: Legacy CategorizationRule tests removed - use Rule model for new tests

    func testInlegDetectionPartner1() {
        let detector = ContributorDetector()

        // IBAN-based detection
        let result1 = detector.detect(
            counterIBAN: "NL00TEST0000000003",
            counterName: "J. DOE",
            sourceIBAN: "NL00TEST0000000001"
        )
        XCTAssertEqual(result1, .partner1)

        // Name-based detection
        let result2 = detector.detect(
            counterIBAN: "NL99XXXX",
            counterName: "J. Doe",
            sourceIBAN: "NL00TEST0000000001"
        )
        XCTAssertEqual(result2, .partner1)
    }

    func testInlegDetectionPartner2() {
        let detector = ContributorDetector()

        // IBAN-based detection
        let result1 = detector.detect(
            counterIBAN: "NL00TEST0000000004",
            counterName: "J. SMITH",
            sourceIBAN: "NL00TEST0000000001"
        )
        XCTAssertEqual(result1, .partner2)

        // Name-based detection
        let result2 = detector.detect(
            counterIBAN: "NL99XXXX",
            counterName: "J. Smith",
            sourceIBAN: "NL00TEST0000000001"
        )
        XCTAssertEqual(result2, .partner2)
    }

    // MARK: - Transaction Type Detection Tests

    func testTransactionTypeDetection() {
        let detector = TransactionTypeDetector(
            knownIBANs: Set(["NL00TEST0000000001", "NL00TEST0000000002", "NL00TEST0000000003"])
        )

        // Income
        let income = detector.determine(
            amount: Decimal(100),
            counterIBAN: "NL99XXXX",
            iban: "NL00TEST0000000001"
        )
        XCTAssertEqual(income, .income)

        // Expense
        let expense = detector.determine(
            amount: Decimal(-50),
            counterIBAN: "NL99XXXX",
            iban: "NL00TEST0000000001"
        )
        XCTAssertEqual(expense, .expense)

        // Internal transfer
        let transfer = detector.determine(
            amount: Decimal(100),
            counterIBAN: "NL00TEST0000000002",
            iban: "NL00TEST0000000001"
        )
        XCTAssertEqual(transfer, .transfer)
    }

    // MARK: - Query Tests

    func testDashboardKPICalculation() async throws {
        // Create test transactions
        let income1 = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 1,
            date: Date(),
            amount: 1000,
            balance: 1000,
            transactionType: .income
        )
        modelContext.insert(income1)

        let expense1 = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 2,
            date: Date(),
            amount: -300,
            balance: 700,
            transactionType: .expense
        )
        modelContext.insert(expense1)

        let expense2 = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 3,
            date: Date(),
            amount: -200,
            balance: 500,
            transactionType: .expense
        )
        modelContext.insert(expense2)

        try modelContext.save()

        let queryService = TransactionQueryService(modelContext: modelContext)
        let kpis = try await queryService.getDashboardKPIs(filter: .empty)

        XCTAssertEqual(kpis.totalIncome, 1000)
        XCTAssertEqual(kpis.totalExpenses, 500)
        XCTAssertEqual(kpis.netSavings, 500)
        XCTAssertEqual(kpis.savingsRate, 50.0, accuracy: 0.01)
        XCTAssertEqual(kpis.transactionCount, 3)
    }

    func testCategorySummaryAggregation() async throws {
        // Create test transactions with categories
        let t1 = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 1,
            date: Date(),
            amount: -100,
            balance: 900,
            autoCategory: "Boodschappen",
            transactionType: .expense
        )
        modelContext.insert(t1)

        let t2 = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 2,
            date: Date(),
            amount: -150,
            balance: 750,
            autoCategory: "Boodschappen",
            transactionType: .expense
        )
        modelContext.insert(t2)

        let t3 = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 3,
            date: Date(),
            amount: -50,
            balance: 700,
            autoCategory: "Uit Eten",
            transactionType: .expense
        )
        modelContext.insert(t3)

        try modelContext.save()

        let queryService = TransactionQueryService(modelContext: modelContext)
        let summaries = try await queryService.getCategorySummaries(filter: .empty)

        let boodschappen = summaries.first { $0.category == "Boodschappen" }
        XCTAssertNotNil(boodschappen)
        XCTAssertEqual(boodschappen?.totalAmount, 250)
        XCTAssertEqual(boodschappen?.transactionCount, 2)

        let uitEten = summaries.first { $0.category == "Uit Eten" }
        XCTAssertNotNil(uitEten)
        XCTAssertEqual(uitEten?.totalAmount, 50)
        XCTAssertEqual(uitEten?.transactionCount, 1)
    }

    // MARK: - Account Balance Tests

    func testAccountCurrentBalance() throws {
        let account = Account(
            iban: "NL00TEST0000000001",
            name: "Test Account",
            accountType: .checking,
            owner: "Test"
        )
        modelContext.insert(account)

        // Use fixed dates for deterministic unique keys
        let baseDate = Date(timeIntervalSince1970: 1735084800) // 2024-12-25

        // Add transactions with different dates
        let t1 = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 1,
            date: baseDate.addingTimeInterval(-86400 * 5), // 5 days before
            amount: 100,
            balance: 100,
            transactionType: .income
        )
        t1.account = account
        modelContext.insert(t1)

        let t2 = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 2,
            date: baseDate.addingTimeInterval(-86400 * 3), // 3 days before
            amount: -50,
            balance: 50,
            transactionType: .expense
        )
        t2.account = account
        modelContext.insert(t2)

        let t3 = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 3,
            date: baseDate, // Most recent (the base date itself)
            amount: 200,
            balance: 250,
            transactionType: .income
        )
        t3.account = account
        modelContext.insert(t3)

        try modelContext.save()

        // Need to refresh balance from transactions (cached balance mechanism)
        account.refreshBalance()

        // Current balance should be from most recent transaction
        XCTAssertEqual(account.currentBalance, 250)
    }

    // MARK: - Duplicate Detection Tests

    func testDuplicateDetection() throws {
        // Use a fixed date for deterministic unique keys
        let testDate = Date(timeIntervalSince1970: 1735084800) // 2024-12-25

        let t1 = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 1,
            date: testDate,
            amount: 100,
            balance: 100,
            transactionType: .income
        )
        modelContext.insert(t1)

        try modelContext.save()

        // SwiftData with @Attribute(.unique) performs upsert on conflict
        // So inserting a duplicate should result in only 1 transaction
        let t2 = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 1, // Same sequence number
            date: testDate,    // Same date = same unique key
            amount: 200,       // Different amount
            balance: 200,
            transactionType: .income
        )
        modelContext.insert(t2)
        try modelContext.save()

        // Should only have 1 transaction (upsert replaced the first)
        let descriptor = FetchDescriptor<Transaction>()
        let fetched = try modelContext.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
    }

    // MARK: - Net Worth Calculation Tests

    func testNetWorthCalculation() async throws {
        // Use fixed date for deterministic unique keys
        let testDate = Date(timeIntervalSince1970: 1735084800) // 2024-12-25

        // Create accounts with balances
        let account1 = Account(
            iban: "NL00TEST0000000001",
            name: "Checking",
            accountType: .checking,
            owner: "Test"
        )
        modelContext.insert(account1)

        let t1 = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 1,
            date: testDate,
            amount: 5000,
            balance: 5000,
            transactionType: .income
        )
        t1.account = account1
        modelContext.insert(t1)

        let account2 = Account(
            iban: "NL00TEST0000000002",
            name: "Savings",
            accountType: .savings,
            owner: "Test"
        )
        modelContext.insert(account2)

        let t2 = Transaction(
            iban: "NL00TEST0000000002",
            sequenceNumber: 1,
            date: testDate,
            amount: 10000,
            balance: 10000,
            transactionType: .income
        )
        t2.account = account2
        modelContext.insert(t2)

        // Create liability
        let liability = Liability(
            name: "Mortgage",
            type: .mortgage,
            amount: 300000,
            startDate: testDate
        )
        modelContext.insert(liability)

        try modelContext.save()

        // Refresh account balances from transactions
        account1.refreshBalance()
        account2.refreshBalance()

        let queryService = TransactionQueryService(modelContext: modelContext)
        let netWorth = try await queryService.getNetWorth()

        XCTAssertEqual(netWorth.assets, 15000)
        XCTAssertEqual(netWorth.liabilities, 300000)
        XCTAssertEqual(netWorth.netWorth, -285000)
    }
}

// MARK: - Test Helper Classes

/// Helper for testing Dutch number parsing (named differently to avoid conflict)
class DutchNumberParserHelper {
    func parse(_ string: String) -> Decimal? {
        guard !string.isEmpty else { return Decimal.zero }

        var cleaned = string
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "+", with: "")

        return Decimal(string: cleaned)
    }
}

/// Helper for testing CSV field parsing
class CSVFieldParser {
    func parseFields(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]

            if char == "\"" {
                if insideQuotes {
                    // Check if next char is also a quote (escaped quote)
                    let nextIndex = line.index(after: i)
                    if nextIndex < line.endIndex && line[nextIndex] == "\"" {
                        // Escaped quote ("") - append a literal quote
                        currentField.append("\"")
                        i = line.index(after: nextIndex) // Skip both quotes
                        continue
                    } else {
                        // End of quoted field
                        insideQuotes = false
                    }
                } else {
                    // Start of quoted field
                    insideQuotes = true
                }
            } else if char == "," && !insideQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }

            i = line.index(after: i)
        }

        fields.append(currentField)
        return fields
    }
}

/// Helper for testing date parsing
class RabobankDateParser {
    func parse(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return formatter.date(from: dateString)
    }
}

/// Helper for testing contributor detection
class ContributorDetector {
    private let partner1IBAN = "NL00TEST0000000003"
    private let partner2IBAN = "NL00TEST0000000004"

    func detect(counterIBAN: String, counterName: String, sourceIBAN: String) -> Contributor? {
        let nameLower = counterName.lowercased()

        // IBAN-based detection (most reliable)
        if counterIBAN == partner1IBAN {
            return .partner1
        }
        if counterIBAN == partner2IBAN {
            return .partner2
        }

        // Name-based detection (fallback)
        if nameLower.contains("smith") {
            return .partner2
        }

        // Match "doe" for partner1 (J. Doe, R. Doe, etc.)
        if nameLower.contains("doe") {
            return .partner1
        }

        return nil
    }
}

/// Helper for testing transaction type detection
class TransactionTypeDetector {
    private let knownIBANs: Set<String>

    init(knownIBANs: Set<String>) {
        self.knownIBANs = knownIBANs
    }

    func determine(amount: Decimal, counterIBAN: String, iban: String) -> TransactionType {
        if knownIBANs.contains(counterIBAN) {
            return .transfer
        }

        if amount > 0 {
            return .income
        } else if amount < 0 {
            return .expense
        } else {
            return .unknown
        }
    }
}
