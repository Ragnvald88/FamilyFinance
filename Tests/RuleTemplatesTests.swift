//
//  RuleTemplatesTests.swift
//  Florijn Tests
//
//  Tests for the rule template system - verifying templates create valid rules
//

import XCTest
@preconcurrency import SwiftData
@testable import FamilyFinance

@MainActor
final class RuleTemplatesTests: XCTestCase {

    // MARK: - Subscription Detection Template

    func test_subscriptionTemplate_creates_correct_rule() throws {
        let template = RuleTemplates.subscriptionDetection
        let rule = template.createRule()

        XCTAssertEqual(rule.name, "Subscription Detection")
        XCTAssertEqual(rule.triggers.count, 3)
        XCTAssertEqual(rule.actions.count, 1)
        XCTAssertTrue(rule.isActive)
        XCTAssertEqual(rule.triggerLogic, .all)

        // Verify triggers
        let amountTriggers = rule.triggers.filter { $0.field == .amount }
        XCTAssertEqual(amountTriggers.count, 2, "Should have two amount triggers (range)")

        let descTriggers = rule.triggers.filter { $0.field == .description }
        XCTAssertEqual(descTriggers.count, 1, "Should have one description trigger")

        // Verify action
        let action = rule.actions.first!
        XCTAssertEqual(action.type, .setCategory)
        XCTAssertEqual(action.value, "Subscriptions")
        XCTAssertTrue(action.stopProcessingAfter)
    }

    func test_subscriptionTemplate_metadata() throws {
        let template = RuleTemplates.subscriptionDetection

        XCTAssertEqual(template.category, .categorization)
        XCTAssertFalse(template.description.isEmpty)
        XCTAssertTrue(template.tags.contains("subscriptions"))
    }

    // MARK: - Transfer Cleanup Template

    func test_transferCleanup_template_creates_correct_rule() throws {
        let template = RuleTemplates.transferCleanup
        let rule = template.createRule()

        XCTAssertEqual(rule.name, "Transfer Cleanup")
        XCTAssertTrue(rule.triggers.contains { $0.field == .description })
        XCTAssertTrue(rule.actions.contains { $0.type == .clearCategory })
    }

    func test_transferCleanup_has_cleanup_category() throws {
        let template = RuleTemplates.transferCleanup

        XCTAssertEqual(template.category, .cleanup)
    }

    // MARK: - Merchant Standardization Template

    func test_merchantStandardization_creates_rule_with_two_actions() throws {
        let template = RuleTemplates.merchantStandardization
        let rule = template.createRule()

        XCTAssertEqual(rule.name, "Merchant Standardization")
        XCTAssertEqual(rule.triggers.count, 1)
        XCTAssertEqual(rule.actions.count, 2, "Should set counter party AND category")

        let counterPartyAction = rule.actions.first { $0.type == .setCounterParty }
        XCTAssertNotNil(counterPartyAction)
        XCTAssertEqual(counterPartyAction?.value, "Albert Heijn")

        let categoryAction = rule.actions.first { $0.type == .setCategory }
        XCTAssertNotNil(categoryAction)
        XCTAssertEqual(categoryAction?.value, "Groceries")
    }

    // MARK: - Grocery Detection Template

    func test_groceryDetection_uses_regex_trigger() throws {
        let template = RuleTemplates.groceryDetection
        let rule = template.createRule()

        XCTAssertEqual(rule.name, "Grocery Store Detection")
        XCTAssertEqual(rule.triggers.count, 1)

        let trigger = rule.triggers.first!
        XCTAssertEqual(trigger.field, .counterParty)
        XCTAssertEqual(trigger.triggerOperator, .matches)
        XCTAssertTrue(trigger.value.contains("albert heijn"))

        let action = rule.actions.first!
        XCTAssertEqual(action.type, .setCategory)
        XCTAssertEqual(action.value, "Groceries")
        XCTAssertTrue(action.stopProcessingAfter)
    }

    // MARK: - Salary Detection Template

    func test_salaryDetection_creates_correct_rule() throws {
        let template = RuleTemplates.salaryDetection
        let rule = template.createRule()

        XCTAssertEqual(rule.name, "Salary Detection")
        XCTAssertEqual(rule.triggers.count, 2)

        // Should have amount trigger for large amounts
        let amountTrigger = rule.triggers.first { $0.field == .amount }
        XCTAssertNotNil(amountTrigger)
        XCTAssertEqual(amountTrigger?.triggerOperator, .greaterThan)

        // Should have description regex for salary keywords
        let descTrigger = rule.triggers.first { $0.field == .description }
        XCTAssertNotNil(descTrigger)
        XCTAssertEqual(descTrigger?.triggerOperator, .matches)

        let action = rule.actions.first!
        XCTAssertEqual(action.type, .setCategory)
        XCTAssertEqual(action.value, "Salary")
        XCTAssertTrue(action.stopProcessingAfter)
    }

