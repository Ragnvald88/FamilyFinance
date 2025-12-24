# Family Finance - Technical Reference

> Detailed technical documentation for the FamilyFinance codebase.
> This file is for reference - see CLAUDE.md for working instructions.

## Architecture Diagram

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

## SwiftData Code Examples

### Transaction Date Update (CRITICAL)
```swift
// ❌ NEVER - causes stale year/month indexes
transaction.date = newDate

// ✅ ALWAYS use the safe method
transaction.updateDate(newDate)
```

### Background Work with ModelActor
```swift
// ❌ NEVER access modelContext on background thread directly
Task.detached {
    modelContext.insert(transaction)  // CRASH
}

// ✅ Use BackgroundDataHandler (is a @ModelActor)
let handler = BackgroundDataHandler(modelContainer: container)
let result = await handler.importTransactions(data)
```

### Relationship Setup
```swift
// ❌ NEVER forget to set relationships
let transaction = Transaction(iban: iban, ...)
// Missing: transaction.account = ???

// ✅ ALWAYS set account relationship
let account = try await handler.getOrCreateAccount(for: iban)
transaction.account = account
```

### Query Optimization
```swift
// ✅ Use indexed fields in predicates
#Predicate<Transaction> { $0.year == 2025 && $0.month == 12 }

// ❌ Avoid Calendar computations in predicates (causes full scan)
#Predicate<Transaction> { Calendar.current.component(.year, from: $0.date) == 2025 }
```

### Duplicate Key Format
```swift
// Format: "IBAN-YYYYMMDD-sequence"
// Example: "NL00BANK0123456001-20251223-42"
Transaction.generateUniqueKey(iban: iban, date: date, sequenceNumber: seq)
```

## Dutch Banking Specifics

### Number Parsing
```swift
// Dutch format: +1.234,56 or -1.234,56
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
| Code | Meaning | Dutch |
|------|---------|-------|
| `bg` | Bank Transfer | Betaalopdracht |
| `bc` | Debit Card/PIN | Betaalkaart |
| `id` | iDEAL | Online Payment |
| `ei` | SEPA Direct Debit | Incasso (subscriptions!) |
| `tb` | Internal Transfer | Telebanking |

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

## SwiftUI Patterns Used

```swift
// Animation standard
.animation(.spring(response: 0.3, dampingFraction: 0.8), value: state)

// Card style
.background(Color(nsColor: .controlBackgroundColor))
.clipShape(RoundedRectangle(cornerRadius: 12))
.shadow(color: .black.opacity(0.1), radius: 4, y: 2)

// Semantic colors
// Income: .green or Color("Income")
// Expense: .red.opacity(0.85) or Color("Expense")
// Neutral: .blue
```

## Performance Targets

| Operation | Target |
|-----------|--------|
| Import 15k transactions | < 2 seconds |
| Dashboard load | < 500ms |
| Query by year/month | < 50ms |
| App launch | < 1 second |
