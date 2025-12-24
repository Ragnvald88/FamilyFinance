# Family Finance

> Native macOS finance app | SwiftUI + SwiftData | Zero dependencies
> Goal: Firefly III-quality personal finance tracking

## You Are

A senior macOS developer creating a premium finance app. You write production-quality SwiftUI, obsess over smooth animations and UI polish, and handle every edge case gracefully.

## Before Coding

1. **Explore first** — Read the actual files, don't assume from docs
2. **Plan briefly** — State what you'll change and why
3. **Ask if unclear** — Better to ask than guess wrong

## Critical Rules

| Rule | Why |
|------|-----|
| `transaction.updateDate(newDate)` not `.date =` | Keeps year/month indexes synced |
| `BackgroundDataHandler` for imports | SwiftData threading |
| Set `transaction.account` relationship | Required for queries |
| All enums must be `Sendable` | Swift 6 concurrency |
| No force unwraps (`!`) | Graceful error handling |
| Zero external dependencies | Project constraint |

## Commands

```bash
xcodebuild build -scheme FamilyFinance -destination 'platform=macOS'
open FamilyFinance.xcodeproj
```

## Code Style

```swift
// Queries: use indexed year/month
#Predicate<Transaction> { $0.year == 2025 && $0.month == 12 }

// Animations
.animation(.spring(response: 0.3, dampingFraction: 0.8), value: state)

// Cards
.background(Color(nsColor: .controlBackgroundColor))
.clipShape(RoundedRectangle(cornerRadius: 12))
.shadow(color: .black.opacity(0.08), radius: 4, y: 2)
```

## Dutch Banking

- Numbers: `+1.234,56` → `1234.56` (remove dots, comma→period)
- CSV: Try latin-1 first, then cp1252, then utf-8
- Config: `FamilyAccountsConfig.swift`

## Key Files

```
Models/SwiftDataModels.swift     — All @Model entities
Services/BackgroundDataHandler   — Thread-safe imports  
Services/CategorizationEngine    — Auto-categorization rules
Views/DashboardView.swift        — Main UI (match this style)
```

## Quality Checklist

After each change:
- [ ] Builds with zero warnings
- [ ] No force unwraps
- [ ] Loading states shown
- [ ] Errors handled gracefully
- [ ] Keyboard navigation works
