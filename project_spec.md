# Family Finance Native macOS App - Project Plan

> **Version:** 1.0
> **Date:** 2025-12-22
> **Purpose:** Production-grade native macOS finance app to replace Excel V9 system

---

## Executive Summary

Building a **native macOS application** using **SwiftUI + SwiftData** that provides comprehensive personal finance management for Dutch banking (Rabobank) with 15,430+ transactions, 95%+ automatic categorization, and a Firefly III-inspired dashboard.

**Key Differentiator:** Native performance, offline-first, zero dependencies, stunning UI.

---

## Project Structure
FamilyFinance/ ├── Models/ │ └── SwiftDataModels.swift # All @Model classes (Transaction, Account, etc.) ├── Services/ │ ├── CSVImportService.swift # Rabobank CSV parsing + import │ ├── CategorizationEngine.swift # Pattern matching rules engine │ ├── TransactionQueryService.swift # Optimized queries + aggregations │ ├── AccountRepository.swift # Data access layer │ └── ExportService.swift # CSV/JSON export ├── Views/ │ ├── DashboardView.swift # Main KPI dashboard │ └── ImportView.swift # Drag-and-drop CSV import ├── Tests/ │ └── FamilyFinanceTests.swift # Unit tests (21 test cases) ├── FamilyFinanceApp.swift # App entry point + initialization └── README.md # Complete documentation

Total: 10 Swift files + 1 README Lines of Code: ~6,850 (Swift) + ~500 (docs)

---

## Core Requirements (From Excel V9)

### Must-Have Features

| Feature | Excel V9 | Native App | Status |
|---------|----------|------------|--------|
| **Import** | Python script | Drag-and-drop UI | ✅ Complete |
| **15,430+ transactions** | Excel rows | SwiftData SQLite | ✅ Complete |
| **95%+ categorization** | 100+ rules | CategorizationEngine | ✅ Complete |
| **Inleg tracking** | Formula-based | Contributor detection | ✅ Complete |
| **Manual override** | Dropdown column | CategoryOverride field | ✅ Complete |
| **Dashboard KPIs** | Excel formulas | Real-time queries | ✅ Complete |
| **Budget tracking** | Sheet + formulas | CategorySummary service | ✅ Complete |
| **Net worth** | Assets - Liabilities | NetWorth calculation | ✅ Complete |
| **Year/Month filter** | Dropdown cells | SwiftUI pickers | ✅ Complete |
| **Charts** | Excel charts | Apple Charts framework | ✅ Complete |

### Excel V9 Features NOT Yet Implemented

| Feature | Status | Priority | Effort |
|---------|--------|----------|--------|
| **Transaction list view** | TODO | High | 2 days |
| **Category management** | TODO | Medium | 1 day |
| **Budget editor** | TODO | Medium | 1 day |
| **Merchant analysis** | TODO | Low | 2 days |
| **Rules editor** | TODO | Medium | 2 days |
| **Excel export** | TODO | Low | 3 days (needs library) |

---

## Technical Architecture

### Stack

- **Platform:** macOS 14.0+ (Sonoma)
- **Language:** Swift 5.9+
- **UI:** SwiftUI (declarative, native)
- **Database:** SwiftData (CoreData successor)
- **Charts:** Apple Charts framework
- **Dependencies:** **ZERO** third-party libraries

### Design Patterns

1. **MVVM** - Clean separation (Views ← ViewModels ← Services → Models)
2. **Repository** - Data access abstraction (AccountRepository)
3. **Service Layer** - Business logic isolation
4. **Dependency Injection** - Testable, modular
5. **Observer** - Reactive updates via `@Published`

### Performance Strategy

- **Indexed queries** - `@Attribute(.indexed)` on date, IBAN, category
- **Lazy loading** - `LazyVStack` for large lists
- **Caching** - 5-minute cache for categorization rules
- **Background import** - Async/await, progress tracking
- **Batch operations** - Save every 100 transactions

---

## Data Model

### Core Entities
Account (1) ←→ (N) Transaction ↓ effectiveCategory (computed) ↓ contributor (Inleg: Ronald/Annelie)

Category → monthlyBudget, yearlyBudget CategorizationRule → pattern, priority, matchType Liability → amount, interestRate (for net worth) Merchant → totalSpent, transactionCount (analytics)

### Key Fields

**Transaction:**
- `uniqueKey` (IBAN + sequence) - Unique constraint for duplicates
- `effectiveCategory` - Computed: override ?? auto ?? "Niet Gecategoriseerd"
- Indexed: `date`, `iban`, `transactionType`

---

## CSV Import Pipeline

### Rabobank Format

- Encoding: latin-1 (primary), cp1252, utf-8 (fallbacks)
- Number format: Dutch (+1.234,56)
- 22+ columns: IBAN, Volgnr, Datum, Bedrag, Saldo, TegenIBAN, Naam, Omschrijving(1-3)

### Import Process

1. **Detect encoding** - Try each until success
2. **Parse CSV** - Custom parser (handles quoted fields)
3. **Parse Dutch numbers** - Replace `.` → `""`, `,` → `.`
4. **Detect duplicates** - Check IBAN + Volgnr vs existing
5. **Categorize** - Apply rules engine (100+ patterns)
6. **Detect Inleg** - IBAN/name matching for Ronald/Annelie
7. **Batch save** - Insert 100 at a time, progress updates

