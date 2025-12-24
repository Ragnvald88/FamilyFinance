# 🎨 Build a New SwiftUI View

You are a SwiftUI expert creating a new view for FamilyFinance. Read @CLAUDE.md first for architecture rules.

## Task

Create `Views/$ARGUMENTS.swift` following these requirements:

### Structure Template

```swift
//
//  $ARGUMENTS.swift
//  Family Finance
//
//  [Description of what this view does]
//
//  Created: [Today's Date]
//

import SwiftUI
import SwiftData

// MARK: - View

struct $ARGUMENTS: View {
    
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State
    @State private var // ... 
    
    // MARK: - Body
    var body: some View {
        // Implementation
    }
}

// MARK: - Subviews

private extension $ARGUMENTS {
    // Extract complex parts here
}

// MARK: - Preview

#Preview {
    $ARGUMENTS()
}
```

### Checklist Before Completion

- [ ] Uses semantic colors from the existing views
- [ ] Has loading state with ProgressView
- [ ] Has error handling with .alert
- [ ] Keyboard navigation works
- [ ] VoiceOver labels present
- [ ] Animations use .spring(response: 0.3, dampingFraction: 0.8)
- [ ] No force unwraps
- [ ] Preview compiles and shows realistic data

### Style Guidelines

Match the existing DashboardView aesthetic:
- Cards with `RoundedRectangle(cornerRadius: 12)` and subtle shadow
- Section headers in `.headline` weight
- Consistent padding: 24pt outer, 16pt inner
- Color accents: use `.blue` for income, `.red.opacity(0.8)` for expenses
