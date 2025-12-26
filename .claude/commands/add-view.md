---
description: Add a new SwiftUI view following Family Finance patterns
argument-hint: ViewName (e.g., TransactionDetailView)
---

# Add SwiftUI View

Create a new SwiftUI view following Family Finance UI patterns.

## View Name: $ARGUMENTS

## Instructions

1. Examine existing views for patterns:
   - `Views/DashboardView.swift` - Complex view with service injection
   - `FamilyFinanceApp.swift` - Contains list views (TransactionsListView, etc.)

2. Create the view file in `Views/`:
   ```swift
   import SwiftUI
   import SwiftData

   struct $ARGUMENTS: View {
       @Environment(\.modelContext) private var modelContext
       
       // For data queries
       @Query(sort: \Transaction.date, order: .reverse) 
       private var transactions: [Transaction]
       
       // State
       @State private var searchText = ""
       
       var body: some View {
           // Content
       }
   }
   ```

3. If view needs services (not just @Query):
   - Create a wrapper in `FamilyFinanceApp.swift`:
   ```swift
   struct $ARGUMENTSWrapper: View {
       @Environment(\.modelContext) private var modelContext
       
       var body: some View {
           let service = SomeService(modelContext: modelContext)
           $ARGUMENTS(service: service)
       }
   }
   ```

4. Add to navigation in `ContentView.detailView`:
   ```swift
   case .newTab:
       $ARGUMENTSWrapper()
   ```

5. Add tab to `AppTab` enum and `SidebarView`

## UI Patterns Used

- `NavigationSplitView` for sidebar navigation
- `Color(nsColor: .controlBackgroundColor)` for cards
- `LazyVStack` for large lists
- `ContentUnavailableView` for empty states
- System locale: `Locale.current` (adapts to user's locale)

## Color Helpers

```swift
// Hex color extension is available
Color(hex: "3B82F6")  // Blue
Color(hex: "10B981")  // Green
Color(hex: "EF4444")  // Red
```
