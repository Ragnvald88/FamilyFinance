---
description: Add a new categorization rule for Dutch banking patterns
argument-hint: "pattern" "Category Name"
---

# Add Categorization Rule

Add a new pattern-based categorization rule to `CategorizationEngine.swift`.

## Pattern Details: $ARGUMENTS

## Instructions

1. Read `Services/CategorizationEngine.swift` to understand existing rules structure
2. Determine the appropriate:
   - **Pattern**: Lowercase search string (e.g., "albert heijn", "thuisbezorgd")
   - **Match Type**: `.contains` (most common), `.startsWith`, `.regex`
   - **Standardized Name**: Clean display name (e.g., "Albert Heijn")
   - **Target Category**: One of the existing categories in the app
   - **Priority**: Lower number = higher precedence (use 50-200 range)

3. Add the rule to the `hardcodedRules` array in alphabetical order within its category section

4. If this is a Dutch merchant, consider common variations:
   - With/without spaces: "albertheijn" vs "albert heijn"
   - Abbreviations: "ah" for Albert Heijn
   - Location suffixes: "albert heijn xl", "ah to go"

5. Test the rule matches expected transactions

## Example Rule Format

```swift
("thuisbezorgd", .contains, "Thuisbezorgd.nl", "Uit Eten", 100),
```

## Common Categories

- **Boodschappen**: Groceries (AH, Jumbo, Lidl)
- **Uit Eten**: Restaurants, food delivery
- **Vervoer**: Transport (NS, Shell, BP)
- **Abonnementen**: Subscriptions (Netflix, Spotify)
- **Nutsvoorzieningen**: Utilities (Ziggo, KPN, Eneco)
