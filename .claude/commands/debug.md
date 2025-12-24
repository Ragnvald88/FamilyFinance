# 🐛 Debug & Fix Issue

You are debugging an issue in FamilyFinance. Read @CLAUDE.md first.

## Issue Description

$ARGUMENTS

## Debugging Process

### Step 1: Reproduce
Before fixing, I need to understand the issue:
- What file(s) are likely involved?
- What's the expected vs actual behavior?
- Can I find related code with grep?

### Step 2: Diagnose
Search the codebase for related code:
```bash
# Find related files
grep -rn "SEARCH_TERM" --include="*.swift" .
```

### Step 3: Root Cause
Identify the actual problem, not just symptoms:
- Is this a SwiftData threading issue? (Check @ModelActor usage)
- Is this a UI state issue? (Check @State/@Published)
- Is this a data race? (Check Sendable compliance)

### Step 4: Fix
Apply minimal, surgical fix:
- Don't refactor unrelated code
- Add comments explaining WHY, not WHAT
- Consider edge cases

### Step 5: Verify
After fixing:
```bash
xcodebuild build -scheme FamilyFinance -destination 'platform=macOS' 2>&1 | tail -10
```

### Step 6: Prevent
If this bug could happen elsewhere:
- Should we add a test?
- Should we update CLAUDE.md with a new "Don't"?
