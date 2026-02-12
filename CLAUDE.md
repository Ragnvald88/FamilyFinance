# Florijn Development Guide

> macOS Personal Finance App | SwiftUI + SwiftData
> **Mission:** Simple, reliable transaction management with automatic categorization

---

## Current State (February 2026)

| Metric | Value |
|--------|-------|
| Total Lines | ~17,200 |
| Swift Files | 28 |
| Test Coverage | 132 tests, 100% passing |
| Build Warnings | 0 |

### Recent Improvements (Completed)

1. **Unified Rule Engine** - Replaced 5 separate services (CategorizationEngine, RuleEngine, TriggerEvaluator, ActionExecutor, RuleProgressPublisher) with single `RuleService.swift`
2. **Removed Dead Code** - Deleted unused RuleStatistics.swift, empty directories
3. **Fixed Bugs** - Cache invalidation issue, batch UUID bug, DateFormatter performance
4. **Fixed Import Path** - Rules without setCategory (name-only standardization) now work during CSV import
5. **E2E Tests** - Added end-to-end tests for `categorizeParsedTransactions()` (the CSV import path)
6. **Enhanced UI Design System** - Upgraded visual design with sophisticated cards, hover states, and animations while maintaining simplicity
7. **Enhanced Categories Management** - Extracted from FlorijnApp.swift into dedicated views with @Observable ViewModel, financial health scoring, search/filtering, educational micro-tips (24 tests)
8. **Budget Management Extraction** - Extracted from FlorijnApp.swift into dedicated views with month/year navigation, color-coded progress bars, inline editing, responsive layout (33 tests)
9. **Rule Templates System** - Created intelligent rule template system with 5 pre-built templates for common scenarios (subscriptions, transfers, merchant standardization, etc.) with template browser and one-click rule creation (23 tests)

### 🚨 **CRITICAL ISSUES IDENTIFIED (February 2026)**

**Comprehensive Analysis Summary**: Deep analysis using specialized agents revealed three critical issue categories that must be addressed before App Store submission:

#### 1. AI-Generated UI System (BLOCKING - Code Quality)
**Location**: `ViewExtensions.swift` (872 lines of over-engineered design system)

**Critical AI Patterns Found:**
- 30+ custom colors with emotional comments ("Deep financial trust", "Confident action")
- "Premium" marketing language throughout design system
- 4 different card styles when 1 would suffice
- Mathematical precision obsessions (0.12, 0.08 opacity values)
- Rigid 8pt grid with excessive documentation
- 15+ font variations when 4-5 semantic styles needed
- Dead code: `PremiumKPICard` defined but never used

**Impact**: Interface looks obviously AI-generated, violates project's "Golden Rule", creates 200+ lines of maintainability debt.

#### 2. App Store Compliance Gaps (BLOCKING - Legal/Metadata)
**Status**: 65/100 readiness score

**Critical Missing Items (Automatic Rejection):**
- ❌ **Privacy Policy URL** - Required for all App Store submissions
- ❌ **App Description/Marketing Text** - No detailed app description
- ❌ **Financial Disclaimer** - Required for finance apps ("not financial advice")
- ❌ **Terms of Service** - Expected for financial data handling
- ❌ **Copyright/Legal Entity** - Empty field in Info.plist

**Secondary Issues:**
- Missing support contact information
- No in-app help/FAQ section
- No app screenshots prepared
- Missing keywords for discoverability

#### 3. Architecture & Performance Issues (HIGH - Scalability)
**Monolithic Structure:**
- `FlorijnApp.swift` still 2,600+ lines despite extraction efforts
- Multiple complete views embedded (SettingsView, InsightsView, etc.)
- Service initialization pattern creates memory inefficiency

**Performance Anti-Patterns:**
- In-memory filtering of 15,000+ transactions (should use DB queries)
- Sequential rule processing: 771,500 evaluations for full dataset
- No lazy loading in dashboard (all sections render immediately)
- O(n*m) complexity in category summary calculations

