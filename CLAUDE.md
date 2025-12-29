# Family Finance

> **App Store-Quality macOS Finance App** | SwiftUI + SwiftData | Premium UI/UX
>
> **Status: 77% Quality Score** — Core app works, cleanup needed before production

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
├── SimpleRulesView.swift        — Firefly III-style rules UI
├── DashboardView.swift          — KPIs, charts, analytics
├── TransactionDetailView.swift  — Transaction editing
└── ImportView.swift             — CSV import UI
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

## Recent Changes (December 28, 2025)

### Legacy Rules System Removed

**Cleaned up legacy code** - Only ONE rules system now:
- Removed `CategorizationRule` model from SwiftDataModels.swift
- Removed `RuleCondition` model from SwiftDataModels.swift
- Removed `RuleMatchType` enum (unused)
- Updated `CategorizationEngine.swift` - now only uses NEW Rule model
- Updated `ExportService.swift` - exports NEW Rule model
- Updated all test files to use NEW Rule model schema

### Rules → CSV Import Integration Fixed

**Critical fix**: Rules created in SimpleRulesView now apply during CSV import:
- `CategorizationEngine.refreshCompiledRules()` fetches from `Rule` model
- `compileNewRule()` converts Rule triggers to CompiledCondition format
- Rules with `setCategory` action are applied during bulk import

### Rules System (Firefly III-Style)

**Single unified system**: `SimpleRulesView.swift` with:
- Rules shown in flat list (primary view)
- Multi-trigger support with AND/OR logic
- Smart pickers for categories/accounts
- TriggerGroup model for nested conditions
- **Integrated with CSV import** via CategorizationEngine

**Result**: Clean codebase, BUILD SUCCEEDED

---

## Quality Assessment (December 29, 2025)

### Benchmark Results

| Dimension | Target | Actual | Status |
|-----------|--------|--------|--------|
| Functionality | 100% | 85% | ⚠️ PARTIAL |
| Code Quality | <5 violations | 3 | ✅ PASS |
| Optimization | <3 issues | 5 | ❌ FAIL |
| Redundancy | <200 lines | ~960 lines | ❌ FAIL |
| Overengineering | <3 patterns | 12 patterns | ❌ FAIL |

### Critical Issues (P0)

| Issue | Location | Status |
|-------|----------|--------|
| TriggerGroups ignored during CSV import | `CategorizationEngine.compileNewRule()` | **TODO** |
| Rules without setCategory silently dropped | `CategorizationEngine.compileNewRule()` | **TODO** |
| Categorization errors not reported | `CSVImportService.importFiles()` | **TODO** |
| CircuitBreaker state hidden from users | `RuleEngine.swift` | **TODO** |

### Known Technical Debt

**Dead Code to Remove (~960 lines):**
- `AdvancedBooleanLogicBuilder.swift` (673 lines) - superseded by SimpleRulesView
- `RuleStatisticsAnalyzer` in RuleStatistics.swift (~100 lines) - never called
- Placeholder editors in RulesView.swift (~66 lines)
- `ThreadSafeCategorization.swift` (11 lines) - stub marked for deletion

**Overengineered Patterns (~560 lines):**
- CircuitBreaker in RuleEngine (75 lines) - enterprise pattern for single-user app
- SystemMonitor with fake random "load" (20 lines) - provides zero value
- LRU evaluation cache in TriggerEvaluator (50 lines) - cache thrashing, no invalidation
- Frame-rate throttling in RuleProgressPublisher (150 lines) - overkill for 3-5 updates

### Architecture Notes

**CategorizationEngine vs RuleEngine:**
- `CategorizationEngine` - Used during CSV import, compiles Rules to CompiledRules
- `RuleEngine` - Used for manual rule execution, uses Rule model directly
- **Gap**: CategorizationEngine only handles setCategory action, ignores TriggerGroups

**Data stored in wrong fields:**
- Tags stored as comma-separated in notes field
- ExternalId and InternalReference appended to notes
- **Fix needed**: Add dedicated fields to Transaction model

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
