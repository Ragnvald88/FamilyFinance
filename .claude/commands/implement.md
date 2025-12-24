---
description: Implement a new feature with proper architecture
argument-hint: Feature description
---

# Implement Feature

Implement the requested feature following Family Finance architecture.

## Feature: $ARGUMENTS

## Implementation Process

### Phase 1: Plan (think harder)

Before writing any code:
1. Identify which layers need changes (Model, Service, View)
2. Determine if new SwiftData models are needed
3. Check if existing services can be extended
4. Consider performance implications

### Phase 2: Data Layer

If new models needed:
1. Add to `Models/SwiftDataModels.swift`
2. Register in `FamilyFinanceApp.swift` Schema
3. Add relationships with proper delete rules
4. Create indexes for query fields

If modifying existing models:
1. Consider migration implications
2. Use `syncDenormalizedFields()` pattern if adding computed-like fields

### Phase 3: Service Layer

Choose the right pattern:
- **Query-only**: Extend `TransactionQueryService`
- **Import/processing**: Extend `BackgroundDataHandler`
- **Categorization**: Extend `CategorizationEngine`
- **New domain**: Create new service in `Services/`

Service template:
```swift
@MainActor
class NewService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func doThing() async throws -> Result {
        // Implementation
    }
}
```

### Phase 4: View Layer

1. Create view in `Views/`
2. Add wrapper in `FamilyFinanceApp.swift` if service needed
3. Add to navigation (AppTab, SidebarView, ContentView)
4. Follow existing UI patterns (cards, lists, headers)

### Phase 5: Testing

1. Write tests FIRST (TDD) in `Tests/`
2. Cover happy path and edge cases
3. Test Dutch number/encoding handling if applicable

### Phase 6: Documentation

1. Update CLAUDE.md if architectural patterns change
2. Add code comments for complex logic
3. Update README.md for user-facing features

## Common Feature Patterns

**Add a new report/aggregation:**
→ TransactionQueryService + new View

**Add user preference:**
→ @AppStorage or new Setting model + SettingsView

**Add export format:**
→ ExportService extension + menu command

**Add validation rule:**
→ DataIntegrityService extension