**Impact**: App works fine with current data but will struggle at App Store scale (100k+ transactions, thousands of users).

---

## 🎯 **ACTION PLAN FOR APP STORE READINESS** (February 2026)

### Phase 1: Critical Blockers (1-2 Weeks) - MUST DO FIRST

**Priority 1A: App Store Compliance (8 hours)**
- [ ] Write Privacy Policy document (3 hours) - Automatic rejection without this
- [ ] Create App Description/Marketing copy (3 hours) - Required for submission
- [ ] Add Financial Disclaimer popup on first launch (1 hour)
- [ ] Set Copyright/Legal Entity in Info.plist (30 min)
- [ ] Add Support URL/Contact email (30 min)

**Priority 1B: Fix AI-Generated Design System (6 hours)**
- [ ] Replace ViewExtensions.swift with semantic system (4 hours)
- [ ] Remove custom colors, use only NSColor system colors
- [ ] Consolidate to 1 card style, 4 font variants maximum
- [ ] Delete `PremiumKPICard` dead code
- [ ] Remove "Premium" branding language throughout (2 hours)

**Priority 1C: Critical Architecture (4 hours)**
- [ ] Extract remaining views from FlorijnApp.swift (3 hours)
  - SettingsView → Views/SettingsView.swift
  - InsightsView → Views/InsightsView.swift
  - CategoryEditorSheet → Views/Components/CategoryEditorSheet.swift
- [ ] Create ServiceContainer for proper initialization (1 hour)

**Phase 1 Total: ~18 hours over 1-2 weeks**

### Phase 2: Performance & Polish (1-2 Weeks) - HIGH PRIORITY

**Priority 2A: Performance Fixes (8 hours)**
- [ ] Replace in-memory filtering with @Query predicates (4 hours)
- [ ] Add lazy rendering to DashboardView (LazyVStack) (2 hours)
- [ ] Optimize rule processing for large datasets (2 hours)

**Priority 2B: User Experience (6 hours)**
- [ ] Implement dashboard TODO navigation (2 hours)
- [ ] Add in-app Help/FAQ section (3 hours)
- [ ] Create app screenshots for App Store (1 hour)

**Priority 2C: Code Quality (4 hours)**
- [ ] Convert remaining ViewModels to @Observable (2 hours)
- [ ] Replace DispatchQueue with async/await patterns (1 hour)
- [ ] Add comprehensive documentation to key methods (1 hour)

**Phase 2 Total: ~18 hours over 1-2 weeks**

### Phase 3: Final Preparation (3-5 Days) - POLISH

**Priority 3A: App Store Submission Prep (4 hours)**
- [ ] Create Terms of Service document (2 hours)
- [ ] Add App Store keywords/search optimization (1 hour)
- [ ] Final compliance review and testing (1 hour)

**Priority 3B: Advanced Features (4 hours)**
- [ ] Add export UI buttons (currently service exists but no UI) (2 hours)
- [ ] Implement undo/redo using existing audit logs (2 hours)

**Phase 3 Total: ~8 hours over 3-5 days**

---

### Overall Timeline: 5-6 Weeks Total

| Phase | Duration | Effort | Critical Path |
|-------|----------|--------|---------------|
| Phase 1: Blockers | 1-2 weeks | 18 hours | BLOCKING - Cannot submit without |
| Phase 2: Performance | 1-2 weeks | 18 hours | HIGH - Needed for scale |
| Phase 3: Polish | 3-5 days | 8 hours | MEDIUM - Professional finish |
| **TOTAL** | **5-6 weeks** | **44 hours** | **App Store Ready** |

---

### Success Criteria

**App Store Submission Ready When:**
- ✅ All legal documents (Privacy Policy, Terms, Disclaimer) complete
- ✅ AI-generated design patterns eliminated
- ✅ FlorijnApp.swift under 500 lines (currently 2,600+)
- ✅ Database queries replace in-memory filtering
- ✅ All 132 tests still passing
- ✅ App screenshots and marketing materials ready

