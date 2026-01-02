# Florijn Development Guide

> macOS Personal Finance App | SwiftUI + SwiftData
> **Mission:** Simple, reliable transaction management with automatic categorization

---

## Current State (January 2026)

| Metric | Value |
|--------|-------|
| Total Lines | 14,854 |
| Swift Files | 21 |
| Test Coverage | 70 tests, 100% passing |
| Build Warnings | 0 |

### Recent Refactoring (Completed)

1. **Unified Rule Engine** - Replaced 5 separate services (CategorizationEngine, RuleEngine, TriggerEvaluator, ActionExecutor, RuleProgressPublisher) with single `RuleService.swift`
2. **Removed Dead Code** - Deleted unused RuleStatistics.swift, empty directories
3. **Fixed Bugs** - Cache invalidation issue, batch UUID bug, DateFormatter performance

### Project Structure

```
Florijn/
├── FlorijnApp.swift          # App entry + views (2,731 lines - needs splitting)
├── Models/
│   ├── SwiftDataModels.swift # All @Model classes (1,348 lines)
│   └── RulesModels.swift     # Rule-related models (751 lines)
├── Services/
│   ├── RuleService.swift     # Unified rule processing (476 lines)
│   ├── CSVImportService.swift # Rabobank CSV parser (883 lines)
│   ├── BackgroundDataHandler.swift # Async import (414 lines)
│   ├── TransactionQueryService.swift # Analytics (1,071 lines)
│   ├── DataIntegrityService.swift # Startup validation (317 lines)
│   └── ExportService.swift   # Data export (232 lines)
├── Views/
│   ├── DashboardView.swift   # Main dashboard (995 lines)
│   ├── TransactionsView.swift # Transaction list (369 lines)
│   ├── AccountsView.swift    # Account management (extracted)
│   ├── SimpleRulesView.swift # Rule editor (998 lines)
│   ├── TransactionDetailView.swift # Detail view (765 lines)
│   └── ImportView.swift      # CSV import UI (475 lines)
├── Extensions/
│   └── ViewExtensions.swift  # Design system (909 lines)
└── Tests/
    ├── RuleServiceTests.swift # Core rule engine tests
    ├── FamilyFinanceTests.swift # Data parsing tests
    ├── TransactionModelTests.swift # Model tests
    └── TransactionDetailViewTests.swift # UI tests
```

---

## The Golden Rule

**Before writing any code, ask: "Is this the simplest solution that works?"**

If you find yourself:
- Creating a new service → Stop. Can an existing one handle it?
- Adding a caching layer → Stop. Is performance actually a problem?
- Writing an abstraction → Stop. Is there more than one use case right now?

---

## Key Architecture Decisions

### Single Rule Service

`RuleService.swift` is the **only** place rules are evaluated. Used by:
- CSV import (categorize during import)
- Manual rule application (re-run rules on existing transactions)
- Rule preview (test rules against transactions)

```swift
// How to use RuleService
let ruleService = RuleService(modelContext: modelContext)
ruleService.processTransactions(transactions)  // For bulk
ruleService.processTransaction(transaction)    // For single
```

### Models That Are Actually Used

All models in SwiftDataModels.swift are used in the UI:
- `Transaction` - Core data
- `Account` - Bank accounts with balance tracking
- `Category` - Categories with budgets
- `Merchant` - Merchant aggregation (shown in insights)
- `Liability` - Debts for net worth calculation
- `BudgetPeriod` - Budget tracking periods
- `TransactionSplit` - Split transactions
- `RecurringTransaction` - Recurring patterns
- `TransactionAuditLog` - Category change history

### Data Flow

```
CSV Import:
  User selects file
    → CSVImportService.parseRabobank()
    → BackgroundDataHandler.importTransactions()
    → RuleService.processTransactions()
    → Views update via @Query

Manual Edit:
  User changes category
    → Transaction.updateCategoryOverride()
    → TransactionAuditLog created
    → Views update via @Query
```

---

## Code Style

### DO

```swift
// Simple, direct code
func processTransaction(_ transaction: Transaction) {
    let rules = getActiveRules()
    for rule in rules {
        if evaluate(rule: rule, against: transaction) {
            apply(rule: rule, to: transaction)
            if rule.stopProcessing { break }
        }
    }
}
```

### DON'T

```swift
// Over-engineered code
func processTransaction(_ transaction: Transaction) async throws -> ProcessingResult {
    let context = ExecutionContext(transaction: transaction)
    return try await executeWithCircuitBreaker {
        try await withRetry(maxAttempts: 3) {
            try await evaluateRulesParallel(transaction, strategy: strategy)
        }
    }
}
```

---

## Testing

Run all tests:
```bash
xcodebuild test -scheme FamilyFinance -destination 'platform=macOS'
```

Run specific test:
```bash
xcodebuild test -scheme FamilyFinance -destination 'platform=macOS' \
  -only-testing:FamilyFinanceTests/RuleServiceTests
```

### Test Coverage

| Test Suite | Tests | Coverage |
|------------|-------|----------|
| RuleServiceTests | 11 | Triggers, actions, AND/OR logic, stopProcessing |
| FlorijnTests | 14 | Dutch parsing, CSV, KPIs, duplicate detection |
| TransactionDetailViewTests | 25 | Categories, splits, audit logs |
| TransactionModelTests | 20 | Model behavior, unique keys |

---

## Forbidden Patterns

Do NOT add:
- New caching layers (profile first)
- Abstract factories or strategy patterns
- "Manager" / "Coordinator" / "Orchestrator" classes
- Multi-tier error handling
- Retry logic with exponential backoff
- Dependency injection frameworks
- Feature flags

---

## Known Technical Debt

### FlorijnApp.swift (2,731 lines)

Still contains many views that could be extracted:
- CategoriesListView, CategoryEditorSheet
- BudgetsListView, BudgetCategoryCard
- MerchantsListView, MerchantRowView
- TransfersListView, TransferRowView
- InsightsView
- SettingsView

**Decision:** Extract when working on these features, not as a separate task.

### TransactionQueryService.swift (1,071 lines)

Large but provides essential dashboard analytics. Not over-engineered.

---

## Quick Commands

```bash
# Build
xcodebuild -scheme FamilyFinance build

# Test
xcodebuild test -scheme FamilyFinance -destination 'platform=macOS'

# Clean
xcodebuild clean -scheme FamilyFinance

# Line count
find . -name "*.swift" -not -path "./.build/*" | xargs wc -l | tail -1
```

---

## Rabobank CSV Format

The app imports Dutch Rabobank CSV files with this structure:
- Semicolon-separated (;)
- Dutch number format: `+1.234,56` or `-1.234,56`
- Date format: `YYYY-MM-DD`
- Fields: IBAN, sequence number, date, amount, balance, counter IBAN, counter name, descriptions

---

## Getting Started

1. `xcodebuild -scheme FamilyFinance build` - Verify build works
2. `xcodebuild test -scheme FamilyFinance -destination 'platform=macOS'` - Verify tests pass
3. Check `git status` for uncommitted changes
4. Make small, incremental changes
5. Run tests after each change

**Remember: The goal is simplicity. If your change adds complexity, reconsider.**
