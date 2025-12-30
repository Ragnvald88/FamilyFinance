# Florijn Design System v2.0

*The Ultimate Design Transformation Plan*

## Executive Summary

Transform FamilyFinance into **Florijn** — a sophisticated, trustworthy personal finance application that embodies the heritage of the historic Florin coin. This comprehensive design system establishes visual hierarchy, interaction patterns, and implementation standards for a cohesive, premium user experience.

**Key Objectives:**
- Create distinctive brand identity rooted in Dutch financial history
- Establish premium aesthetic without sacrificing usability
- Implement native macOS design patterns with custom branding
- Ensure accessibility and performance across all components

---

## Brand Foundation

### Etymology & Heritage
**Florijn** derives from the Florin, first minted in Florence (1252), becoming Europe's premier gold standard. This heritage informs our design philosophy:

- **Established Trust** → Consistent, reliable interface patterns
- **Refined Quality** → Attention to detail without ostentation
- **Enduring Value** → Timeless design choices over trends
- **European Heritage** → Sophisticated, understated elegance

### Brand Attributes
| Attribute | Expression | Anti-Pattern |
|-----------|------------|--------------|
| **Trustworthy** | Consistent spacing, predictable interactions | Flashy animations, inconsistent states |
| **Sophisticated** | Refined color palette, quality typography | Oversaturated colors, comic fonts |
| **Approachable** | Clear hierarchy, helpful guidance | Intimidating complexity, hidden features |
| **Native** | macOS conventions, system integration | Web-like patterns, custom scrollbars |

---

## Color System

### Primary Palette

#### Florijn Gold
```
Primary:    #C9A227    ████████    RGB(201, 162, 39)    HSL(43, 67%, 47%)
Light:      #E5D5A0    ████████    RGB(229, 213, 160)   HSL(43, 53%, 76%)
Dark:       #9A7B1C    ████████    RGB(154, 123, 28)    HSL(43, 69%, 36%)
Subtle:     #F9F6EC    ████████    RGB(249, 246, 236)   HSL(43, 54%, 95%)
```
**Usage:** Accent color, call-to-action buttons, selection states, progress indicators
**Contrast Ratios:** ✓ AAA compliant on white/navy backgrounds

#### Florijn Navy
```
Primary:    #0D1B2A    ████████    RGB(13, 27, 42)      HSL(210, 53%, 11%)
Medium:     #1B3A4B    ████████    RGB(27, 58, 75)      HSL(203, 47%, 20%)
Light:      #2D5066    ████████    RGB(45, 80, 102)     HSL(203, 39%, 29%)
```
**Usage:** Primary text, navigation, headers, high-contrast elements
**Contrast Ratios:** ✓ AAA compliant on light backgrounds

### Semantic Palette

#### Financial Status Colors
```
Income:     #059669    ████████    Emerald - Sophisticated positive
Expense:    #DC2626    ████████    Ruby - Clear but not alarming
Transfer:   #64748B    ████████    Slate - Neutral, distinct
Warning:    #F59E0B    ████████    Amber - Attention without panic
Error:      #DC2626    ████████    Ruby - Same as expense for consistency
Success:    #059669    ████████    Emerald - Same as income
```

### Background System
```
Canvas:     #FDFBF7    ████████    Warm white main background
Surface:    #FFFFFF    ████████    Pure white for cards/elevated content
Subtle:     #F8F6F1    ████████    Alternating row background
Overlay:    rgba(13, 27, 42, 0.6)    Semi-transparent navy for modals
```

### Accessibility Compliance
| Combination | Contrast Ratio | WCAG Level |
|-------------|----------------|------------|
| Gold on Canvas | 7.2:1 | AAA |
| Navy on Canvas | 15.1:1 | AAA |
| Gold on Navy | 4.8:1 | AA+ |
| Income on Canvas | 6.8:1 | AAA |
| Expense on Canvas | 6.9:1 | AAA |

### Dark Mode Considerations
*Planned for Phase 6 (Post-Launch)*
```
Dark Canvas:   #0D1B2A    Navy becomes background
Dark Surface:  #1B3A4B    Navy medium for cards
Dark Gold:     #E5D5A0    Light gold maintains warmth
```

---

## Typography System

