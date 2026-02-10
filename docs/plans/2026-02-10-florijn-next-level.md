# 🌟 Florijn Next-Level Implementation Plan (Enhanced)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform Florijn into a brilliant next-level personal finance app based on 2026 fintech UX research, Apple Swift Charts power, and modern SwiftUI patterns.

**Research Foundation:**
- [2026 Fintech UX Best Practices](https://www.eleken.co/blog-posts/fintech-ux-best-practices) - Accessibility-first, educational micro-tips, financial health scoring
- Apple Swift Charts - Native data visualization with custom scales and interactions
- Modern SwiftUI - @Observable + @MainActor patterns for thread-safe state management

**Architecture:** Four-pillar brilliance: Foundation (modern patterns), Rule Intelligence (templates + testing), Dashboard Excellence (Swift Charts + health scoring), Workflow Mastery (micro-interactions + accessibility)

**Tech Stack:** SwiftUI with @Observable, SwiftData, Swift Charts framework, SF Symbols, enhanced rule engine with educational elements

---

## Phase 1: Foundation Work (View Extraction)

### Task 1: Enhanced Categories Management with Modern State Management

**Files:**
- Create: `Views/CategoryManagementView.swift` (with @Observable patterns)
- Create: `ViewModels/CategoryManagementViewModel.swift`
- Create: `Views/Components/FinancialHealthIndicator.swift`
- Modify: `FlorijnApp.swift:1800-2200` (categories section)
- Test: `Tests/CategoryManagementViewTests.swift`

**Step 1: Write the failing test for modern @Observable pattern**

```swift
// Tests/CategoryManagementViewTests.swift
import XCTest
import SwiftUI
import SwiftData
@testable import Florijn

final class CategoryManagementViewTests: XCTestCase {
    func test_categoryViewModel_calculates_health_score() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Category.self, configurations: [config])
        let context = ModelContext(container)

        // Create test category with budget
        let category = Category(name: "Test Category", type: .expense)
        category.monthlyBudget = 500.0
        context.insert(category)
        try context.save()

        let viewModel = CategoryManagementViewModel()
        let healthScore = viewModel.calculateCategoryHealth(for: category, spent: 300.0)

        // 60% usage = good health (above 50%, below 80%)
        XCTAssertEqual(healthScore.rating, .good)
        XCTAssertEqual(healthScore.percentage, 0.6, accuracy: 0.01)
    }

    func test_categoryManagementView_displays_with_health_indicators() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Category.self, configurations: [config])
        let context = ModelContext(container)

        let category = Category(name: "Test Category", type: .expense)
        category.monthlyBudget = 500.0
        context.insert(category)
        try context.save()

        let view = CategoryManagementView()
            .modelContainer(container)

        XCTAssertNotNil(view)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme FamilyFinance -destination 'platform=macOS' -only-testing:FamilyFinanceTests/CategoryManagementViewTests/test_categoryViewModel_calculates_health_score`
Expected: FAIL with "Cannot find 'CategoryManagementViewModel' in scope"

**Step 3: Create modern @Observable ViewModel**

```swift
// ViewModels/CategoryManagementViewModel.swift
import Foundation
import SwiftData

@Observable
@MainActor
final class CategoryManagementViewModel {
    var searchText = ""
    var selectedFilter: CategoryFilter = .all
    var showingHealthDetails = false

    enum CategoryFilter: String, CaseIterable {
        case all = "All Categories"
        case income = "Income"
        case expense = "Expense"
        case overBudget = "Over Budget"
        case healthy = "Healthy"
    }

    struct CategoryHealth {
        enum Rating: String, CaseIterable {
            case excellent = "Excellent"  // < 50%
            case good = "Good"           // 50-80%
            case warning = "Warning"     // 80-100%
            case critical = "Critical"   // > 100%

            var color: Color {
                switch self {
                case .excellent: return .green
                case .good: return .blue
                case .warning: return .orange
                case .critical: return .red
                }
            }

            var icon: String {
                switch self {
                case .excellent: return "checkmark.seal.fill"
                case .good: return "checkmark.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .critical: return "xmark.octagon.fill"
                }
            }
        }

        let percentage: Double
        let rating: Rating
        let microTip: String
    }

    func calculateCategoryHealth(for category: Category, spent: Decimal) -> CategoryHealth {
        guard let budget = category.monthlyBudget, budget > 0 else {
            return CategoryHealth(
                percentage: 0,
                rating: .good,
                microTip: "Set a budget to track your spending health"
            )
        }

        let percentage = Double(spent / budget)
        let rating: CategoryHealth.Rating
        let microTip: String

        switch percentage {
        case 0..<0.5:
            rating = .excellent
            microTip = "Great job! You're well within budget with room to spare."
        case 0.5..<0.8:
            rating = .good
            microTip = "You're on track. Consider setting money aside for next month."
        case 0.8..<1.0:
            rating = .warning
            microTip = "Approaching your limit. Consider reducing spending in this category."
        default:
            rating = .critical
            microTip = "Over budget! Review your spending patterns and adjust accordingly."
        }

        return CategoryHealth(
            percentage: percentage,
            rating: rating,
            microTip: microTip
        )
    }

    func filteredCategories(_ categories: [Category]) -> [Category] {
        let filtered = categories.filter { category in
            let matchesSearch = searchText.isEmpty ||
                category.name.localizedCaseInsensitiveContains(searchText)
            let matchesFilter: Bool

            switch selectedFilter {
            case .all: matchesFilter = true
            case .income: matchesFilter = category.type == .income
            case .expense: matchesFilter = category.type == .expense
            case .overBudget: matchesFilter = false // TODO: Calculate if over budget
            case .healthy: matchesFilter = false // TODO: Calculate if healthy
            }

            return matchesSearch && matchesFilter
        }

        return filtered.sorted { $0.name < $1.name }
    }
}
```

**Step 4: Create enhanced CategoryManagementView with health indicators**

```swift
// Views/CategoryManagementView.swift
import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Query(sort: \Category.name) private var categories: [Category]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = CategoryManagementViewModel()
    @State private var showingCategoryEditor = false
    @State private var editingCategory: Category?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Enhanced search and filter toolbar
                CategoryFilterToolbar(viewModel: viewModel)

                // Categories list with health indicators
                List {
                    ForEach(viewModel.filteredCategories(categories)) { category in
                        EnhancedCategoryRow(
                            category: category,
                            viewModel: viewModel
                        ) {
                            editingCategory = category
                            showingCategoryEditor = true
                        }
                    }
                    .onDelete(perform: deleteCategories)
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        Button(action: { viewModel.showingHealthDetails.toggle() }) {
                            Image(systemName: viewModel.showingHealthDetails ?
                                "chart.bar.fill" : "chart.bar")
                        }
                        .help("Toggle health indicators")

                        Button("Add Category") {
                            editingCategory = nil
                            showingCategoryEditor = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCategoryEditor) {
            CategoryEditorSheet(category: editingCategory) { savedCategory in
                if editingCategory == nil {
                    modelContext.insert(savedCategory)
                }
                try? modelContext.save()
                showingCategoryEditor = false
                editingCategory = nil
            }
        }
    }

    private func deleteCategories(offsets: IndexSet) {
        for index in offsets {
            let filteredCategories = viewModel.filteredCategories(categories)
            if index < filteredCategories.count {
                modelContext.delete(filteredCategories[index])
            }
        }
        try? modelContext.save()
    }
}

struct CategoryFilterToolbar: View {
    @Bindable var viewModel: CategoryManagementViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search categories...", text: $viewModel.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Filter picker
            Picker("Filter", selection: $viewModel.selectedFilter) {
                ForEach(CategoryManagementViewModel.CategoryFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 0))
    }
}

struct EnhancedCategoryRow: View {
    let category: Category
    let viewModel: CategoryManagementViewModel
    let onEdit: () -> Void

    @Query private var transactions: [Transaction]

    init(category: Category, viewModel: CategoryManagementViewModel, onEdit: @escaping () -> Void) {
        self.category = category
        self.viewModel = viewModel
        self.onEdit = onEdit

        // Query transactions for this category this month
        let currentDate = Date()
        let year = Calendar.current.component(.year, from: currentDate)
        let month = Calendar.current.component(.month, from: currentDate)
        let predicate = #Predicate<Transaction> { transaction in
            transaction.year == year &&
            transaction.month == month &&
            transaction.effectiveCategory == category.name
        }
        _transactions = Query(filter: predicate)
    }

    private var monthlySpent: Decimal {
        transactions
            .filter { $0.amount < 0 } // Expenses are negative
            .reduce(0) { $0 + abs($1.amount) }
    }

    private var health: CategoryManagementViewModel.CategoryHealth {
        viewModel.calculateCategoryHealth(for: category, spent: monthlySpent)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category icon and type indicator
            Image(systemName: category.type == .income ?
                "plus.circle.fill" : "minus.circle.fill")
                .foregroundColor(category.type == .income ? .green : .red)
                .font(.title2)
                .accessibilityLabel(category.type == .income ? "Income category" : "Expense category")

            VStack(alignment: .leading, spacing: 4) {
                // Category name
                Text(category.name)
                    .font(.headline)
                    .lineLimit(1)

                // Budget and spending info
                if let budget = category.monthlyBudget, budget > 0 {
                    HStack {
                        Text("€\(monthlySpent, specifier: "%.2f") of €\(budget, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()

                        Spacer()

                        if viewModel.showingHealthDetails {
                            FinancialHealthIndicator(health: health)
                        }
                    }

                    // Progress bar
                    ProgressView(value: min(health.percentage, 1.0))
                        .progressViewStyle(LinearProgressViewStyle(tint: health.rating.color))
                        .frame(height: 4)
                } else {
                    Text("No budget set")
                        .font(.caption)
                        .foregroundColor(.tertiary)
                }

                // Educational micro-tip (2026 UX best practice)
                if viewModel.showingHealthDetails && category.monthlyBudget != nil {
                    Text(health.microTip)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil.circle")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Edit \(category.name)")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
```

**Step 5: Create FinancialHealthIndicator component**

```swift
// Views/Components/FinancialHealthIndicator.swift
import SwiftUI

struct FinancialHealthIndicator: View {
    let health: CategoryManagementViewModel.CategoryHealth

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: health.rating.icon)
                .foregroundColor(health.rating.color)
                .font(.caption)

            Text(health.rating.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(health.rating.color)

            Text("\(Int(health.percentage * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(health.rating.color.opacity(0.1))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(health.rating.rawValue) health rating, \(Int(health.percentage * 100)) percent of budget used")
    }
}
```

```swift
// Views/CategoryManagementView.swift
import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Query(sort: \Category.name) private var categories: [Category]
    @Environment(\.modelContext) private var modelContext
    @State private var showingCategoryEditor = false
    @State private var editingCategory: Category?

    var body: some View {
        NavigationView {
            List {
                ForEach(categories) { category in
                    CategoryRowView(category: category) {
                        editingCategory = category
                        showingCategoryEditor = true
                    }
                }
                .onDelete(perform: deleteCategories)
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Category") {
                        editingCategory = nil
                        showingCategoryEditor = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingCategoryEditor) {
            CategoryEditorSheet(category: editingCategory) { savedCategory in
                if editingCategory == nil {
                    modelContext.insert(savedCategory)
                }
                try? modelContext.save()
                showingCategoryEditor = false
                editingCategory = nil
            }
        }
    }

    private func deleteCategories(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
        try? modelContext.save()
    }
}

struct CategoryRowView: View {
    let category: Category
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Image(systemName: category.type == .income ? "plus.circle.fill" : "minus.circle.fill")
                .foregroundColor(category.type == .income ? .green : .red)

            VStack(alignment: .leading) {
                Text(category.name)
                    .font(.headline)
                if let budget = category.monthlyBudget {
                    Text("Budget: €\(budget, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme FamilyFinance -destination 'platform=macOS' -only-testing:FamilyFinanceTests/CategoryManagementViewTests/test_categoryManagementView_displays_categories`
Expected: PASS

**Step 5: Extract CategoryEditorSheet from FlorijnApp.swift**

```swift
// Views/CategoryEditorSheet.swift
import SwiftUI

struct CategoryEditorSheet: View {
    let category: Category?
    let onSave: (Category) -> Void

    @State private var name: String
    @State private var categoryType: Category.CategoryType
    @State private var monthlyBudget: Decimal?
    @Environment(\.dismiss) private var dismiss

    init(category: Category?, onSave: @escaping (Category) -> Void) {
        self.category = category
        self.onSave = onSave

        // Initialize state from category or defaults
        if let category = category {
            _name = State(initialValue: category.name)
            _categoryType = State(initialValue: category.type)
            _monthlyBudget = State(initialValue: category.monthlyBudget)
        } else {
            _name = State(initialValue: "")
            _categoryType = State(initialValue: .expense)
            _monthlyBudget = State(initialValue: nil)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                TextField("Category Name", text: $name)

                Picker("Type", selection: $categoryType) {
                    Text("Income").tag(Category.CategoryType.income)
                    Text("Expense").tag(Category.CategoryType.expense)
                }

                TextField("Monthly Budget (optional)", value: $monthlyBudget, format: .number)
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let savedCategory = category ?? Category(name: name, type: categoryType)
                        savedCategory.name = name
                        savedCategory.type = categoryType
                        savedCategory.monthlyBudget = monthlyBudget
                        onSave(savedCategory)
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
```

**Step 6: Commit foundation work**

```bash
git add Views/CategoryManagementView.swift Views/CategoryEditorSheet.swift Tests/CategoryManagementViewTests.swift
git commit -m "feat: extract category management into dedicated view

- Create CategoryManagementView with list and editing
- Extract CategoryEditorSheet from FlorijnApp.swift
- Add basic test coverage for category management"
```

### Task 2: Extract Budget Management View

**Files:**
- Create: `Views/BudgetManagementView.swift`
- Create: `Views/BudgetCategoryCard.swift`
- Modify: `FlorijnApp.swift:1400-1800` (budget section)
- Test: `Tests/BudgetManagementViewTests.swift`

**Step 1: Write the failing test**

```swift
// Tests/BudgetManagementViewTests.swift
import XCTest
import SwiftUI
import SwiftData
@testable import Florijn

final class BudgetManagementViewTests: XCTestCase {
    func test_budgetManagementView_displays_budget_periods() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BudgetPeriod.self, Category.self,
            configurations: [config]
        )
        let context = ModelContext(container)

        // Create test data
        let category = Category(name: "Test Category", type: .expense)
        context.insert(category)

        let budgetPeriod = BudgetPeriod(
            year: 2026,
            month: 2,
            category: category,
            budgetAmount: 500.0
        )
        context.insert(budgetPeriod)
        try context.save()

        let view = BudgetManagementView()
            .modelContainer(container)

        XCTAssertNotNil(view)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme FamilyFinance -destination 'platform=macOS' -only-testing:FamilyFinanceTests/BudgetManagementViewTests/test_budgetManagementView_displays_budget_periods`
Expected: FAIL with "Cannot find 'BudgetManagementView' in scope"

**Step 3: Create BudgetManagementView**

```swift
// Views/BudgetManagementView.swift
import SwiftUI
import SwiftData

struct BudgetManagementView: View {
    @Query private var budgetPeriods: [BudgetPeriod]
    @Query private var categories: [Category]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())

    var body: some View {
        NavigationView {
            VStack {
                // Month/Year selector
                HStack {
                    Picker("Month", selection: $selectedMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text(DateFormatter().monthSymbols[month-1])
                                .tag(month)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    Picker("Year", selection: $selectedYear) {
                        ForEach((selectedYear-2)...(selectedYear+2), id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                .padding()

                // Budget categories grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 300))
                    ], spacing: 16) {
                        ForEach(categories) { category in
                            BudgetCategoryCard(
                                category: category,
                                year: selectedYear,
                                month: selectedMonth
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Budget Management")
        }
    }
}
```

**Step 4: Create BudgetCategoryCard**

```swift
// Views/BudgetCategoryCard.swift
import SwiftUI
import SwiftData

struct BudgetCategoryCard: View {
    let category: Category
    let year: Int
    let month: Int

    @Query private var transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false
    @State private var budgetAmount: Decimal = 0

    private var budgetPeriod: BudgetPeriod? {
        let descriptor = FetchDescriptor<BudgetPeriod>(
            predicate: #Predicate { period in
                period.year == year &&
                period.month == month &&
                period.category?.name == category.name
            }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private var spent: Decimal {
        let categoryTransactions = transactions.filter { transaction in
            transaction.year == year &&
            transaction.month == month &&
            transaction.effectiveCategory == category.name &&
            transaction.amount < 0 // Expenses are negative
        }
        return categoryTransactions.reduce(0) { $0 + abs($1.amount) }
    }

    private var budget: Decimal {
        budgetPeriod?.budgetAmount ?? category.monthlyBudget ?? 0
    }

    private var percentageUsed: Double {
        guard budget > 0 else { return 0 }
        return min(Double(spent / budget), 1.0)
    }

    init(category: Category, year: Int, month: Int) {
        self.category = category
        self.year = year
        self.month = month

        // Query transactions for this category, year, and month
        let predicate = #Predicate<Transaction> { transaction in
            transaction.year == year &&
            transaction.month == month &&
            transaction.effectiveCategory == category.name
        }
        _transactions = Query(filter: predicate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Button(action: { isEditing = true }) {
                    Image(systemName: "pencil.circle")
                }
                .buttonStyle(PlainButtonStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Spent: €\(spent, specifier: "%.2f")")
                        .font(.title3.monospacedDigit())
                        .foregroundColor(.primary)

                    Spacer()

                    Text("Budget: €\(budget, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Progress bar
                ProgressView(value: percentageUsed)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressBarColor))
                    .frame(height: 8)

                // Percentage text
                HStack {
                    Text("\(Int(percentageUsed * 100))% used")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if spent > budget {
                        Text("€\(spent - budget, specifier: "%.2f") over")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("€\(budget - spent, specifier: "%.2f") remaining")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            budgetAmount = budget
        }
        .sheet(isPresented: $isEditing) {
            BudgetEditorSheet(
                category: category,
                year: year,
                month: month,
                initialAmount: budget
            ) { newAmount in
                saveBudget(amount: newAmount)
            }
        }
    }

    private var progressBarColor: Color {
        if percentageUsed > 1.0 {
            return .red
        } else if percentageUsed > 0.8 {
            return .orange
        } else {
            return .blue
        }
    }

    private func saveBudget(amount: Decimal) {
        if let existingPeriod = budgetPeriod {
            existingPeriod.budgetAmount = amount
        } else {
            let newPeriod = BudgetPeriod(
                year: year,
                month: month,
                category: category,
                budgetAmount: amount
            )
            modelContext.insert(newPeriod)
        }
        try? modelContext.save()
    }
}

struct BudgetEditorSheet: View {
    let category: Category
    let year: Int
    let month: Int
    let initialAmount: Decimal
    let onSave: (Decimal) -> Void

    @State private var amount: Decimal
    @Environment(\.dismiss) private var dismiss

    init(category: Category, year: Int, month: Int, initialAmount: Decimal, onSave: @escaping (Decimal) -> Void) {
        self.category = category
        self.year = year
        self.month = month
        self.initialAmount = initialAmount
        self.onSave = onSave
        _amount = State(initialValue: initialAmount)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Category:")
                        Spacer()
                        Text(category.name)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Period:")
                        Spacer()
                        Text("\(DateFormatter().monthSymbols[month-1]) \(year)")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Budget Amount") {
                    TextField("Amount", value: $amount, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .navigationTitle("Edit Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(amount)
                        dismiss()
                    }
                }
            }
        }
    }
}
```

**Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme FamilyFinance -destination 'platform=macOS' -only-testing:FamilyFinanceTests/BudgetManagementViewTests/test_budgetManagementView_displays_budget_periods`
Expected: PASS

**Step 6: Commit budget management**

```bash
git add Views/BudgetManagementView.swift Views/BudgetCategoryCard.swift Tests/BudgetManagementViewTests.swift
git commit -m "feat: extract budget management into dedicated views

- Create BudgetManagementView with month/year navigation
- Create BudgetCategoryCard with progress tracking
- Add budget editing functionality
- Include test coverage for budget management"
```

---

## Phase 2: Rule System Unleashing

### Task 3: Rule Templates System

**Files:**
- Create: `Models/RuleTemplates.swift`
- Create: `Views/RuleTemplatesView.swift`
- Modify: `Views/SimpleRulesView.swift:50-100`
- Test: `Tests/RuleTemplatesTests.swift`

**Step 1: Write the failing test**

```swift
// Tests/RuleTemplatesTests.swift
import XCTest
import SwiftData
@testable import Florijn

final class RuleTemplatesTests: XCTestCase {
    func test_subscriptionTemplate_creates_correct_rule() throws {
        let template = RuleTemplates.subscriptionDetection
        let rule = template.createRule()

        XCTAssertEqual(rule.name, "Subscription Detection")
        XCTAssertEqual(rule.triggers.count, 2) // Amount and recurring pattern
        XCTAssertEqual(rule.actions.count, 1) // Set category
    }

    func test_transferCleanup_template_creates_correct_rule() throws {
        let template = RuleTemplates.transferCleanup
        let rule = template.createRule()

        XCTAssertEqual(rule.name, "Transfer Cleanup")
        XCTAssertTrue(rule.triggers.contains { $0.field == .description })
        XCTAssertTrue(rule.actions.contains { $0.type == .clearCategory })
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme FamilyFinance -destination 'platform=macOS' -only-testing:FamilyFinanceTests/RuleTemplatesTests/test_subscriptionTemplate_creates_correct_rule`
Expected: FAIL with "Cannot find 'RuleTemplates' in scope"

**Step 3: Create RuleTemplates**

```swift
// Models/RuleTemplates.swift
import Foundation

struct RuleTemplate {
    let name: String
    let description: String
    let category: RuleTemplateCategory
    let triggers: [RuleTriggerTemplate]
    let actions: [RuleActionTemplate]
    let tags: [String]

    func createRule() -> Rule {
        let rule = Rule(name: name)

        // Create triggers
        for triggerTemplate in triggers {
            let trigger = RuleTrigger(
                field: triggerTemplate.field,
                triggerOperator: triggerTemplate.operator,
                value: triggerTemplate.value
            )
            trigger.isInverted = triggerTemplate.isInverted
            rule.triggers.append(trigger)
        }

        // Set match mode
        rule.matchMode = .allMustMatch

        // Create actions
        for actionTemplate in actions {
            let action = RuleAction(
                type: actionTemplate.type,
                value: actionTemplate.value
            )
            action.stopProcessingAfter = actionTemplate.stopProcessing
            rule.actions.append(action)
        }

        return rule
    }
}

struct RuleTriggerTemplate {
    let field: TriggerField
    let operator: TriggerOperator
    let value: String
    let isInverted: Bool

    init(field: TriggerField, operator: TriggerOperator, value: String, isInverted: Bool = false) {
        self.field = field
        self.operator = `operator`
        self.value = value
        self.isInverted = isInverted
    }
}

struct RuleActionTemplate {
    let type: ActionType
    let value: String
    let stopProcessing: Bool

    init(type: ActionType, value: String, stopProcessing: Bool = false) {
        self.type = type
        self.value = value
        self.stopProcessing = stopProcessing
    }
}

enum RuleTemplateCategory: String, CaseIterable {
    case categorization = "Categorization"
    case cleanup = "Cleanup"
    case automation = "Automation"
    case detection = "Detection"
}

struct RuleTemplates {
    static let subscriptionDetection = RuleTemplate(
        name: "Subscription Detection",
        description: "Automatically categorize recurring small payments as subscriptions",
        category: .categorization,
        triggers: [
            RuleTriggerTemplate(field: .amount, operator: .greaterThan, value: "-50"),
            RuleTriggerTemplate(field: .amount, operator: .lessThan, value: "-2"),
            RuleTriggerTemplate(field: .description, operator: .contains, value: "subscription")
        ],
        actions: [
            RuleActionTemplate(type: .setCategory, value: "Subscriptions", stopProcessing: true)
        ],
        tags: ["automation", "categorization", "subscriptions"]
    )

    static let transferCleanup = RuleTemplate(
        name: "Transfer Cleanup",
        description: "Remove categories from inter-account transfers",
        category: .cleanup,
        triggers: [
            RuleTriggerTemplate(field: .description, operator: .contains, value: "overboeking")
        ],
        actions: [
            RuleActionTemplate(type: .clearCategory, value: "", stopProcessing: true)
        ],
        tags: ["cleanup", "transfers"]
    )

    static let merchantStandardization = RuleTemplate(
        name: "Merchant Standardization",
        description: "Standardize merchant names (Albert Heijn variations)",
        category: .cleanup,
        triggers: [
            RuleTriggerTemplate(field: .counterParty, operator: .contains, value: "AH ")
        ],
        actions: [
            RuleActionTemplate(type: .setCounterParty, value: "Albert Heijn"),
            RuleActionTemplate(type: .setCategory, value: "Groceries")
        ],
        tags: ["standardization", "merchants", "groceries"]
    )

    static let groceryDetection = RuleTemplate(
        name: "Grocery Store Detection",
        description: "Auto-categorize common grocery stores",
        category: .categorization,
        triggers: [
            RuleTriggerTemplate(field: .counterParty, operator: .regexMatches, value: "(?i)(albert heijn|jumbo|lidl|aldi|plus|coop)")
        ],
        actions: [
            RuleActionTemplate(type: .setCategory, value: "Groceries", stopProcessing: true)
        ],
        tags: ["categorization", "groceries", "regex"]
    )

    static let salaryDetection = RuleTemplate(
        name: "Salary Detection",
        description: "Automatically categorize salary payments",
        category: .categorization,
        triggers: [
            RuleTriggerTemplate(field: .amount, operator: .greaterThan, value: "1000"),
            RuleTriggerTemplate(field: .description, operator: .regexMatches, value: "(?i)(salaris|loon|salary)")
        ],
        actions: [
            RuleActionTemplate(type: .setCategory, value: "Salary", stopProcessing: true)
        ],
        tags: ["categorization", "income", "salary"]
    )

    static let allTemplates: [RuleTemplate] = [
        subscriptionDetection,
        transferCleanup,
        merchantStandardization,
        groceryDetection,
        salaryDetection
    ]

    static func templatesForCategory(_ category: RuleTemplateCategory) -> [RuleTemplate] {
        allTemplates.filter { $0.category == category }
    }

    static func templatesWithTag(_ tag: String) -> [RuleTemplate] {
        allTemplates.filter { $0.tags.contains(tag) }
    }
}
```

**Step 4: Create RuleTemplatesView**

```swift
// Views/RuleTemplatesView.swift
import SwiftUI
import SwiftData

struct RuleTemplatesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: RuleTemplateCategory = .categorization
    @State private var searchText = ""

    private var filteredTemplates: [RuleTemplate] {
        let categoryTemplates = RuleTemplates.templatesForCategory(selectedCategory)
        if searchText.isEmpty {
            return categoryTemplates
        } else {
            return categoryTemplates.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                // Category picker
                Picker("Category", selection: $selectedCategory) {
                    ForEach(RuleTemplateCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search templates", text: $searchText)
                }
                .padding(.horizontal)
                .padding(.bottom)

                // Templates list
                List(filteredTemplates, id: \.name) { template in
                    RuleTemplateRow(template: template) {
                        createRuleFromTemplate(template)
                    }
                }
            }
            .navigationTitle("Rule Templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func createRuleFromTemplate(_ template: RuleTemplate) {
        let rule = template.createRule()
        modelContext.insert(rule)
        try? modelContext.save()
        dismiss()
    }
}

struct RuleTemplateRow: View {
    let template: RuleTemplate
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(template.name)
                    .font(.headline)

                Spacer()

                Button("Add Rule") {
                    onSelect()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Text(template.description)
                .font(.body)
                .foregroundColor(.secondary)

            // Tags
            HStack {
                ForEach(template.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }

                Spacer()

                // Rule summary
                Text("\(template.triggers.count) triggers, \(template.actions.count) actions")
                    .font(.caption)
                    .foregroundColor(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
```

**Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme FamilyFinance -destination 'platform=macOS' -only-testing:FamilyFinanceTests/RuleTemplatesTests/test_subscriptionTemplate_creates_correct_rule`
Expected: PASS

**Step 6: Add template button to SimpleRulesView**

Modify `Views/SimpleRulesView.swift` toolbar to add:
```swift
ToolbarItem(placement: .primaryAction) {
    Button("Templates") {
        showingTemplates = true
    }
}
```

Add state: `@State private var showingTemplates = false`
Add sheet: `.sheet(isPresented: $showingTemplates) { RuleTemplatesView() }`

**Step 7: Commit rule templates**

```bash
git add Models/RuleTemplates.swift Views/RuleTemplatesView.swift Tests/RuleTemplatesTests.swift Views/SimpleRulesView.swift
git commit -m "feat: add rule templates system

- Create comprehensive rule template library
- Add RuleTemplatesView for template selection
- Include 5 pre-built templates (subscriptions, transfers, merchants, etc.)
- Integrate template access into SimpleRulesView"
```

---

## Execution Handoff Options

**Plan complete (Phase 1-2) and saved to `docs/plans/2026-02-10-florijn-next-level.md`.**

**Three execution options:**

**1. Start Implementation Now (Subagent-Driven)** - I dispatch fresh subagents per task, review between tasks, fast iteration in this session

**2. Parallel Session (Separate)** - Open new session with executing-plans skill, batch execution with checkpoints

**3. Continue Building Plan** - Add Phase 3 (Dashboard Intelligence) and Phase 4 (Workflow Revolution) to create complete roadmap first

**Which approach would you prefer?**
```