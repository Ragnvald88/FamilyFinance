//
//  RuleServiceTests.swift
//  Florijn Tests
//
//  Tests for the core rule engine - the foundation of automatic categorization
//

import XCTest
@preconcurrency import SwiftData
@testable import FamilyFinance

@MainActor
final class RuleServiceTests: XCTestCase {

    var modelContext: ModelContext!
    var modelContainer: ModelContainer!
    var ruleService: RuleService!

    override func setUp() async throws {
        let schema = Schema([
            Transaction.self,
            Account.self,
            Category.self,
            RuleGroup.self,
            Rule.self,
            RuleTrigger.self,
            RuleAction.self,
            TriggerGroup.self
        ])

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
        ruleService = RuleService(modelContext: modelContext)
    }

    override func tearDown() async throws {
        modelContext = nil
        modelContainer = nil
        ruleService = nil
    }

    // MARK: - Trigger Evaluation Tests

    func testTriggerContains() throws {
        // Create rule: IF description contains "albert heijn" THEN set category "Groceries"
        let rule = Rule(name: "Albert Heijn Rule")
        rule.isActive = true

        let trigger = RuleTrigger(field: .description, triggerOperator: .contains, value: "albert heijn")
        trigger.rule = rule
        rule.triggers.append(trigger)

        let action = RuleAction(type: .setCategory, value: "Groceries")
        action.rule = rule
        rule.actions.append(action)

        modelContext.insert(rule)
        try modelContext.save()

        // Create transaction that should match
        let transaction = Transaction(
            iban: "NL00TEST001",
            sequenceNumber: 1,
            date: Date(),
            amount: -50,
            balance: 950,
            transactionType: .expense
        )
        transaction.description1 = "Payment to Albert Heijn Amsterdam"
        modelContext.insert(transaction)

        // Process
        ruleService.processTransaction(transaction)

        // Verify
        XCTAssertEqual(transaction.autoCategory, "Groceries")
    }

    func testTriggerEquals() throws {
        let rule = Rule(name: "Exact Match Rule")
        rule.isActive = true

        let trigger = RuleTrigger(field: .counterParty, triggerOperator: .equals, value: "spotify")
        trigger.rule = rule
        rule.triggers.append(trigger)

        let action = RuleAction(type: .setCategory, value: "Subscriptions")
        action.rule = rule
        rule.actions.append(action)

        modelContext.insert(rule)
        try modelContext.save()

        // Should match
        let t1 = Transaction(iban: "NL00TEST001", sequenceNumber: 1, date: Date(), amount: -10, balance: 990, transactionType: .expense)
        t1.counterName = "Spotify"
        modelContext.insert(t1)
        ruleService.processTransaction(t1)
        XCTAssertEqual(t1.autoCategory, "Subscriptions")

        // Should NOT match (contains but not equals)
        let t2 = Transaction(iban: "NL00TEST001", sequenceNumber: 2, date: Date(), amount: -10, balance: 980, transactionType: .expense)
        t2.counterName = "Spotify Premium"
        modelContext.insert(t2)
        ruleService.processTransaction(t2)
        XCTAssertNil(t2.autoCategory)
    }

    func testTriggerStartsWith() throws {
        let rule = Rule(name: "Starts With Rule")
        rule.isActive = true

        let trigger = RuleTrigger(field: .description, triggerOperator: .startsWith, value: "sepa")
        trigger.rule = rule
        rule.triggers.append(trigger)

        let action = RuleAction(type: .setCategory, value: "Bank Transfer")
        action.rule = rule
        rule.actions.append(action)

        modelContext.insert(rule)
        try modelContext.save()

        let transaction = Transaction(iban: "NL00TEST001", sequenceNumber: 1, date: Date(), amount: -100, balance: 900, transactionType: .expense)
        transaction.description1 = "SEPA Overboeking naar NL00XXXX"
        modelContext.insert(transaction)

        ruleService.processTransaction(transaction)
        XCTAssertEqual(transaction.autoCategory, "Bank Transfer")
    }

