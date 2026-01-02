# Florijn Development Guide

> macOS Personal Finance App | SwiftUI + SwiftData
> **Mission:** Simple, reliable transaction management with automatic categorization

---

## Critical Context

**Florijn is a personal finance app that imports Dutch bank CSV files and automatically categorizes transactions.** The current codebase has accumulated complexity that obscures this simple purpose. This guide exists to reverse that trend.

### The Golden Rule

**Before writing any code, ask: "Is this the simplest solution that works?"**

If you find yourself:
- Creating a new actor or service → Stop. Can an existing one handle it?
- Adding a caching layer → Stop. Is performance actually a problem?
- Writing an abstraction → Stop. Is there more than one use case right now?
- Adding error classification → Stop. Can you just handle the error where it occurs?

---

## Architecture Overview

### Target Structure (What We're Working Toward)

```
Florijn/
├── FlorijnApp.swift              # App entry + ModelContainer ONLY (~100 lines)
├── Models/
│   ├── Transaction.swift         # Core transaction model
│   ├── Account.swift             # Bank account model
│   ├── Category.swift            # Transaction categories
│   └── Rule.swift                # Rule + Trigger + Action (unified)
├── Services/
│   ├── ImportService.swift       # CSV parsing + transaction creation
│   ├── RuleService.swift         # ONE service for ALL rule operations
│   └── QueryService.swift        # Analytics and aggregations
├── Views/
│   ├── DashboardView.swift       # Main dashboard
│   ├── TransactionsView.swift    # Transaction list
│   ├── RulesView.swift           # Rule management
│   ├── ImportView.swift          # CSV import UI
│   ├── AccountsView.swift        # Account management
│   ├── CategoriesView.swift      # Category management
│   └── Components/               # Reusable UI components
└── Extensions/
    └── ViewExtensions.swift      # Design system
```

### Current Problems to Fix

| Problem | Location | Impact |
|---------|----------|--------|
| **Two rule engines** | `RuleEngine.swift` + `CategorizationEngine.swift` | Rules work inconsistently |
| **God file** | `FlorijnApp.swift` (3,188 lines) | Impossible to navigate |
| **Unused models** | `Merchant`, `BudgetPeriod`, `TransactionSplit`, `RecurringTransaction` | Dead code confusion |
| **Over-engineering** | Saga patterns, circuit breakers, error classifiers | Hides simple bugs |

---

## Refactoring Tasks (Execute In Order)

### Phase 1: Unify Rule Execution (CRITICAL)

**Problem:** `CategorizationEngine` (used during import) and `RuleEngine` (used manually) produce different results.

**Solution:** Create ONE `RuleService` that handles all rule operations.

#### Step 1.1: Create Unified RuleService

Create `Services/RuleService.swift`:

