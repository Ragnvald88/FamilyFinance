//
//  TransactionQueryService.swift
//  Family Finance
//
//  High-performance query service for transaction aggregations
//  Optimized for 15,430+ transactions with smart filtering
//
//  Created: 2025-12-22
//

import Foundation
import SwiftData

// MARK: - Query Filters

/// Comprehensive filter for transaction queries
struct TransactionFilter {
    var year: Int?
    var month: Int? // 1-12, nil = all months
    var accounts: [String]? // IBANs
    var categories: [String]?
    var transactionType: TransactionType?
    var contributor: Contributor?
    var minAmount: Decimal?
    var maxAmount: Decimal?
    var searchText: String?
    var dateRange: DateInterval?

    static var empty: TransactionFilter {
        TransactionFilter()
    }

    /// Quick filter for current year
    static var currentYear: TransactionFilter {
        let year = Calendar.current.component(.year, from: Date())
        return TransactionFilter(year: year)
    }

    /// Quick filter for current month
    static var currentMonth: TransactionFilter {
        let now = Date()
        let year = Calendar.current.component(.year, from: now)
        let month = Calendar.current.component(.month, from: now)
        return TransactionFilter(year: year, month: month)
    }
}

// MARK: - Aggregation Results

/// KPI summary for dashboard
struct DashboardKPIs {
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let netSavings: Decimal
    let savingsRate: Double // Percentage
    let transactionCount: Int
    let averageExpense: Decimal
    let topCategory: String?
    let topCategoryAmount: Decimal

    var savingsRateFormatted: String {
        String(format: "%.1f%%", savingsRate)
    }
}

/// Category spending summary
struct CategorySummary: Identifiable {
    let id = UUID()
    let category: String
    let totalAmount: Decimal
    let transactionCount: Int
    let budget: Decimal?
    let percentageOfBudget: Double?

    var averageTransaction: Decimal {
        guard transactionCount > 0 else { return 0 }
        return totalAmount / Decimal(transactionCount)
    }

    var isOverBudget: Bool {
        guard let budget = budget, budget > 0 else { return false }
        return totalAmount > budget
    }

    var budgetRemaining: Decimal? {
        guard let budget = budget else { return nil }
        return budget - totalAmount
    }
}

/// Monthly trend data point
struct MonthlyTrend: Identifiable {
    let id = UUID()
    let year: Int
    let month: Int
    let income: Decimal
    let expenses: Decimal
    let savings: Decimal

    var monthName: String {
        guard month >= 1 && month <= 12 else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.monthSymbols[month - 1]
    }

    var periodKey: String {
        String(format: "%04d-%02d", year, month)
    }
}

// MARK: - Transaction Query Service

/// Optimized query service for transaction data
@MainActor
class TransactionQueryService: ObservableObject {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Published State

    @Published var isLoading = false

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Dashboard Queries

    /// Get comprehensive dashboard KPIs
    func getDashboardKPIs(filter: TransactionFilter) async throws -> DashboardKPIs {
        let transactions = try await fetchTransactions(filter: filter)

        let income = transactions
            .filter { $0.transactionType == .income }
            .reduce(Decimal.zero) { $0 + $1.amount }

        let expenses = abs(transactions
            .filter { $0.transactionType == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount })

        let netSavings = income - expenses

        let savingsRate = income > 0
            ? (Double(truncating: netSavings as NSNumber) / Double(truncating: income as NSNumber)) * 100
            : 0.0

        let expenseTransactions = transactions.filter { $0.transactionType == .expense }
        let averageExpense = expenseTransactions.isEmpty
            ? 0
            : abs(expenseTransactions.reduce(Decimal.zero) { $0 + $1.amount }) / Decimal(expenseTransactions.count)

        // Find top category
        let categoryTotals = Dictionary(grouping: expenseTransactions) { $0.effectiveCategory }
            .mapValues { abs($0.reduce(Decimal.zero) { $0 + $1.amount }) }

        let topCategory = categoryTotals.max(by: { $0.value < $1.value })

        return DashboardKPIs(
            totalIncome: income,
            totalExpenses: expenses,
            netSavings: netSavings,
            savingsRate: savingsRate,
            transactionCount: transactions.count,
            averageExpense: averageExpense,
            topCategory: topCategory?.key,
            topCategoryAmount: topCategory?.value ?? 0
        )
    }