    func testTriggerAmountGreaterThan() throws {
        let rule = Rule(name: "Large Expense Rule")
        rule.isActive = true

        let trigger = RuleTrigger(field: .amount, triggerOperator: .lessThan, value: "-100")
        trigger.rule = rule
        rule.triggers.append(trigger)

        let action = RuleAction(type: .setCategory, value: "Large Expense")
        action.rule = rule
        rule.actions.append(action)

        modelContext.insert(rule)
        try modelContext.save()

        // Should match (amount -150 < -100)
        let t1 = Transaction(iban: "NL00TEST001", sequenceNumber: 1, date: Date(), amount: -150, balance: 850, transactionType: .expense)
        modelContext.insert(t1)
        ruleService.processTransaction(t1)
        XCTAssertEqual(t1.autoCategory, "Large Expense")

        // Should NOT match (amount -50 > -100)
        let t2 = Transaction(iban: "NL00TEST001", sequenceNumber: 2, date: Date(), amount: -50, balance: 800, transactionType: .expense)
        modelContext.insert(t2)
        ruleService.processTransaction(t2)
        XCTAssertNil(t2.autoCategory)
    }

    // MARK: - Multiple Triggers (AND logic)

    func testMultipleTriggersAND() throws {
        let rule = Rule(name: "Multi Trigger Rule")
        rule.isActive = true
        rule.triggerLogic = .all  // AND

        let trigger1 = RuleTrigger(field: .description, triggerOperator: .contains, value: "albert")
        trigger1.rule = rule
        rule.triggers.append(trigger1)

        let trigger2 = RuleTrigger(field: .amount, triggerOperator: .lessThan, value: "0")
        trigger2.rule = rule
        rule.triggers.append(trigger2)

        let action = RuleAction(type: .setCategory, value: "Groceries")
        action.rule = rule
        rule.actions.append(action)

        modelContext.insert(rule)
        try modelContext.save()

        // Should match - both conditions true
        let t1 = Transaction(iban: "NL00TEST001", sequenceNumber: 1, date: Date(), amount: -50, balance: 950, transactionType: .expense)
        t1.description1 = "Albert Heijn"
        modelContext.insert(t1)
        ruleService.processTransaction(t1)
        XCTAssertEqual(t1.autoCategory, "Groceries")

        // Should NOT match - only one condition true (positive amount)
        let t2 = Transaction(iban: "NL00TEST001", sequenceNumber: 2, date: Date(), amount: 50, balance: 1000, transactionType: .income)
        t2.description1 = "Albert Heijn refund"
        modelContext.insert(t2)
        ruleService.processTransaction(t2)
        XCTAssertNil(t2.autoCategory)
    }

    // MARK: - Multiple Triggers (OR logic)

    func testMultipleTriggersOR() throws {
        let rule = Rule(name: "OR Trigger Rule")
        rule.isActive = true
        rule.triggerLogic = .any  // OR

        let trigger1 = RuleTrigger(field: .counterParty, triggerOperator: .contains, value: "netflix")
        trigger1.rule = rule
        rule.triggers.append(trigger1)

        let trigger2 = RuleTrigger(field: .counterParty, triggerOperator: .contains, value: "spotify")
        trigger2.rule = rule
        rule.triggers.append(trigger2)

        let action = RuleAction(type: .setCategory, value: "Subscriptions")
        action.rule = rule
        rule.actions.append(action)

        modelContext.insert(rule)
        try modelContext.save()

        // Should match - first condition true
        let t1 = Transaction(iban: "NL00TEST001", sequenceNumber: 1, date: Date(), amount: -15, balance: 985, transactionType: .expense)
        t1.counterName = "Netflix"
        modelContext.insert(t1)
        ruleService.processTransaction(t1)
        XCTAssertEqual(t1.autoCategory, "Subscriptions")

        // Should match - second condition true
        let t2 = Transaction(iban: "NL00TEST001", sequenceNumber: 2, date: Date(), amount: -10, balance: 975, transactionType: .expense)
        t2.counterName = "Spotify"
        modelContext.insert(t2)
        ruleService.processTransaction(t2)
        XCTAssertEqual(t2.autoCategory, "Subscriptions")
    }

    // MARK: - Action Tests

