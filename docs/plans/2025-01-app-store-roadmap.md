# FamilyFinance App Store Publication Roadmap

## Overview

Phased plan to transform FamilyFinance into Florijn and publish to the Mac App Store.

**Current State:** Functional macOS app for Dutch banking (FamilyFinance brand)
**Phase 0:** Complete transformation to Florijn branding
**Target:** Published "Florijn" app on Mac App Store

---

## Phase 0: Brand Transformation (Must Have First)

Complete transformation from FamilyFinance to Florijn branding.

**See:** `2025-01-florijn-transformation-plan.md` for complete implementation details.

### 0.1 Project Transformation
- [ ] Rename Xcode project: FamilyFinance.xcodeproj → Florijn.xcodeproj
- [ ] Update bundle identifier: `com.familyfinance.app` → `com.florijn.app`
- [ ] Rename main app file: FamilyFinanceApp.swift → FlorijnApp.swift
- [ ] Update all source code references and navigation titles

### 0.2 Documentation Rebrand
- [ ] Update all .md files to reference Florijn
- [ ] Update Claude commands and configurations
- [ ] Rewrite marketing descriptions

### 0.3 Asset Creation
- [ ] Design and implement Florijn app icon
- [ ] Implement Florijn design system
- [ ] Create new screenshots for App Store

**Timeline:** 4 hours for complete transformation
**Result:** Professional "Florijn" app ready for App Store preparation

---

## Phase 1: App Store Requirements (Must Have)

These items are **required** for App Store submission.

### 1.1 Apple Developer Program

- [ ] Enroll in Apple Developer Program ($99/year)
- [ ] Set up App Store Connect
- [ ] Create App ID for FamilyFinance

### 1.2 App Sandbox

macOS App Store apps **must** be sandboxed.