    /// Get category summaries with budget comparison.
    /// Handles split transactions by aggregating split amounts per category.
    func getCategorySummaries(filter: TransactionFilter) async throws -> [CategorySummary] {
        let transactions = try await fetchTransactions(filter: filter)
        let budgets = try await fetchBudgets(year: filter.year, month: filter.month)

        // Aggregate amounts per category (handles splits)
        var categoryAmounts: [String: Decimal] = [:]
        var categoryCounts: [String: Int] = [:]

        for transaction in transactions {
            // Use categoryBreakdown which handles both split and unsplit transactions
            for (category, amount) in transaction.categoryBreakdown {
                categoryAmounts[category, default: 0] += abs(amount)
                categoryCounts[category, default: 0] += 1
            }
        }

        var summaries: [CategorySummary] = []

        for (category, totalAmount) in categoryAmounts {
            let count = categoryCounts[category] ?? 0
            let budget = budgets[category]

            let percentageOfBudget: Double? = {
                guard let budget = budget, budget > 0 else { return nil }
                return (Double(truncating: totalAmount as NSNumber) / Double(truncating: budget as NSNumber)) * 100
            }()

            summaries.append(CategorySummary(
                category: category,
                totalAmount: totalAmount,
                transactionCount: count,
                budget: budget,
                percentageOfBudget: percentageOfBudget
            ))
        }

        // Sort by total amount descending
        return summaries.sorted { $0.totalAmount > $1.totalAmount }
    }

