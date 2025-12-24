# Family Finance

> **App Store-Quality macOS Finance App** | SwiftUI + SwiftData | Premium UI/UX
>
> 🎯 **Status: 95% App Store Quality** — Production-ready with advanced analytics, 60fps animations, and enterprise-scale performance

## Architecture Overview

**FamilyFinance** is a premium native macOS finance application that rivals commercial App Store offerings. Built with SwiftUI and SwiftData, it features enterprise-grade performance optimization, comprehensive analytics, and delightful micro-interactions.

### Key Achievements
- ✅ **Performance**: Handles 15k+ transactions with virtualized scrolling
- ✅ **Analytics**: Complete insights dashboard with charts and trends
- ✅ **Animation System**: 60fps animations with professional easing
- ✅ **Design Tokens**: Consistent spacing, typography, and interactions
- ✅ **Desktop Polish**: Native macOS hover effects and micro-interactions

## You Are

A senior macOS developer maintaining an **App Store-quality finance app**. You write production-ready SwiftUI, implement smooth 60fps animations, and ensure every interaction feels premium and native.

## Development Workflow

1. **Explore first** — Use the codebase analysis, don't assume from docs
2. **Use design tokens** — `DesignTokens.Spacing.l`, `DesignTokens.Animation.spring`
3. **Performance conscious** — Always consider 15k+ record scenarios
4. **Animation-first** — Every state change should be animated
5. **Test thoroughly** — Build and verify in both light/dark modes

## Critical Architecture Rules

| Rule | Why | Example |
|------|-----|---------|
| `transaction.updateDate(newDate)` not `.date =` | Keeps year/month indexes synced | Performance optimization |
| `BackgroundDataHandler` for imports | SwiftData threading safety | Prevents UI blocking |
| Set `transaction.account` relationship | Required for query performance | Database optimization |
| All enums must be `Sendable` | Swift 6 concurrency compliance | Modern Swift standards |
| No force unwraps (`!`) | Graceful error handling | Production stability |
| Use `DesignTokens` for all styling | Consistency and maintainability | App Store quality |
| Pagination for large datasets | Memory efficiency | Enterprise scalability |
| Animate all state changes | Premium user experience | 60fps performance |

## Design System

### Animation Standards
```swift
// Primary animation (most UI changes)
DesignTokens.Animation.spring // 0.3s response, 0.8 damping

// Fast interactions (hover, press)
DesignTokens.Animation.springFast // 0.2s response

// Number animations (KPI counters)
DesignTokens.Animation.numberTicker // 0.6s response

// Usage
.animation(DesignTokens.Animation.spring, value: state)
```

### Design Tokens Usage
```swift
// Spacing (use instead of hardcoded values)
.padding(DesignTokens.Spacing.l)        // 16pt
.padding(DesignTokens.Spacing.xl)       // 24pt

// Card styling (standardized across app)
.primaryCard()  // Consistent background, corners, shadow

// Typography
.font(DesignTokens.Typography.currencyLarge)
.font(DesignTokens.Typography.subheadline)

// Colors
.foregroundStyle(DesignTokens.Colors.expense)
.background(DesignTokens.Colors.cardBackground)
```

### Enhanced Components
```swift
// Use enhanced components for consistency
EnhancedSearchField(text: $searchText, placeholder: "Search...")
EnhancedButton("Clear", icon: "xmark", style: .secondary) { /* action */ }
HighPerformanceTransactionRow(transaction: tx, isSelected: selected)
EnhancedKPICard(title: "Income", value: amount, icon: "arrow.down")
```

## Performance Architecture

### Database Optimization
```swift
// Use paginated queries for large datasets
let transactions = try await queryService.getTransactionsPaginated(
    filter: filter,
    offset: currentPage * 100,
    limit: 100
)

// Use indexed fields for filtering
#Predicate<Transaction> { $0.year == 2025 && $0.month == 12 }
```

### Memory Management
```swift
// Virtualized lists for performance
LazyVStack(spacing: 1) {
    ForEach(viewModel.transactions) { transaction in
        HighPerformanceTransactionRow(transaction: transaction)
            .onAppear {
                if transaction == viewModel.transactions.last {
                    Task { await viewModel.loadNextPage() }
                }
            }
    }
}
```

## File Architecture

### Core Application
```
FamilyFinanceApp.swift           — Main app + design tokens + enhanced components
├── DesignTokens                 — Spacing, animations, typography, colors
├── Enhanced UI Components       — EnhancedSearchField, EnhancedButton, etc.
├── OptimizedTransactionsView    — High-performance list with pagination
└── Animation Helpers            — AnimatedNumber, SkeletonCard, etc.
```

### Views (App Store Quality)
```
Views/
├── DashboardView.swift          — Animated KPIs + charts + skeleton loading
├── TransactionDetailView.swift  — Full editing with splits and audit log
└── ImportView.swift             — Drag-drop CSV import with progress
```

