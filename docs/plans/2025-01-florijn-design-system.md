# Florijn Design System

## Brand Story

**Florijn** — named after the historic Florin, a gold coin first minted in Florence in 1252 that became the standard currency across medieval Europe. It represented trust, stability, and prosperity.

This heritage informs every design decision: **elegant without being ostentatious, trustworthy without being cold, modern while honoring tradition.**

---

## Design Principles

1. **Refined Confidence** — Not flashy, but assured. Like old money, not new.
2. **Warm Precision** — Exact and functional, but never clinical.
3. **Progressive Heritage** — Respects history, embraces modernity.
4. **Quiet Luxury** — Quality you feel, not shout.

---

## Color System

### Primary Palette

```
┌─────────────────────────────────────────────────────────────┐
│  FLORIJN GOLD                                               │
│  The hero color. Used sparingly for maximum impact.         │
│                                                             │
│  Primary:     #C9A227  ████████  RGB(201, 162, 39)         │
│  Light:       #E5D5A0  ████████  RGB(229, 213, 160)         │
│  Dark:        #9A7B1C  ████████  RGB(154, 123, 28)          │
│  Subtle:      #F9F6EC  ████████  RGB(249, 246, 236)         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  FLORIJN NAVY                                               │
│  The grounding color. Primary text, headers, navigation.    │
│                                                             │
│  Primary:     #0D1B2A  ████████  RGB(13, 27, 42)           │
│  Medium:      #1B3A4B  ████████  RGB(27, 58, 75)           │
│  Light:       #2D5066  ████████  RGB(45, 80, 102)          │
└─────────────────────────────────────────────────────────────┘
```

### Semantic Colors

```
┌─────────────────────────────────────────────────────────────┐
│  INCOME (Positive)                                          │
│  Emerald — sophisticated, not garish                        │
│                                                             │
│  Primary:     #059669  ████████  RGB(5, 150, 105)          │
│  Light:       #D1FAE5  ████████  RGB(209, 250, 229)         │
│  Dark:        #047857  ████████  RGB(4, 120, 87)           │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  EXPENSE (Negative)                                         │
│  Ruby — clear but not alarming                              │
│                                                             │
│  Primary:     #DC2626  ████████  RGB(220, 38, 38)          │
│  Light:       #FEE2E2  ████████  RGB(254, 226, 226)         │
│  Dark:        #B91C1C  ████████  RGB(185, 28, 28)          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  TRANSFER (Neutral)                                         │
│  Slate — clearly different from income/expense              │
│                                                             │
│  Primary:     #64748B  ████████  RGB(100, 116, 139)        │
│  Light:       #F1F5F9  ████████  RGB(241, 245, 249)         │
└─────────────────────────────────────────────────────────────┘
```

### Background System

```
┌─────────────────────────────────────────────────────────────┐
│  BACKGROUNDS                                                │
│  Warm whites and creams — never pure white                  │
│                                                             │
│  Canvas:      #FDFBF7  ████████  Main app background       │
│  Surface:     #FFFFFF  ████████  Cards, elevated elements   │
│  Subtle:      #F8F6F1  ████████  Alternating rows          │
│  Sidebar:     #0D1B2A  ████████  Navigation (navy)         │
└─────────────────────────────────────────────────────────────┘
```

### SwiftUI Implementation

