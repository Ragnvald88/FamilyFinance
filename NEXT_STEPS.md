# Family Finance - Prioritized Action Plan

> **What to Build Next**
> **Date:** 2025-12-22
> **Status:** Post-Critical Analysis

---

## Current Status

✅ **Complete:** Core functionality (import, categorization, dashboard)
🔴 **Blockers Found:** 3 critical architecture issues
🟠 **Warnings:** 5 important improvements needed
🟡 **Optimizations:** 8 nice-to-have enhancements

---

## Priority 1: Fix Critical Blockers (2-3 days)

### Task 1.1: Add Denormalized Year/Month Fields (4 hours)

**Why:** Current Calendar predicates cause full table scans

**Changes:**

1. Update `SwiftDataModels.swift`:
```swift
@Model
final class Transaction {
    @Attribute(.indexed) var year: Int
    @Attribute(.indexed) var month: Int
    var date: Date {
        didSet {
            year = Calendar.current.component(.year, from: date)
            month = Calendar.current.component(.month, from: date)
        }
    }

    init(..., date: Date, ...) {
        self.date = date
        self.year = Calendar.current.component(.year, from: date)
        self.month = Calendar.current.component(.month, from: date)
        // ... rest
    }
}
```

2. Update `TransactionQueryService.swift` predicates:
```swift
// OLD: #Predicate { Calendar.current.component(.year, from: $0.date) == year }
// NEW:
#Predicate<Transaction> { $0.year == year }
```

3. Add migration test (new data model version)

**Test:** Import 15k transactions, verify query speed <50ms

---

### Task 1.2: Implement Atomic Import Transactions (6 hours)

**Why:** Import failures leave database in corrupted state

**Changes:**

1. Update `CSVImportService.swift`:
```swift
func importFiles(_ urls: [URL]) async throws -> ImportResult {
    let container = modelContext.container

    // Create isolated context for atomic operation
    let importContext = ModelContext(container)
    importContext.autosaveEnabled = false  // Manual control

    do {
        // Parse all files
        var allTransactions: [Transaction] = []

        for url in urls {
            let transactions = try await parseCSVFile(url, batchID: batchID)
            allTransactions.append(contentsOf: transactions)
        }

        // Categorize (sync version - see Task 1.3)
        for transaction in allTransactions {
            importContext.insert(transaction)
        }

        // ATOMIC SAVE: All or nothing
        try importContext.save()

        return ImportResult(...)

    } catch {
        // Context discarded, no partial data saved
        throw CSVImportError.importFailed(error.localizedDescription)
    }
}
```

2. Add error recovery UI (show "Import failed, no data saved")

**Test:** Corrupt CSV mid-way, verify database unchanged

---

### Task 1.3: Move Import to Background Actor (6 hours)

**Why:** @MainActor blocks UI for 2+ seconds

**Changes:**

1. Update `CSVImportService.swift`:
```swift
class CSVImportService: ObservableObject {
    @Published var isImporting = false
    @MainActor @Published var progress: ImportProgress?  // Only progress on main

    func importFiles(_ urls: [URL]) async throws -> ImportResult {
        let container = modelContext.container

        // Background task
        return try await Task.detached(priority: .userInitiated) {
            let backgroundContext = ModelContext(container)

            // Heavy work here (parsing, categorization)

            // Update UI periodically
            await MainActor.run {
                self.progress = ImportProgress(...)
            }

            try backgroundContext.save()
            return ImportResult(...)
        }.value
    }
}
```

2. Make categorization synchronous (no await needed):
```swift
// Remove async
func categorize(_ transaction: ParsedTransaction) -> CategorizationResult {
    // Just pattern matching, no async work
    for rule in cachedRules {
        if rule.matches(searchText) {
            return CategorizationResult(...)
        }
    }
}
```

**Test:** Import 15k transactions, verify UI stays responsive, can click other tabs

---

## Priority 2: Performance Improvements (1-2 days)

### Task 2.1: External Storage for Descriptions (2 hours)

**Changes:**

```swift
@Model
final class Transaction {
    @Attribute(.externalStorage) var description1: String?
    @Attribute(.externalStorage) var description2: String?
    @Attribute(.externalStorage) var description3: String?
}
```

**Test:** Measure memory before/after (expect ~80% reduction for large queries)

---

### Task 2.2: Relationship Prefetching (1 hour)

**Changes:**

```swift
var descriptor = FetchDescriptor<Transaction>(predicate: predicate)
descriptor.relationshipKeyPathsForPrefetching = [\Transaction.account]
let transactions = try modelContext.fetch(descriptor)
```

**Test:** Profile with Instruments, verify single JOIN query instead of N+1

---

### Task 2.3: Integration Tests with Real CSVs (3 hours)

**Add to `FamilyFinanceTests.swift`:**