```swift
import SwiftData
import Foundation

/// Single source of truth for all rule operations
/// Used by both CSV import AND manual rule execution
@MainActor
class RuleService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Evaluate a single rule against a transaction
    func evaluate(rule: Rule, against transaction: Transaction) -> Bool {
        // Get all triggers (handles both simple and grouped)
        let triggers = rule.allTriggers
        guard !triggers.isEmpty else { return false }

        let results = triggers.map { evaluate(trigger: $0, against: transaction) }

        // Apply trigger logic (AND/OR)
        switch rule.triggerLogic {
        case .all: return results.allSatisfy { $0 }
        case .any: return results.contains { $0 }
        }
    }

    /// Apply a rule's actions to a transaction
    func apply(rule: Rule, to transaction: Transaction) {
        for action in rule.actions.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            apply(action: action, to: transaction)

            if action.stopProcessingAfter {
                break
            }
        }

        // Update rule statistics
        rule.matchCount += 1
        rule.lastMatchedAt = Date()
    }

    /// Process a transaction through all active rules
    func processTransaction(_ transaction: Transaction) {
        let rules = fetchActiveRules()

        for rule in rules {
            if evaluate(rule: rule, against: transaction) {
                apply(rule: rule, to: transaction)

                if rule.stopProcessing {
                    break
                }
            }
        }
    }

    /// Process multiple transactions (for import)
    func processTransactions(_ transactions: [Transaction]) {
        let rules = fetchActiveRules()

        for transaction in transactions {
            for rule in rules {
                if evaluate(rule: rule, against: transaction) {
                    apply(rule: rule, to: transaction)

                    if rule.stopProcessing {
                        break
                    }
                }
            }
        }
    }

    // MARK: - Private Implementation

    private func fetchActiveRules() -> [Rule] {
        let descriptor = FetchDescriptor<Rule>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.groupExecutionOrder)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func evaluate(trigger: RuleTrigger, against transaction: Transaction) -> Bool {
        let fieldValue = getFieldValue(trigger.field, from: transaction)
        let result = evaluateOperator(trigger.triggerOperator, fieldValue: fieldValue, triggerValue: trigger.value)
        return trigger.isInverted ? !result : result
    }

    private func getFieldValue(_ field: TriggerField, from transaction: Transaction) -> String {
        switch field {
        case .description:
            return transaction.fullDescription.lowercased()
        case .counterParty:
            return (transaction.counterName ?? "").lowercased()
        case .counterIban:
            return (transaction.counterIBAN ?? "").lowercased()
        case .amount:
            return "\(transaction.amount)"
        case .accountName:
            return (transaction.account?.name ?? "").lowercased()
        case .iban:
            return transaction.iban.lowercased()
        case .transactionType:
            return transaction.transactionType.rawValue.lowercased()
        case .category:
            return transaction.effectiveCategory.lowercased()
        case .notes:
            return (transaction.notes ?? "").lowercased()
        case .date:
            return ISO8601DateFormatter().string(from: transaction.date)
        case .externalId, .internalReference, .tags:
            return "" // Not implemented yet
        }
    }

    private func evaluateOperator(_ op: TriggerOperator, fieldValue: String, triggerValue: String) -> Bool {
        let value = triggerValue.lowercased()

        switch op {
        case .contains:
            return fieldValue.contains(value)
        case .equals:
            return fieldValue == value
        case .startsWith:
            return fieldValue.hasPrefix(value)
        case .endsWith:
            return fieldValue.hasSuffix(value)
        case .matches:
            guard let regex = try? NSRegularExpression(pattern: triggerValue, options: [.caseInsensitive]) else {
                return false
            }
            let range = NSRange(fieldValue.startIndex..., in: fieldValue)
            return regex.firstMatch(in: fieldValue, range: range) != nil
        case .isEmpty:
            return fieldValue.isEmpty
        case .isNotEmpty, .hasValue:
            return !fieldValue.isEmpty
        case .greaterThan:
            guard let fieldNum = Double(fieldValue), let triggerNum = Double(triggerValue) else { return false }
            return fieldNum > triggerNum
        case .lessThan:
            guard let fieldNum = Double(fieldValue), let triggerNum = Double(triggerValue) else { return false }
            return fieldNum < triggerNum
        case .greaterThanOrEqual:
            guard let fieldNum = Double(fieldValue), let triggerNum = Double(triggerValue) else { return false }
            return fieldNum >= triggerNum
        case .lessThanOrEqual:
            guard let fieldNum = Double(fieldValue), let triggerNum = Double(triggerValue) else { return false }
            return fieldNum <= triggerNum
        case .before, .after, .on, .today, .yesterday, .tomorrow:
            return false // Date operators - implement if needed
        }
    }

    private func apply(action: RuleAction, to transaction: Transaction) {
        switch action.type {
        case .setCategory:
            transaction.autoCategory = action.value
            transaction.indexedCategory = transaction.effectiveCategory
        case .clearCategory:
            transaction.autoCategory = nil
            transaction.indexedCategory = transaction.effectiveCategory
        case .setNotes:
            transaction.notes = action.value
        case .setDescription:
            transaction.description1 = action.value
        case .appendDescription:
            transaction.description1 = (transaction.description1 ?? "") + " " + action.value
        case .prependDescription:
            transaction.description1 = action.value + " " + (transaction.description1 ?? "")
        case .setCounterParty:
            transaction.standardizedName = action.value
        case .addTag, .removeTag, .clearAllTags:
            break // Tags stored in notes - implement if needed
        case .setSourceAccount, .setDestinationAccount, .swapAccounts:
            break // Account operations - implement if needed
        case .convertToDeposit:
            transaction.transactionType = .income
        case .convertToWithdrawal:
            transaction.transactionType = .expense
        case .convertToTransfer:
            transaction.transactionType = .transfer
        case .deleteTransaction:
            break // Dangerous - skip
        case .setExternalId, .setInternalReference:
            break // Metadata - implement if needed
        }
    }
}
```