    func testActionSetCategory() throws {
        let rule = Rule(name: "Set Category")
        rule.isActive = true

        let trigger = RuleTrigger(field: .description, triggerOperator: .contains, value: "test")
        trigger.rule = rule
        rule.triggers.append(trigger)

        let action = RuleAction(type: .setCategory, value: "Test Category")
        action.rule = rule
        rule.actions.append(action)

        modelContext.insert(rule)
        try modelContext.save()

        let transaction = Transaction(iban: "NL00TEST001", sequenceNumber: 1, date: Date(), amount: -10, balance: 990, transactionType: .expense)
        transaction.description1 = "This is a test"
        modelContext.insert(transaction)

        ruleService.processTransaction(transaction)

        XCTAssertEqual(transaction.autoCategory, "Test Category")
        XCTAssertEqual(transaction.indexedCategory, "Test Category")
    }

    func testActionSetCounterParty() throws {
        let rule = Rule(name: "Standardize Name")
        rule.isActive = true

        let trigger = RuleTrigger(field: .counterParty, triggerOperator: .contains, value: "ah ")
        trigger.rule = rule
        rule.triggers.append(trigger)

        let action = RuleAction(type: .setCounterParty, value: "Albert Heijn")
        action.rule = rule
        rule.actions.append(action)

        modelContext.insert(rule)
        try modelContext.save()

        let transaction = Transaction(iban: "NL00TEST001", sequenceNumber: 1, date: Date(), amount: -30, balance: 970, transactionType: .expense)
        transaction.counterName = "AH To Go Station"
        modelContext.insert(transaction)

        ruleService.processTransaction(transaction)

        XCTAssertEqual(transaction.standardizedName, "Albert Heijn")
    }

    // MARK: - Inactive Rule Test

    func testInactiveRuleNotApplied() throws {
        let rule = Rule(name: "Inactive Rule")
        rule.isActive = false  // INACTIVE

        let trigger = RuleTrigger(field: .description, triggerOperator: .contains, value: "test")
        trigger.rule = rule
        rule.triggers.append(trigger)

        let action = RuleAction(type: .setCategory, value: "Should Not Apply")
        action.rule = rule
        rule.actions.append(action)

        modelContext.insert(rule)
        try modelContext.save()

        let transaction = Transaction(iban: "NL00TEST001", sequenceNumber: 1, date: Date(), amount: -10, balance: 990, transactionType: .expense)
        transaction.description1 = "This is a test"
        modelContext.insert(transaction)

        ruleService.processTransaction(transaction)

        XCTAssertNil(transaction.autoCategory)
    }

    // MARK: - Stop Processing Test

    func testStopProcessing() throws {
        // First rule - should match and stop
        let rule1 = Rule(name: "First Rule")
        rule1.isActive = true
        rule1.stopProcessing = true
        rule1.groupExecutionOrder = 1

        let trigger1 = RuleTrigger(field: .description, triggerOperator: .contains, value: "test")
        trigger1.rule = rule1
        rule1.triggers.append(trigger1)

        let action1 = RuleAction(type: .setCategory, value: "First")
        action1.rule = rule1
        rule1.actions.append(action1)

        modelContext.insert(rule1)

        // Second rule - would also match but shouldn't run
        let rule2 = Rule(name: "Second Rule")
        rule2.isActive = true
        rule2.groupExecutionOrder = 2

        let trigger2 = RuleTrigger(field: .description, triggerOperator: .contains, value: "test")
        trigger2.rule = rule2
        rule2.triggers.append(trigger2)

        let action2 = RuleAction(type: .setCategory, value: "Second")
        action2.rule = rule2
        rule2.actions.append(action2)

        modelContext.insert(rule2)
        try modelContext.save()

        let transaction = Transaction(iban: "NL00TEST001", sequenceNumber: 1, date: Date(), amount: -10, balance: 990, transactionType: .expense)
        transaction.description1 = "This is a test"
        modelContext.insert(transaction)

        ruleService.processTransaction(transaction)

        // Should be "First" because first rule stopped processing
        XCTAssertEqual(transaction.autoCategory, "First")
    }

    // MARK: - Bulk Processing Test