```swift
func testImportGezinsrekeningCSV() async throws {
    let url = URL(fileURLWithPath: "/path/to/real/csv")
    let result = try await importService.importFiles([url])

    XCTAssertGreaterThan(result.imported, 10000)
    XCTAssertGreaterThan(result.categorizationRate, 95.0)
    XCTAssertEqual(result.duplicates, 0)  // First import
}

func testCategorizationAccuracy() async throws {
    // Import, then verify specific merchants categorized correctly
    XCTAssertEqual(findTransaction("Albert Heijn").effectiveCategory, "Boodschappen")
    XCTAssertEqual(findTransaction("Thuisbezorgd").effectiveCategory, "Uit Eten")
}
```

---

## Priority 3: Complete TODO Views (1 week)

### Task 3.1: TransactionsView (2 days)

**Features:**
- Searchable table (by description, merchant, amount)
- Sortable columns (date, amount, category)
- Category override dropdown per row
- Filter by account, category, type
- Export selected to CSV

**UI Design:** Similar to Excel Data sheet but native macOS table

---

### Task 3.2: CategoriesView (1 day)

**Features:**
- List all categories with budgets
- Edit budget amounts inline
- Add/delete categories
- Color picker for each category
- Icon selector (SF Symbols)

---

### Task 3.3: RulesView (2 days)

**Features:**
- Drag-and-drop priority reordering
- Add/edit/delete rules
- Test rule against sample transactions
- Export/import rules (CSV)
- Statistics (match count, last matched)

**Complex:** Need drag-drop in SwiftUI (use `onDrag`/`onDrop`)

---

### Task 3.4: BudgetsView + MerchantsView (2 days total)

**BudgetsView:**
- Timeline visualization (monthly budget usage)
- Editable budget per category per month
- Alerts when over budget

**MerchantsView:**
- Top 500 merchants table
- Total spent, transaction count, average
- Click to filter transactions by merchant

---

## Priority 4: Polish for App Store (1 week)

### Task 4.1: App Icon & Branding (1 day)

- Design app icon (SF Symbols `chart.bar.fill` + gradient)
- Xcode asset catalog
- macOS icon sizes (16x16 to 1024x1024)

---

### Task 4.2: Help Documentation (2 days)

- In-app help menu
- Quick start guide (overlay on first launch)
- Keyboard shortcuts legend
- Tooltips for all UI elements

---

### Task 4.3: Accessibility (2 days)

- VoiceOver support for all views
- Keyboard navigation (Tab, Arrow keys)
- Dynamic Type for all text
- High contrast mode support

---

### Task 4.4: Error Handling & Recovery (2 days)

- User-friendly error messages
- Automatic backup before import
- Restore from backup feature
- Corrupted database detection + repair

---

## Priority 5: Advanced Features (Optional)

### Task 5.1: Recurring Transaction Detection (3 days)

- Detect monthly/weekly patterns
- Auto-categorize based on recurrence
- Notify when expected transaction missing

---

### Task 5.2: Budget Alerts (2 days)

- macOS notifications when over budget
- Weekly spending summary
- Month-end report

---

### Task 5.3: iCloud Sync (1 week)

- Sync database across Macs
- Conflict resolution
- Offline support

---

## Timeline Summary

| Phase | Duration | Priority |
|-------|----------|----------|
| Fix Blockers | 2-3 days | 🔴 Must Do |
| Performance | 1-2 days | 🟠 Should Do |
| TODO Views | 1 week | 🟠 Should Do |
| App Store Polish | 1 week | 🟡 Nice to Have |
| Advanced Features | 2-3 weeks | 🟢 Future |

**Minimum Viable Product:** Fix blockers + TransactionsView = 1 week
**App Store Ready:** All above except Phase 5 = 3-4 weeks
**Full Featured:** Everything = 6-8 weeks

---

## Immediate Next Step (Right Now)

**Start Here:** Task 1.1 - Add denormalized year/month fields

1. Open `SwiftDataModels.swift`
2. Add `var year: Int` and `var month: Int`
3. Add `@Attribute(.indexed)` to both
4. Update `init()` to set from date
5. Update `date` didSet to maintain sync
6. Build, run, verify migration works
7. Update all predicates in `TransactionQueryService.swift`
8. Test query performance with Instruments

**Expected time:** 3-4 hours (including testing)

---

## Success Metrics

After completing Priority 1-3:

- ✅ Dashboard loads in <50ms (currently ~500ms)
- ✅ Import 15k transactions in <1.5s (currently ~2s)
- ✅ UI stays responsive during import
- ✅ Zero data corruption on import failures
- ✅ All TODO views functional
- ✅ 95%+ categorization accuracy verified with real data
- ✅ Memory usage <100MB for 15k transactions

---

*Ready to build a production-quality finance app!*