#### Step 1.2: Update ImportService to Use RuleService

Modify `CSVImportService.swift` to use `RuleService` instead of `CategorizationEngine`:

```swift
// In CSVImportService, replace CategorizationEngine usage:
let ruleService = RuleService(modelContext: modelContext)
ruleService.processTransactions(importedTransactions)
```

#### Step 1.3: Remove Redundant Services

After RuleService is working:
1. Delete `Services/CategorizationEngine.swift`
2. Delete `Services/TriggerEvaluator.swift`
3. Delete `Services/ActionExecutor.swift`
4. Simplify `Services/RuleEngine.swift` to just call RuleService (or remove entirely)

---

### Phase 2: Split FlorijnApp.swift

**Problem:** 3,188 lines in one file mixing app entry, views, editors, and view models.

**Solution:** Extract each view to its own file.

#### Step 2.1: Extract Views

Create these files by moving code from FlorijnApp.swift:

| New File | Content to Extract |
|----------|-------------------|
| `Views/TransactionsView.swift` | `TransactionsListView`, `TransactionRowView`, `TransactionEditorSheet` |
| `Views/AccountsView.swift` | `AccountsListView`, `AccountCardView` |
| `Views/CategoriesView.swift` | `CategoriesListView`, `CategoryRowView`, `CategoryEditorSheet` |
| `Views/BudgetsView.swift` | `BudgetsListView`, `BudgetCategoryCard` |
| `Views/MerchantsView.swift` | `MerchantsListView`, `MerchantRowView`, `MerchantDisplayStats` |
| `Views/TransfersView.swift` | `TransfersListView`, `TransferRowView` |
| `Views/InsightsView.swift` | Already exists, but ensure view model is included |
| `Views/SettingsView.swift` | Extract if exists |

#### Step 2.2: Slim Down FlorijnApp.swift

After extraction, FlorijnApp.swift should contain ONLY:
- `@main struct FlorijnApp: App`
- `sharedModelContainer` setup
- `body: some Scene` with navigation
- `ContentView` and `SidebarView`
- App state and tab definitions

Target: **Under 300 lines**

---

### Phase 3: Clean Up Models

#### Step 3.1: Remove Unused Models

Delete or comment out until needed:
- `Merchant` model (line 767-842 in SwiftDataModels.swift)
- `BudgetPeriod` model (line 844-904)
- `TransactionSplit` model (line 906-961)
- `RecurringTransaction` model (line 963-1104)

Keep `TransactionAuditLog` only if actively displayed in UI.

#### Step 3.2: Simplify Transaction Model

Consider removing denormalized fields if not performance-critical:
- Keep `year` and `month` (they help with queries)
- Ensure `indexedCategory` is always synced via `updateCategoryOverride()`

---

### Phase 4: Simplify Services

#### Step 4.1: Consolidate Query Service

`TransactionQueryService.swift` (1,071 lines) does too much. Consider:
- Keep aggregation methods
- Remove anything not used by views
- Remove caching if queries are fast enough without it

#### Step 4.2: Simplify Import Service

`CSVImportService.swift` + `BackgroundDataHandler.swift` can potentially merge into one simpler service:

```swift
class ImportService {
    func importCSV(from url: URL) async throws -> ImportResult
    // That's it. One method.
}
```

