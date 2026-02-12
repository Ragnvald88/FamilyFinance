//
//  BudgetManagementViewTests.swift
//  Florijn Tests
//
//  Tests for budget management with progress tracking
//

import XCTest
@preconcurrency import SwiftData
@testable import FamilyFinance

@MainActor
final class BudgetManagementViewTests: XCTestCase {

    var modelContext: ModelContext!
    var modelContainer: ModelContainer!

    override func setUp() async throws {
        let schema = Schema([
            Transaction.self,
            Account.self,
            Category.self,
            BudgetPeriod.self,
            TransactionSplit.self,
            RecurringTransaction.self,
            TransactionAuditLog.self,
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

    // MARK: - View Instantiation Tests

    func testBudgetManagementView_canBeInstantiated() throws {
        let view = BudgetManagementView()
            .modelContainer(modelContainer)

        XCTAssertNotNil(view)
    }

    func testBudgetCategoryCard_canBeInstantiated() throws {
        let category = Category(name: "Groceries", type: .expense, monthlyBudget: 500)
        modelContext.insert(category)
        try modelContext.save()

        let summary = CategorySummary(
            category: "Groceries",
            totalAmount: 200,
            transactionCount: 5,
            budget: 500,
            percentageOfBudget: 40.0
        )

        let card = BudgetCategoryCard(category: category, summary: summary)
        XCTAssertNotNil(card)
    }

    func testBudgetEditorSheet_canBeInstantiated() throws {
        let category = Category(name: "Transport", type: .expense, monthlyBudget: 200)
        modelContext.insert(category)
        try modelContext.save()

        let sheet = BudgetEditorSheet(
            categoryName: "Transport",
            year: 2026,
            month: 2,
            initialAmount: 200
        ) { _ in }

        XCTAssertNotNil(sheet)
    }

    // MARK: - ViewModel State Tests

    func testViewModel_initialState_usesCurrentDate() {
        let viewModel = BudgetManagementViewModel()
        let calendar = Calendar.current
        let now = Date()

        XCTAssertEqual(viewModel.selectedYear, calendar.component(.year, from: now))
        XCTAssertEqual(viewModel.selectedMonth, calendar.component(.month, from: now))
    }

    func testViewModel_monthNavigation_forward() {
        let viewModel = BudgetManagementViewModel()
        viewModel.selectedYear = 2026
        viewModel.selectedMonth = 6

        viewModel.navigateForward()

        XCTAssertEqual(viewModel.selectedMonth, 7)
        XCTAssertEqual(viewModel.selectedYear, 2026)
    }

    func testViewModel_monthNavigation_forward_wrapsYear() {
        let viewModel = BudgetManagementViewModel()
        viewModel.selectedYear = 2026
        viewModel.selectedMonth = 12

        viewModel.navigateForward()

        XCTAssertEqual(viewModel.selectedMonth, 1)
        XCTAssertEqual(viewModel.selectedYear, 2027)
    }

    func testViewModel_monthNavigation_backward() {
        let viewModel = BudgetManagementViewModel()
        viewModel.selectedYear = 2026
        viewModel.selectedMonth = 6

        viewModel.navigateBackward()

        XCTAssertEqual(viewModel.selectedMonth, 5)
        XCTAssertEqual(viewModel.selectedYear, 2026)
    }

    func testViewModel_monthNavigation_backward_wrapsYear() {
        let viewModel = BudgetManagementViewModel()
        viewModel.selectedYear = 2026
        viewModel.selectedMonth = 1

        viewModel.navigateBackward()

        XCTAssertEqual(viewModel.selectedMonth, 12)
        XCTAssertEqual(viewModel.selectedYear, 2025)
    }

    func testViewModel_navigateToCurrentMonth() {
        let viewModel = BudgetManagementViewModel()
        viewModel.selectedYear = 2024
        viewModel.selectedMonth = 3

        viewModel.navigateToCurrentMonth()

        let calendar = Calendar.current
        let now = Date()
        XCTAssertEqual(viewModel.selectedYear, calendar.component(.year, from: now))
        XCTAssertEqual(viewModel.selectedMonth, calendar.component(.month, from: now))
    }

    // MARK: - Progress Calculation Tests

    func testViewModel_progressPercentage_zeroBudget() {
        let viewModel = BudgetManagementViewModel()

        let percentage = viewModel.progressPercentage(spent: 500, budget: 0)
        XCTAssertEqual(percentage, 0, accuracy: 0.001)
    }

    func testViewModel_progressPercentage_normalSpending() {
        let viewModel = BudgetManagementViewModel()

        let percentage = viewModel.progressPercentage(spent: 250, budget: 500)
        XCTAssertEqual(percentage, 0.5, accuracy: 0.001)
    }

    func testViewModel_progressPercentage_overBudget() {
        let viewModel = BudgetManagementViewModel()

        let percentage = viewModel.progressPercentage(spent: 750, budget: 500)
        XCTAssertEqual(percentage, 1.5, accuracy: 0.001)
    }

    func testViewModel_progressPercentage_exactlyAtBudget() {
        let viewModel = BudgetManagementViewModel()

        let percentage = viewModel.progressPercentage(spent: 500, budget: 500)
        XCTAssertEqual(percentage, 1.0, accuracy: 0.001)
    }

    // MARK: - Spending Level Tests

    func testViewModel_spendingLevel_healthy_under80Percent() {
        let viewModel = BudgetManagementViewModel()

        let level = viewModel.spendingLevel(percentage: 0.5)
        XCTAssertEqual(level, .healthy)
    }

    func testViewModel_spendingLevel_caution_between80And100() {
        let viewModel = BudgetManagementViewModel()

        let level = viewModel.spendingLevel(percentage: 0.85)
        XCTAssertEqual(level, .caution)
    }

    func testViewModel_spendingLevel_over_above100() {
        let viewModel = BudgetManagementViewModel()

        let level = viewModel.spendingLevel(percentage: 1.2)
        XCTAssertEqual(level, .over)
    }

    func testViewModel_spendingLevel_boundary_at80() {
        let viewModel = BudgetManagementViewModel()

        let level = viewModel.spendingLevel(percentage: 0.8)
        XCTAssertEqual(level, .caution)
    }

    func testViewModel_spendingLevel_boundary_at100() {
        let viewModel = BudgetManagementViewModel()

        let level = viewModel.spendingLevel(percentage: 1.0)
        XCTAssertEqual(level, .over)
    }

    func testViewModel_spendingLevel_zero() {
        let viewModel = BudgetManagementViewModel()

        let level = viewModel.spendingLevel(percentage: 0)
        XCTAssertEqual(level, .healthy)
    }

    // MARK: - Summary Calculation Tests

    func testViewModel_totalBudget_sumsCategories() {
        let viewModel = BudgetManagementViewModel()

        let categories = [
            Category(name: "Groceries", type: .expense, monthlyBudget: 500),
            Category(name: "Transport", type: .expense, monthlyBudget: 200),
            Category(name: "Salary", type: .income, monthlyBudget: 0)
        ]

        let total = viewModel.totalBudget(for: categories)
        XCTAssertEqual(total, 700)
    }

    func testViewModel_totalBudget_emptyCategories() {
        let viewModel = BudgetManagementViewModel()
        let total = viewModel.totalBudget(for: [])
        XCTAssertEqual(total, 0)
    }

    func testViewModel_totalSpent_sumsSummaries() {
        let viewModel = BudgetManagementViewModel()

        let summaries = [
            CategorySummary(category: "Groceries", totalAmount: 300, transactionCount: 10, budget: 500, percentageOfBudget: 60),
            CategorySummary(category: "Transport", totalAmount: 150, transactionCount: 5, budget: 200, percentageOfBudget: 75)
        ]

        let total = viewModel.totalSpent(for: summaries)
        XCTAssertEqual(total, 450)
    }

    func testViewModel_totalSpent_emptySummaries() {
        let viewModel = BudgetManagementViewModel()
        let total = viewModel.totalSpent(for: [])
        XCTAssertEqual(total, 0)
    }

    // MARK: - Category Filtering Tests

    func testViewModel_expenseCategories_filtersCorrectly() {
        let viewModel = BudgetManagementViewModel()

        let categories = [
            Category(name: "Groceries", type: .expense, monthlyBudget: 500),
            Category(name: "Salary", type: .income, monthlyBudget: 0),
            Category(name: "Transport", type: .expense, monthlyBudget: 200),
            Category(name: "No Budget", type: .expense, monthlyBudget: 0)
        ]

        let budgeted = viewModel.expenseCategoriesWithBudget(categories)
        XCTAssertEqual(budgeted.count, 2)
        XCTAssertTrue(budgeted.contains { $0.name == "Groceries" })
        XCTAssertTrue(budgeted.contains { $0.name == "Transport" })
    }

    func testViewModel_categoriesWithoutBudgets_filtersCorrectly() {
        let viewModel = BudgetManagementViewModel()

        let categories = [
            Category(name: "Groceries", type: .expense, monthlyBudget: 500),
            Category(name: "Salary", type: .income, monthlyBudget: 0),
            Category(name: "No Budget", type: .expense, monthlyBudget: 0)
        ]

        let unbudgeted = viewModel.expenseCategoriesWithoutBudget(categories)
        XCTAssertEqual(unbudgeted.count, 1)
        XCTAssertEqual(unbudgeted.first?.name, "No Budget")
    }

    // MARK: - Month Display Tests

    func testViewModel_monthName_returnsCorrectName() {
        let viewModel = BudgetManagementViewModel()

        XCTAssertFalse(viewModel.monthName(1).isEmpty)
        XCTAssertFalse(viewModel.monthName(12).isEmpty)
    }

    func testViewModel_monthName_invalidMonth_returnsUnknown() {
        let viewModel = BudgetManagementViewModel()

        XCTAssertEqual(viewModel.monthName(0), "Unknown")
        XCTAssertEqual(viewModel.monthName(13), "Unknown")
    }

    func testViewModel_periodDisplayString_format() {
        let viewModel = BudgetManagementViewModel()
        viewModel.selectedYear = 2026
        viewModel.selectedMonth = 2

        let display = viewModel.periodDisplayString
        XCTAssertTrue(display.contains("2026"))
        // Should contain the month name
        let monthName = viewModel.monthName(2)
        XCTAssertTrue(display.contains(monthName))
    }

    // MARK: - SpendingLevel Properties Tests

    func testSpendingLevel_allCases_haveIcons() {
        for level in BudgetManagementViewModel.SpendingLevel.allCases {
            XCTAssertFalse(level.icon.isEmpty, "\(level) should have an icon")
        }
    }

    func testSpendingLevel_allCases_haveLabels() {
        for level in BudgetManagementViewModel.SpendingLevel.allCases {
            XCTAssertFalse(level.label.isEmpty, "\(level) should have a label")
        }
    }

    // MARK: - Budget Data Loading Integration Test

    func testBudgetDataLoading_withTransactionsAndCategories() throws {
        // Create categories with budgets
        let groceries = Category(name: "Groceries", type: .expense, monthlyBudget: 500)
        let transport = Category(name: "Transport", type: .expense, monthlyBudget: 200)
        modelContext.insert(groceries)
        modelContext.insert(transport)

        // Create test transactions
        let account = Account(iban: "NL00TEST0000000001", name: "Test", accountType: .checking, owner: "Test")
        modelContext.insert(account)

        let tx1 = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 1,
            date: Date(),
            amount: -50,
            balance: 950,
            autoCategory: "Groceries",
            transactionType: .expense,
            account: account
        )
        modelContext.insert(tx1)

        let tx2 = Transaction(
            iban: "NL00TEST0000000001",
            sequenceNumber: 2,
            date: Date(),
            amount: -30,
            balance: 920,
            autoCategory: "Transport",
            transactionType: .expense,
            account: account
        )
        modelContext.insert(tx2)

        try modelContext.save()

        // Verify the data is saved correctly
        let fetchedCategories = try modelContext.fetch(FetchDescriptor<Category>())
        XCTAssertEqual(fetchedCategories.count, 2)

        let fetchedTransactions = try modelContext.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(fetchedTransactions.count, 2)
    }

    func testBudgetPeriod_canBeCreatedAndFetched() throws {
        let budgetPeriod = BudgetPeriod(
            year: 2026,
            month: 2,
            category: "Groceries",
            budgetAmount: 500
        )
        modelContext.insert(budgetPeriod)
        try modelContext.save()

        let descriptor = FetchDescriptor<BudgetPeriod>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.year, 2026)
        XCTAssertEqual(fetched.first?.month, 2)
        XCTAssertEqual(fetched.first?.category, "Groceries")
        XCTAssertEqual(fetched.first?.budgetAmount, 500)
    }

    func testBudgetPeriod_periodKey_format() throws {
        let monthly = BudgetPeriod(year: 2026, month: 3, category: "Test", budgetAmount: 100)
        XCTAssertEqual(monthly.periodKey, "2026-03")

        let yearly = BudgetPeriod(year: 2026, month: 0, category: "Test", budgetAmount: 1200)
        XCTAssertEqual(yearly.periodKey, "2026")
    }
}