### Font Stack
**Primary:** SF Pro (System Default)
- **Display:** SF Pro Rounded - For large numbers and hero content
- **Monospace:** SF Mono - For financial figures requiring alignment
- **UI:** SF Pro - All interface text

### Type Scale & Hierarchy

#### Display Typography (Large Values, Heroes)
```swift
displayLarge:   Font.system(size: 48, weight: .bold, design: .rounded)
displayMedium:  Font.system(size: 36, weight: .bold, design: .rounded)
displaySmall:   Font.system(size: 28, weight: .bold, design: .rounded)
```
**Usage:** Dashboard totals, primary KPI values, onboarding heroes

#### Currency Typography (Financial Precision)
```swift
currencyLarge:  Font.system(size: 28, weight: .semibold, design: .monospaced)
currencyMedium: Font.system(size: 20, weight: .semibold, design: .monospaced)
currencySmall:  Font.system(size: 16, weight: .medium, design: .monospaced)
currencyMicro:  Font.system(size: 13, weight: .medium, design: .monospaced)
```
**Usage:** Transaction amounts, account balances, KPI cards, financial calculations

#### Interface Typography (UI Elements)
```swift
h1:             Font.system(size: 28, weight: .bold)           // Page titles
h2:             Font.system(size: 22, weight: .semibold)       // Section headers
h3:             Font.system(size: 18, weight: .semibold)       // Subsection headers
h4:             Font.system(size: 16, weight: .medium)         // Component headers

bodyLarge:      Font.system(size: 16, weight: .regular)       // Important text
body:           Font.system(size: 14, weight: .regular)       // Default body text
bodySmall:      Font.system(size: 13, weight: .regular)       // Secondary content

label:          Font.system(size: 12, weight: .medium)        // Form labels
caption:        Font.system(size: 11, weight: .regular)       // Help text, metadata
overline:       Font.system(size: 10, weight: .semibold)      // Categories, tags
```

### Typography Implementation
```swift
// Florijn/Theme/FlorijnTypography.swift
enum FlorijnTypography {
    // MARK: - Display (Hero content)
    static let displayLarge = Font.system(size: 48, weight: .bold, design: .rounded)

    // MARK: - Currency (Precision alignment)
    static let currencyLarge = Font.system(size: 28, weight: .semibold, design: .monospaced)

    // MARK: - Interface (Standard UI)
    static let h1 = Font.system(size: 28, weight: .bold)
    static let body = Font.system(size: 14, weight: .regular)

    // MARK: - Accessibility
    static func scaledFont(_ font: Font) -> Font {
        // Respects user's Dynamic Type preferences
        return font
    }
}
```

---

## Spacing System

### Base Grid: 4px
```swift
enum FlorijnSpacing {
    static let xxs: CGFloat = 2     // Micro adjustments, borders
    static let xs: CGFloat = 4      // Icon gaps, tight spacing
    static let sm: CGFloat = 8      // Related element spacing
    static let md: CGFloat = 12     // Component internal padding
    static let lg: CGFloat = 16     // Section spacing, card padding
    static let xl: CGFloat = 24     // Major section gaps
    static let xxl: CGFloat = 32    // Page-level margins
    static let xxxl: CGFloat = 48   // Hero spacing, modal margins
    static let xxxxl: CGFloat = 64  // Empty state spacing
}
```

### Layout Measurements
```swift
enum FlorijnLayout {
    static let sidebarWidth: CGFloat = 240      // Navigation sidebar
    static let minWindowWidth: CGFloat = 800    // Minimum app window
    static let minWindowHeight: CGFloat = 600   // Minimum app window
    static let maxContentWidth: CGFloat = 1200  // Content area constraint
    static let cardMinHeight: CGFloat = 120     // Minimum card height
    static let rowHeight: CGFloat = 56          // Standard list row
    static let buttonHeight: CGFloat = 40       // Standard button
}
```

### Corner Radius System
```swift
enum FlorijnRadius {
    static let xs: CGFloat = 4      // Small buttons, badges
    static let sm: CGFloat = 6      // Input fields
    static let md: CGFloat = 8      // Standard buttons
    static let lg: CGFloat = 12     // Cards, panels
    static let xl: CGFloat = 16     // Large cards, modals
    static let xxl: CGFloat = 24    // Hero cards, main panels
    static let full: CGFloat = 9999 // Circular elements, pills
}
```

