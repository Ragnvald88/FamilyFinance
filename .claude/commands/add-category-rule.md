---
description: Add a new categorization rule for banking patterns (LEGACY SYSTEM)
argument-hint: "pattern" "Category Name"
---

# Add Categorization Rule (Legacy System)

**⚠️ NOTE**: This adds rules to the legacy `CategorizationEngine.swift` system. For new Firefly III-inspired rules, use the Rules tab in the app interface.

Add a new pattern-based categorization rule to `CategorizationEngine.swift`.

## Pattern Details: $ARGUMENTS

## Instructions

1. Read `Services/CategorizationEngine.swift` to understand existing rules structure
2. Determine the appropriate:
   - **Pattern**: Lowercase search string (e.g., "amazon", "starbucks", "netflix")
   - **Match Type**: `.contains` (most common), `.startsWith`, `.regex`
   - **Standardized Name**: Clean display name (e.g., "Amazon", "Starbucks")
   - **Target Category**: One of the existing categories in the app
   - **Priority**: Lower number = higher precedence (use 50-200 range)

3. Add the rule to the `hardcodedRules` array in alphabetical order within its category section

4. Consider common variations for merchants:
   - With/without spaces: "walmart" vs "wal mart"
   - Abbreviations and variations: "mcd" for McDonald's, "amzn" for Amazon
   - Location suffixes: "starbucks store #1234", "walmart supercenter"
   - Payment processors: "sq *merchant name", "paypal *merchant"

5. Test the rule matches expected transactions

## Example Rule Format

```swift
("amazon", .contains, "Amazon", "Shopping", 100),
("netflix", .contains, "Netflix", "Subscriptions", 50),
("shell", .contains, "Shell", "Transportation", 75),
```

## Common Universal Categories

- **Groceries**: Supermarkets, food stores
- **Dining**: Restaurants, food delivery, coffee shops
- **Transportation**: Gas stations, public transit, ride sharing
- **Subscriptions**: Streaming services, software, memberships
- **Shopping**: Retail stores, online purchases
- **Utilities**: Electric, gas, water, internet, phone
- **Healthcare**: Medical, dental, pharmacy
- **Entertainment**: Movies, games, events
- **Banking**: Bank fees, transfers, ATM
- **Insurance**: Health, auto, home insurance
