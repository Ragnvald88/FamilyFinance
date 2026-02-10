//
//  CategoryManagementViewTests.swift
//  Florijn Tests
//
//  Tests for category management with financial health scoring
//

import XCTest
@preconcurrency import SwiftData
@testable import FamilyFinance

@MainActor
final class CategoryManagementViewTests: XCTestCase {

    var modelContext: ModelContext!
    var modelContainer: ModelContainer!

    override func setUp() async throws {
        let schema = Schema([
            Transaction.self,
            Account.self,
            Category.self,
            RuleGroup.self,
            Rule.self,
            RuleTrigger.self,
            RuleAction.self,
            TriggerGroup.self
        ])

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContext = nil
        modelContainer = nil
    }

    // MARK: - Health Score Calculation Tests

    func testHealthScore_excellent_under50Percent() throws {
        let category = Category(name: "Groceries", type: .expense, monthlyBudget: 500)
        modelContext.insert(category)
        try modelContext.save()

        let viewModel = CategoryManagementViewModel()
        let health = viewModel.calculateCategoryHealth(for: category, spent: 200)

        XCTAssertEqual(health.rating, .excellent)
        XCTAssertEqual(health.percentage, 0.4, accuracy: 0.01)
        XCTAssertFalse(health.microTip.isEmpty)
    }

    func testHealthScore_good_between50And80Percent() throws {
        let category = Category(name: "Dining", type: .expense, monthlyBudget: 500)
        modelContext.insert(category)
        try modelContext.save()

        let viewModel = CategoryManagementViewModel()
        let health = viewModel.calculateCategoryHealth(for: category, spent: 300)

        XCTAssertEqual(health.rating, .good)
        XCTAssertEqual(health.percentage, 0.6, accuracy: 0.01)
    }

    func testHealthScore_warning_between80And100Percent() throws {
        let category = Category(name: "Transport", type: .expense, monthlyBudget: 200)
        modelContext.insert(category)
        try modelContext.save()

        let viewModel = CategoryManagementViewModel()
        let health = viewModel.calculateCategoryHealth(for: category, spent: 180)

        XCTAssertEqual(health.rating, .warning)
        XCTAssertEqual(health.percentage, 0.9, accuracy: 0.01)
    }

    func testHealthScore_critical_over100Percent() throws {
        let category = Category(name: "Entertainment", type: .expense, monthlyBudget: 100)
        modelContext.insert(category)
        try modelContext.save()

        let viewModel = CategoryManagementViewModel()
        let health = viewModel.calculateCategoryHealth(for: category, spent: 150)

        XCTAssertEqual(health.rating, .critical)
        XCTAssertEqual(health.percentage, 1.5, accuracy: 0.01)
    }

    func testHealthScore_noBudget_returnsGoodWithTip() throws {
        let category = Category(name: "No Budget", type: .expense, monthlyBudget: 0)
        modelContext.insert(category)
        try modelContext.save()

        let viewModel = CategoryManagementViewModel()
        let health = viewModel.calculateCategoryHealth(for: category, spent: 300)

        XCTAssertEqual(health.rating, .good)
        XCTAssertEqual(health.percentage, 0)
        XCTAssertTrue(health.microTip.contains("budget"))
    }

    func testHealthScore_zeroBudgetZeroSpent() throws {
        let category = Category(name: "Unused", type: .expense, monthlyBudget: 0)
        modelContext.insert(category)
        try modelContext.save()

        let viewModel = CategoryManagementViewModel()
        let health = viewModel.calculateCategoryHealth(for: category, spent: 0)

        XCTAssertEqual(health.rating, .good)
        XCTAssertEqual(health.percentage, 0)
    }

    func testHealthScore_exactlyAtBudget() throws {
        let category = Category(name: "Exact", type: .expense, monthlyBudget: 500)
        modelContext.insert(category)
        try modelContext.save()

        let viewModel = CategoryManagementViewModel()
        let health = viewModel.calculateCategoryHealth(for: category, spent: 500)

        // 100% = critical (>= 1.0)
        XCTAssertEqual(health.rating, .critical)
        XCTAssertEqual(health.percentage, 1.0, accuracy: 0.01)
    }

    func testHealthScore_boundaryAt50Percent() throws {
        let category = Category(name: "Boundary50", type: .expense, monthlyBudget: 200)
        modelContext.insert(category)
        try modelContext.save()

        let viewModel = CategoryManagementViewModel()
        let health = viewModel.calculateCategoryHealth(for: category, spent: 100)

        // Exactly 50% = good (0.5 is start of good range)
        XCTAssertEqual(health.rating, .good)
        XCTAssertEqual(health.percentage, 0.5, accuracy: 0.01)
    }

    func testHealthScore_boundaryAt80Percent() throws {
        let category = Category(name: "Boundary80", type: .expense, monthlyBudget: 500)
        modelContext.insert(category)
        try modelContext.save()

        let viewModel = CategoryManagementViewModel()
        let health = viewModel.calculateCategoryHealth(for: category, spent: 400)

        // Exactly 80% = warning (0.8 is start of warning range)
        XCTAssertEqual(health.rating, .warning)
        XCTAssertEqual(health.percentage, 0.8, accuracy: 0.01)
    }

    // MARK: - Rating Properties Tests

    func testRating_icons_areNotEmpty() {
        for rating in CategoryManagementViewModel.CategoryHealth.Rating.allCases {
            XCTAssertFalse(rating.icon.isEmpty, "\(rating.rawValue) should have an icon")
        }
    }