**Quality Metrics:**
- **Code Maintainability**: ViewExtensions.swift reduced from 872→200 lines
- **Performance**: Dashboard loads in <2 seconds with 15k+ transactions
- **Architecture**: Single file no longer >1000 lines
- **Compliance**: 95/100 App Store readiness score

#### UI Enhancement Details (January 2026)

**Critical UI Fixes Applied:**
- ✅ **Fixed Background Color Issues**: Replaced ugly gray gradient with clean system background
- ✅ **Replaced Geometric Icons**: Removed terrible custom icons with clean SF Symbols (arrow.up.circle.fill, etc.)
- ✅ **Clean Professional Cards**: Simplified card styling to clean white backgrounds with subtle borders
- ✅ **System Color Integration**: Used NSColor.labelColor and system colors for proper contrast
- ✅ **Removed Over-Styling**: Eliminated complex gradients and effects that made interface feel "AI-generated"

**Color System Improvements:**
- **Background**: System window background instead of custom gray gradient
- **Cards**: Clean white backgrounds with subtle system borders
- **Text**: System label colors for perfect contrast across light/dark modes
- **Icons**: Standard SF Symbols (arrow.up/down.circle.fill, banknote.fill, percent) instead of custom geometric shapes

**Architectural Approach:**
- ✅ **Enhanced existing design system** - No architectural overhaul
- ✅ **Maintained all functionality** - 75/75 tests still passing
- ✅ **Followed project principles** - Simple enhancements, not overengineering
- ✅ **Preserved existing patterns** - NavigationSplitView and component structure unchanged

**Technical Implementation:**
- Replaced `GeometricFlowIcon` with `FinancialIcon` using SF Symbols
- Updated color system to use `NSColor` system colors for proper contrast
- Simplified card styling by removing complex gradients and overlays
- Fixed `professionalWindowBackground()` to use clean system background
- Maintained existing functionality while dramatically improving visual appeal

### Project Structure

