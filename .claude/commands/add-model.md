---
description: Add a new SwiftData @Model class with proper patterns
argument-hint: ModelName
---

# Add SwiftData Model

Create a new `@Model` class following Family Finance patterns.

## Model Name: $ARGUMENTS

## Instructions

1. Read `Models/SwiftDataModels.swift` to understand existing patterns:
   - `@Attribute(.indexed)` for frequently queried fields
   - `@Attribute(.unique)` for natural keys
   - `@Relationship` with proper delete rules
   - All enums must conform to `Sendable`

2. Add the new model class to `SwiftDataModels.swift`:
   ```swift
   @Model
   final class $ARGUMENTS {
       // Indexed fields for query performance
       @Attribute(.indexed) var primaryField: String
       
       // Relationships
       @Relationship(deleteRule: .cascade)
       var relatedItems: [RelatedModel]?
       
       // Computed properties (not stored)
       var computed: String { ... }
       
       init(...) {
           // Initialize all stored properties
       }
   }
   ```

3. Register in `FamilyFinanceApp.swift` → `Schema([...])`:
   ```swift
   let schema = Schema([
       Transaction.self,
       // ... existing models
       $ARGUMENTS.self,  // Add here
   ])
   ```

4. If model has relationships to Transaction or Account:
   - Add inverse relationship on the other side
   - Consider delete rules carefully (cascade vs nullify)

5. Create unit tests in `Tests/TransactionModelTests.swift`

## SwiftData Gotchas

- Computed properties cannot use `@Attribute`
- `Date` fields that need querying should have denormalized year/month
- Always use `private(set)` for fields that need sync methods
- New enums MUST be `Sendable` for Swift 6 concurrency