    func testProcessMultipleTransactions() throws {
        let rule = Rule(name: "Bulk Test Rule")
        rule.isActive = true

        let trigger = RuleTrigger(field: .counterParty, triggerOperator: .contains, value: "shop")
        trigger.rule = rule
        rule.triggers.append(trigger)

        let action = RuleAction(type: .setCategory, value: "Shopping")
        action.rule = rule
        rule.actions.append(action)

        modelContext.insert(rule)
        try modelContext.save()

        // Create multiple transactions
        var transactions: [Transaction] = []
        for i in 1...5 {
            let t = Transaction(iban: "NL00TEST001", sequenceNumber: i, date: Date(), amount: Decimal(-10 * i), balance: Decimal(1000 - 10 * i), transactionType: .expense)
            t.counterName = "Shop \(i)"
            modelContext.insert(t)
            transactions.append(t)
        }

        // Process all at once
        ruleService.processTransactions(transactions)

        // All should be categorized
        for t in transactions {
            XCTAssertEqual(t.autoCategory, "Shopping", "Transaction \(t.sequenceNumber) should be categorized")
        }
    }

    // MARK: - Name Standardization Only Tests

    func testRuleWithOnlySetCounterParty() throws {
        // Rule that ONLY sets counter party (no category)
        let rule = Rule(name: "Standardize AH Name")
        rule.isActive = true

        let trigger = RuleTrigger(field: .counterParty, triggerOperator: .contains, value: "ah ")
        trigger.rule = rule
        rule.triggers.append(trigger)

        // Only setCounterParty action, no setCategory
        let action = RuleAction(type: .setCounterParty, value: "Albert Heijn")
        action.rule = rule
        rule.actions.append(action)

        modelContext.insert(rule)
        try modelContext.save()

        let transaction = Transaction(iban: "NL00TEST001", sequenceNumber: 1, date: Date(), amount: -30, balance: 970, transactionType: .expense)
        transaction.counterName = "AH To Go Station"
        modelContext.insert(transaction)

        ruleService.processTransaction(transaction)

        // Should have standardized name but no category
        XCTAssertEqual(transaction.standardizedName, "Albert Heijn")
        XCTAssertNil(transaction.autoCategory)
    }

    func testRuleWithBothCategoryAndCounterParty() throws {
        let rule = Rule(name: "Albert Heijn Rule")
        rule.isActive = true

        let trigger = RuleTrigger(field: .counterParty, triggerOperator: .contains, value: "albert")
        trigger.rule = rule
        rule.triggers.append(trigger)

        let categoryAction = RuleAction(type: .setCategory, value: "Groceries")
        categoryAction.rule = rule
        categoryAction.sortOrder = 1
        rule.actions.append(categoryAction)

        let counterPartyAction = RuleAction(type: .setCounterParty, value: "Albert Heijn")
        counterPartyAction.rule = rule
        counterPartyAction.sortOrder = 2
        rule.actions.append(counterPartyAction)

        modelContext.insert(rule)
        try modelContext.save()

        let transaction = Transaction(iban: "NL00TEST001", sequenceNumber: 1, date: Date(), amount: -50, balance: 950, transactionType: .expense)
        transaction.counterName = "Albert Heijn Amsterdam"
        modelContext.insert(transaction)

        ruleService.processTransaction(transaction)

        // Should have both
        XCTAssertEqual(transaction.autoCategory, "Groceries")
        XCTAssertEqual(transaction.standardizedName, "Albert Heijn")
    }

    // MARK: - End-to-End Categorization Tests (ParsedTransaction path)

    func testCategorizeParsedTransactionsWithCategory() throws {
        // Create a rule
        let rule = Rule(name: "Groceries Rule")
        rule.isActive = true

        let trigger = RuleTrigger(field: .description, triggerOperator: .contains, value: "supermarket")
        trigger.rule = rule
        rule.triggers.append(trigger)

        let action = RuleAction(type: .setCategory, value: "Groceries")
        action.rule = rule
        rule.actions.append(action)

        modelContext.insert(rule)
        try modelContext.save()

        // Create parsed transactions (simulating CSV import)
        let parsed = [
            ParsedTransaction(
                iban: "NL00TEST001",
                sequenceNumber: 1,
                date: Date(),
                amount: Decimal(-50),
                balance: Decimal(950),
                counterIBAN: nil,
                counterName: "Local Store",
                description1: "Purchase at supermarket",
                description2: nil,
                description3: nil,
                transactionCode: nil,
                valueDate: nil,
                returnReason: nil,
                mandateReference: nil,
                transactionType: .expense,
                contributor: nil,
                sourceFile: "test.csv"
            ),
            ParsedTransaction(
                iban: "NL00TEST001",
                sequenceNumber: 2,
                date: Date(),
                amount: Decimal(-100),
                balance: Decimal(850),
                counterIBAN: nil,
                counterName: "Gas Station",
                description1: "Fuel purchase",
                description2: nil,
                description3: nil,
                transactionCode: nil,
                valueDate: nil,
                returnReason: nil,
                mandateReference: nil,
                transactionType: .expense,
                contributor: nil,
                sourceFile: "test.csv"
            )
        ]

        // Run categorization
        let results = ruleService.categorizeParsedTransactions(parsed)

        // First should be categorized, second should not
        XCTAssertEqual(results[0].category, "Groceries")
        XCTAssertNil(results[1].category)
    }