    func testRating_displayNames_areNotEmpty() {
        for rating in CategoryManagementViewModel.CategoryHealth.Rating.allCases {
            XCTAssertFalse(rating.rawValue.isEmpty, "\(rating.rawValue) should have a display name")
        }
    }

    // MARK: - Filtering Tests

    func testFilteredCategories_all_returnsAllCategories() {
        let viewModel = CategoryManagementViewModel()
        viewModel.selectedFilter = .all

        let categories = [
            Category(name: "Groceries", type: .expense),
            Category(name: "Salary", type: .income),
            Category(name: "Transport", type: .expense)
        ]

        let filtered = viewModel.filteredCategories(categories)
        XCTAssertEqual(filtered.count, 3)
    }

    func testFilteredCategories_incomeFilter_returnsOnlyIncome() {
        let viewModel = CategoryManagementViewModel()
        viewModel.selectedFilter = .income

        let categories = [
            Category(name: "Groceries", type: .expense),
            Category(name: "Salary", type: .income),
            Category(name: "Transport", type: .expense)
        ]

        let filtered = viewModel.filteredCategories(categories)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.name, "Salary")
    }

    func testFilteredCategories_expenseFilter_returnsOnlyExpenses() {
        let viewModel = CategoryManagementViewModel()
        viewModel.selectedFilter = .expense

        let categories = [
            Category(name: "Groceries", type: .expense),
            Category(name: "Salary", type: .income),
            Category(name: "Transport", type: .expense)
        ]

        let filtered = viewModel.filteredCategories(categories)
        XCTAssertEqual(filtered.count, 2)
    }

    func testFilteredCategories_searchText_filtersCorrectly() {
        let viewModel = CategoryManagementViewModel()
        viewModel.searchText = "Groc"

        let categories = [
            Category(name: "Groceries", type: .expense),
            Category(name: "Salary", type: .income),
            Category(name: "Transport", type: .expense)
        ]

        let filtered = viewModel.filteredCategories(categories)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.name, "Groceries")
    }

    func testFilteredCategories_searchAndFilter_combined() {
        let viewModel = CategoryManagementViewModel()
        viewModel.searchText = "sub"
        viewModel.selectedFilter = .expense

        let categories = [
            Category(name: "Groceries", type: .expense),
            Category(name: "Salary", type: .income),
            Category(name: "Subscriptions", type: .expense),
            Category(name: "Transport", type: .expense)
        ]

        let filtered = viewModel.filteredCategories(categories)
        // Should match only "Subscriptions" (expense + contains "sub")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.name, "Subscriptions")
    }

    func testFilteredCategories_caseInsensitiveSearch() {
        let viewModel = CategoryManagementViewModel()
        viewModel.searchText = "groc"

        let categories = [
            Category(name: "Groceries", type: .expense)
        ]

        let filtered = viewModel.filteredCategories(categories)
        XCTAssertEqual(filtered.count, 1)
    }

    func testFilteredCategories_emptySearch_returnsAll() {
        let viewModel = CategoryManagementViewModel()
        viewModel.searchText = ""
        viewModel.selectedFilter = .all

        let categories = [
            Category(name: "A", type: .expense),
            Category(name: "B", type: .income)
        ]

        let filtered = viewModel.filteredCategories(categories)
        XCTAssertEqual(filtered.count, 2)
    }

    func testFilteredCategories_sortedAlphabetically() {
        let viewModel = CategoryManagementViewModel()

        let categories = [
            Category(name: "Zulu", type: .expense),
            Category(name: "Alpha", type: .expense),
            Category(name: "Mike", type: .expense)
        ]

        let filtered = viewModel.filteredCategories(categories)
        XCTAssertEqual(filtered.map(\.name), ["Alpha", "Mike", "Zulu"])
    }

    // MARK: - MicroTip Tests

    func testMicroTip_excellent_mentionsWellWithinBudget() throws {
        let category = Category(name: "Test", type: .expense, monthlyBudget: 1000)
        modelContext.insert(category)
        try modelContext.save()

        let viewModel = CategoryManagementViewModel()
        let health = viewModel.calculateCategoryHealth(for: category, spent: 200)

        XCTAssertTrue(health.microTip.lowercased().contains("within budget") ||
                      health.microTip.lowercased().contains("great"))
    }

    func testMicroTip_critical_mentionsOverBudget() throws {
        let category = Category(name: "Test", type: .expense, monthlyBudget: 100)
        modelContext.insert(category)
        try modelContext.save()

        let viewModel = CategoryManagementViewModel()
        let health = viewModel.calculateCategoryHealth(for: category, spent: 200)

        XCTAssertTrue(health.microTip.lowercased().contains("over budget") ||
                      health.microTip.lowercased().contains("review"))
    }

    // MARK: - CategoryFilter CaseIterable

    func testCategoryFilter_allCases_exist() {
        let cases = CategoryManagementViewModel.CategoryFilter.allCases
        XCTAssertTrue(cases.count >= 4)
        XCTAssertTrue(cases.contains(.all))
        XCTAssertTrue(cases.contains(.income))
        XCTAssertTrue(cases.contains(.expense))
    }

    // MARK: - View Instantiation Tests

    func testCategoryManagementView_canBeInstantiated() throws {
        let view = CategoryManagementView()
            .modelContainer(modelContainer)

        XCTAssertNotNil(view)
    }

    func testFinancialHealthIndicator_canBeInstantiated() throws {
        let health = CategoryManagementViewModel.CategoryHealth(
            percentage: 0.6,
            rating: .good,
            microTip: "On track"
        )

        let indicator = FinancialHealthIndicator(health: health)
        XCTAssertNotNil(indicator)
    }
}