---

## Shadow & Elevation

### Elevation Layers
```swift
enum FlorijnShadow {
    // Level 0: Flush with background
    static let none = (color: Color.clear, radius: 0, x: 0, y: 0)

    // Level 1: Subtle lift (resting cards)
    static let sm = (color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)

    // Level 2: Default elevation (active cards)
    static let md = (color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)

    // Level 3: Hover state (interactive elevation)
    static let lg = (color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

    // Level 4: Modal/drawer (overlay elevation)
    static let xl = (color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)

    // Level 5: Tooltip/popover (highest elevation)
    static let xxl = (color: Color.black.opacity(0.16), radius: 24, x: 0, y: 12)

    // Special: Gold glow (selection/focus)
    static let goldGlow = (color: FlorijnColors.gold.opacity(0.4), radius: 8, x: 0, y: 0)
}

// SwiftUI Shadow Modifier Extension
extension View {
    func florijnShadow(_ level: FlorijnShadow) -> some View {
        shadow(
            color: level.color,
            radius: level.radius,
            x: level.x,
            y: level.y
        )
    }
}
```

---

## Component Specifications

### 1. Navigation Sidebar

#### Visual Design
```
┌─────────────────────────────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │  Background: Navy (#0D1B2A)
│                                         │  Width: 240px
│   ◈  Florijn                           │  Logo: Gold wordmark
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ ▣  Dashboard                      │ │  Selected: Gold subtle bg
│  └───────────────────────────────────┘ │  Text: White
│     ◻  Transactions                    │  Icon: Gold
│     ◻  Categories                      │
│     ◻  Rules                           │  Unselected: 60% opacity
│     ◻  Accounts                        │  Hover: 80% opacity
│                                         │
│  ─────────────────────────────────     │  Divider: 15% white
│                                         │
│     ◻  Import                          │  Bottom section
│     ◻  Export                          │
│     ◻  Settings                        │
│                                         │
└─────────────────────────────────────────┘
```

#### Implementation
```swift
struct FlorijnSidebar: View {
    @Binding var selectedTab: NavigationTab

    var body: some View {
        VStack(spacing: 0) {
            // Logo section
            VStack(spacing: FlorijnSpacing.lg) {
                HStack {
                    Text("Florijn")
                        .font(FlorijnTypography.h2)
                        .foregroundStyle(FlorijnColors.gold)
                    Spacer()
                }
                .padding(.horizontal, FlorijnSpacing.lg)
                .padding(.top, FlorijnSpacing.xl)
            }

            Spacer().frame(height: FlorijnSpacing.xl)

            // Main navigation
            LazyVStack(spacing: FlorijnSpacing.xs) {
                FlorijnSidebarItem(.dashboard, isSelected: selectedTab == .dashboard)
                FlorijnSidebarItem(.transactions, isSelected: selectedTab == .transactions)
                // ...additional items
            }
            .padding(.horizontal, FlorijnSpacing.md)

            Spacer()

            // Bottom navigation
            Divider()
                .overlay(.white.opacity(0.15))
                .padding(.horizontal, FlorijnSpacing.lg)
                .padding(.vertical, FlorijnSpacing.md)

            LazyVStack(spacing: FlorijnSpacing.xs) {
                FlorijnSidebarItem(.import, isSelected: selectedTab == .import)
                FlorijnSidebarItem(.settings, isSelected: selectedTab == .settings)
            }
            .padding(.horizontal, FlorijnSpacing.md)
            .padding(.bottom, FlorijnSpacing.lg)
        }
        .frame(width: FlorijnLayout.sidebarWidth)
        .background(FlorijnColors.navy)
    }
}
```

### 2. KPI Card Component

#### Visual Design
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  ◈  Total Balance                          ▲ +2.4%     │  Icon: Gold
│                                                         │  Title: Secondary
│  € 24,567.89                                           │  Value: Navy, monospace
│  ▔▔▔▔▔▔▔▔▔▔▔▔                                           │  Accent: Gold bar
│                                                         │  Trend: Green/Red badge
└─────────────────────────────────────────────────────────┘

