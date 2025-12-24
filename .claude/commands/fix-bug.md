---
description: Debug and fix a bug with step-by-step analysis
argument-hint: Description of the bug or error message
---

# Debug & Fix Bug

Systematically debug and fix the reported issue.

## Bug Report: $ARGUMENTS

## Debugging Process

### Step 1: Understand the Problem
- What is the expected behavior?
- What is the actual behavior?
- When does it occur? (Always, sometimes, specific conditions)

### Step 2: Locate Relevant Code
Check these files based on the bug type:

**Import/CSV Issues:**
- `Services/CSVImportService.swift`
- `Services/BackgroundDataHandler.swift`
- `Services/CategorizationEngine.swift`

**UI/Display Issues:**
- `Views/*.swift`
- `FamilyFinanceApp.swift` (contains many views)

**Data/Query Issues:**
- `Services/TransactionQueryService.swift`
- `Models/SwiftDataModels.swift`

**Categorization Issues:**
- `Services/CategorizationEngine.swift`
- `Configuration/FamilyAccountsConfig.swift`

### Step 3: Common Family Finance Bugs

1. **Stale year/month after date change**
   - Cause: Direct `date` assignment
   - Fix: Use `transaction.updateDate(newDate)`

2. **Duplicate transactions imported**
   - Cause: Unique key mismatch or cache not preloaded
   - Check: `BackgroundDataHandler.preloadExistingUniqueKeys()`

3. **Wrong category assigned**
   - Cause: Rule priority or pattern mismatch
   - Check: `CategorizationEngine.hardcodedRules` order

4. **Crash on background import**
   - Cause: ModelContext accessed off main thread
   - Fix: Use `@ModelActor` pattern

5. **Chart not showing data**
   - Cause: Decimal→Double conversion needed for Charts
   - Fix: `Double(truncating: decimal as NSNumber)`

### Step 4: Write Test First (TDD)
Add a failing test in `Tests/` that reproduces the bug, then fix.

### Step 5: Verify Fix
- Run all tests: ⌘U in Xcode
- Test with real CSV import if applicable
- Check no regression in related features