    /// Get monthly trends for charting
    /// Optimized: Fetches year once, groups in memory (avoids 12 separate queries)
    func getMonthlyTrends(year: Int) async throws -> [MonthlyTrend] {
        // Fetch all transactions for the year in ONE query
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.year == year }
        )
        let transactions = try modelContext.fetch(descriptor)

        // Group by month in memory (O(n) instead of 12 × O(n))
        let grouped = Dictionary(grouping: transactions) { $0.month }

        var trends: [MonthlyTrend] = []

        for month in 1...12 {
            let monthTransactions = grouped[month] ?? []

            let income = monthTransactions
                .filter { $0.transactionType == .income }
                .reduce(Decimal.zero) { $0 + $1.amount }

            let expenses = abs(monthTransactions
                .filter { $0.transactionType == .expense }
                .reduce(Decimal.zero) { $0 + $1.amount })

            trends.append(MonthlyTrend(
                year: year,
                month: month,
                income: income,
                expenses: expenses,
                savings: income - expenses
            ))
        }

        return trends
    }

    /// Get Inleg (contribution) totals
    func getInlegTotals() async throws -> (partner1: Decimal, partner2: Decimal) {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { transaction in
                transaction.contributor != nil
            }
        )

        let transactions = try modelContext.fetch(descriptor)

        let partner1 = transactions
            .filter { $0.contributor == .partner1 }
            .reduce(Decimal.zero) { $0 + $1.amount }

        let partner2 = transactions
            .filter { $0.contributor == .partner2 }
            .reduce(Decimal.zero) { $0 + $1.amount }

        return (partner1, partner2)
    }

    /// Get merchant statistics (top N merchants by spending).
    /// Uses memory-efficient aggregation to avoid OOM with large datasets.
    func getTopMerchants(limit: Int = 500, filter: TransactionFilter) async throws -> [MerchantStats] {
        let transactions = try await fetchTransactions(filter: filter)

        // Aggregate totals without creating full MerchantStats objects
        // This reduces memory footprint significantly for large datasets
        var merchantTotals: [String: (total: Decimal, count: Int, category: String?)] = [:]

        for transaction in transactions {
            let name = transaction.standardizedName ?? transaction.counterName ?? "Unknown"
            let existing = merchantTotals[name] ?? (total: 0, count: 0, category: nil)
            merchantTotals[name] = (
                total: existing.total + abs(transaction.amount),
                count: existing.count + 1,
                category: existing.category ?? transaction.effectiveCategory
            )
        }

        // Only create MerchantStats for top N merchants (memory efficient)
        // Sort keys by total, take top N, then create stats
        let topMerchants = merchantTotals
            .sorted { $0.value.total > $1.value.total }
            .prefix(limit)

        return topMerchants.map { (name, data) in
            MerchantStats(
                name: name,
                totalSpent: data.total,
                transactionCount: data.count,
                averageTransaction: data.count > 0 ? data.total / Decimal(data.count) : 0,
                primaryCategory: data.category
            )
        }
    }

    // MARK: - Account Queries

    /// Get current balance for all accounts
    func getAccountBalances() async throws -> [AccountBalance] {
        let descriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\Account.sortOrder)]
        )

        let accounts = try modelContext.fetch(descriptor)

        return accounts.map { account in
            AccountBalance(
                iban: account.iban,
                name: account.name,
                type: account.accountType,
                balance: account.currentBalance,
                owner: account.owner
            )
        }
    }

    /// Get net worth (assets - liabilities)
    func getNetWorth() async throws -> NetWorth {
        let accountBalances = try await getAccountBalances()
        let totalAssets = accountBalances.reduce(Decimal.zero) { $0 + $1.balance }

        let liabilityDescriptor = FetchDescriptor<Liability>(
            predicate: #Predicate<Liability> { $0.isActive }
        )
        let liabilities = try modelContext.fetch(liabilityDescriptor)
        let totalLiabilities = liabilities.reduce(Decimal.zero) { $0 + $1.amount }

        return NetWorth(
            assets: totalAssets,
            liabilities: totalLiabilities,
            netWorth: totalAssets - totalLiabilities
        )
    }

    // MARK: - Recurring Transaction Queries

    /// Get all active recurring transactions
    func getActiveRecurringTransactions() async throws -> [RecurringTransaction] {
        let descriptor = FetchDescriptor<RecurringTransaction>(
            predicate: #Predicate<RecurringTransaction> { $0.isActive },
            sortBy: [SortDescriptor(\RecurringTransaction.nextDueDate)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Get overdue recurring transactions
    func getOverdueRecurringTransactions() async throws -> [RecurringTransaction] {
        let now = Date()
        let descriptor = FetchDescriptor<RecurringTransaction>(
            predicate: #Predicate<RecurringTransaction> { $0.isActive && $0.nextDueDate < now },
            sortBy: [SortDescriptor(\RecurringTransaction.nextDueDate)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Get upcoming recurring transactions within specified days
    func getUpcomingRecurringTransactions(withinDays: Int = 7) async throws -> [RecurringTransaction] {
        let now = Date()
        let futureDate = Calendar.current.date(byAdding: .day, value: withinDays, to: now) ?? now
        let descriptor = FetchDescriptor<RecurringTransaction>(
            predicate: #Predicate<RecurringTransaction> {
                $0.isActive && $0.nextDueDate >= now && $0.nextDueDate <= futureDate
            },
            sortBy: [SortDescriptor(\RecurringTransaction.nextDueDate)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Calculate total expected recurring expenses/income for a month
    func getMonthlyRecurringTotal(type: TransactionType) async throws -> Decimal {
        let recurring = try await getActiveRecurringTransactions()

        return recurring
            .filter { tx in
                // Match type based on amount sign
                (type == .expense && tx.expectedAmount < 0) ||
                (type == .income && tx.expectedAmount > 0)
            }
            .reduce(Decimal.zero) { total, tx in
                // Calculate monthly equivalent
                let monthlyAmount: Decimal
                switch tx.frequency {
                case .daily: monthlyAmount = tx.expectedAmount * 30
                case .weekly: monthlyAmount = tx.expectedAmount * Decimal(30.0 / 7.0)
                case .biweekly: monthlyAmount = tx.expectedAmount * Decimal(30.0 / 14.0)
                case .monthly: monthlyAmount = tx.expectedAmount
                case .quarterly: monthlyAmount = tx.expectedAmount / 3
                case .yearly: monthlyAmount = tx.expectedAmount / 12
                }
                return total + abs(monthlyAmount)
            }
    }

    // MARK: - Cash Flow Forecast

    /// Simple cash flow forecast based on recurring transactions
    func getCashFlowForecast(forMonths months: Int = 3) async throws -> [CashFlowForecast] {
        let recurring = try await getActiveRecurringTransactions()
        let accountBalances = try await getAccountBalances()
        var currentBalance = accountBalances.reduce(Decimal.zero) { $0 + $1.balance }

        var forecasts: [CashFlowForecast] = []
        let calendar = Calendar.current

        for monthOffset in 0..<months {
            guard let targetDate = calendar.date(byAdding: .month, value: monthOffset, to: Date()) else { continue }
            let year = calendar.component(.year, from: targetDate)
            let month = calendar.component(.month, from: targetDate)

            var expectedIncome: Decimal = 0
            var expectedExpenses: Decimal = 0

            for tx in recurring {
                // Check if this recurring transaction occurs in this month
                let occurrences = countOccurrencesInMonth(recurring: tx, year: year, month: month)
                let amount = tx.expectedAmount * Decimal(occurrences)

                if amount > 0 {
                    expectedIncome += amount
                } else {
                    expectedExpenses += abs(amount)
                }
            }

            let projectedBalance = currentBalance + expectedIncome - expectedExpenses

            forecasts.append(CashFlowForecast(
                year: year,
                month: month,
                expectedIncome: expectedIncome,
                expectedExpenses: expectedExpenses,
                projectedBalance: projectedBalance
            ))

            currentBalance = projectedBalance
        }

        return forecasts
    }

    /// Count how many times a recurring transaction occurs in a given month
    private func countOccurrencesInMonth(recurring: RecurringTransaction, year: Int, month: Int) -> Int {
        switch recurring.frequency {
        case .daily:
            let calendar = Calendar.current
            let components = DateComponents(year: year, month: month)
            guard let date = calendar.date(from: components),
                  let range = calendar.range(of: .day, in: .month, for: date) else { return 30 }
            return range.count
        case .weekly: return 4
        case .biweekly: return 2
        case .monthly: return 1
        case .quarterly: return month % 3 == 0 ? 1 : 0
        case .yearly: return 1  // Simplified - assumes yearly occurs in this month
        }
    }

    // MARK: - Private Helper Methods

    /// Fetch transactions with filter (optimized with predicates)
    ///
    /// Strategy: Use denormalized year/month fields for efficient indexed queries.
    /// SwiftData doesn't support dynamic predicate composition, so we:
    /// 1. Build the most selective predicate using indexed fields (year, month, iban, type)
    /// 2. Apply remaining filters in memory (categories, contributor, amounts, search)
    private func fetchTransactions(filter: TransactionFilter) async throws -> [Transaction] {
        // Build predicate based on which filters are set
        // Uses denormalized year/month fields for O(log n) indexed lookup
        let predicate = buildPredicate(for: filter)

        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )

        var transactions = try modelContext.fetch(descriptor)

        // Apply in-memory filters for fields that can't be efficiently combined in predicate
        transactions = applyInMemoryFilters(transactions, filter: filter)

        return transactions
    }

    /// Build SwiftData predicate for indexed fields
    /// Uses denormalized year/month for performance (avoids Calendar.component() which causes O(n) scans)
    private func buildPredicate(for filter: TransactionFilter) -> Predicate<Transaction>? {
        // Handle different combinations of year/month filters
        // SwiftData requires static predicates, so we match on combinations

        switch (filter.year, filter.month, filter.transactionType, filter.accounts?.first) {

        // Year + Month + Type + Account (most specific)
        case let (year?, month?, type?, iban?):
            return #Predicate<Transaction> {
                $0.year == year && $0.month == month && $0.transactionType == type && $0.iban == iban
            }

        // Year + Month + Type
        case let (year?, month?, type?, nil):
            return #Predicate<Transaction> {
                $0.year == year && $0.month == month && $0.transactionType == type
            }

        // Year + Month + Account
        case let (year?, month?, nil, iban?):
            return #Predicate<Transaction> {
                $0.year == year && $0.month == month && $0.iban == iban
            }

        // Year + Type
        case let (year?, nil, type?, nil):
            return #Predicate<Transaction> {
                $0.year == year && $0.transactionType == type
            }

        // Year + Month (common case for dashboard)
        case let (year?, month?, nil, nil):
            return #Predicate<Transaction> {
                $0.year == year && $0.month == month
            }

        // Year only
        case let (year?, nil, nil, nil):
            return #Predicate<Transaction> {
                $0.year == year
            }

        // Month only (across all years - rare)
        case let (nil, month?, nil, nil):
            return #Predicate<Transaction> {
                $0.month == month
            }

        // Type only
        case let (nil, nil, type?, nil):
            return #Predicate<Transaction> {
                $0.transactionType == type
            }

        // Account only
        case let (nil, nil, nil, iban?):
            return #Predicate<Transaction> {
                $0.iban == iban
            }

        // No filters - fetch all
        default:
            return nil
        }
    }

    /// Apply filters that can't be efficiently combined in SwiftData predicates
    private func applyInMemoryFilters(_ transactions: [Transaction], filter: TransactionFilter) -> [Transaction] {
        var result = transactions

        // Filter by multiple accounts (if more than one specified)
        if let accounts = filter.accounts, accounts.count > 1 {
            result = result.filter { accounts.contains($0.iban) }
        }

        // Category filter (uses indexedCategory for consistency)
        if let categories = filter.categories, !categories.isEmpty {
            result = result.filter { categories.contains($0.indexedCategory) }
        }

        // Contributor filter
        if let contributor = filter.contributor {
            result = result.filter { $0.contributor == contributor }
        }

        // Amount range filters
        if let minAmount = filter.minAmount {
            result = result.filter { $0.amount >= minAmount }
        }
        if let maxAmount = filter.maxAmount {
            result = result.filter { $0.amount <= maxAmount }
        }

        // Date range filter (more specific than year/month)
        if let dateRange = filter.dateRange {
            result = result.filter { dateRange.contains($0.date) }
        }

        // Search text filter
        if let searchText = filter.searchText, !searchText.isEmpty {
            let search = searchText.lowercased()
            result = result.filter { transaction in
                transaction.counterName?.lowercased().contains(search) == true ||
                transaction.standardizedName?.lowercased().contains(search) == true ||
                transaction.fullDescription.lowercased().contains(search) ||
                transaction.indexedCategory.lowercased().contains(search)
            }
        }

        return result
    }

    /// Fetch budgets for given period
    private func fetchBudgets(year: Int?, month: Int?) async throws -> [String: Decimal] {
        // First try to get period-specific budgets
        var budgets: [String: Decimal] = [:]

        if let year = year {
            let descriptor = FetchDescriptor<BudgetPeriod>(
                predicate: #Predicate<BudgetPeriod> { budget in
                    budget.year == year && (budget.month == (month ?? 0))
                }
            )

            let periodBudgets = try modelContext.fetch(descriptor)
            for budget in periodBudgets {
                budgets[budget.category] = budget.budgetAmount
            }
        }

        // Fall back to category defaults if no period budgets found
        if budgets.isEmpty {
            let categoryDescriptor = FetchDescriptor<Category>()
            let categories = try modelContext.fetch(categoryDescriptor)

            for category in categories {
                budgets[category.name] = category.monthlyBudget
            }
        }

        return budgets
    }
}

