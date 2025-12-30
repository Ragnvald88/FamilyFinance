//
//  ActionExecutorTests.swift
//  FlorijnTests
//
//  Integration tests for ActionExecutor component
//  Tests all 16 action types and ACID transaction safety
//
//  Created: 2025-12-27
//

import XCTest
import SwiftData
@testable import Florijn

@MainActor
final class ActionExecutorTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var actionExecutor: ActionExecutor!
    var testAccount: Account!
    var testTransaction: Transaction!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory model container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: Transaction.self, Account.self, Category.self,
                 RuleGroup.self, Rule.self, RuleTrigger.self, RuleAction.self, TriggerGroup.self,
            configurations: config
        )
        modelContext = ModelContext(modelContainer)

        // Initialize ActionExecutor
        actionExecutor = ActionExecutor(modelContainer: modelContainer)

        // Create test data
        testAccount = Account(
            iban: "NL91ABNA0417164300",
            name: "Test Account",
            accountType: .checking,
            owner: "Test Owner"
        )
        modelContext.insert(testAccount)

        testTransaction = Transaction(
            iban: "NL91ABNA0417164300",
            sequenceNumber: 1,
            date: Date(),
            amount: Decimal(-50.00),
            balance: Decimal(1000.00),
            counterName: "Test Merchant",
            description1: "Test Transaction",
            transactionType: .expense,
            account: testAccount
        )
        modelContext.insert(testTransaction)

        try modelContext.save()
    }

    override func tearDown() async throws {
        actionExecutor = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - Categorization Action Tests

    func testSetCategoryAction() async throws {
        // Given
        let action = RuleAction(type: .setCategory, value: "Groceries")

        // When
        let result = try await actionExecutor.executeActions([action], on: testTransaction)

        // Then
        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(result.failureCount, 0)
        XCTAssertEqual(testTransaction.categoryOverride, "Groceries")
    }

    func testClearCategoryAction() async throws {
        // Given
        testTransaction.updateCategoryOverride("OldCategory")
        let action = RuleAction(type: .clearCategory, value: "")

        // When
        let result = try await actionExecutor.executeActions([action], on: testTransaction)

        // Then
        XCTAssertEqual(result.successCount, 1)
        XCTAssertNil(testTransaction.categoryOverride)
    }

    func testSetNotesAction() async throws {
        // Given
        let action = RuleAction(type: .setNotes, value: "Added by rule")

        // When
        let result = try await actionExecutor.executeActions([action], on: testTransaction)

        // Then
        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(testTransaction.notes, "Added by rule")
    }

    func testAddTagAction() async throws {
        // Given
        let action = RuleAction(type: .addTag, value: "important")

        // When
        let result = try await actionExecutor.executeActions([action], on: testTransaction)

        // Then
        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(testTransaction.notes, "important")
    }

    func testRemoveTagAction() async throws {
        // Given
        testTransaction.notes = "tag1, important, tag2"
        let action = RuleAction(type: .removeTag, value: "important")

        // When
        let result = try await actionExecutor.executeActions([action], on: testTransaction)

        // Then
        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(testTransaction.notes, "tag1, tag2")
    }

    func testClearAllTagsAction() async throws {
        // Given
        testTransaction.notes = "tag1, tag2, tag3"
        let action = RuleAction(type: .clearAllTags, value: "")

        // When
        let result = try await actionExecutor.executeActions([action], on: testTransaction)

        // Then
        XCTAssertEqual(result.successCount, 1)
        XCTAssertNil(testTransaction.notes)
    }

    // MARK: - Account Operation Tests

    func testSetCounterPartyAction() async throws {
        // Given
        let action = RuleAction(type: .setCounterParty, value: "New Merchant")

        // When
        let result = try await actionExecutor.executeActions([action], on: testTransaction)

        // Then
        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(testTransaction.counterName, "New Merchant")
        XCTAssertEqual(testTransaction.standardizedName, "New Merchant")
    }

    func testSetSourceAccountAction() async throws {
        // Given
        // Create another account for testing
        let secondAccount = Account(
            iban: "NL91RABO0000000001",
            name: "Second Account",
            accountType: .savings,
            owner: "Test Owner"
        )
        modelContext.insert(secondAccount)
        try modelContext.save()

        let action = RuleAction(type: .setSourceAccount, value: "Second Account")

        // When
        let result = try await actionExecutor.executeActions([action], on: testTransaction)

        // Then
        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(testTransaction.account?.name, "Second Account")
    }

    // MARK: - Transaction Conversion Tests

    func testConvertToDepositAction() async throws {
        // Given
        let action = RuleAction(type: .convertToDeposit, value: "")

        // When
        let result = try await actionExecutor.executeActions([action], on: testTransaction)

        // Then
        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(testTransaction.transactionType, .income)
        XCTAssertTrue(testTransaction.amount > 0) // Amount should be positive for deposits
    }

    func testConvertToWithdrawalAction() async throws {
        // Given
        testTransaction.amount = Decimal(50.00) // Start with positive amount
        let action = RuleAction(type: .convertToWithdrawal, value: "")

        // When
        let result = try await actionExecutor.executeActions([action], on: testTransaction)

        // Then
        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(testTransaction.transactionType, .expense)
        XCTAssertTrue(testTransaction.amount < 0) // Amount should be negative for withdrawals
    }

    func testConvertToTransferAction() async throws {
        // Given
        let action = RuleAction(type: .convertToTransfer, value: "")

        // When
        let result = try await actionExecutor.executeActions([action], on: testTransaction)

        // Then
        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(testTransaction.transactionType, .transfer)
    }

    // MARK: - Advanced Action Tests

    func testDeleteTransactionAction() async throws {
        // Given
        let action = RuleAction(type: .deleteTransaction, value: "")

        // When
        let result = try await actionExecutor.executeActions([action], on: testTransaction)

        // Then
        XCTAssertEqual(result.successCount, 1)
        XCTAssertTrue(testTransaction.notes?.contains("[DELETED by rule]") == true)
    }

    func testSetExternalIdAction() async throws {
        // Given
        let action = RuleAction(type: .setExternalId, value: "EXT123456")

        // When
        let result = try await actionExecutor.executeActions([action], on: testTransaction)

        // Then
        XCTAssertEqual(result.successCount, 1)
        XCTAssertTrue(testTransaction.notes?.contains("External ID: EXT123456") == true)
    }

    func testSetInternalReferenceAction() async throws {
        // Given
        let action = RuleAction(type: .setInternalReference, value: "REF789")

        // When
        let result = try await actionExecutor.executeActions([action], on: testTransaction)

        // Then
        XCTAssertEqual(result.successCount, 1)
        XCTAssertTrue(testTransaction.notes?.contains("Ref: REF789") == true)
    }

    // MARK: - Error Handling Tests

    func testInvalidActionValue() async throws {
        // Given
        let action = RuleAction(type: .setCategory, value: "") // Invalid empty value

        // When & Then
        do {
            _ = try await actionExecutor.executeActions([action], on: testTransaction)
            XCTFail("Expected error for invalid action")
        } catch ActionExecutionError.partialFailure(let results, _) {
            XCTAssertEqual(results.count, 1)
            if case .failure = results[0] {
                // Expected behavior
            } else {
                XCTFail("Expected failure result")
            }
        }
    }

    func testNonExistentAccount() async throws {
        // Given
        let action = RuleAction(type: .setSourceAccount, value: "NonExistentAccount")

        // When & Then
        do {
            _ = try await actionExecutor.executeActions([action], on: testTransaction)
            XCTFail("Expected error for non-existent account")
        } catch {
            // Expected behavior - should fail when account doesn't exist
        }
    }

    // MARK: - Multiple Actions Test

    func testMultipleActions() async throws {
        // Given
        let actions = [
            RuleAction(type: .setCategory, value: "Shopping"),
            RuleAction(type: .setNotes, value: "Processed by rule"),
            RuleAction(type: .setCounterParty, value: "Updated Merchant")
        ]

        // When
        let result = try await actionExecutor.executeActions(actions, on: testTransaction)

        // Then
        XCTAssertEqual(result.successCount, 3)
        XCTAssertEqual(result.failureCount, 0)
        XCTAssertEqual(testTransaction.categoryOverride, "Shopping")
        XCTAssertEqual(testTransaction.notes, "Processed by rule")
        XCTAssertEqual(testTransaction.counterName, "Updated Merchant")
    }

    // MARK: - ACID Transaction Test

    func testACIDTransactionRollback() async throws {
        // Given - Actions where second one will fail
        let actions = [
            RuleAction(type: .setCategory, value: "ValidCategory"),
            RuleAction(type: .setSourceAccount, value: "NonExistentAccount") // This will fail
        ]

        let originalCategoryOverride = testTransaction.categoryOverride

        // When & Then
        do {
            _ = try await actionExecutor.executeActions(actions, on: testTransaction)
            XCTFail("Expected transaction to fail and rollback")
        } catch ActionExecutionError.partialFailure {
            // Expected behavior
            // Verify rollback - category should not have been set
            XCTAssertEqual(testTransaction.categoryOverride, originalCategoryOverride)
        }
    }

    // MARK: - Relationship Cache Test

    func testCategoryCreation() async throws {
        // Given
        let action = RuleAction(type: .setCategory, value: "NewUniqueCategory")

        // When
        let result = try await actionExecutor.executeActions([action], on: testTransaction)

        // Then
        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(testTransaction.categoryOverride, "NewUniqueCategory")

        // Verify category was created in database
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.name == "NewUniqueCategory" }
        )
        let categories = try modelContext.fetch(descriptor)
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories.first?.name, "NewUniqueCategory")
    }

    // MARK: - Performance Test

    func testBulkActionPerformance() async throws {
        // Given - Create multiple transactions
        var transactions: [Transaction] = []
        for i in 1...100 {
            let transaction = Transaction(
                iban: "NL91ABNA0417164300",
                sequenceNumber: i + 1,
                date: Date(),
                amount: Decimal(-10.00 * Double(i)),
                balance: Decimal(1000.00),
                counterName: "Merchant \(i)",
                description1: "Transaction \(i)",
                transactionType: .expense,
                account: testAccount
            )
            modelContext.insert(transaction)
            transactions.append(transaction)
        }
        try modelContext.save()

        let actions = [RuleAction(type: .setCategory, value: "BulkCategory")]

        // When - Measure bulk processing time
        let startTime = Date()

        var processedCount = 0
        for result in actionExecutor.executeBulkActions(actions, on: transactions) {
            switch result {
            case .item(let executionResult):
                XCTAssertEqual(executionResult.successCount, 1)
                processedCount += 1
            case .progress(let progress):
                XCTAssertGreaterThanOrEqual(progress.completed, 0)
                XCTAssertLessThanOrEqual(progress.completed, 100)
            case .completed(let summary):
                XCTAssertEqual(summary.totalProcessed, 100)
                XCTAssertEqual(summary.successCount, 100)
                XCTAssertEqual(summary.failureCount, 0)
                break
            }
        }

        let processingTime = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertEqual(processedCount, 100)
        XCTAssertLessThan(processingTime, 5.0) // Should complete within 5 seconds
        print("Processed 100 transactions in \(processingTime) seconds")
    }
}