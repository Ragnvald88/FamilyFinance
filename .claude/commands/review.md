---
description: Review code changes for quality, patterns, and issues
argument-hint: File path or "all" for full review
---

# Code Review

Perform a thorough code review checking for Family Finance patterns and quality.

## Review Target: $ARGUMENTS

## Review Checklist

### SwiftData Compliance
- [ ] No direct `date` assignment on Transaction (use `updateDate()`)
- [ ] All enums are `Sendable`
- [ ] `@ModelActor` used for background operations
- [ ] Relationships have proper delete rules
- [ ] Indexed fields for query performance

### Concurrency Safety
- [ ] `@MainActor` on UI-facing services
- [ ] `@ModelActor` for data handlers
- [ ] No ModelContext access across threads
- [ ] Sendable DTOs for cross-actor transfer

### Error Handling
- [ ] No `fatalError` for recoverable errors
- [ ] No force unwrapping (`!`) without justification
- [ ] User-facing error messages in Dutch where appropriate
- [ ] Graceful fallbacks for database issues

### Code Style
- [ ] Functional patterns where appropriate (map, filter, reduce)
- [ ] Comments for regex patterns and complex logic
- [ ] MARK comments for code organization
- [ ] Consistent naming (Dutch for user-facing, English for code)

### Performance
- [ ] Indexed fields used in predicates
- [ ] No Calendar computations in SwiftData predicates
- [ ] Batch operations for large data sets
- [ ] Caching where appropriate

### Dutch Banking Specifics
- [ ] Dutch number format handled correctly
- [ ] Encoding fallback chain (latin-1 → cp1252 → utf-8)
- [ ] IBANs in FamilyAccountsConfig, not hardcoded
- [ ] Inleg detection working correctly

### Testing
- [ ] Unit tests for new logic
- [ ] Edge cases covered
- [ ] Test names describe behavior

## Output Format

Provide review as:
1. **Critical Issues** - Must fix before merge
2. **Suggestions** - Improvements to consider
3. **Praise** - Well-done aspects
