# Family Finance - Claude Code Instructions

> Native macOS finance app replacing Excel V9 | SwiftUI + SwiftData | Zero dependencies

## Quick Reference

```bash
# Build & Run
open FamilyFinance.xcodeproj
# ⌘B to build, ⌘R to run

# Tests
# In Xcode: ⌘U to run all tests
# Or: xcodebuild test -scheme FamilyFinance -destination 'platform=macOS'

# Database location
~/Library/Application Support/Family Finance/default.store
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    SwiftUI Views                    │
│  Dashboard, Transactions, Import, Categories, etc.  │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│               Service Layer (@MainActor)            │
│  CSVImportService, CategorizationEngine,            │
│  TransactionQueryService, ExportService             │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│           BackgroundDataHandler (@ModelActor)       │
│  Heavy imports, batch operations (background thread)│
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│            SwiftData Models (10 entities)           │
│  Transaction, Account, Category, Rule, Split, etc.  │
└─────────────────────────────────────────────────────┘
```

## Critical SwiftData Rules

### 1. Transaction Date is Private

```swift
// ❌ NEVER - causes stale year/month indexes
transaction.date = newDate

// ✅ ALWAYS use the safe method
transaction.updateDate(newDate)
```

**Why:** Transaction has denormalized `year` and `month` fields for query performance. Direct date modification leaves them stale.

### 2. ModelActor for Background Work

```swift
// ❌ NEVER access modelContext on background thread directly
Task.detached {
    modelContext.insert(transaction)  // CRASH
}

// ✅ Use BackgroundDataHandler (is a @ModelActor)
let handler = BackgroundDataHandler(modelContainer: container)
let result = await handler.importTransactions(data)
```

### 3. Relationship Setup During Import

```swift
// ❌ NEVER forget to set relationships
let transaction = Transaction(iban: iban, ...)
// Missing: transaction.account = ???

// ✅ ALWAYS set account relationship
let account = try await handler.getOrCreateAccount(for: iban)
transaction.account = account
```

### 4. Duplicate Key Format

```swift
// Current format: "IBAN-YYYYMMDD-sequence"
// Example: "NL00BANK0123456001-20251223-42"
Transaction.generateUniqueKey(iban: iban, date: date, sequenceNumber: seq)
```

## Dutch Banking Specifics

### Number Parsing
```swift
// Dutch format: +1.234,56 or -1.234,56
// Steps: remove dots, replace comma with period
let dutch = "+1.234,56"
let normalized = dutch.replacingOccurrences(of: ".", with: "")
                      .replacingOccurrences(of: ",", with: ".")
// Result: "+1234.56"
```

### CSV Encoding Priority
1. `latin-1` (ISO-8859-1) - Rabobank default
2. `cp1252` (Windows-1252) - fallback
3. `utf-8` - last resort

### Rabobank Transaction Codes
- `bg` = Bank Transfer (Betaalopdracht)
- `bc` = Debit Card/PIN (Betaalkaart)
- `id` = iDEAL (Online Payment)
- `ei` = SEPA Direct Debit (subscriptions!) 
- `tb` = Internal Transfer (Telebanking)

## Code Style

```swift
// Prefer functional patterns
let expenses = transactions.filter { $0.isExpense }
let total = expenses.map(\.amount).reduce(0, +)

// All enums must be Sendable (Swift 6 concurrency)
enum TransactionType: String, Codable, Sendable { ... }

// Document regex patterns
/// Matches "albert heijn" variants: "ah", "albert h", "ah xl"
static let ahPattern = "^(albert\\s*h|ah\\b)"

// Error handling: never force unwrap
do {
    let result = try await service.import(files)
} catch {
    // Show error UI, don't crash
}
```

## File Map

| File | Purpose |
|------|---------|
| `Models/SwiftDataModels.swift` | All 10 @Model classes + enums |
| `Services/BackgroundDataHandler.swift` | @ModelActor for imports |
| `Services/CSVImportService.swift` | CSV parsing, encoding detection |
| `Services/CategorizationEngine.swift` | 150+ pattern rules |
| `Services/TransactionQueryService.swift` | Optimized predicates |
| `Configuration/FamilyAccountsConfig.swift` | IBANs, names (customize!) |
| `Views/DashboardView.swift` | KPI cards, charts |
| `Views/ImportView.swift` | Drag-drop CSV import |

## Common Tasks

### Add New Categorization Rule
1. Edit `CategorizationEngine.swift` → `hardcodedRules` array
2. Add: `("pattern", .contains, "Standardized Name", "Category", priority)`
3. Lower priority = higher precedence

### Add New SwiftData Model
1. Add `@Model final class` in `SwiftDataModels.swift`
2. Register in `FamilyFinanceApp.swift` → `Schema([...])`
3. Create migration if modifying existing models

### Query Optimization
```swift
// ✅ Use indexed fields in predicates
#Predicate<Transaction> { $0.year == 2025 && $0.month == 12 }

// ❌ Avoid Calendar computations in predicates (causes full scan)
#Predicate<Transaction> { Calendar.current.component(.year, from: $0.date) == 2025 }
```

## Don'ts

- **Don't** use third-party dependencies - this is a zero-dependency project
- **Don't** set `transaction.date` directly - use `updateDate(_:)`
- **Don't** access `modelContext` from background threads without `@ModelActor`
- **Don't** use `fatalError` for recoverable errors - show error UI
- **Don't** hardcode IBANs outside `FamilyAccountsConfig.swift`
- **Don't** forget `Sendable` conformance on new enums/DTOs

## Performance Targets

| Operation | Target |
|-----------|--------|
| Import 15k transactions | < 2 seconds |
| Dashboard load | < 500ms |
| Query by year/month | < 50ms |
| App launch | < 1 second |

## Current Phase: UI Polish

**Done:** Core data layer, CSV import, categorization, dashboard UI
**Next:** Transaction detail editing, split UI, recurring management

## Helpful Links

- [SwiftData Docs](https://developer.apple.com/documentation/swiftdata)
- [Swift Charts](https://developer.apple.com/documentation/charts)
- [Firefly III](https://www.firefly-iii.org/) - UI inspiration