```swift
// Florijn/Theme/FlorijnColors.swift

import SwiftUI

enum FlorijnColors {
    // MARK: - Primary

    static let gold = Color(red: 201/255, green: 162/255, blue: 39/255)        // #C9A227
    static let goldLight = Color(red: 229/255, green: 213/255, blue: 160/255)  // #E5D5A0
    static let goldDark = Color(red: 154/255, green: 123/255, blue: 28/255)    // #9A7B1C
    static let goldSubtle = Color(red: 249/255, green: 246/255, blue: 236/255) // #F9F6EC

    static let navy = Color(red: 13/255, green: 27/255, blue: 42/255)          // #0D1B2A
    static let navyMedium = Color(red: 27/255, green: 58/255, blue: 75/255)    // #1B3A4B
    static let navyLight = Color(red: 45/255, green: 80/255, blue: 102/255)    // #2D5066

    // MARK: - Semantic

    static let income = Color(red: 5/255, green: 150/255, blue: 105/255)       // #059669
    static let incomeLight = Color(red: 209/255, green: 250/255, blue: 229/255)// #D1FAE5
    static let expense = Color(red: 220/255, green: 38/255, blue: 38/255)      // #DC2626
    static let expenseLight = Color(red: 254/255, green: 226/255, blue: 226/255)// #FEE2E2
    static let transfer = Color(red: 100/255, green: 116/255, blue: 139/255)   // #64748B

    // MARK: - Backgrounds

    static let canvas = Color(red: 253/255, green: 251/255, blue: 247/255)     // #FDFBF7
    static let surface = Color.white
    static let surfaceSubtle = Color(red: 248/255, green: 246/255, blue: 241/255) // #F8F6F1

    // MARK: - Text

    static let textPrimary = navy
    static let textSecondary = Color(red: 100/255, green: 116/255, blue: 139/255) // #64748B
    static let textTertiary = Color(red: 148/255, green: 163/255, blue: 184/255)  // #94A3B8
}
```

---

## Typography

### System Fonts (Native macOS)

Using SF Pro ensures native feel and optimal rendering.

```swift
// Florijn/Theme/FlorijnTypography.swift

import SwiftUI

enum FlorijnTypography {
    // MARK: - Display (Large numbers, hero stats)
    static let displayLarge = Font.system(size: 48, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 36, weight: .bold, design: .rounded)

    // MARK: - Currency (Financial figures)
    static let currencyLarge = Font.system(size: 28, weight: .semibold, design: .monospaced)
    static let currencyMedium = Font.system(size: 20, weight: .semibold, design: .monospaced)
    static let currencySmall = Font.system(size: 16, weight: .medium, design: .monospaced)

    // MARK: - Headings
    static let h1 = Font.system(size: 28, weight: .bold)
    static let h2 = Font.system(size: 22, weight: .semibold)
    static let h3 = Font.system(size: 18, weight: .semibold)
    static let h4 = Font.system(size: 16, weight: .medium)

    // MARK: - Body
    static let bodyLarge = Font.system(size: 16, weight: .regular)
    static let body = Font.system(size: 14, weight: .regular)
    static let bodySmall = Font.system(size: 13, weight: .regular)

    // MARK: - Labels & Captions
    static let label = Font.system(size: 12, weight: .medium)
    static let caption = Font.system(size: 11, weight: .regular)
    static let overline = Font.system(size: 10, weight: .semibold).uppercaseSmallCaps()
}
```

### Typography Hierarchy

```
DISPLAY LARGE (48pt Bold Rounded)
€ 12,450.00

DISPLAY MEDIUM (36pt Bold Rounded)
Monthly Overview

CURRENCY LARGE (28pt Semibold Mono)
€ 2,345.67

H1 HEADING (28pt Bold)
Dashboard

H2 HEADING (22pt Semibold)
Recent Transactions

H3 HEADING (18pt Semibold)
Groceries

Body Text (14pt Regular)
Transaction description text goes here

OVERLINE (10pt Semibold Caps)
CATEGORY

Caption (11pt Regular)
Dec 29, 2025
```

---

## Spacing System

### Base Unit: 4px

```swift
enum FlorijnSpacing {
    static let xxs: CGFloat = 2    // Tight spacing
    static let xs: CGFloat = 4     // Icon gaps
    static let sm: CGFloat = 8     // Related elements
    static let md: CGFloat = 12    // Component padding
    static let lg: CGFloat = 16    // Section spacing
    static let xl: CGFloat = 24    // Major sections
    static let xxl: CGFloat = 32   // Page margins
    static let xxxl: CGFloat = 48  // Hero spacing
}
```

### Corner Radii

