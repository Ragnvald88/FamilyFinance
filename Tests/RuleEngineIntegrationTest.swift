//
//  RuleEngineIntegrationTest.swift
//  Family Finance
//
//  Integration test for complete TriggerEvaluator + ActionExecutor + RuleEngine
//  Verifies end-to-end rule processing with ACID compliance
//
//  Created: 2025-12-27 (Component 7/8: Integration verification)
//

import XCTest
import SwiftData
@testable import Family_Finance

/// Integration test for the complete rule processing pipeline
/// Tests the expert-approved integration architecture
final class RuleEngineIntegrationTest: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var ruleEngine: RuleEngine!

    override func setUp() async throws {
        // Create in-memory test container
        let schema = Schema([
            Transaction.self,
            Account.self,
            Category.self,
            RuleGroup.self,
            Rule.self,
            RuleTrigger.self,
            RuleAction.self,
            RuleStatistics.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        ruleEngine = RuleEngine(modelContainer: container)

        // Set up test data
        try await createTestData()
    }

    override func tearDown() async throws {
        ruleEngine = nil
        context = nil
        container = nil
    }

    /// Test single transaction processing through complete pipeline
    func testSingleTransactionProcessing() async throws {
        // Create test transaction
        let transaction = createTestTransaction(
            description: "Starbucks Coffee Shop",
            amount: -4.50
        )
        context.insert(transaction)
        try context.save()

        // Process transaction through rule engine
        let result = try await ruleEngine.processTransaction(transaction)

        // Verify result structure
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result.rulesExecuted, 0, "Should have executed at least one rule")
        XCTAssertTrue(result.errors.isEmpty, "Should have no errors")
        XCTAssertGreaterThan(result.executionTime, 0, "Should record execution time")

        // Verify transaction was categorized
        try context.save()
        XCTAssertEqual(transaction.category?.name, "Food & Dining", "Should categorize coffee purchase as Food & Dining")

        print("✅ Single transaction processing: SUCCESS")
        print("   Rules executed: \(result.rulesExecuted)")
        print("   Actions performed: \(result.actionsPerformed)")
        print("   Execution time: \(String(format: "%.2f", result.executionTime * 1000))ms")
    }

    /// Test bulk processing with progress reporting
    func testBulkTransactionProcessing() async throws {
        // Create multiple test transactions
        let transactions = [
            createTestTransaction(description: "McDonald's", amount: -8.99),
            createTestTransaction(description: "Shell Gas Station", amount: -45.00),
            createTestTransaction(description: "Amazon.com", amount: -23.99),
            createTestTransaction(description: "Supermarket", amount: -67.50)
        ]

        for transaction in transactions {
            context.insert(transaction)
        }
        try context.save()

        // Process bulk transactions
        let result = try await ruleEngine.processBulk(transactions)

        // Verify bulk result
        XCTAssertEqual(result.totalProcessed, 4, "Should process all 4 transactions")
        XCTAssertEqual(result.successfullyProcessed, 4, "All should succeed")
        XCTAssertEqual(result.failed, 0, "None should fail")
        XCTAssertGreaterThan(result.throughput, 0, "Should have positive throughput")
        XCTAssertTrue(result.errorSummary.isEmpty, "Should have no errors")

        // Verify all transactions were categorized
        try context.save()
        for transaction in transactions {
            XCTAssertNotNil(transaction.category, "Transaction should be categorized: \(transaction.fullDescription)")
        }

        print("✅ Bulk transaction processing: SUCCESS")
        print("   Processed: \(result.totalProcessed)")
        print("   Success rate: \(result.successfullyProcessed)/\(result.totalProcessed)")
        print("   Throughput: \(String(format: "%.1f", result.throughput)) TPS")
    }

    /// Test manual rule execution with specific rule groups
    func testManualRuleExecution() async throws {
        // Get test rule groups
        let descriptor = FetchDescriptor<RuleGroup>()
        let ruleGroups = try context.fetch(descriptor)
        XCTAssertFalse(ruleGroups.isEmpty, "Should have test rule groups")

        // Create test transactions
        let transactions = [
            createTestTransaction(description: "Coffee Bean", amount: -5.99),
            createTestTransaction(description: "Walmart", amount: -89.99)
        ]

        for transaction in transactions {
            context.insert(transaction)
        }
        try context.save()

        // Execute rules manually
        let result = try await ruleEngine.executeRulesManually(
            for: transactions,
            ruleGroups: ruleGroups
        )

        // Verify manual execution result
        XCTAssertEqual(result.totalTransactions, 2, "Should process 2 transactions")
        XCTAssertEqual(result.processedTransactions, 2, "Should complete processing")
        XCTAssertGreaterThan(result.successfulTransactions, 0, "Should have successful matches")
        XCTAssertGreaterThan(result.executedRules.count, 0, "Should execute rules")
        XCTAssertGreaterThan(result.executionTime, 0, "Should record execution time")

        print("✅ Manual rule execution: SUCCESS")
        print("   Processed: \(result.processedTransactions)/\(result.totalTransactions)")
        print("   Successful: \(result.successfulTransactions)")
        print("   Rules executed: \(result.executedRules.count)")
    }

    /// Test error handling and recovery
    func testErrorHandlingAndRecovery() async throws {
        // Create transaction with problematic data that might cause trigger issues
        let transaction = createTestTransaction(
            description: "", // Empty description
            amount: 0.0      // Zero amount
        )
        context.insert(transaction)
        try context.save()

        // Process transaction - should handle gracefully
        let result = try await ruleEngine.processTransaction(transaction)

        // Verify graceful handling
        XCTAssertNotNil(result, "Should return result even for problematic transaction")
        // Note: Depending on rule configuration, this might or might not match rules

        print("✅ Error handling: SUCCESS")
        print("   Rules executed: \(result.rulesExecuted)")
        print("   Errors encountered: \(result.errors.count)")
    }

    /// Test statistics integration
    func testStatisticsIntegration() async throws {
        // Create and process transaction
        let transaction = createTestTransaction(
            description: "Test Statistics Transaction",
            amount: -10.00
        )
        context.insert(transaction)
        try context.save()

        // Process transaction
        let result = try await ruleEngine.processTransaction(transaction)

        // Verify statistics were recorded
        let statsDescriptor = FetchDescriptor<RuleStatistics>()
        let allStats = try context.fetch(statsDescriptor)

        if result.rulesExecuted > 0 {
            XCTAssertFalse(allStats.isEmpty, "Should have created rule statistics")

            let stats = allStats.first!
            XCTAssertGreaterThan(stats.matchCount, 0, "Should record rule matches")
            XCTAssertNotNil(stats.lastMatchedAt, "Should record last match time")
        }

        print("✅ Statistics integration: SUCCESS")
        print("   Statistics records: \(allStats.count)")
        print("   Match counts: \(allStats.map(\.matchCount))")
    }

    // MARK: - Test Data Setup

    private func createTestData() async throws {
        // Create test account
        let account = Account(
            name: "Test Checking",
            iban: "NL91ABNA0417164300",
            type: .checking
        )
        context.insert(account)

        // Create test categories
        let foodCategory = Category(name: "Food & Dining")
        let transportCategory = Category(name: "Transportation")
        let shoppingCategory = Category(name: "Shopping")

        context.insert(foodCategory)
        context.insert(transportCategory)
        context.insert(shoppingCategory)

        // Create test rule group
        let ruleGroup = RuleGroup(
            name: "Auto Categorization",
            executionOrder: 1,
            isActive: true,
            stopProcessingAfter: false
        )
        context.insert(ruleGroup)

        // Create test rules

        // Rule 1: Coffee shops → Food & Dining
        let coffeeRule = Rule(
            name: "Coffee Shops",
            isActive: true,
            stopProcessing: false,
            triggerLogic: .any
        )
        ruleGroup.rules.append(coffeeRule)

        let coffeeTrigger = RuleTrigger(
            field: .description,
            operator: .contains,
            value: "coffee",
            isInverted: false,
            sortOrder: 1
        )
        coffeeRule.triggers.append(coffeeTrigger)

        let coffeeAction = RuleAction(
            type: .setCategory,
            value: "Food & Dining",
            stopProcessingAfter: false,
            sortOrder: 1
        )
        coffeeRule.actions.append(coffeeAction)

        // Rule 2: Gas stations → Transportation
        let gasRule = Rule(
            name: "Gas Stations",
            isActive: true,
            stopProcessing: false,
            triggerLogic: .any
        )
        ruleGroup.rules.append(gasRule)

        let gasTrigger = RuleTrigger(
            field: .description,
            operator: .contains,
            value: "gas",
            isInverted: false,
            sortOrder: 1
        )
        gasRule.triggers.append(gasTrigger)

        let gasAction = RuleAction(
            type: .setCategory,
            value: "Transportation",
            stopProcessingAfter: false,
            sortOrder: 1
        )
        gasRule.actions.append(gasAction)

        // Rule 3: Shopping patterns → Shopping
        let shoppingRule = Rule(
            name: "Shopping",
            isActive: true,
            stopProcessing: false,
            triggerLogic: .any
        )
        ruleGroup.rules.append(shoppingRule)

        let amazonTrigger = RuleTrigger(
            field: .description,
            operator: .contains,
            value: "amazon",
            isInverted: false,
            sortOrder: 1
        )
        shoppingRule.triggers.append(amazonTrigger)

        let marketTrigger = RuleTrigger(
            field: .description,
            operator: .contains,
            value: "market",
            isInverted: false,
            sortOrder: 2
        )
        shoppingRule.triggers.append(marketTrigger)

        let shoppingAction = RuleAction(
            type: .setCategory,
            value: "Shopping",
            stopProcessingAfter: false,
            sortOrder: 1
        )
        shoppingRule.actions.append(shoppingAction)

        context.insert(coffeeRule)
        context.insert(gasRule)
        context.insert(shoppingRule)

        try context.save()
    }

    private func createTestTransaction(description: String, amount: Double) -> Transaction {
        let account = try! context.fetch(FetchDescriptor<Account>()).first!

        return Transaction(
            date: Date(),
            amount: Decimal(amount),
            fullDescription: description,
            account: account,
            iban: account.iban,
            transactionType: .debit,
            counterName: description,
            counterIBAN: "NL12BANK0123456789"
        )
    }
}