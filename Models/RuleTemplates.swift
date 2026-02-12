//
//  RuleTemplates.swift
//  Florijn
//
//  Pre-built rule templates for common financial scenarios.
//  Makes the rule engine accessible by providing one-click rule creation.
//
//  Created: 2026-02-10
//

import Foundation

// MARK: - Template Category

enum RuleTemplateCategory: String, CaseIterable, Sendable {
    case categorization = "Categorization"
    case cleanup = "Cleanup"
    case automation = "Automation"
    case detection = "Detection"

    var icon: String {
        switch self {
        case .categorization: return "folder.badge.plus"
        case .cleanup: return "paintbrush"
        case .automation: return "gearshape.2"
        case .detection: return "magnifyingglass"
        }
    }
}

// MARK: - Template Trigger

struct RuleTriggerTemplate: Sendable {
    let field: TriggerField
    let op: TriggerOperator
    let value: String
    let isInverted: Bool

    init(field: TriggerField, op: TriggerOperator, value: String, isInverted: Bool = false) {
        self.field = field
        self.op = op
        self.value = value
        self.isInverted = isInverted
    }
}

// MARK: - Template Action

struct RuleActionTemplate: Sendable {
    let type: ActionType
    let value: String
    let stopProcessing: Bool

    init(type: ActionType, value: String, stopProcessing: Bool = false) {
        self.type = type
        self.value = value
        self.stopProcessing = stopProcessing
    }
}

// MARK: - Rule Template

struct RuleTemplate: Sendable {
    let name: String
    let description: String
    let category: RuleTemplateCategory
    let triggers: [RuleTriggerTemplate]
    let actions: [RuleActionTemplate]
    let tags: [String]

    /// Create a Rule object from this template.
    /// The rule is NOT inserted into any model context -- caller is responsible for that.
    @MainActor
    func createRule() -> Rule {
        let rule = Rule(name: name)
        rule.triggerLogic = .all

        // Create triggers with sequential sort orders
        for (index, triggerTemplate) in triggers.enumerated() {
            let trigger = RuleTrigger(
                field: triggerTemplate.field,
                triggerOperator: triggerTemplate.op,
                value: triggerTemplate.value,
                isInverted: triggerTemplate.isInverted
            )
            trigger.sortOrder = index
            trigger.rule = rule
            rule.triggers.append(trigger)
        }

        // Create actions with sequential sort orders
        for (index, actionTemplate) in actions.enumerated() {
            let action = RuleAction(
                type: actionTemplate.type,
                value: actionTemplate.value,
                stopProcessingAfter: actionTemplate.stopProcessing
            )
            action.sortOrder = index
            action.rule = rule
            rule.actions.append(action)
        }

        return rule
    }
}

// MARK: - Pre-built Templates

struct RuleTemplates {

    // MARK: - Categorization Templates

    /// Detect recurring subscription payments by amount range + description keyword
    static let subscriptionDetection = RuleTemplate(
        name: "Subscription Detection",
        description: "Automatically categorize recurring small payments as subscriptions",
        category: .categorization,
        triggers: [
            RuleTriggerTemplate(field: .amount, op: .greaterThan, value: "-50"),
            RuleTriggerTemplate(field: .amount, op: .lessThan, value: "-2"),
            RuleTriggerTemplate(field: .description, op: .contains, value: "subscription"),
        ],
        actions: [
            RuleActionTemplate(type: .setCategory, value: "Subscriptions", stopProcessing: true),
        ],
        tags: ["automation", "categorization", "subscriptions"]
    )

    /// Detect common Dutch grocery stores via regex
    static let groceryDetection = RuleTemplate(
        name: "Grocery Store Detection",
        description: "Auto-categorize common Dutch grocery stores",
        category: .categorization,
        triggers: [
            RuleTriggerTemplate(
                field: .counterParty,
                op: .matches,
                value: "(?i)(albert heijn|jumbo|lidl|aldi|plus|coop)"
            ),
        ],
        actions: [
            RuleActionTemplate(type: .setCategory, value: "Groceries", stopProcessing: true),
        ],
        tags: ["categorization", "groceries", "regex"]
    )

    /// Detect salary/income by amount + description keywords
    static let salaryDetection = RuleTemplate(
        name: "Salary Detection",
        description: "Automatically categorize salary payments",
        category: .categorization,
        triggers: [
            RuleTriggerTemplate(field: .amount, op: .greaterThan, value: "1000"),
            RuleTriggerTemplate(field: .description, op: .matches, value: "(?i)(salaris|loon|salary)"),
        ],
        actions: [
            RuleActionTemplate(type: .setCategory, value: "Salary", stopProcessing: true),
        ],
        tags: ["categorization", "income", "salary"]
    )

    // MARK: - Cleanup Templates

    /// Remove categories from inter-account transfers (Dutch: overboeking)
    static let transferCleanup = RuleTemplate(
        name: "Transfer Cleanup",
        description: "Remove categories from inter-account transfers",
        category: .cleanup,
        triggers: [
            RuleTriggerTemplate(field: .description, op: .contains, value: "overboeking"),
        ],
        actions: [
            RuleActionTemplate(type: .clearCategory, value: "", stopProcessing: true),
        ],
        tags: ["cleanup", "transfers"]
    )

    /// Standardize Albert Heijn name variations and set category
    static let merchantStandardization = RuleTemplate(
        name: "Merchant Standardization",
        description: "Standardize merchant names (Albert Heijn variations)",
        category: .cleanup,
        triggers: [
            RuleTriggerTemplate(field: .counterParty, op: .contains, value: "AH "),
        ],
        actions: [
            RuleActionTemplate(type: .setCounterParty, value: "Albert Heijn"),
            RuleActionTemplate(type: .setCategory, value: "Groceries"),
        ],
        tags: ["standardization", "merchants", "groceries"]
    )

    // MARK: - Collection Accessors

    static let allTemplates: [RuleTemplate] = [
        subscriptionDetection,
        transferCleanup,
        merchantStandardization,
        groceryDetection,
        salaryDetection,
    ]

    /// Filter templates by category
    static func templatesForCategory(_ category: RuleTemplateCategory) -> [RuleTemplate] {
        allTemplates.filter { $0.category == category }
    }

    /// Filter templates by tag
    static func templatesWithTag(_ tag: String) -> [RuleTemplate] {
        allTemplates.filter { $0.tags.contains(tag) }
    }

    /// Search templates by name, description, or tags (case-insensitive)
    static func search(_ query: String) -> [RuleTemplate] {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            return allTemplates
        }
        return allTemplates.filter { template in
            template.name.localizedCaseInsensitiveContains(query) ||
            template.description.localizedCaseInsensitiveContains(query) ||
            template.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
}