    func testCategorizeParsedTransactionsNameStandardizationOnly() throws {
        // Rule that only sets counter party (no category)
        let rule = Rule(name: "Standardize Name")
        rule.isActive = true

        let trigger = RuleTrigger(field: .counterParty, triggerOperator: .contains, value: "ah ")
        trigger.rule = rule
        rule.triggers.append(trigger)

        let action = RuleAction(type: .setCounterParty, value: "Albert Heijn")
        action.rule = rule
        rule.actions.append(action)

        modelContext.insert(rule)
        try modelContext.save()

        let parsed = [
            ParsedTransaction(
                iban: "NL00TEST001",
                sequenceNumber: 1,
                date: Date(),
                amount: Decimal(-30),
                balance: Decimal(970),
                counterIBAN: nil,
                counterName: "AH To Go",
                description1: "Purchase",
                description2: nil,
                description3: nil,
                transactionCode: nil,
                valueDate: nil,
                returnReason: nil,
                mandateReference: nil,
                transactionType: .expense,
                contributor: nil,
                sourceFile: "test.csv"
            )
        ]

        let results = ruleService.categorizeParsedTransactions(parsed)

        // Should have standardized name but no category
        XCTAssertNil(results[0].category)
        XCTAssertEqual(results[0].standardizedName, "Albert Heijn")
    }

    func testCategorizeParsedTransactionsMultipleRules() throws {
        // First rule: Only standardizes name (no category)
        let rule1 = Rule(name: "Standardize AH")
        rule1.isActive = true
        rule1.groupExecutionOrder = 1

        let trigger1 = RuleTrigger(field: .counterParty, triggerOperator: .contains, value: "ah ")
        trigger1.rule = rule1
        rule1.triggers.append(trigger1)

        let action1 = RuleAction(type: .setCounterParty, value: "Albert Heijn")
        action1.rule = rule1
        rule1.actions.append(action1)

        modelContext.insert(rule1)

        // Second rule: Sets category for groceries
        let rule2 = Rule(name: "Groceries Category")
        rule2.isActive = true
        rule2.groupExecutionOrder = 2

        let trigger2 = RuleTrigger(field: .counterParty, triggerOperator: .contains, value: "ah ")
        trigger2.rule = rule2
        rule2.triggers.append(trigger2)

        let action2 = RuleAction(type: .setCategory, value: "Groceries")
        action2.rule = rule2
        rule2.actions.append(action2)

        modelContext.insert(rule2)
        try modelContext.save()

        let parsed = [
            ParsedTransaction(
                iban: "NL00TEST001",
                sequenceNumber: 1,
                date: Date(),
                amount: Decimal(-30),
                balance: Decimal(970),
                counterIBAN: nil,
                counterName: "AH To Go",
                description1: "Purchase",
                description2: nil,
                description3: nil,
                transactionCode: nil,
                valueDate: nil,
                returnReason: nil,
                mandateReference: nil,
                transactionType: .expense,
                contributor: nil,
                sourceFile: "test.csv"
            )
        ]

        let results = ruleService.categorizeParsedTransactions(parsed)

        // Should have BOTH standardized name (from rule1) and category (from rule2)
        XCTAssertEqual(results[0].category, "Groceries")
        XCTAssertEqual(results[0].standardizedName, "Albert Heijn")
    }
}