    // MARK: - Template Collection Tests

    func test_allTemplates_returns_five_templates() throws {
        XCTAssertEqual(RuleTemplates.allTemplates.count, 5)
    }

    func test_allTemplates_have_unique_names() throws {
        let names = RuleTemplates.allTemplates.map(\.name)
        let uniqueNames = Set(names)
        XCTAssertEqual(names.count, uniqueNames.count, "All template names should be unique")
    }

    func test_allTemplates_create_valid_rules() throws {
        for template in RuleTemplates.allTemplates {
            let rule = template.createRule()
            XCTAssertFalse(rule.name.isEmpty, "Rule from '\(template.name)' should have a name")
            XCTAssertFalse(rule.triggers.isEmpty, "Rule from '\(template.name)' should have triggers")
            XCTAssertFalse(rule.actions.isEmpty, "Rule from '\(template.name)' should have actions")
            XCTAssertTrue(rule.isActive, "Rule from '\(template.name)' should be active by default")
        }
    }

    // MARK: - Category Filtering Tests

    func test_templatesForCategory_categorization() throws {
        let templates = RuleTemplates.templatesForCategory(.categorization)

        XCTAssertFalse(templates.isEmpty)
        XCTAssertTrue(templates.allSatisfy { $0.category == .categorization })
        XCTAssertTrue(templates.contains { $0.name == "Subscription Detection" })
        XCTAssertTrue(templates.contains { $0.name == "Grocery Store Detection" })
        XCTAssertTrue(templates.contains { $0.name == "Salary Detection" })
    }

    func test_templatesForCategory_cleanup() throws {
        let templates = RuleTemplates.templatesForCategory(.cleanup)

        XCTAssertFalse(templates.isEmpty)
        XCTAssertTrue(templates.allSatisfy { $0.category == .cleanup })
        XCTAssertTrue(templates.contains { $0.name == "Transfer Cleanup" })
        XCTAssertTrue(templates.contains { $0.name == "Merchant Standardization" })
    }

    // MARK: - Tag Filtering Tests

    func test_templatesWithTag_groceries() throws {
        let templates = RuleTemplates.templatesWithTag("groceries")

        XCTAssertFalse(templates.isEmpty)
        XCTAssertTrue(templates.allSatisfy { $0.tags.contains("groceries") })
    }

    func test_templatesWithTag_nonexistent_returns_empty() throws {
        let templates = RuleTemplates.templatesWithTag("nonexistent-tag-xyz")
        XCTAssertTrue(templates.isEmpty)
    }

    // MARK: - Template Search Tests

    func test_search_matches_name() throws {
        let results = RuleTemplates.search("subscription")
        XCTAssertTrue(results.contains { $0.name == "Subscription Detection" })
    }

    func test_search_matches_description() throws {
        let results = RuleTemplates.search("recurring")
        XCTAssertTrue(results.contains { $0.name == "Subscription Detection" })
    }

    func test_search_matches_tags() throws {
        let results = RuleTemplates.search("salary")
        XCTAssertTrue(results.contains { $0.name == "Salary Detection" })
    }

    func test_search_empty_returns_all() throws {
        let results = RuleTemplates.search("")
        XCTAssertEqual(results.count, RuleTemplates.allTemplates.count)
    }

    func test_search_no_match_returns_empty() throws {
        let results = RuleTemplates.search("zxywvut-no-match")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Rule Properties Tests

    func test_created_rules_have_triggerLogic_all() throws {
        // All templates should use AND logic by default
        for template in RuleTemplates.allTemplates {
            let rule = template.createRule()
            XCTAssertEqual(rule.triggerLogic, .all,
                           "Template '\(template.name)' should create rule with .all trigger logic")
        }
    }

    func test_created_rules_are_not_persisted() throws {
        // Templates create Rule objects but do NOT insert them into a model context
        let rule = RuleTemplates.subscriptionDetection.createRule()
        XCTAssertNotNil(rule)
        // Rule should exist as an in-memory object, not yet persisted
        XCTAssertEqual(rule.matchCount, 0)
        XCTAssertNil(rule.lastMatchedAt)
    }

    func test_trigger_sort_orders_are_sequential() throws {
        for template in RuleTemplates.allTemplates {
            let rule = template.createRule()
            let sortOrders = rule.triggers.map(\.sortOrder)
            let expected = Array(0..<rule.triggers.count)
            XCTAssertEqual(sortOrders, expected,
                           "Template '\(template.name)' triggers should have sequential sort orders")
        }
    }

    func test_action_sort_orders_are_sequential() throws {
        for template in RuleTemplates.allTemplates {
            let rule = template.createRule()
            let sortOrders = rule.actions.map(\.sortOrder)
            let expected = Array(0..<rule.actions.count)
            XCTAssertEqual(sortOrders, expected,
                           "Template '\(template.name)' actions should have sequential sort orders")
        }
    }
}