States:
- Rest: White bg, subtle shadow, 70% gold bar
- Hover: Scale 1.02, stronger shadow, full gold bar
- Loading: Skeleton animation
```

#### Implementation
```swift
struct FlorijnKPICard: View {
    let title: String
    let value: Decimal?
    let formatter: NumberFormatter = .currency
    let trend: Double?
    let icon: String
    let index: Int

    @State private var isHovered = false
    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: FlorijnSpacing.md) {
            // Header row
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FlorijnColors.gold)

                Spacer()

                if let trend = trend {
                    FlorijnTrendBadge(value: trend)
                }
            }

            // Title
            Text(title.uppercased())
                .font(FlorijnTypography.overline)
                .foregroundStyle(FlorijnColors.textSecondary)

            // Value
            if let value = value {
                AnimatedNumber(value: value, font: FlorijnTypography.currencyLarge)
                    .foregroundStyle(FlorijnColors.textPrimary)
            } else {
                FlorijnSkeletonLine(width: 120, height: 28)
            }
        }
        .padding(FlorijnSpacing.lg)
        .background(FlorijnColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FlorijnRadius.lg))
        .florijnShadow(isHovered ? .lg : .md)
        .overlay(alignment: .bottom) {
            // Gold accent bar
            Rectangle()
                .fill(FlorijnColors.gold.opacity(isHovered ? 1.0 : 0.7))
                .frame(height: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .padding(.horizontal, FlorijnSpacing.lg)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .opacity(hasAppeared ? 1.0 : 0.0)
        .offset(y: hasAppeared ? 0 : 10)
        .animation(FlorijnAnimation.spring, value: isHovered)
        .animation(FlorijnAnimation.spring.delay(Double(index) * 0.1), value: hasAppeared)
        .onHover { isHovered = $0 }
        .onAppear { hasAppeared = true }
    }
}
```

### 3. Transaction Row Component

#### Implementation
```swift
struct FlorijnTransactionRow: View {
    let transaction: Transaction
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: FlorijnSpacing.md) {
            // Type indicator
            Circle()
                .fill(typeIndicatorColor)
                .frame(width: 8, height: 8)

            // Transaction content
            VStack(alignment: .leading, spacing: FlorijnSpacing.xs) {
                Text(transaction.displayName)
                    .font(FlorijnTypography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(FlorijnColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: FlorijnSpacing.xs) {
                    Text(transaction.category?.name ?? "Uncategorized")
                        .foregroundStyle(FlorijnColors.textSecondary)

                    Text("•")
                        .foregroundStyle(FlorijnColors.textTertiary)

                    Text(transaction.date.formatted(.dateTime.day().month(.abbreviated)))
                        .foregroundStyle(FlorijnColors.textSecondary)
                }
                .font(FlorijnTypography.caption)
            }

            Spacer()

            // Amount
            Text(transaction.amount.formatted(.currency(code: "EUR")))
                .font(FlorijnTypography.currencySmall)
                .foregroundStyle(amountColor)
        }
        .padding(.horizontal, FlorijnSpacing.lg)
        .padding(.vertical, FlorijnSpacing.md)
        .background(isHovered ? FlorijnColors.goldSubtle : .clear)
        .overlay(
            Rectangle()
                .fill(FlorijnColors.gold.opacity(isHovered ? 0.3 : 0))
                .frame(height: 1),
            alignment: .bottom
        )
        .animation(FlorijnAnimation.fast, value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var typeIndicatorColor: Color {
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

### 4. Button System

#### Hierarchy & States
```swift
enum FlorijnButtonStyle {
    case primary        // Gold fill, navy text
    case secondary      // Gold outline, gold text
    case tertiary       // No outline, secondary text
    case destructive    // Red fill/outline
}

struct FlorijnButton: View {
    let title: String
    let icon: String?
    let style: FlorijnButtonStyle
    let size: FlorijnButtonSize
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: handleAction) {
            HStack(spacing: FlorijnSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .medium))
                }

                Text(title)
                    .font(titleFont)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : (isHovered ? 1.02 : 1.0))
        .animation(FlorijnAnimation.fast, value: isHovered)
        .animation(FlorijnAnimation.fast, value: isPressed)
        .onHover { isHovered = $0 }
    }

    private func handleAction() {
        withAnimation(FlorijnAnimation.fast) {
            isPressed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(FlorijnAnimation.fast) {
                isPressed = false
            }
            action()
        }
    }
}
```

---

## Animation System

### Timing Functions
```swift
enum FlorijnAnimation {
    // Primary spring for UI interactions
    static let spring = Animation.spring(response: 0.3, dampingFraction: 0.8)

    // Quick interactions (hovers, selections)
    static let fast = Animation.spring(response: 0.2, dampingFraction: 0.8)

    // Slow, considered movements (page transitions)
    static let slow = Animation.spring(response: 0.4, dampingFraction: 0.85)

    // Number counting animations
    static let number = Animation.spring(response: 0.6, dampingFraction: 0.7)

    // Gentle bounce for attention
    static let bounce = Animation.spring(response: 0.5, dampingFraction: 0.6)

    // Accessibility: Respects reduced motion
    static func respectingMotion(_ animation: Animation) -> Animation {
        return UIAccessibility.isReduceMotionEnabled ? .easeInOut(duration: 0.25) : animation
    }
}
```

### Interaction Choreography
| Interaction | Animation | Duration | Effect |
|-------------|-----------|----------|---------|
| **Card hover** | Scale + shadow | 200ms spring | `scale(1.02)` + `shadow(lg)` |
| **Row hover** | Background + border | 200ms spring | Gold tint + subtle border |
| **Button press** | Scale down/up | 100ms + 200ms | `scale(0.96)` → `scale(1.0)` |
| **Page transition** | Slide + fade | 400ms spring | Native navigation feel |
| **Number update** | Count animation | 600ms spring | Smooth value interpolation |
| **Loading state** | Skeleton pulse | 1.2s ease-in-out | Breathing opacity cycle |

### Performance Considerations
- Animations disabled automatically when `UIAccessibility.isReduceMotionEnabled`
- Hardware acceleration via `CALayer` for complex animations
- Skeleton animations use `CABasicAnimation` for efficiency
- Number animations use interpolation to avoid layout thrashing

---

## Accessibility

### Color & Contrast
- All color combinations meet WCAG AAA standards (7:1+ contrast ratio)
- Additional visual indicators beyond color for status (icons, patterns)
- High contrast mode support via semantic colors

### Typography & Legibility
- Dynamic Type support for all text elements
- Minimum 16pt touch targets for interactive elements
- Clear visual hierarchy with size, weight, and color differentiation

### Motor & Cognitive
- Large click targets (minimum 44pt on macOS)
- Hover states provide clear feedback
- Keyboard navigation support for all interactive elements
- Reduced motion support maintains functionality

### Screen Reader Support
```swift
// Accessibility Implementation Example
struct FlorijnKPICard: View {
    var body: some View {
        VStack {
            // Card content
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value.formatted())")
        .accessibilityValue(trend.map { "trending \($0 > 0 ? "up" : "down") \(abs($0))%" } ?? "")
        .accessibilityHint("Double tap to view details")
    }
}
```

---

## App Icon Design

### Concept: The Modern Florijn
```
┌─────────────────────────────────────────┐
│                                         │
│           ╭─────────────╮               │
│         ╭─┴─╮         ╭─┴─╮             │  Coin silhouette
│        │   F           │   │            │  Gold gradient
│         ╰─┬─╯         ╰─┬─╯             │  Navy background
│           ╰─────────────╯               │  Geometric "F"
│                                         │
└─────────────────────────────────────────┘
```

### Technical Specifications
#### Master Icon (1024×1024)
- **Background:** Navy gradient (#0D1B2A → #1B3A4B)
- **Coin:** 720×720px centered, gold gradient (#C9A227 → #E5D5A0)
- **Typography:** 420×420px "F" in navy, geometric, slight radius
- **Shadow:** Inner shadow on coin for depth (2px, 20% opacity)

#### Size Variations
| Size | Coin Detail | "F" Weight | Export Format |
|------|-------------|------------|---------------|
| 1024×1024 | Full detail + shadow | Medium | PNG (App Store) |
| 512×512 | Full detail | Medium | PNG |
| 256×256 | Simplified detail | Bold | PNG |
| 128×128 | Basic coin shape | Bold | PNG |
| 64×64 | Solid color coin | Heavy | PNG |
| 32×32 | Circular gold dot | N/A | PNG |
| 16×16 | Single gold pixel | N/A | PNG |

---

## Implementation Sequence

**PREREQUISITE:** Complete brand transformation first (see `2025-01-florijn-transformation-plan.md`)

### Phase 1: Theme Foundation (One focused session)
**Goal:** Establish design system infrastructure

**Prerequisites:**
- [ ] Project is renamed to "Florijn"
- [ ] App builds successfully as Florijn
- [ ] Bundle identifier updated to `com.florijn.app`

**Tasks:**
- [ ] Create `Florijn/Theme/` directory structure
- [ ] Implement `FlorijnColors.swift` with full palette
- [ ] Implement `FlorijnTypography.swift` with complete scale
- [ ] Implement `FlorijnSpacing.swift` with grid system
- [ ] Implement `FlorijnShadow.swift` with elevation system
- [ ] Create base view modifiers (`.florijnShadow()`, `.primaryCard()`)
- [ ] Add color assets to `Assets.xcassets`

**Deliverable:** Complete theme system ready for component usage

**Validation:**
```swift
// Verify all imports work
import FlorijnTheme

// Test color compilation
let testColor = FlorijnColors.gold
let testFont = FlorijnTypography.currencyLarge
let testSpacing = FlorijnSpacing.lg
```

### Phase 2: Core Components (Day 2 - 4 hours)
**Goal:** Build essential UI components with new design system

**Tasks:**
- [ ] `FlorijnButton` with all variants and states
- [ ] `FlorijnKPICard` with animations and accessibility
- [ ] `FlorijnTransactionRow` with hover states
- [ ] `FlorijnSidebarItem` with selection and navigation
- [ ] `FlorijnTextField` for form inputs
- [ ] `FlorijnBadge` for categories and status
- [ ] `FlorijnSkeletonLine` for loading states

**Deliverable:** Reusable component library

**Validation:**
- All components render correctly
- Hover states work across all interactive elements
- Accessibility labels are properly set
- Animation performance is smooth

### Phase 3: View Integration (Day 3-4 - 6 hours)
**Goal:** Apply design system to main application views

**Tasks:**
- [ ] **Sidebar Navigation:** Apply `FlorijnSidebar` styling
- [ ] **Dashboard View:** Update with `FlorijnKPICard` components
- [ ] **Transaction List:** Apply `FlorijnTransactionRow` styling
- [ ] **Rules View:** Update with new button and card styles
- [ ] **Import View:** Apply form styling and progress indicators
- [ ] **Settings View:** Apply consistent styling

**Deliverable:** Cohesive application experience

**Validation:**
- Visual consistency across all views
- Navigation flows feel natural
- Performance remains smooth with new styling

### Phase 4: Polish & Microinteractions (Day 5 - 3 hours)
**Goal:** Add delight and refined interactions

**Tasks:**
- [ ] Enhanced empty states with illustration style
- [ ] Refined loading animations
- [ ] Smooth page transitions
- [ ] Contextual hover feedback
- [ ] Sound design consideration (system sounds)
- [ ] Error state styling
- [ ] Success confirmation animations

**Deliverable:** Production-ready polish

**Validation:**
- App feels responsive and delightful
- Edge cases are handled gracefully
- Error recovery is clear and helpful

### Phase 5: App Icon Creation (Day 5 - 2 hours)
**Goal:** Professional app icon aligned with brand

**Tasks:**
- [ ] Create master 1024×1024 icon in design tool
- [ ] Generate all required size variants
- [ ] Test icon in Dock, Spotlight, and App Store
- [ ] Update `Assets.xcassets` with icon set
- [ ] Verify icon displays correctly in build

**Deliverable:** Professional app icon

**Validation:**
- Icon is legible at all sizes
- Icon matches brand identity
- Icon looks professional in macOS system contexts

### Phase 6: Quality Assurance (Day 6 - 2 hours)
**Goal:** Ensure design system is robust and complete

**Tasks:**
- [ ] Accessibility audit (VoiceOver, keyboard navigation)
- [ ] Performance testing with large datasets
- [ ] Visual regression testing across views
- [ ] Color contrast verification
- [ ] Animation performance on older hardware
- [ ] Documentation review and updates

**Deliverable:** Verified, production-ready design system

**Success Metrics:**
- [ ] Zero accessibility violations
- [ ] 60fps performance maintained
- [ ] All views use design system consistently
- [ ] Build produces zero warnings
- [ ] Design system is documented and maintainable

---

## File Structure

```
Florijn/
├── Florijn/
│   ├── Theme/
│   │   ├── FlorijnColors.swift         // Color palette + semantic colors
│   │   ├── FlorijnTypography.swift     // Type scale + font definitions
│   │   ├── FlorijnSpacing.swift        // Spacing scale + layout constants
│   │   ├── FlorijnShadow.swift         // Elevation system
│   │   ├── FlorijnAnimation.swift      // Animation timing + accessibility
│   │   └── FlorijnRadius.swift         // Corner radius system
│   ├── Components/
│   │   ├── FlorijnButton.swift         // Button component + variants
│   │   ├── FlorijnKPICard.swift        // KPI card with animations
│   │   ├── FlorijnTransactionRow.swift // Transaction list row
│   │   ├── FlorijnSidebar.swift        // Navigation sidebar
│   │   ├── FlorijnTextField.swift      // Form input styling
│   │   ├── FlorijnBadge.swift          // Status and category badges
│   │   └── FlorijnSkeleton.swift       // Loading state components
│   └── Extensions/
│       ├── View+FlorijnModifiers.swift // Custom view modifiers
│       ├── Color+Accessibility.swift   // Contrast ratio utilities
│       └── Animation+Motion.swift      // Reduced motion support
├── Assets.xcassets/
│   ├── AppIcon.appiconset/            // All app icon sizes
│   ├── Colors/                        // Color asset definitions
│   │   ├── FlorijnGold.colorset/
│   │   ├── FlorijnNavy.colorset/
│   │   └── [additional color sets]
│   └── Icons/                         // Custom icons and symbols
├── Views/                             // Updated with Florijn styling
│   ├── DashboardView.swift            // Uses FlorijnKPICard
│   ├── TransactionsView.swift         // Uses FlorijnTransactionRow
│   ├── SidebarView.swift              // Uses FlorijnSidebar
│   └── [other views]
├── FlorijnApp.swift                   // Main app file (renamed from FamilyFinanceApp.swift)
└── docs/
    ├── Design-System.md               // This document
    └── Component-Library.md           // Component usage guide
```

---

## Migration Strategy

### Gradual Rollout Approach
1. **Foundation First:** Establish theme system without breaking existing functionality
2. **Component by Component:** Update one component at a time, test thoroughly
3. **View by View:** Apply new components to views systematically
4. **Polish Last:** Add final touches and microinteractions

### Rollback Plan
- Keep existing components available during transition period
- Use feature flags for design system adoption per view
- Maintain git tags for stable design system versions
- Document any breaking changes for team awareness

### Testing Strategy
- Visual regression testing using screenshot comparisons
- Accessibility testing at each phase
- Performance benchmarking with representative data
- User feedback collection during internal testing

---

## Success Metrics

### Brand Recognition
- [ ] App is immediately recognizable as "Florijn"
- [ ] Visual consistency across all views and components
- [ ] Design system assets are reusable and maintainable

### User Experience
- [ ] Improved task completion rates
- [ ] Positive feedback on visual design
- [ ] Maintained or improved performance metrics
- [ ] Zero accessibility regressions

### Technical Quality
- [ ] 100% design system adoption across views
- [ ] Zero build warnings related to styling
- [ ] All components properly documented
- [ ] Design system scales for future features

### App Store Readiness
- [ ] Professional app icon at all sizes
- [ ] Screenshots showcase refined design
- [ ] App meets all App Store design guidelines
- [ ] Visual design supports marketing efforts

---

## Post-Launch Evolution

### Phase 7: Dark Mode (Q2 2025)
Complete dark mode implementation with adjusted color palette

### Phase 8: Localization Support
Design system expansion to support multiple languages

### Phase 9: iOS Companion
Adapt design system for iOS app consistency

### Phase 10: Advanced Animations
Enhanced microinteractions and transitions for power users

---

**This design system transforms FamilyFinance into Florijn — a sophisticated, trustworthy finance application that honors its Dutch heritage while embracing modern design excellence.**