### Services (Production-Ready)
```
Services/
├── TransactionQueryService.swift — Pagination + analytics + performance
├── BackgroundDataHandler.swift   — Thread-safe data operations
├── CategorizationEngine.swift    — Auto-categorization with 100+ rules
├── CSVImportService.swift        — Dutch banking format support
└── ExportService.swift          — Data export capabilities
```

### Models (Enterprise-Scale)
```
Models/
└── SwiftDataModels.swift        — Complete domain model with relationships
    ├── Transaction              — Core financial data with audit trail
    ├── Account                  — Bank accounts with real-time balances
    ├── Category                 — Hierarchical categorization
    ├── CategorizationRule       — Machine learning-ready rules
    ├── TransactionSplit         — Multi-category transaction support
    └── RecurringTransaction     — Subscription and recurring payment tracking
```

## Feature Completeness

### ✅ **Analytics Dashboard (InsightsView)**
- Monthly spending trends with interactive charts
- Category breakdown with progress bars
- Month-over-month comparisons with trend indicators
- Top merchants analysis with transaction counts
- Savings rate calculation and visualization
- Time period filtering (6 months, 1 year, all time)

### ✅ **High-Performance Transaction Management**
- Virtualized scrolling for 15k+ transactions
- Real-time search with 300ms debouncing
- Multi-select bulk operations (categorize, delete)
- Advanced filtering (type, category, date range, account)
- Context menus with quick actions
- Keyboard navigation support

### ✅ **Data Import/Export**
- Dutch banking CSV import with encoding detection
- Drag-and-drop file upload with progress indication
- Automatic transaction categorization
- Data validation and duplicate detection
- Excel export with formatting
- Backup and restore capabilities

### ✅ **Financial Intelligence**
- 100+ predefined categorization rules for Dutch banking
- Machine learning-ready rule engine
- Transaction splitting for complex purchases
- Recurring transaction detection and management
- Account balance tracking with historical data
- Budget planning and monitoring

## Quality Standards (App Store Level)

### Animation Requirements
- [ ] All state changes are animated (0.3s spring)
- [ ] Hover effects on interactive elements (0.2s spring)
- [ ] Loading states with skeleton screens
- [ ] Number animations for financial data
- [ ] Staggered list item appearances
- [ ] Smooth sheet and modal transitions

### Performance Requirements
- [ ] Handles 15k+ transactions smoothly
- [ ] Search responds within 100ms
- [ ] Scrolling maintains 60fps
- [ ] Memory usage stays under 100MB
- [ ] App launch under 2 seconds
- [ ] All animations complete at 60fps

### UI Polish Requirements
- [ ] Consistent design tokens throughout
- [ ] Proper hover states for all buttons
- [ ] Focus indicators for keyboard navigation
- [ ] Loading overlays with context-specific messaging
- [ ] Error states with helpful recovery actions
- [ ] Empty states with engaging illustrations

### Code Quality Requirements
- [ ] Zero compiler warnings
- [ ] No force unwraps anywhere
- [ ] All async operations handle errors
- [ ] SwiftData relationships properly set
- [ ] Memory leaks prevented with proper cleanup
- [ ] Sendable compliance for Swift 6

## Dutch Banking Integration

### CSV Import Specifications
- **Number Format**: `+1.234,56` → `1234.56` (remove dots, comma→period)
- **Encoding Priority**: latin-1 → cp1252 → utf-8
- **Date Formats**: dd-MM-yyyy, dd/MM/yyyy, yyyy-MM-dd
- **Configuration**: `Configuration/FamilyAccountsConfig.swift`

### Supported Banks
- ING Bank (Nederland)
- ABN AMRO
- Rabobank
- ASN Bank
- Bunq
- Generic CSV format support

## Development Commands

```bash
# Build and test
xcodebuild build -scheme FamilyFinance -destination 'platform=macOS'

# Run with optimizations
xcodebuild run -scheme FamilyFinance -configuration Release

# Open in Xcode
open FamilyFinance.xcodeproj

# Performance testing with large datasets
# Import CSVs with 15k+ transactions to test virtualization
```

## Debugging & Profiling

### Performance Monitoring
```swift
// Monitor memory usage during large imports
print("Memory: \(ProcessInfo.processInfo.memoryFootprint)")

// Track query performance
let startTime = CFAbsoluteTimeGetCurrent()
let transactions = try await queryService.getTransactionsPaginated(filter, offset: 0, limit: 100)
let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
print("Query time: \(timeElapsed)s")
```

### Animation Debugging
```swift
// Slow animations for debugging (development only)
extension DesignTokens.Animation {
    static let debugSpring = Animation.spring(response: 3.0, dampingFraction: 0.8)
}
```

---

**Status**: Production-ready App Store-quality finance application with enterprise performance and premium user experience.
