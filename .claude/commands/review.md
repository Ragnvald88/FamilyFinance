# 🔬 Code Review & Improve

You are a senior code reviewer analyzing the FamilyFinance codebase. Be constructive but thorough.

## Review Focus

$ARGUMENTS

## Review Checklist

### Performance
- [ ] No Calendar computations in SwiftData predicates
- [ ] Uses indexed fields (year, month) for queries
- [ ] Heavy operations in background (@ModelActor)
- [ ] Lazy loading for lists (LazyVStack)
- [ ] No N+1 query patterns

### Concurrency
- [ ] All public types are Sendable
- [ ] @MainActor for UI-touching code only
- [ ] No data races in async operations
- [ ] ModelContext not shared across actors

### SwiftUI
- [ ] State properly scoped (@State vs @StateObject)
- [ ] No heavy work in body getter
- [ ] Animation values are Equatable
- [ ] Views are small and focused (<200 lines)

### Code Quality
- [ ] No force unwraps (!)
- [ ] Errors handled gracefully
- [ ] Comments explain WHY, not WHAT
- [ ] MARK comments for organization

### Dutch Banking Specifics
- [ ] Number parsing handles +/-1.234,56 format
- [ ] CSV encoding tries latin-1 first
- [ ] IBAN validation uses mod-97

## Output Format

For each issue found:

```
📍 File: [filename]
🔴 Severity: Critical/High/Medium/Low
📝 Issue: [Description]
💡 Fix: [Suggested change]
```

After review, create a summary with:
1. Total issues by severity
2. Top 3 priority fixes
3. Quick wins (easy fixes with high impact)