```swift
enum FlorijnRadius {
    static let xs: CGFloat = 4     // Badges, small buttons
    static let sm: CGFloat = 8     // Buttons, inputs
    static let md: CGFloat = 12    // Cards
    static let lg: CGFloat = 16    // Large cards, modals
    static let xl: CGFloat = 24    // Hero sections
    static let full: CGFloat = 9999 // Pills, circular
}
```

---

## Shadows

### Elevation System

```swift
enum FlorijnShadow {
    // Subtle lift (cards at rest)
    static let sm = (color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)

    // Default card shadow
    static let md = (color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)

    // Hover/elevated state
    static let lg = (color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

    // Modals, popovers
    static let xl = (color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)

    // Gold glow for emphasis
    static let goldGlow = (color: FlorijnColors.gold.opacity(0.3), radius: 12, x: 0, y: 0)
}
```

---

## Component Specifications

### 1. Sidebar Navigation

```
┌────────────────────────────────────────┐
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  │  Background: navy (#0D1B2A)
│                                        │
│   ◉  Florijn                          │  Logo/wordmark in gold
│                                        │
│  ┌──────────────────────────────────┐ │
│  │ ▣  Dashboard                     │ │  Selected: goldSubtle bg, gold icon
│  └──────────────────────────────────┘ │
│    ◻  Transactions                    │  Unselected: white text, 60% opacity
│    ◻  Categories                      │
│    ◻  Rules                           │
│    ◻  Accounts                        │
│                                        │
│  ─────────────────────────────────    │  Divider: white 10% opacity
│                                        │
│    ◻  Import                          │
│    ◻  Settings                        │
│                                        │
└────────────────────────────────────────┘
```

**SwiftUI Implementation:**

```swift
struct FlorijnSidebarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: FlorijnSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isSelected ? FlorijnColors.gold : .white.opacity(0.7))
                .frame(width: 24)

            Text(title)
                .font(FlorijnTypography.body)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.7))

            Spacer()
        }
        .padding(.horizontal, FlorijnSpacing.md)
        .padding(.vertical, FlorijnSpacing.sm)
        .background(
            isSelected ? FlorijnColors.goldSubtle.opacity(0.15) : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: FlorijnRadius.sm))
    }
}
```

---

### 2. KPI Cards

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   ◉ Total Balance                              ▲ +2.4%     │
│                                                             │
│   € 24,567.89                                              │
│   ▔▔▔▔▔▔▔▔▔▔▔                                              │
│   Gold accent line                                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘

Background: white (#FFFFFF)
Shadow: md (0.06 opacity, 4px radius, 2px y)
Corner radius: 12px
Padding: 20px

Icon: Gold (#C9A227)
Title: Secondary text (#64748B), 12pt overline
Value: Navy (#0D1B2A), 28pt currency
Trend badge: Income green or expense red
Accent line: 3px gold bar at bottom
```

**SwiftUI Implementation:**

```swift
struct FlorijnKPICard: View {
    let title: String
    let value: Decimal
    let trend: Double?
    let icon: String

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: FlorijnSpacing.md) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FlorijnColors.gold)

                Spacer()

                if let trend = trend {
                    TrendBadge(value: trend)
                }
            }

            // Title
            Text(title.uppercased())
                .font(FlorijnTypography.overline)
                .foregroundStyle(FlorijnColors.textSecondary)

            // Value
            Text(value.formatted(.currency(code: "EUR")))
                .font(FlorijnTypography.currencyLarge)
                .foregroundStyle(FlorijnColors.textPrimary)
        }
        .padding(FlorijnSpacing.xl - 4)
        .background(FlorijnColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FlorijnRadius.md))
        .shadow(
            color: isHovered ? FlorijnShadow.lg.color : FlorijnShadow.md.color,
            radius: isHovered ? FlorijnShadow.lg.radius : FlorijnShadow.md.radius,
            y: isHovered ? FlorijnShadow.lg.y : FlorijnShadow.md.y
        )
        .overlay(alignment: .bottom) {
            // Gold accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(FlorijnColors.gold)
                .frame(height: 3)
                .padding(.horizontal, FlorijnSpacing.lg)
                .padding(.bottom, FlorijnSpacing.sm)
                .opacity(isHovered ? 1 : 0.7)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
```

---

### 3. Transaction Rows

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  ● ━━  Albert Heijn                         - € 127.45                 │
│        Groceries · Dec 29                                               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

Layout:
- Left: Transaction type indicator (colored dot)
- Center: Name (16pt medium), Category + Date below (13pt, secondary)
- Right: Amount (16pt currency mono), colored by type

Hover state:
- Background: goldSubtle (#F9F6EC)
- Subtle gold border appears
```

**SwiftUI Implementation:**

```swift
struct FlorijnTransactionRow: View {
    let transaction: Transaction
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: FlorijnSpacing.md) {
            // Type indicator
            Circle()
                .fill(typeColor)
                .frame(width: 8, height: 8)

            // Content
            VStack(alignment: .leading, spacing: FlorijnSpacing.xxs) {
                Text(transaction.displayName)
                    .font(FlorijnTypography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(FlorijnColors.textPrimary)

                HStack(spacing: FlorijnSpacing.xs) {
                    Text(transaction.category?.name ?? "Uncategorized")
                    Text("·")
                    Text(transaction.date.formatted(.dateTime.day().month(.abbreviated)))
                }
                .font(FlorijnTypography.bodySmall)
                .foregroundStyle(FlorijnColors.textSecondary)
            }

            Spacer()

            // Amount
            Text(transaction.amount.formatted(.currency(code: "EUR")))
                .font(FlorijnTypography.currencySmall)
                .foregroundStyle(amountColor)
        }
        .padding(.horizontal, FlorijnSpacing.lg)
        .padding(.vertical, FlorijnSpacing.md)
        .background(isHovered ? FlorijnColors.goldSubtle : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: FlorijnRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: FlorijnRadius.sm)
                .stroke(FlorijnColors.gold.opacity(isHovered ? 0.3 : 0), lineWidth: 1)
        )
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var typeColor: Color {
        switch transaction.transactionType {
        case .income: return FlorijnColors.income
        case .expense: return FlorijnColors.expense
        case .transfer: return FlorijnColors.transfer
        default: return FlorijnColors.textTertiary
        }
    }

    private var amountColor: Color {
        transaction.amount >= 0 ? FlorijnColors.income : FlorijnColors.textPrimary
    }
}
```

---

### 4. Buttons

```
PRIMARY BUTTON (Gold)
┌─────────────────────────────────────┐
│          Import CSV                 │  Background: gold
└─────────────────────────────────────┘  Text: navy (dark)
                                         Hover: goldDark bg

SECONDARY BUTTON (Outlined)
┌─────────────────────────────────────┐
│          Add Rule                   │  Background: transparent
└─────────────────────────────────────┘  Border: gold
                                         Text: gold
                                         Hover: goldSubtle bg

TERTIARY BUTTON (Ghost)
┌─────────────────────────────────────┐
│          Cancel                     │  Background: transparent
└─────────────────────────────────────┘  Text: textSecondary
                                         Hover: surfaceSubtle bg
```

---

### 5. Charts

```
Color palette for charts (in order of use):

1. Primary data:    Gold (#C9A227)
2. Secondary:       Navy Medium (#1B3A4B)
3. Tertiary:        Emerald (#059669)
4. Quaternary:      Slate (#64748B)
5. Additional:      Gold Light (#E5D5A0)
6. Additional:      Navy Light (#2D5066)

Grid lines: #E5E7EB (gray-200) at 0.5px
Axis labels: textSecondary
```

---

## App Icon

### Concept: The Florijn Coin

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                    ╭──────────────╮                        │
│                  ╭─┤              ├─╮                      │
│                 │  │      F       │  │                     │
│                 │  │              │  │                     │
│                  ╰─┤              ├─╯                      │
│                    ╰──────────────╯                        │
│                                                             │
│  Style: Minimalist gold coin with stylized "F"             │
│  Background: Deep navy (#0D1B2A)                           │
│  Coin: Gold gradient (#C9A227 → #E5D5A0)                   │
│  "F": Navy, slightly inset                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Icon Specifications

- 1024x1024 master (App Store)
- Coin centered, ~70% of icon area
- Subtle gold-to-light-gold gradient (top-left to bottom-right)
- Navy background extends to edges (no transparency)
- Coin has subtle inner shadow for depth
- "F" is clean, geometric, weighted toward left

---

## Animation Specifications

### Timing Functions

```swift
enum FlorijnAnimation {
    // Default spring for UI interactions
    static let spring = Animation.spring(response: 0.3, dampingFraction: 0.8)

    // Quick interactions (hovers, toggles)
    static let fast = Animation.spring(response: 0.2, dampingFraction: 0.8)

    // Number animations (counting up)
    static let number = Animation.spring(response: 0.6, dampingFraction: 0.7)

    // Page transitions
    static let page = Animation.spring(response: 0.4, dampingFraction: 0.85)
}
```

### Interaction States

| State | Transform | Duration |
|-------|-----------|----------|
| Hover (card) | scale(1.02), shadow(lg) | 0.2s spring |
| Hover (row) | background(goldSubtle), border(gold) | 0.2s spring |
| Press | scale(0.98) | 0.1s spring |
| Focus | gold ring (2px, 2px offset) | immediate |

---

## Implementation Phases

### Phase 1: Foundation (Day 1)
- [ ] Create `Florijn/Theme/` folder
- [ ] Implement `FlorijnColors.swift`
- [ ] Implement `FlorijnTypography.swift`
- [ ] Implement `FlorijnSpacing.swift`
- [ ] Create base view modifiers

### Phase 2: Components (Day 2)
- [ ] Update sidebar navigation styling
- [ ] Restyle KPI cards with gold accents
- [ ] Update transaction row component
- [ ] Style buttons (primary, secondary, tertiary)
- [ ] Update form inputs and selectors

### Phase 3: Views (Day 3-4)
- [ ] Dashboard view transformation
- [ ] Transactions list view
- [ ] Rules editor styling
- [ ] Import flow
- [ ] Settings/preferences

### Phase 4: Polish (Day 5)
- [ ] App icon creation
- [ ] Empty states with illustrations
- [ ] Loading states
- [ ] Microinteractions review
- [ ] Dark mode consideration (future)

---

## File Structure

```
FamilyFinance/
├── Theme/
│   ├── FlorijnColors.swift
│   ├── FlorijnTypography.swift
│   ├── FlorijnSpacing.swift
│   ├── FlorijnShadows.swift
│   └── FlorijnAnimations.swift
├── Components/
│   ├── FlorijnButton.swift
│   ├── FlorijnCard.swift
│   ├── FlorijnKPICard.swift
│   ├── FlorijnTransactionRow.swift
│   ├── FlorijnSidebarItem.swift
│   └── FlorijnTextField.swift
├── Assets.xcassets/
│   ├── AppIcon.appiconset/
│   ├── Colors/
│   │   ├── FlorijnGold.colorset/
│   │   ├── FlorijnNavy.colorset/
│   │   └── ...
│   └── Images/
└── ...
```

---

## Before/After Preview

### Dashboard - Before
- Generic gray/blue palette
- Standard macOS controls
- No brand identity

### Dashboard - After
- Warm cream canvas background
- Navy sidebar with gold selected state
- KPI cards with gold accent bars
- Gold highlights on interactive elements
- Refined typography hierarchy
- Cohesive, premium feel

---

## Success Criteria

- [ ] All colors use FlorijnColors constants (no hardcoded hex)
- [ ] All text uses FlorijnTypography (no arbitrary font sizes)
- [ ] All spacing uses FlorijnSpacing (no magic numbers)
- [ ] Hover states on all interactive elements
- [ ] Consistent shadow usage across cards
- [ ] App icon matches brand identity
- [ ] Build succeeds with zero warnings
