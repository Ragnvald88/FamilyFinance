//
//  DashboardView.swift
//  Family Finance
//
//  Stunning Firefly III-inspired dashboard with KPIs, charts, and insights
//  macOS-native design with smooth animations
//
//  Created: 2025-12-22
//

import SwiftUI
import Charts

// MARK: - Dashboard View

struct DashboardView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @StateObject private var viewModel: DashboardViewModel
    @State private var selectedYear: Int
    @State private var selectedMonth: Int = 0 // 0 = all months

    // MARK: - Initialization

    init(queryService: TransactionQueryService) {
        let currentYear = Calendar.current.component(.year, from: Date())
        _selectedYear = State(initialValue: currentYear)
        _viewModel = StateObject(wrappedValue: DashboardViewModel(queryService: queryService))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with filters
                    headerSection

                    // Main KPIs
                    kpiCardsSection

                    // Charts section
                    chartsSection

                    // Category breakdown
                    categorySection

                    // Accounts overview
                    accountsSection

                    // Net worth
                    netWorthSection

                    Spacer(minLength: 40)
                }
                .padding(24)
            }
            .background(Color(nsColor: .windowBackgroundColor))

            // Loading overlay
            if viewModel.isLoading {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView("Loading...")
                            .padding(24)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 4)
                    }
            }
        }
        .task {
            await loadData()
        }
        .onChange(of: selectedYear) { _, _ in
            Task { await loadData() }
        }
        .onChange(of: selectedMonth) { _, _ in
            Task { await loadData() }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dashboard")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)

                Text(periodDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Year picker
            Picker("Year", selection: $selectedYear) {
                ForEach(availableYears, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)

            // Month picker
            Picker("Month", selection: $selectedMonth) {
                Text("All Months").tag(0)
                ForEach(1...12, id: \.self) { month in
                    Text(monthName(month)).tag(month)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)

            // Refresh button
            Button(action: { Task { await loadData() } }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
        .padding(.bottom, 8)
    }

    // MARK: - KPI Cards Section

    private var kpiCardsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            KPICard(
                title: "Inkomen",
                value: viewModel.kpis?.totalIncome.toCurrencyString() ?? "—",
                icon: "arrow.down.circle.fill",
                color: .green,
                trend: nil
            )

            KPICard(
                title: "Uitgaven",
                value: viewModel.kpis?.totalExpenses.toCurrencyString() ?? "—",
                icon: "arrow.up.circle.fill",
                color: .red,
                trend: nil
            )

            KPICard(
                title: "Gespaard",
                value: viewModel.kpis?.netSavings.toCurrencyString() ?? "—",
                icon: "banknote.fill",
                color: .blue,
                trend: nil
            )

            KPICard(
                title: "Spaarrate",
                value: viewModel.kpis?.savingsRateFormatted ?? "—",
                icon: "percent",
                color: .orange,
                trend: nil
            )
        }
    }

    // MARK: - Charts Section

    private var chartsSection: some View {
        HStack(spacing: 16) {
            // Monthly trend chart
            VStack(alignment: .leading, spacing: 12) {
                Text("Monthly Trends")
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let trends = viewModel.monthlyTrends, !trends.isEmpty {
                    Chart(trends) { trend in
                        LineMark(
                            x: .value("Month", trend.monthName),
                            y: .value("Income", Double(truncating: trend.income as NSNumber))
                        )
                        .foregroundStyle(.green)
                        .symbol(.circle)

                        LineMark(
                            x: .value("Month", trend.monthName),
                            y: .value("Expenses", Double(truncating: trend.expenses as NSNumber))
                        )
                        .foregroundStyle(.red)
                        .symbol(.square)
                    }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                } else {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("No transactions for this period")
                    )
                    .frame(height: 200)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Category pie chart (placeholder)
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Categories")
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let categories = viewModel.categorySummaries?.prefix(5) {
                    VStack(spacing: 8) {
                        ForEach(Array(categories)) { category in
                            HStack {
                                Circle()
                                    .fill(categoryColor(category.category))
                                    .frame(width: 8, height: 8)

                                Text(category.category)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text(category.totalAmount.toCurrencyString())
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .padding(.top, 8)
                } else {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.pie.fill",
                        description: Text("No categories found")
                    )
                    .frame(height: 200)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Budget vs Actual")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(viewModel.categorySummaries?.count ?? 0) categories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let categories = viewModel.categorySummaries {
                LazyVStack(spacing: 8) {
                    ForEach(categories.prefix(10)) { category in
                        CategoryRow(category: category)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(40)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Accounts Section

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accounts")
                .font(.headline)
                .foregroundStyle(.primary)

            if let accounts = viewModel.accountBalances {
                LazyVStack(spacing: 8) {
                    ForEach(accounts) { account in
                        AccountRow(account: account)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Net Worth Section

    private var netWorthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Net Worth")
                .font(.headline)
                .foregroundStyle(.primary)

            if let netWorth = viewModel.netWorth {
                HStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Assets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(netWorth.assets.toCurrencyString())
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Liabilities")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(netWorth.liabilities.toCurrencyString())
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                    }

                    Divider()
                        .frame(height: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Net Worth")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(netWorth.netWorth.toCurrencyString())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helper Methods

    private func loadData() async {
        let filter = TransactionFilter(
            year: selectedYear,
            month: selectedMonth > 0 ? selectedMonth : nil
        )

        await viewModel.loadData(filter: filter, year: selectedYear)
    }

    private var periodDescription: String {
        if selectedMonth > 0 {
            return "\(monthName(selectedMonth)) \(selectedYear)"
        } else {
            return "Year \(selectedYear)"
        }
    }

    private func monthName(_ month: Int) -> String {
        guard month >= 1 && month <= 12 else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.monthSymbols[month - 1].capitalized
    }

    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 5)...currentYear).reversed()
    }

    private func categoryColor(_ categoryName: String) -> Color {
        // Simple hash-based color assignment
        let hash = categoryName.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }
}

// MARK: - KPI Card Component

struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Spacer()

                if let trend = trend {
                    HStack(spacing: 4) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(String(format: "%.1f%%", abs(trend)))
                    }
                    .font(.caption)
                    .foregroundStyle(trend >= 0 ? .green : .red)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Category Row Component

struct CategoryRow: View {
    let category: CategorySummary

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(category.category)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                Text(category.totalAmount.toCurrencyString())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(category.isOverBudget ? .red : .primary)

                if let budget = category.budget {
                    Text("/ \(budget.toCurrencyString())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let percentage = category.percentageOfBudget {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(budgetColor(percentage))
                            .frame(width: geometry.size.width * min(CGFloat(percentage / 100), 1.0), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(.vertical, 4)
    }

    private func budgetColor(_ percentage: Double) -> Color {
        if percentage < 75 {
            return .green
        } else if percentage < 100 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Account Row Component

struct AccountRow: View {
    let account: AccountBalance

    var body: some View {
        HStack {
            Image(systemName: account.type.icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Text(account.owner)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(account.balance.toCurrencyString())
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Dashboard View Model

@MainActor
class DashboardViewModel: ObservableObject {

    // MARK: - Published State

    @Published var kpis: DashboardKPIs?
    @Published var categorySummaries: [CategorySummary]?
    @Published var monthlyTrends: [MonthlyTrend]?
    @Published var accountBalances: [AccountBalance]?
    @Published var netWorth: NetWorth?
    @Published var errorMessage: String?
    @Published var isLoading = false

    // MARK: - Dependencies

    private let queryService: TransactionQueryService

    // MARK: - Initialization

    init(queryService: TransactionQueryService) {
        self.queryService = queryService
    }

    // MARK: - Data Loading

    func loadData(filter: TransactionFilter, year: Int) async {
        isLoading = true
        errorMessage = nil

        // Use structured concurrency with proper error handling for each task
        do {
            // Run all queries concurrently
            async let kpisTask = queryService.getDashboardKPIs(filter: filter)
            async let categoriesTask = queryService.getCategorySummaries(filter: filter)
            async let trendsTask = queryService.getMonthlyTrends(year: year)
            async let accountsTask = queryService.getAccountBalances()
            async let netWorthTask = queryService.getNetWorth()

            // Await results
            kpis = try await kpisTask
            categorySummaries = try await categoriesTask
            monthlyTrends = try await trendsTask
            accountBalances = try await accountsTask
            netWorth = try await netWorthTask

        } catch {
            errorMessage = "Failed to load dashboard data: \(error.localizedDescription)"
            print("Dashboard loading error: \(error)")
        }

        isLoading = false
    }

    /// Clear error message
    func dismissError() {
        errorMessage = nil
    }
}