// MARK: - Supporting Types

struct MerchantStats: Identifiable {
    let id = UUID()
    let name: String
    let totalSpent: Decimal
    let transactionCount: Int
    let averageTransaction: Decimal
    let primaryCategory: String?
}

struct AccountBalance: Identifiable {
    let id = UUID()
    let iban: String
    let name: String
    let type: AccountType
    let balance: Decimal
    let owner: String
}

struct NetWorth {
    let assets: Decimal
    let liabilities: Decimal
    let netWorth: Decimal

    var debtToAssetsRatio: Double {
        guard assets > 0 else { return 0 }
        return Double(truncating: liabilities as NSNumber) / Double(truncating: assets as NSNumber) * 100
    }
}

/// Cash flow forecast for a single month
struct CashFlowForecast: Identifiable {
    let id = UUID()
    let year: Int
    let month: Int
    let expectedIncome: Decimal
    let expectedExpenses: Decimal
    let projectedBalance: Decimal

    var netCashFlow: Decimal {
        expectedIncome - expectedExpenses
    }

    var monthName: String {
        guard month >= 1 && month <= 12 else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.monthSymbols[month - 1]
    }

    var periodKey: String {
        String(format: "%04d-%02d", year, month)
    }
}

// MARK: - Cached Formatters (Performance Optimization)

private enum FormatterCache {
    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter
    }()

    static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter
    }()

    static let dutchMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter
    }()
}

// MARK: - Extensions

extension Decimal {
    /// Format as Dutch currency (uses cached formatter for performance)
    func toCurrencyString() -> String {
        FormatterCache.currencyFormatter.string(from: self as NSNumber) ?? "€0,00"
    }

    /// Format as percentage (uses cached formatter for performance)
    func toPercentageString(decimals: Int = 1) -> String {
        // Use cached formatter for default decimals, create new for custom
        if decimals == 1 {
            return FormatterCache.percentFormatter.string(from: (self / 100) as NSNumber) ?? "0%"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.string(from: (self / 100) as NSNumber) ?? "0%"
    }
}

import SwiftUI

extension Color {
    /// Initialize from hex string (e.g., "3B82F6" or "#3B82F6")
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}
