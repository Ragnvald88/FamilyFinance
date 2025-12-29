# FamilyFinance

A macOS personal finance application built with SwiftUI and SwiftData.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-green.svg)
![SwiftData](https://img.shields.io/badge/SwiftData-Latest-purple.svg)

---

## Features

### Analytics Dashboard
- Monthly spending trends with Charts framework
- Category breakdown with progress bars
- Month-over-month comparisons
- Savings rate calculation
- Top merchants by transaction count
- Time period filtering (6 months, 1 year, all time)

### Transaction Management
- Supports 15k+ transactions with virtualized scrolling
- Paginated data loading (100 records per page)
- Search with 300ms debouncing
- Multi-select for bulk operations

### Dutch Banking Import
- Rabobank CSV format supported
- Automatic encoding detection (UTF-8, Windows-1252, ISO-8859-1)
- Dutch number format parsing (`1.234,56` format)
- Resilient row-level error handling (continues on malformed rows)

### Firefly III-Style Rules
- Trigger-action rule system
- AND/OR logic for multiple conditions
- 15 trigger operators (contains, equals, regex, etc.)
- 16 action types (set category, set account, etc.)
- Rule groups for organization

### Data Features
- Transaction splitting for multi-category purchases
- Recurring transaction detection
- Account balance tracking
- Audit trail for changes
- CSV/JSON export

---

## Technical Constraints

### Threading Model
- **UI operations**: Run on `@MainActor` for SwiftUI observation
- **CSV parsing**: Runs in `Task.detached` to prevent UI blocking
- **Heavy imports**: Use `@ModelActor` (`BackgroundDataHandler`) for database writes
- **Rule engine**: Uses `@ModelActor` for thread-safe rule evaluation

This architecture ensures 60fps UI responsiveness during large imports (15k+ transactions).

### Data Layer
- **SwiftData** with indexed `year` and `month` fields for fast queries
- **Pagination** prevents O(n) memory growth with large datasets
- **Unique keys** for duplicate detection: `{IBAN}-{date}-{sequence}`

### Encoding Detection
The CSV importer tries encodings in order:
1. UTF-8 (modern default)
2. Windows-1252 (common for Dutch banking exports)
3. ISO-8859-1 (legacy fallback)

---

## Requirements

- macOS 13.0+ (Ventura or later)
- Xcode 15.0+
- Swift 6.0

---

## Getting Started

### Build
```bash
git clone [repository-url]
cd FamilyFinance
open FamilyFinance.xcodeproj
# ⌘+R to build and run
```

### Import Bank Data
1. Export CSV from your bank (Rabobank format)
2. Drag & drop CSV file into the Import tab
3. Rules apply automatically during import
4. Review imported transactions

---

## Architecture

### Services
| Service | Purpose | Actor |
|---------|---------|-------|
| `BackgroundDataHandler` | Bulk imports, deduplication | `@ModelActor` |
| `RuleEngine` | Rule evaluation and execution | `@ModelActor` |
| `TriggerEvaluator` | Evaluates rule conditions | `@ModelActor` |
| `ActionExecutor` | Executes rule actions | `@ModelActor` |
| `CSVImportService` | CSV parsing, encoding detection | `@MainActor` (parsing in background) |
| `TransactionQueryService` | Analytics, aggregations | `@MainActor` |
| `CategorizationEngine` | Rule compilation for bulk matching | `@MainActor` |

### Data Model
```
Transaction (SwiftData @Model)
├── Account (relationship)
├── Category (relationship)
├── year, month (indexed for queries)
└── uniqueKey (for duplicate detection)

Rule (SwiftData @Model)
├── RuleTrigger[] (conditions)
├── RuleAction[] (what to do)
└── RuleGroup? (optional organization)
```

---

## Documentation

| File | Purpose |
|------|---------|
| [CLAUDE.md](CLAUDE.md) | Development instructions |
| [TECHNICAL_REFERENCE.md](TECHNICAL_REFERENCE.md) | Detailed architecture |
| README.md | This file |

---

## Dependencies

Zero external dependencies. Built with Apple frameworks:
- SwiftUI
- SwiftData
- Charts

---

## Status

Production-ready for personal use. Core features complete:
- Transaction import/export
- Rule-based categorization
- Analytics dashboard
- Multi-account support
