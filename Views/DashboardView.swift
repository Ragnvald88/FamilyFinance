//
//  DashboardView.swift
//  Florijn
//
//  Dashboard with KPIs, charts, and insights
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
                VStack(spacing: PremiumSpacing.xxlarge) {
                    // Enhanced professional header with better spacing
                    headerSection
                        .padding(.bottom, PremiumSpacing.medium)

                    // Main KPIs with enhanced visual hierarchy
                    kpiCardsSection
                        .padding(.bottom, PremiumSpacing.large)

                    // Charts section with premium styling
                    chartsSection

                    // Category breakdown
                    categorySection

                    // Accounts overview
                    accountsSection

                    // Net worth with hero treatment
                    netWorthSection

                    // Professional bottom spacing
                    Spacer(minLength: PremiumSpacing.hero)
                }
                .padding(.horizontal, PremiumSpacing.xxlarge)
                .padding(.vertical, PremiumSpacing.xlarge)
            }

            // Professional loading overlay with trust elements
            if viewModel.isLoading {
                Color.black.opacity(0.05)
                    .ignoresSafeArea()
                    .background(.ultraThinMaterial)
                    .overlay {
                        VStack(spacing: PremiumSpacing.medium) {
                            // Security-conscious loading indicator
                            HStack(spacing: PremiumSpacing.small) {
                                Image(systemName: "lock.shield")
                                    .font(.title3)
                                    .foregroundStyle(Color.florijnGreen)

                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.florijnBlue))
                            }

                            Text("Analyzing Your Financial Data...")
                                .font(.bodyLarge)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.florijnCharcoal)

                            Text("Your data is processed locally on your device")
                                .font(.caption)
                                .foregroundStyle(Color.florijnMediumGray)
                        }
                        .padding(PremiumSpacing.xlarge)
                        .background {
                            RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius)
                                .fill(.regularMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 8)
                        }
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
            VStack(alignment: .leading, spacing: PremiumSpacing.tiny) {
                Text("Dashboard")
                    .font(.financialHero)
                    .foregroundStyle(Color.florijnCharcoal)

                Text(periodDescription)
                    .font(.bodyRegular)
                    .foregroundStyle(Color.florijnMediumGray)
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
            Button("Refresh") {
                Task { await loadData() }
            }
            .premiumSecondaryButton()
            .disabled(viewModel.isLoading)
        }
        .padding(.bottom, PremiumSpacing.small)
    }

    // MARK: - KPI Cards Section (Enhanced with Animations)

    private var kpiCardsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: PremiumSpacing.large) {

            if viewModel.isLoading && viewModel.kpis == nil {
                // Premium loading states
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius)
                        .fill(Color.florijnLightGray.opacity(0.3))
                        .frame(height: 120)
                        .overlay {
                            VStack(spacing: PremiumSpacing.small) {
                                Circle()
                                    .fill(Color.florijnMediumGray.opacity(0.3))
                                    .frame(width: PremiumSpacing.iconSize, height: PremiumSpacing.iconSize)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.florijnMediumGray.opacity(0.3))
                                    .frame(width: 80, height: 12)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.florijnMediumGray.opacity(0.3))
                                    .frame(width: 60, height: 20)
                            }
                        }
                        .redacted(reason: .placeholder)
                }
            } else {
                // Professional trust-enhanced KPI cards
                Group {
                    VStack(alignment: .leading, spacing: PremiumSpacing.tiny) {
                        TrustEnhancedKPICard(
                            title: "Income",
                            value: viewModel.kpis?.totalIncome ?? 0,
                            percentage: nil,
                            icon: .income,
                            color: .incomeGreen,
                            trend: nil,
                            cardType: .income
                        )

                        // Financial context for users
                        Text(incomeContextText(viewModel.kpis?.totalIncome ?? 0))
                            .financialLabel()
                            .padding(.horizontal, PremiumSpacing.medium)
                    }

                    VStack(alignment: .leading, spacing: PremiumSpacing.tiny) {
                        TrustEnhancedKPICard(
                            title: "Expenses",
                            value: abs(viewModel.kpis?.totalExpenses ?? 0),
                            percentage: nil,
                            icon: .expenses,
                            color: .expenseRed,
                            trend: nil,
                            cardType: .expenses
                        )

                        Text(expenseContextText(abs(viewModel.kpis?.totalExpenses ?? 0)))
                            .financialLabel()
                            .padding(.horizontal, PremiumSpacing.medium)
                    }

                    VStack(alignment: .leading, spacing: PremiumSpacing.tiny) {
                        TrustEnhancedKPICard(
                            title: "Saved",
                            value: viewModel.kpis?.netSavings ?? 0,
                            percentage: nil,
                            icon: .saved,
                            color: .savingsWin,
                            trend: nil,
                            cardType: .savings
                        )

                        Text(savingsContextText(viewModel.kpis?.netSavings ?? 0))
                            .financialLabel()
                            .padding(.horizontal, PremiumSpacing.medium)
                    }

                    VStack(alignment: .leading, spacing: PremiumSpacing.tiny) {
                        TrustEnhancedKPICard(
                            title: "Savings Rate",
                            value: nil,
                            percentage: Double(truncating: ((viewModel.kpis?.savingsRate ?? 0) * 100) as NSNumber),
                            icon: .savingsRate,
                            color: .florijnBlue,
                            trend: nil,
                            cardType: .supporting
                        )

                        Text(savingsRateContextText(Double(truncating: ((viewModel.kpis?.savingsRate ?? 0) * 100) as NSNumber)))
                            .financialLabel()
                            .padding(.horizontal, PremiumSpacing.medium)
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.kpis != nil)
    }

    // MARK: - Charts Section

    private var chartsSection: some View {
        HStack(spacing: PremiumSpacing.large) {
            // Monthly trend chart
            VStack(alignment: .leading, spacing: PremiumSpacing.medium) {
                HStack {
                    GeometricFlowIcon(.income, size: PremiumSpacing.iconSizeSmall)

                    Text("Financial Flow Trends")
                        .font(.headingMedium)
                        .foregroundStyle(Color.florijnCharcoal)

                    Spacer()
                }

                if let trends = viewModel.monthlyTrends, !trends.isEmpty {
                    Chart(trends) { trend in
                        LineMark(
                            x: .value("Month", trend.monthName),
                            y: .value("Income", Double(truncating: trend.income as NSNumber))
                        )
                        .foregroundStyle(Color.florijnGreen.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .symbol(.circle)
                        .symbolSize(60)

                        LineMark(
                            x: .value("Month", trend.monthName),
                            y: .value("Expenses", Double(truncating: trend.expenses as NSNumber))
                        )
                        .foregroundStyle(Color.expenseRed.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .symbol(.square)
                        .symbolSize(60)
                    }
                    .frame(height: 220)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                                .foregroundStyle(Color.florijnLightGray.opacity(0.3))
                            AxisValueLabel()
                                .font(.caption)
                                .foregroundStyle(Color.florijnMediumGray)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                                .foregroundStyle(Color.florijnLightGray.opacity(0.3))
                            AxisValueLabel()
                                .font(.caption)
                                .foregroundStyle(Color.florijnMediumGray)
                        }
                    }
                    .chartLegend {
                        HStack(spacing: PremiumSpacing.medium) {
                            Label("Income", systemImage: "circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.florijnGreen)

                            Label("Expenses", systemImage: "square.fill")
                                .font(.caption)
                                .foregroundStyle(Color.expenseRed)
                        }
                    }
                    .padding(PremiumSpacing.small)
                } else {
                    // Sarah's UX fix: Actionable empty state with clear next steps
                    ContentUnavailableView {
                        VStack(spacing: PremiumSpacing.small) {
                            GeometricFlowIcon(.income, size: 32, color: .incomeGreen)
                            Text("Let's Track Your Money Flow")
                                .font(.headingMedium)
                                .foregroundStyle(Color.florijnCharcoal)
                        }
                    } description: {
                        Text("Import your bank statements to see where your money comes from and goes. This helps you understand your financial patterns.")
                            .font(.body)
                            .foregroundStyle(Color.florijnMediumGray)
                            .multilineTextAlignment(.center)
                    } actions: {
                        Button {
                            // TODO: Navigate to import view
                        } label: {
                            HStack(spacing: PremiumSpacing.small) {
                                Image(systemName: "square.and.arrow.down")
                                Text("Import Bank Statements")
                            }
                        }
                        .premiumPrimaryButton()
                    }
                    .frame(height: 220)
                }
            }
            .padding(PremiumSpacing.large)
            .premiumCard()

            // Enhanced category breakdown with sophisticated styling
            VStack(alignment: .leading, spacing: PremiumSpacing.medium) {
                HStack {
                    GeometricFlowIcon(.expenses, size: PremiumSpacing.iconSizeSmall)

                    Text("Top Spending")
                        .font(.headingMedium)
                        .foregroundStyle(Color.florijnCharcoal)

                    Spacer()
                }

                if let categories = viewModel.categorySummaries?.prefix(5) {
                    VStack(spacing: PremiumSpacing.small) {
                        ForEach(Array(categories)) { category in
                            HStack(spacing: PremiumSpacing.small) {
                                Circle()
                                    .fill(categoryColor(category.category))
                                    .frame(width: 10, height: 10)
                                    .shadow(color: categoryColor(category.category).opacity(0.3), radius: 2)

                                Text(category.category)
                                    .font(.body)
                                    .foregroundStyle(Color.florijnDarkGray)
                                    .lineLimit(1)

                                Spacer()

                                PremiumAnimatedNumber(
                                    category.totalAmount,
                                    font: .bodySmall,
                                    color: .florijnCharcoal
                                )
                            }
                            .padding(.vertical, PremiumSpacing.tiny)
                        }
                    }
                    .padding(.top, PremiumSpacing.small)
                } else {
                    // Sarah's UX fix: Guide users to categorization success
                    ContentUnavailableView {
                        VStack(spacing: PremiumSpacing.small) {
                            GeometricFlowIcon(.expenses, size: 32, color: .expenseRed)
                            Text("Discover Your Spending Patterns")
                                .font(.headingMedium)
                                .foregroundStyle(Color.florijnCharcoal)
                        }
                    } description: {
                        Text("Categorize your transactions to see which areas consume most of your money. This reveals opportunities to save.")
                            .font(.body)
                            .foregroundStyle(Color.florijnMediumGray)
                            .multilineTextAlignment(.center)
                    } actions: {
                        Button {
                            // TODO: Navigate to rules/categorization
                        } label: {
                            HStack(spacing: PremiumSpacing.small) {
                                Image(systemName: "tag")
                                Text("Set Up Categories")
                            }
                        }
                        .premiumSecondaryButton()
                    }
                    .frame(height: 220)
                }
            }
            .padding(PremiumSpacing.large)
            .premiumCard()
        }
    }

    // MARK: - Premium Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: PremiumSpacing.medium) {
            HStack {
                GeometricFlowIcon(.saved, size: PremiumSpacing.iconSizeSmall)

                Text("Budget vs Actual")
                    .font(.headingMedium)
                    .foregroundStyle(Color.florijnCharcoal)

                Spacer()

                Text("\(viewModel.categorySummaries?.count ?? 0) categories")
                    .font(.caption)
                    .foregroundStyle(Color.florijnMediumGray)
                    .padding(.horizontal, PremiumSpacing.small)
                    .padding(.vertical, PremiumSpacing.tiny)
                    .background(Color.florijnLightGray.opacity(0.5))
                    .clipShape(Capsule())
            }

            if let categories = viewModel.categorySummaries {
                LazyVStack(spacing: PremiumSpacing.small) {
                    ForEach(categories.prefix(10)) { category in
                        CategoryRow(category: category)
                            .padding(.vertical, PremiumSpacing.tiny)
                    }
                }
            } else {
                // Sarah's UX fix: Meaningful loading state
                ContentUnavailableView {
                    VStack(spacing: PremiumSpacing.small) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Organizing Your Spending")
                            .font(.bodyLarge)
                            .foregroundStyle(Color.florijnCharcoal)
                    }
                } description: {
                    Text("Grouping transactions by category to show your financial priorities")
                        .font(.body)
                        .foregroundStyle(Color.florijnMediumGray)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 120)
            }
        }
        .padding(PremiumSpacing.large)
        .premiumCard()
    }

    // MARK: - Premium Accounts Section

    private var accountsSection: some View {
        Group {
            // Only show accounts section if there are accounts with actual data
            if let accounts = viewModel.accountBalances, !accounts.isEmpty {
                VStack(alignment: .leading, spacing: PremiumSpacing.medium) {
                    HStack {
                        GeometricFlowIcon(.saved, size: PremiumSpacing.iconSizeSmall, color: .tealSecure)

                        Text("Account Balances")
                            .font(.headingMedium)
                            .foregroundStyle(Color.florijnCharcoal)

                        Spacer()

                        Text("\(accounts.count)")
                            .font(.caption)
                            .foregroundStyle(Color.florijnMediumGray)
                            .padding(.horizontal, PremiumSpacing.small)
                            .padding(.vertical, PremiumSpacing.tiny)
                            .background(Color.tealSecure.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    LazyVStack(spacing: PremiumSpacing.small) {
                        ForEach(accounts) { account in
                            AccountRow(account: account)
                                .padding(.vertical, PremiumSpacing.tiny)
                        }
                    }
                }
                .padding(PremiumSpacing.large)
                .premiumCard()
            } else {
                // Enhanced empty state with sophisticated styling
                ContentUnavailableView {
                    VStack(spacing: PremiumSpacing.medium) {
                        GeometricFlowIcon(.saved, size: 48, color: .florijnMediumGray)
                        Text("No Bank Accounts")
                            .font(.headingLarge)
                            .foregroundStyle(Color.florijnCharcoal)
                    }
                } description: {
                    Text("Import your bank statements to see account balances and track your financial progress")
                        .font(.body)
                        .foregroundStyle(Color.florijnMediumGray.opacity(0.8))
                        .multilineTextAlignment(.center)
                } actions: {
                    Button {
                        // TODO: Navigate to import view
                    } label: {
                        HStack(spacing: PremiumSpacing.small) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import Statements")
                        }
                    }
                    .buttonStyle(PremiumPrimaryButtonStyle())
                }
                .padding(PremiumSpacing.xlarge)
                .premiumCard()
            }
        }
    }

    // MARK: - Premium Net Worth Section

    private var netWorthSection: some View {
        VStack(alignment: .leading, spacing: PremiumSpacing.large) {
            HStack {
                GeometricFlowIcon(.savingsRate, size: PremiumSpacing.iconSizeSmall)

                Text("Financial Position")
                    .font(.headingMedium)
                    .foregroundStyle(Color.florijnCharcoal)

                Spacer()
            }

            if let netWorth = viewModel.netWorth {
                HStack(spacing: PremiumSpacing.xlarge) {
                    // Assets
                    VStack(alignment: .leading, spacing: PremiumSpacing.small) {
                        Text("Assets")
                            .font(.caption)
                            .foregroundStyle(Color.florijnMediumGray)

                        PremiumAnimatedNumber(
                            netWorth.assets,
                            font: .currencyMedium,
                            color: .florijnGreen
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Liabilities
                    VStack(alignment: .leading, spacing: PremiumSpacing.small) {
                        Text("Liabilities")
                            .font(.caption)
                            .foregroundStyle(Color.florijnMediumGray)

                        PremiumAnimatedNumber(
                            netWorth.liabilities,
                            font: .currencyMedium,
                            color: .expenseRed
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Divider with sophisticated styling
                    Rectangle()
                        .fill(Color.florijnLightGray.opacity(0.5))
                        .frame(width: 1, height: 50)

                    // Net Worth (Hero)
                    VStack(alignment: .leading, spacing: PremiumSpacing.small) {
                        Text("Net Worth")
                            .font(.caption)
                            .foregroundStyle(Color.florijnMediumGray)

                        PremiumAnimatedNumber(
                            netWorth.netWorth,
                            font: .currencyLarge,
                            color: netWorth.netWorth >= 0 ? .florijnGreen : .florijnRed
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, PremiumSpacing.medium)
            } else {
                ContentUnavailableView {
                    VStack(spacing: PremiumSpacing.small) {
                        GeometricFlowIcon(.savingsRate, size: 32, color: .florijnMediumGray)
                        Text("Calculating Net Worth")
                            .font(.bodyLarge)
                            .foregroundStyle(Color.florijnMediumGray)
                    }
                } description: {
                    Text("Import account data to calculate your financial position")
                        .font(.body)
                        .foregroundStyle(Color.florijnMediumGray.opacity(0.8))
                }
                .frame(height: 120)
            }
        }
        .padding(PremiumSpacing.large)
        .heroCard()
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
        formatter.locale = Locale.current
        return formatter.monthSymbols[month - 1].capitalized
    }

    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 5)...currentYear).reversed()
    }

    private func categoryColor(_ categoryName: String) -> Color {
        // Use cached color from view model instead of expensive hash calculation in view
        return viewModel.getCachedCategoryColor(for: categoryName)
    }

    // MARK: - Sarah's Context Functions: Financial Intelligence

    private func incomeContextText(_ income: Decimal) -> String {
        let amount = NSDecimalNumber(decimal: income).doubleValue

        if selectedMonth > 0 {
            let dailyRate = amount / 30
            if amount == 0 {
                return "Add income transactions to track your earnings"
            } else {
                return String(format: "≈ €%.0f per day this month", dailyRate)
            }
        } else {
            let monthlyAverage = amount / 12
            if amount == 0 {
                return "Import bank data to see your annual income"
            } else {
                return String(format: "≈ €%.0f average per month", monthlyAverage)
            }
        }
    }

    private func expenseContextText(_ expenses: Decimal) -> String {
        let amount = NSDecimalNumber(decimal: expenses).doubleValue

        if selectedMonth > 0 {
            let dailyBurn = amount / 30
            if amount == 0 {
                return "No expenses recorded this month"
            } else if dailyBurn > 100 {
                return String(format: "€%.0f daily spending rate", dailyBurn)
            } else {
                return String(format: "€%.0f daily spending (moderate)", dailyBurn)
            }
        } else {
            let monthlyAverage = amount / 12
            if amount == 0 {
                return "Add expense transactions to track spending"
            } else {
                return String(format: "€%.0f monthly average", monthlyAverage)
            }
        }
    }

    private func savingsContextText(_ savings: Decimal) -> String {
        let amount = NSDecimalNumber(decimal: savings).doubleValue

        if amount > 0 {
            if selectedMonth > 0 {
                return "Great job staying in the green this month! 💚"
            } else {
                let monthlyRate = amount / 12
                return String(format: "€%.0f saved per month on average", monthlyRate)
            }
        } else if amount == 0 {
            return "Breaking even - income matches expenses"
        } else {
            return "Spending more than earning - time to review expenses"
        }
    }

    private func savingsRateContextText(_ percentage: Double) -> String {
        if percentage >= 20 {
            return "Excellent savings rate! You're building wealth 🚀"
        } else if percentage >= 15 {
            return "Good savings rate - on track for financial goals"
        } else if percentage >= 10 {
            return "Decent savings - consider increasing to 15%+"
        } else if percentage >= 5 {
            return "Low savings rate - aim for at least 10%"
        } else if percentage > 0 {
            return "Very low savings - consider expense review"
        } else {
            return "Negative savings - spending exceeds income"
        }
    }
}

// MARK: - Helper Components

// Note: EnhancedKPICard removed - using PremiumKPICard from design system instead

// MARK: - Legacy Components (Updated for Premium Design System)
// Note: Removed redundant EnhancedKPICard, AnimatedNumber structs - using PremiumAnimatedNumber and PremiumKPICard instead

// MARK: - Removed AnimatedPercentage (redundant with PremiumAnimatedNumber)

// MARK: - Category Row Component

struct CategoryRow: View {
    let category: CategorySummary

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(category.category)
                    .font(.body)
                    .foregroundStyle(Color.florijnCharcoal)

                Spacer()

                Text(category.totalAmount.toCurrencyString())
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(category.isOverBudget ? Color.florijnRed : Color.florijnCharcoal)

                if let budget = category.budget {
                    Text("/ \(budget.toCurrencyString())")
                        .font(.caption)
                        .foregroundStyle(Color.gray)
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
            return Color.green
        } else if percentage < 100 {
            return Color.orange
        } else {
            return Color.red
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
                    .font(.body)
                    .foregroundStyle(Color.florijnCharcoal)

                Text(account.owner)
                    .font(.caption)
                    .foregroundStyle(Color.gray)
            }

            Spacer()

            Text(account.balance.toCurrencyString())
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(Color.florijnCharcoal)
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

    // MARK: - Performance Optimizations (Alex's fixes)

    // Category color cache - prevents expensive hash calculation in view
    private var categoryColorCache: [String: Color] = [:]

    // Data cache to prevent repeated queries
    private var dataCache: [String: CachedDashboardData] = [:]
    private let cacheExpiry: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    init(queryService: TransactionQueryService) {
        self.queryService = queryService
    }

    // MARK: - Data Loading (Optimized by Alex)

    func loadData(filter: TransactionFilter, year: Int) async {
        let cacheKey = "\(filter.year ?? 0)-\(filter.month ?? 0)"

        // Check cache first (Alex's optimization)
        if let cachedData = dataCache[cacheKey],
           !cachedData.isExpired {
            // Use cached data
            kpis = cachedData.kpis
            categorySummaries = cachedData.categorySummaries
            monthlyTrends = cachedData.monthlyTrends
            accountBalances = cachedData.accountBalances
            netWorth = cachedData.netWorth
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Alex's optimization: Instead of 5 concurrent queries, load in logical groups
            // Group 1: Core financial metrics (can be optimized into single query)
            async let coreDataTask = loadCoreFinancialData(filter: filter)
            // Group 2: Account data (less frequent changes)
            async let accountDataTask = loadAccountData()
            // Group 3: Trends (year-based, can be cached longer)
            async let trendsTask = queryService.getMonthlyTrends(year: year)

            let (coreData, accountData, trends) = try await (coreDataTask, accountDataTask, trendsTask)

            // Update state
            kpis = coreData.kpis
            categorySummaries = coreData.categories
            accountBalances = accountData.accounts
            netWorth = accountData.netWorth
            monthlyTrends = trends

            // Cache the results (Alex's optimization)
            dataCache[cacheKey] = CachedDashboardData(
                kpis: kpis,
                categorySummaries: categorySummaries,
                monthlyTrends: monthlyTrends,
                accountBalances: accountBalances,
                netWorth: netWorth,
                timestamp: Date()
            )

        } catch {
            errorMessage = "Failed to load dashboard data: \(error.localizedDescription)"
            print("Dashboard loading error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Optimized Data Loading Helpers

    private func loadCoreFinancialData(filter: TransactionFilter) async throws -> (kpis: DashboardKPIs, categories: [CategorySummary]) {
        // Future optimization: Single query for both KPIs and categories
        async let kpisTask = queryService.getDashboardKPIs(filter: filter)
        async let categoriesTask = queryService.getCategorySummaries(filter: filter)
        return try await (kpisTask, categoriesTask)
    }

    private func loadAccountData() async throws -> (accounts: [AccountBalance], netWorth: NetWorth) {
        // Account data changes less frequently - can be cached longer
        async let accountsTask = queryService.getAccountBalances()
        async let netWorthTask = queryService.getNetWorth()
        return try await (accountsTask, netWorthTask)
    }

    // MARK: - Performance Utilities

    /// Get cached category color to prevent expensive hash calculation in view
    func getCachedCategoryColor(for categoryName: String) -> Color {
        if let cachedColor = categoryColorCache[categoryName] {
            return cachedColor
        }

        // Calculate once and cache
        let hash = categoryName.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        let color = Color(hue: hue, saturation: 0.7, brightness: 0.8)
        categoryColorCache[categoryName] = color
        return color
    }

    /// Clear error message
    func dismissError() {
        errorMessage = nil
    }
}

// MARK: - Performance Data Structures (Alex's optimization)

struct CachedDashboardData {
    let kpis: DashboardKPIs?
    let categorySummaries: [CategorySummary]?
    let monthlyTrends: [MonthlyTrend]?
    let accountBalances: [AccountBalance]?
    let netWorth: NetWorth?
    let timestamp: Date

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 300 // 5 minutes
    }
}