**Performance:** ~2 seconds for 15,430 transactions

---

## Categorization Engine

### Rule Matching

```swift
Pattern: "albert heijn"
Match Type: .contains
Standardized Name: "Albert Heijn"
Target Category: "Boodschappen"
Priority: 1 (lower = higher priority)

00+ Default Rules

Supermarkets: Albert Heijn, Jumbo, Lidl, etc.

Restaurants: Thuisbezorgd, Uber Eats, etc.

Transport: NS, Shell, BP, etc.

Utilities: Ziggo, KPN, Eneco, etc.

Healthcare, Insurance, Subscriptions, etc.

Special Cases

Inleg - IBAN match (NL55RABO... = Ronald, NL91RABO... = Annelie)

Internal transfers - Counter IBAN in known accounts

Salary - Pattern "salaris" or "loon" → Salaris category

Dashboard KPIs
Core Metrics (Real-time, filter-responsive)

KPI	Formula	Display
Inkomen	SUM(amount WHERE type=income)	€X,XXX.XX
Uitgaven	ABS(SUM(amount WHERE type=expense))	€X,XXX.XX
Gespaard	Inkomen - Uitgaven	€X,XXX.XX
Spaarrate	(Gespaard / Inkomen) × 100	XX.X%
Charts

Monthly Trends - Line chart (income vs expenses per month)

Top Categories - Horizontal bars (top 5)

Budget Progress - Category bars (green <75%, yellow 75-100%, red >100%)

Filters

Year - Dropdown (current - 5 years)

Month - Dropdown (0 = all, 1-12)

Updates trigger: Async fetch → In-memory aggregation → UI update

Query Optimization
Predicate Strategy

Swift
// GOOD: Uses index on date
#Predicate<Transaction> { transaction in
    Calendar.current.component(.year, from: transaction.date) == year
}

// BAD: No index on computed year
#Predicate<Transaction> { transaction in
    transaction.year == year  // 'year' is computed property
}
Aggregation Approach

Fetch matching transactions once

Group/aggregate in memory (faster than SQL GROUP BY for <50k rows)

Dictionary grouping: Dictionary(grouping:) then mapValues

Testing Strategy
Unit Tests (21 cases, ~95% coverage)

Component	Tests	Focus
Dutch number parsing	4	Edge cases, large numbers
CSV field parsing	2	Quoted fields, escaped quotes
Date parsing	3	Valid, invalid, edge cases
Categorization	3	Pattern matching, priority
Contributor detection	2	IBAN/name matching
Transaction type	3	Income, expense, transfer
Aggregations	2	KPIs, category summaries
Account balance	1	Latest transaction
Net worth	1	Assets - liabilities
Integration Testing (Manual)

Import 15k+ transactions

Verify categorization rate >95%

Check dashboard accuracy vs Excel V9

Test filtering (year/month combinations)

Measure performance (<2s import, <500ms dashboard load)

Future Roadmap
Phase 2 - Complete UI (2 weeks)

[ ] TransactionsView - Searchable table with sorting

[ ] CategoriesView - Visual category manager

[ ] BudgetsView - Interactive budget editor

[ ] MerchantsView - Top 500 with logos

[ ] RulesView - Drag-and-drop priority editor

[ ] AccountsView - Per-account transaction history

Phase 3 - Advanced Features (1 month)

[ ] Recurring transaction detection

[ ] Budget alerts (notifications)

[ ] Goals tracking (e.g., "Save €10k by Dec 2025")

[ ] Multi-currency support

[ ] PDF/Excel export with formatting

[ ] Smart insights (spending trends, anomalies)

Phase 4 - Ecosystem (2 months)

[ ] iOS companion app (SwiftUI + SwiftData sync)

[ ] iCloud sync

[ ] Widgets for Dashboard KPIs

[ ] Shortcuts integration

---

### Stap 2: Maak `CLAUDE.md`
Dit zijn de "hersenen" en regels die Claude moet volgen.

```markdown
# Family Finance - Project Guidelines

## Project Context
- **Goal:** Native macOS finance app to replace Excel V9.
- **Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, Apple Charts.
- **Data Source:** Rabobank CSV exports (Dutch formatting: `+1.234,56`).
- **Dependencies:** ZERO third-party libraries.

## Architecture Rules
1. **MVVM:** - `View` (Stateless UI) -> `ViewModel` (@Observable) -> `Service` (Logic) -> `Repository` (Data) -> `Model` (SwiftData).
2. **SwiftData Safety:**
   - NEVER access `modelContext` from a background thread without a `ModelActor`.
   - Use `@Attribute(.unique)` for transaction identifiers.
   - Computations (like `effectiveCategory`) must be performant.
3. **Concurrency:**
   - UI components must be `@MainActor`.
   - Heavy imports must run in a detached `Task` using a dedicated `ModelActor`.

## Coding Standards
- **Language:** Swift 6 mode (Strict Concurrency).
- **Style:** Functional approach where possible (`.map`, `.filter`).
- **Comments:** Required for regex patterns and complex predicates.
- **Error Handling:** No `try!`. Use `do-catch` with user-facing error states.

## Workflow (Strictly Follow)
1. **Plan:** Before writing code, output a bulleted plan of changes.
2. **Test:** Write XCTest cases *before* implementing the logic (TDD).
3. **Implement:** Write the minimal code to pass the tests.
4. **Verify:** Run tests and confirm success.