```
Florijn/
├── FlorijnApp.swift          # App entry + views (needs splitting)
├── Models/
│   ├── SwiftDataModels.swift # All @Model classes (1,348 lines)
│   └── RulesModels.swift     # Rule-related models (751 lines)
├── ViewModels/
│   ├── CategoryManagementViewModel.swift # Category health scoring (164 lines)
│   └── BudgetManagementViewModel.swift  # Budget navigation & progress (134 lines)
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
│   ├── ImportView.swift      # CSV import UI (475 lines)
│   ├── CategoryManagementView.swift # Category management (336 lines)
│   ├── BudgetManagementView.swift   # Budget tracking (650 lines)
│   └── Components/
│       └── FinancialHealthIndicator.swift # Health gauge (188 lines)
├── Extensions/
│   └── ViewExtensions.swift  # Design system (909 lines)
└── Tests/
    ├── RuleServiceTests.swift # Core rule engine tests (16)
    ├── FamilyFinanceTests.swift # Data parsing tests (14)
    ├── TransactionModelTests.swift # Model tests (20)
    ├── TransactionDetailViewTests.swift # UI tests (25)
    ├── CategoryManagementViewTests.swift # Category tests (24)
    └── BudgetManagementViewTests.swift # Budget tests (33)
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
| BudgetManagementViewTests | 33 | Navigation, progress, spending levels, filtering, integration |
| CategoryManagementViewTests | 24 | Health scoring, filtering, search, micro-tips |
| TransactionDetailViewTests | 25 | Categories, splits, audit logs |
| TransactionModelTests | 20 | Model behavior, unique keys |
| RuleServiceTests | 16 | Triggers, actions, AND/OR logic, stopProcessing, E2E import |
| FlorijnTests | 14 | Dutch parsing, CSV, KPIs, duplicate detection |

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

### FlorijnApp.swift (reduced from 2,731 lines)

Views extracted so far:
- CategoryManagementView (extracted) -> Views/CategoryManagementView.swift
- BudgetManagementView (extracted) -> Views/BudgetManagementView.swift

Still contains views that could be extracted:
- CategoryEditorSheet
- MerchantsListView, MerchantRowView
- TransfersListView, TransferRowView
- InsightsView
- SettingsView

**Decision:** Extract when working on these features, not as a separate task.

### TransactionQueryService.swift (1,071 lines)

**Problem**: Large file with mixed responsibilities and performance issues.

**Issues Found:**
- Mixing query logic with data transformation
- O(n*m) complexity in category summary calculations
- In-memory filtering of 15,000+ transactions instead of database queries
- Multiple aggregation methods that could be split by domain

**Recommendation**: Split into focused services:
- `DashboardKPIService.swift` (dashboard metrics)
- `CategoryAnalyticsService.swift` (category summaries)
- `TrendAnalysisService.swift` (monthly/yearly trends)

**Impact**: Improved performance, easier testing, clearer responsibilities.

### Additional Technical Debt (February 2026 Analysis)

**1. Service Initialization Anti-Pattern**
- `FlorijnApp.swift` lines 366-450: Four wrapper views for service initialization
- Creates services on every tab switch with race conditions
- 100+ lines of boilerplate code
- **Fix**: Create ServiceContainer with lazy initialization

**2. ViewModels Architecture Inconsistency**
- `BudgetManagementViewModel` + `CategoryManagementViewModel`: Modern `@Observable`
- Dashboard/Import/Transaction ViewModels: Legacy `@StateObject` + `@Published`
- **Fix**: Convert all to `@Observable` for consistency

**3. Performance Bottlenecks**
- Dashboard renders all sections immediately (no lazy loading)
- Rule processing: 771,500 evaluations for full dataset (sequential)
- DateFormatter created per call instead of cached
- **Fix**: LazyVStack, parallel processing, static formatters

**4. Missing UX Elements**
- Dashboard TODOs not implemented (users see alerts but can't act)
- No in-app export UI (service exists, no buttons)
- Empty states lack guidance
- **Fix**: Add navigation, export buttons, contextual help

**5. Thread Safety Legacy Patterns**
- 3 instances of `DispatchQueue.main.async` instead of async/await
- **Fix**: Replace with Task-based concurrency

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

---

## 🚀 **IMMEDIATE NEXT STEPS** (Start Here)

### Critical Path Analysis
**The biggest blocker to App Store success is legal/metadata compliance, not code quality.** The app has excellent technical foundations but will be automatically rejected without proper documentation.

### Start With (This Week):
1. **Write Privacy Policy** (3 hours) - Use template: "No data collection, local storage only"
2. **Create App Description** (2 hours) - Highlight: transaction import, categorization, budgets, local-only privacy
3. **Add Financial Disclaimer** (1 hour) - "For tracking only, not financial advice"
4. **Fix ViewExtensions.swift** (4 hours) - Replace with semantic color system

### Validation Commands:
```bash
# Verify current state
xcodebuild test -scheme FamilyFinance -destination 'platform=macOS'
find . -name "*.swift" -exec wc -l {} + | sort -nr | head -10

# Check for AI patterns
grep -r "Premium\|Sophisticated\|Deep.*trust" --include="*.swift" .
grep -r "opacity(0\.[0-9][0-9])" --include="*.swift" .

# Performance check
grep -r "filter.*reduce\|allTransactions" --include="*.swift" .
```

### Success Metrics:
- [ ] ViewExtensions.swift: 872 lines → <200 lines
- [ ] FlorijnApp.swift: 2,600 lines → <500 lines
- [ ] All legal documents drafted
- [ ] 132/132 tests still passing
- [ ] Zero "Premium"/"Sophisticated" comments in code

**Estimated to App Store submission: 5-6 weeks following the phased plan above.**