#### Step 4.3: Remove Over-Engineering

Delete these patterns wherever found:
- `CircuitBreaker`
- `ErrorClassifier` / `ErrorClassification`
- `ConcurrencyManager` (just use fixed batch size)
- `Saga` pattern references
- `RecoveryStrategy` enums

---

## Code Style Rules

### DO

```swift
// Simple, direct code
func categorize(_ transaction: Transaction) {
    for rule in rules where rule.isActive {
        if matches(rule, transaction) {
            transaction.category = rule.category
            return
        }
    }
}
```

### DON'T

```swift
// Over-engineered code
func categorize(_ transaction: Transaction) async throws -> CategorizationResult {
    let context = ExecutionContext(transaction: transaction)
    let strategy = await strategySelector.selectOptimalStrategy(for: context)
    let result = try await executeWithCircuitBreaker {
        try await withRetry(maxAttempts: 3) {
            try await evaluateRulesParallel(transaction, strategy: strategy)
        }
    }
    await metricsCollector.record(result)
    return result
}
```

### Naming Conventions

- Services: `XxxService` (not `XxxEngine`, not `XxxHandler`, not `XxxManager`)
- One service = one responsibility
- View files match their main view: `TransactionsView.swift` contains `TransactionsView`

### Error Handling

```swift
// Good: Handle errors where they occur
do {
    try modelContext.save()
} catch {
    print("Failed to save: \(error)")
    // Show user-facing error if needed
}

// Bad: Error classification hierarchies
let classification = errorClassifier.classify(error)
switch classification {
    case .transient: return .retry
    case .permanent: return .fail
    // etc.
}
```

---

## Testing Checklist

Before any PR, verify:

1. **Build succeeds**: `xcodebuild -scheme Florijn build`
2. **Rules work during import**: Import CSV, check transactions are categorized
3. **Rules work manually**: Create rule, run "Apply Rules", verify it works
4. **Same rule produces same result** in both contexts
5. **No regressions**: Existing features still work

---

## File Size Limits

| File Type | Max Lines | Action if Exceeded |
|-----------|-----------|-------------------|
| View | 500 | Extract components |
| Service | 400 | Split responsibilities |
| Model | 200 | Question if too complex |
| App entry | 300 | Extract views |

---

## Forbidden Patterns

Do NOT add:
- New actors (unless absolutely necessary for thread safety)
- New caching layers (profile first, optimize if proven slow)
- Abstract factories or strategy patterns
- Publisher/Subscriber for simple data flow
- "Manager" or "Coordinator" or "Orchestrator" classes
- Multi-tier error handling
- Retry logic with exponential backoff (for local operations)
- Feature flags
- Dependency injection frameworks

---

## Quick Reference

### Data Flow

```
User imports CSV
    → ImportService parses file
    → Creates Transaction objects
    → RuleService.processTransactions() categorizes them
    → Saved to SwiftData
    → Views update via @Query
```

### Rule Flow

```
Rule has:
    - Triggers (conditions to match)
    - Actions (changes to apply)
    - triggerLogic (ALL must match vs ANY can match)

Evaluation:
    1. Get all triggers (including from TriggerGroups)
    2. Evaluate each trigger against transaction
    3. Apply triggerLogic (AND/OR)
    4. If matched, apply actions in sortOrder
```

### Key Models

| Model | Purpose |
|-------|---------|
| Transaction | Bank transaction with categorization |
| Account | Bank account |
| Category | Transaction category with budget |
| Rule | Categorization rule |
| RuleTrigger | Condition for rule matching |
| RuleAction | Change to apply when rule matches |
| RuleGroup | Optional folder for organizing rules |

---

## Getting Started

When starting work on Florijn:

1. Read this file completely
2. Run `xcodebuild -scheme Florijn build` to verify current state
3. Check `git status` for any uncommitted changes
4. Identify which phase of refactoring to work on
5. Make small, incremental changes
6. Test after each change
7. Commit frequently with clear messages

**Remember: The goal is simplicity. If your change makes the codebase more complex, reconsider.**
