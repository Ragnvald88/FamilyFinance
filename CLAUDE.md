# Family Finance

> **App Store-Quality macOS Finance App** | SwiftUI + SwiftData | Premium UI/UX
>
> **Status: 90% App Store Quality** — Core app production-ready, rules UI complete

## Current Status (December 27, 2025)

### Core App: Production Ready
- **Transaction management** - full CRUD, 15k+ transaction support
- **CSV import** for Dutch banks - robust encoding detection
- **Dashboard with analytics** - charts, trends, KPIs
- **Categories management** - hierarchical system
- **Account management** - multi-bank support
- **Performance** - 60fps animations, virtualized scrolling

### Rules System: Firefly III-Style Complete

**Design Philosophy** (from [Firefly III](https://docs.firefly-iii.org/how-to/firefly-iii/features/rules/)):
- **Rules are primary** - Not groups
- **Groups are optional** - Just folders for organization
- **Simple workflow** - Create rule → Add triggers → Add actions → Done

| Component | Status |
|-----------|--------|
| `SimpleRulesView.swift` | **Complete** - Rules-first UI with built-in editor |
| `RulesModels.swift` | Complete (Rule, RuleGroup, RuleTrigger, RuleAction) |
| `TriggerEvaluator.swift` | Production ready (15 operators) |
| `ActionExecutor.swift` | Production ready (16 action types) |
| `RuleEngine.swift` | Compiles and integrates |

---

## Architecture

### File Structure

```
FamilyFinanceApp.swift           — Main app + design tokens

Models/
├── SwiftDataModels.swift        — Transaction/Account/Category
├── RulesModels.swift            — Rule/RuleGroup/RuleTrigger/RuleAction
└── RuleStatistics.swift         — Performance metrics

Services/
├── RuleEngine.swift             — Rule orchestration
├── TriggerEvaluator.swift       — Trigger evaluation
├── ActionExecutor.swift         — Action execution
└── [Other services]             — CSV import, queries, etc.

Views/
├── SimpleRulesView.swift        — Firefly III-style rules UI (ACTIVE)
├── RulesView.swift              — Old groups-first UI (deprecated)
└── [Other views]                — Dashboard, transactions, etc.
```

### Rules UI Design

```
Sidebar (Filters):              Main Area:
├── All Rules (12)              ┌─────────────────────────────┐
├── Active (10)                 │ [+ Create Rule]             │
├── Inactive (2)                ├─────────────────────────────┤
├── Ungrouped (5)               │ ● Rule Name                 │
└── Groups:                     │   IF description contains   │
    ├── Bills (4)               │   "spotify" THEN Set        │
    └── Shopping (3)            │   Category                  │
                                └─────────────────────────────┘
```

---

## Key Patterns

### SwiftData Identity

```swift
@Model final class Rule {
    @Attribute(.unique) var uuid: UUID  // Stable for UI bindings
}

// Use .uuid in views, not .id
ForEach(rules) { rule in
    RuleRow(rule: rule)
}
```

### Reserved Keywords

```swift
// Swift's "operator" is reserved
var triggerOperator: TriggerOperator  // Not "operator"
```

### Design Tokens

```swift
DesignTokens.Animation.spring        // 0.3s
DesignTokens.Spacing.xl              // 24pt
```

---

## Quality Standards

- [x] All animations 0.3s spring
- [x] 15k+ transactions smoothly
- [x] Zero compiler errors
- [x] Memory under 100MB
- [x] Swift 6 Sendable compliance

---

## Development

1. **Verify build**: `xcodebuild -scheme FamilyFinance build`
2. **Use design tokens** for spacing/animations
3. **Test with real data** - 15k+ transactions

---

## Recent Changes (December 27, 2025)

### Simplified to Firefly III Pattern

**Problem**: Old UI put "Groups" first - users had to understand groups before creating rules.

**Solution**: New `SimpleRulesView.swift` with:
- Rules shown in flat list (primary view)
- "Create Rule" as main action
- Groups as optional filters in sidebar
- Built-in rule editor (no separate placeholder views)

**Files Changed**:
- Created `Views/SimpleRulesView.swift` (700 lines, complete)
- Updated `FamilyFinanceApp.swift` to use `SimpleRulesView`
- Deprecated `RulesView.swift` (old groups-first approach)

**Result**: Clean, Firefly III-style interface - BUILD SUCCEEDED

---

## Code Enhancement Protocol

> **The best code change is the smallest one that completely solves the problem.**

### Core Principles

1. **Understand First, Code Second**
   - Read existing code thoroughly before touching anything
   - Identify patterns, conventions, and architectural decisions already in place
   - Ask: "Why was it built this way?" before changing it

2. **The Simplicity Test** - Before every change, ask:
   - Can I solve this with LESS code?
   - Am I adding complexity to handle a case that won't happen?
   - Would a junior developer understand this in 6 months?

3. **Creative Debugging Loop**
   ```
   OBSERVE → What exactly is broken/suboptimal?
   HYPOTHESIZE → What's the root cause? (not symptoms)
   DEBATE → Challenge your hypothesis. What else could it be?
   IMPLEMENT → Smallest possible fix that addresses root cause
   VERIFY → Build/run. Does it actually work?
   REFLECT → Could this be simpler? Did I introduce new issues?
   ```

4. **Anti-Patterns to Avoid**
   - ❌ "While I'm here, let me also refactor..."
   - ❌ Adding abstractions for hypothetical future needs
   - ❌ Fixing symptoms instead of causes
   - ❌ Over-engineering simple problems
   - ❌ Changing code style of untouched code

5. **Creative Problem Solving** - When stuck:
   - **Invert**: What if I did the opposite?
   - **Eliminate**: What if I removed this entirely?
   - **Combine**: Can two things become one?
   - **Steal**: How do other codebases solve this?
   - **Simplify**: What's the 80/20 solution?

6. **Self-Debate Protocol** - Before finalizing significant changes:
   ```
   "I'm about to [change].
   - What could go wrong?
   - Is there a simpler way?
   - Am I solving the right problem?
   - What would a skeptical senior dev say?"
   ```

7. **Quality Checklist**
   - ✓ Does it compile/build?
   - ✓ Does it solve the actual problem?
   - ✓ Is it the minimal change needed?
   - ✓ Does it follow existing patterns?
   - ✓ Would I be proud to show this code?