**Create entitlements file:** `FamilyFinance.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

**Entitlements needed:**
- `app-sandbox` - Required for App Store
- `files.user-selected.read-write` - For CSV import/export via file picker

**NOT needed:**
- Network access (app is offline-only)
- Keychain (no credentials stored)
- Location (not used)

### 1.3 Privacy Manifest

Required since Xcode 15 / macOS 14.

**Create:** `PrivacyInfo.xcprivacy`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

**Why FileTimestamp:** Used by SwiftData/file operations.

### 1.4 App Icon

Required sizes for macOS:
- 1024x1024 (App Store)
- 512x512 @2x
- 256x256 @2x
- 128x128 @2x
- 64x64 @2x
- 32x32 @2x
- 16x16 @2x

**Options:**
1. Design custom icon (finance/chart theme)
2. Use SF Symbols as base + customize
3. Commission from designer (~$50-150)

### 1.5 Code Signing

- [ ] Create Distribution certificate in Apple Developer portal
- [ ] Create Mac App Store provisioning profile
- [ ] Configure Xcode signing settings:
  - Team: Your Developer Team
  - Signing: Automatic
  - Provisioning: App Store

### 1.6 App Store Metadata

Required for submission:

| Field | Content |
|-------|---------|
| App Name | Florijn |
| Subtitle | Personal Finance for Dutch Banking |
| Category | Finance |
| Price | Free (or €X.XX) |
| Description | 4000 chars max, Dutch + English |
| Keywords | florijn, finance, banking, rabobank, personal, dutch |
| Screenshots | 3-10 screenshots per size (Florijn-branded) |
| Support URL | Required (florijn.app or GitHub) |
| Privacy Policy URL | Required |

### 1.7 Screenshots

Required sizes for Mac App Store:
- 2880 x 1800 (16" MacBook Pro)
- 2560 x 1600 (13" MacBook)

**Suggested screenshots:**
1. Dashboard with KPIs and charts
2. Transaction list with search
3. CSV import flow
4. Rules editor
5. Category management

---

## Phase 2: Quality & Polish (Recommended)

Reduces rejection risk and improves user reviews.

### 2.1 First-Run Experience

Currently: App opens to empty dashboard.

**Needed:**
- Welcome screen explaining the app
- Guide to import first CSV
- Sample data option for exploration

### 2.2 Empty States

Currently: Some views show blank when no data.

**Needed:**
- Dashboard: "Import your first bank statement to get started"
- Transactions: "No transactions yet"
- Rules: "Create rules to auto-categorize" (already done)

### 2.3 Accessibility Audit

- [ ] Test with VoiceOver enabled
- [ ] Verify all buttons have labels
- [ ] Check color contrast ratios
- [ ] Test keyboard navigation

### 2.4 Error Handling Polish

- [ ] User-friendly error messages (not technical)
- [ ] Recovery suggestions
- [ ] No crashes on malformed input

### 2.5 Help & Documentation

- [ ] Brief in-app help (tooltip or popover)
- [ ] Link to support/FAQ page

---

## Phase 3: Multi-Bank Support (Optional)

Expands market but NOT required for initial release.

### 3.1 Strategy Decision

**Option A: Header-Based Auto-Detection (Recommended)**

Parse CSV header row to detect columns dynamically:

```swift
// Known header names across Dutch banks
let headerMappings: [String: ColumnType] = [
    // IBAN variants
    "iban/bban": .iban, "iban": .iban, "rekening": .iban,
    // Date variants
    "datum": .date, "boekdatum": .date, "date": .date,
    // Amount variants
    "bedrag": .amount, "af bij": .amount, "amount": .amount,
    // etc.
]
```

**Pros:**
- Works with unknown banks if headers match
- No per-bank code needed
- Self-healing if bank changes column order

**Cons:**
- Needs header name research per bank
- May fail on unusual formats

**Option B: Per-Bank Parsers**

Protocol-based approach with specific parser per bank.

**Pros:**
- Full control over quirks
- Can handle non-CSV formats (MT940, CAMT.053)

**Cons:**
- More code to maintain
- Need sample files from each bank

### 3.2 Dutch Banks to Consider

| Bank | Market Share | CSV Available | Priority |
|------|--------------|---------------|----------|
| ING | ~25% | Yes | High |
| Rabobank | ~20% | ✅ Done | - |
| ABN AMRO | ~15% | Yes | High |
| SNS/Volksbank | ~5% | Yes | Medium |
| Bunq | ~3% | Yes | Medium |
| ASN | ~2% | Yes | Low |
| Triodos | ~1% | Yes | Low |

### 3.3 Implementation Plan

1. **Get sample CSVs** from ING and ABN AMRO (redacted)
2. **Analyze formats** - column names, encoding, date formats
3. **Build header mapping** for auto-detection
4. **Test** with real exports
5. **UI** - show detected bank or let user confirm

---

## Phase 4: Future Enhancements (Post-Launch)

Ideas for updates after initial release:

- [ ] iCloud sync between Macs
- [ ] iOS companion app (view-only)
- [ ] Bank connection via PSD2 APIs (complex, regulated)
- [ ] Receipt photo attachment
- [ ] Recurring transaction predictions
- [ ] Budget alerts/notifications
- [ ] Export to accounting software
- [ ] Multi-currency support

---

## Timeline Estimate

| Phase | Effort | Dependencies |
|-------|--------|--------------|
| Phase 0 (Brand Transform) | 4 hours | Design system + app icon |
| Phase 1 (Required) | 1-2 sessions | Developer account |
| Phase 2 (Polish) | 2-3 sessions | None |
| Phase 3 (Multi-bank) | When needed | Sample CSVs from other banks |
| App Review | 1-7 days | Apple |

**Minimum to submit:** Phase 0 + 1 (~1 day focused work)

**Recommended before submit:** Phase 0 + 1 + 2 (~2-3 sessions)

---

## Immediate Next Steps

### Priority 1: Brand Transformation
1. [ ] **Execute Florijn transformation** (see transformation plan)
2. [ ] **Verify app builds and runs** as Florijn
3. [ ] **Implement Florijn design system** (colors, typography)
4. [ ] **Create Florijn app icon** (gold coin design)

### Priority 2: App Store Preparation
5. [ ] Enroll in Apple Developer Program
6. [ ] Create App Sandbox entitlements file
7. [ ] Create Privacy Manifest
8. [ ] Take new screenshots of Florijn-branded app
9. [ ] Write App Store description (Florijn focus)
10. [ ] Create privacy policy page (florijn.app)
11. [ ] Test full app flow in sandboxed mode
12. [ ] Submit to App Store Connect

---

## Decision Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Multi-bank for v1.0? | No | Ship Rabobank first, add banks in updates |
| Localization for v1.0? | Dutch only | Target market is Dutch, data is Dutch |
| Price model | Free or one-time | No recurring costs to justify subscription |
| iCloud sync | Post-launch | Adds complexity, not core value |
