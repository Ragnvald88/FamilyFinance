//
//  BudgetManagementView.swift
//  Florijn
//
//  Budget management with month/year navigation, progress tracking,
//  and visual spending indicators per category
//
//  Replaces BudgetsListView from FlorijnApp.swift
//
//  Created: 2026-02-10
//

import SwiftUI
import SwiftData

// MARK: - Budget Management View

struct BudgetManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var viewModel = BudgetManagementViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: PremiumSpacing.large) {
                // Header with navigation
                headerSection

                // Overall budget summary card
                overallSummaryCard

                // Budget category cards
                if viewModel.expenseCategoriesWithBudget(categories).isEmpty {
                    emptyState
                } else {
                    categoryCardsSection
                }
            }
            .padding(.vertical)
        }
        .background(Color.adaptiveBackground)
        .onAppear {
            Task { await loadBudgetData() }
        }
        .onChange(of: viewModel.selectedYear) { _, _ in
            Task { await loadBudgetData() }
        }
        .onChange(of: viewModel.selectedMonth) { _, _ in
            Task { await loadBudgetData() }
        }
        .sheet(isPresented: $viewModel.showingAddBudget) {
            AddBudgetSheet(categories: viewModel.expenseCategoriesWithoutBudget(categories))
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("Budgets")
                .font(.headingLarge)
                .foregroundStyle(Color.adaptivePrimary)

            Spacer()

            // Add budget button
            Button {
                viewModel.showingAddBudget = true
            } label: {
                Label("Add Budget", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.expenseCategoriesWithoutBudget(categories).isEmpty)
            .accessibilityLabel("Add new budget")

            // Month navigation
            monthNavigator
        }
        .padding(.horizontal)
    }

    private var monthNavigator: some View {
        HStack(spacing: PremiumSpacing.small) {
            Button {
                viewModel.navigateBackward()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            Button {
                viewModel.navigateToCurrentMonth()
            } label: {
                Text(viewModel.periodDisplayString)
                    .font(.bodyLarge)
                    .monospacedDigit()
                    .frame(minWidth: 150)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Current period: \(viewModel.periodDisplayString). Click to go to current month.")

            Button {
                viewModel.navigateForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")

            // Pickers for direct selection
            Picker("Month", selection: $viewModel.selectedMonth) {
                ForEach(1...12, id: \.self) { month in
                    Text(viewModel.monthName(month)).tag(month)
                }
            }
            .frame(width: 120)
            .accessibilityLabel("Select month")

            Picker("Year", selection: $viewModel.selectedYear) {
                ForEach((viewModel.selectedYear - 2)...(viewModel.selectedYear + 1), id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .frame(width: 100)
            .accessibilityLabel("Select year")
        }
    }

    // MARK: - Overall Summary Card

    private var overallSummaryCard: some View {
        let totalBudget = viewModel.totalBudget(for: categories)
        let totalSpent = viewModel.totalSpent(for: viewModel.categorySummaries)
        let percentage = viewModel.progressPercentage(spent: totalSpent, budget: totalBudget)
        let level = viewModel.spendingLevel(percentage: percentage)

        return VStack(spacing: PremiumSpacing.medium) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Budget")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveSecondary)
                    Text(totalBudget.toCurrencyString())
                        .font(.currencyLarge)
                        .foregroundStyle(Color.adaptivePrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Spent")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveSecondary)
                    Text(totalSpent.toCurrencyString())
                        .font(.currencyLarge)
                        .foregroundStyle(totalSpent > totalBudget ? Color.florijnRed : Color.adaptivePrimary)
                }
            }

            // Overall progress bar
            if totalBudget > 0 {
                VStack(spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.adaptiveSecondary.opacity(0.15))
                                .frame(height: 10)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(level.color)
                                .frame(
                                    width: min(geometry.size.width, geometry.size.width * CGFloat(min(percentage, 1.0))),
                                    height: 10
                                )
                        }
                    }
                    .frame(height: 10)

                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: level.icon)
                                .font(.caption2)
                                .foregroundStyle(level.color)
                            Text("\(Int(percentage * 100))% used")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveSecondary)
                        }

                        Spacer()

                        if totalSpent > totalBudget {
                            Text("\((totalSpent - totalBudget).toCurrencyString()) over budget")
                                .font(.caption)
                                .foregroundStyle(Color.florijnRed)
                        } else {
                            Text("\((totalBudget - totalSpent).toCurrencyString()) remaining")
                                .font(.caption)
                                .foregroundStyle(Color.florijnGreen)
                        }
                    }
                }
            }
        }
        .padding(PremiumSpacing.large)
        .background(Color.adaptiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: PremiumSpacing.cardCornerRadius)
                .stroke(Color.subtleBorder, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Budget overview: \(totalSpent.toCurrencyString()) of \(totalBudget.toCurrencyString()) spent")
    }

    // MARK: - Category Cards

    private var categoryCardsSection: some View {
        LazyVStack(spacing: PremiumSpacing.medium) {
            ForEach(viewModel.expenseCategoriesWithBudget(categories)) { category in
                let summary = viewModel.categorySummaries.first { $0.category == category.name }
                BudgetCategoryCard(category: category, summary: summary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: PremiumSpacing.medium) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "chart.pie")
                .font(.system(size: 56))
                .foregroundStyle(Color.adaptiveTertiary)

            Text("No Budgets Set")
                .font(.headingLarge)
                .foregroundStyle(Color.adaptivePrimary)

            Text("Set budgets for your expense categories to track spending progress")
                .font(.body)
                .foregroundStyle(Color.adaptiveSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button("Add Budget") {
                viewModel.showingAddBudget = true
            }
            .buttonStyle(PremiumPrimaryButtonStyle())
            .disabled(viewModel.expenseCategoriesWithoutBudget(categories).isEmpty)
            .padding(.top, PremiumSpacing.small)

            Spacer()
                .frame(height: 60)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Data Loading

    @MainActor
    private func loadBudgetData() async {
        viewModel.isLoading = true
        let filter = TransactionFilter(year: viewModel.selectedYear, month: viewModel.selectedMonth)
        let queryService = TransactionQueryService(modelContext: modelContext)

        do {
            viewModel.categorySummaries = try await queryService.getCategorySummaries(filter: filter)
        } catch {
            print("Error loading budget data: \(error)")
            viewModel.categorySummaries = []
        }
        viewModel.isLoading = false
    }
}

// MARK: - Budget Category Card

struct BudgetCategoryCard: View {
    let category: Category
    let summary: CategorySummary?

    @State private var isEditing = false
    @State private var editedBudget = ""
    @State private var isHovered = false
    @Environment(\.modelContext) private var modelContext

    private var spentAmount: Decimal {
        summary?.totalAmount ?? 0
    }

    private var progressPercentage: Double {
        guard category.monthlyBudget > 0 else { return 0 }
        return Double(truncating: (spentAmount / category.monthlyBudget) as NSNumber)
    }

    private var clampedPercentage: Double {
        min(progressPercentage, 1.0)
    }

    private var isOverBudget: Bool {
        spentAmount > category.monthlyBudget
    }

    private var progressColor: Color {
        if progressPercentage >= 1.0 {
            return .red
        } else if progressPercentage >= 0.8 {
            return .orange
        } else {
            return Color(hex: category.color ?? "3B82F6")
        }
    }

    var body: some View {
        VStack(spacing: PremiumSpacing.medium) {
            // Top row: icon, name, amounts
            HStack {
                // Category icon
                Image(systemName: category.icon ?? "square.grid.2x2")
                    .font(.title3)
                    .foregroundStyle(Color(hex: category.color ?? "3B82F6"))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: category.color ?? "3B82F6").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptivePrimary)
                        .lineLimit(1)

                    if let count = summary?.transactionCount, count > 0 {
                        Text("\(count) transactions")
                            .font(.caption2)
                            .foregroundStyle(Color.adaptiveTertiary)
                    }
                }

                Spacer()

                // Amounts
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(spentAmount.toCurrencyString())
                            .font(.currencySmall)
                            .foregroundStyle(isOverBudget ? Color.florijnRed : Color.adaptivePrimary)

                        Text("/")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTertiary)

                        if isEditing {
                            TextField("Budget", text: $editedBudget)
                                .font(.caption)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .onSubmit { saveBudgetEdit() }
                        } else {
                            Button {
                                startEditing()
                            } label: {
                                Text(category.monthlyBudget.toCurrencyString())
                                    .font(.currencySmall)
                                    .foregroundStyle(Color.florijnBlue)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit budget for \(category.name): \(category.monthlyBudget.toCurrencyString())")
                        }
                    }

                    if isEditing {
                        HStack(spacing: 4) {
                            Button("Save") { saveBudgetEdit() }
                                .font(.caption2)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)

                            Button("Cancel") { cancelEditing() }
                                .font(.caption2)
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                        }
                    }
                }
            }

            // Progress bar
            VStack(spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.adaptiveSecondary.opacity(0.15))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor)
                            .frame(width: geometry.size.width * clampedPercentage, height: 8)
                    }
                }
                .frame(height: 8)

                // Status row
                HStack {
                    Text("\(Int(progressPercentage * 100))% used")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveSecondary)

                    Spacer()

                    if isOverBudget {
                        let overAmount = spentAmount - category.monthlyBudget
                        Text("\(overAmount.toCurrencyString()) over")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.florijnRed)
                    } else {
                        let remaining = category.monthlyBudget - spentAmount
                        Text("\(remaining.toCurrencyString()) remaining")
                            .font(.caption2)
                            .foregroundStyle(Color.florijnGreen)
                    }
                }
            }
        }
        .padding(PremiumSpacing.medium)
        .background(Color.adaptiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.subtleBorder, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(isHovered ? 0.12 : 0.06), radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.subtleHover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Remove Budget") {
                removeBudget()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.name): \(spentAmount.toCurrencyString()) of \(category.monthlyBudget.toCurrencyString()) budget, \(Int(progressPercentage * 100)) percent used")
        .accessibilityValue(isOverBudget ? "Over budget" : "Within budget")
    }

    // MARK: - Budget Editing

    private func startEditing() {
        isEditing = true
        editedBudget = String(describing: category.monthlyBudget)
    }

    private func saveBudgetEdit() {
        guard let newBudget = Decimal(string: editedBudget.replacingOccurrences(of: ",", with: ".")) else {
            cancelEditing()
            return
        }

        category.monthlyBudget = newBudget
        try? modelContext.save()
        isEditing = false
    }

    private func cancelEditing() {
        isEditing = false
        editedBudget = ""
    }

    private func removeBudget() {
        category.monthlyBudget = 0
        try? modelContext.save()
    }
}

// MARK: - Budget Editor Sheet

struct BudgetEditorSheet: View {
    let categoryName: String
    let year: Int
    let month: Int
    let initialAmount: Decimal
    let onSave: (Decimal) -> Void

    @State private var amountText: String
    @Environment(\.dismiss) private var dismiss

    init(categoryName: String, year: Int, month: Int, initialAmount: Decimal, onSave: @escaping (Decimal) -> Void) {
        self.categoryName = categoryName
        self.year = year
        self.month = month
        self.initialAmount = initialAmount
        self.onSave = onSave
        _amountText = State(initialValue: initialAmount > 0 ? String(describing: initialAmount) : "")
    }

    private func monthName(_ month: Int) -> String {
        guard month >= 1, month <= 12 else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.monthSymbols[month - 1].capitalized
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Text("Edit Budget")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    if let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")) {
                        onSave(amount)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(amountText.isEmpty)
            }
            .padding()

            Divider()

            Form {
                Section {
                    HStack {
                        Text("Category")
                        Spacer()
                        Text(categoryName)
                            .foregroundStyle(Color.adaptiveSecondary)
                    }

                    HStack {
                        Text("Period")
                        Spacer()
                        Text("\(monthName(month)) \(year)")
                            .foregroundStyle(Color.adaptiveSecondary)
                    }
                }

                Section("Monthly Budget Amount") {
                    TextField("Amount", text: $amountText)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 400, height: 280)
    }
}

// MARK: - Add Budget Sheet

struct AddBudgetSheet: View {
    let categories: [Category]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedCategory: Category?
    @State private var budgetAmount: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Text("Add Budget")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    saveBudget()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedCategory == nil || budgetAmount.isEmpty)
            }
            .padding()

            Divider()

            Form {
                Section {
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select category").tag(nil as Category?)
                        ForEach(categories) { category in
                            HStack {
                                Image(systemName: category.icon ?? "square.grid.2x2")
                                    .foregroundStyle(Color(hex: category.color ?? "3B82F6"))
                                Text(category.name)
                            }.tag(category as Category?)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Select category for budget")
                }

                Section("Monthly Budget Amount") {
                    TextField("Amount", text: $budgetAmount)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Monthly budget amount")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 400, height: 300)
    }

    private func saveBudget() {
        guard let category = selectedCategory,
              let amount = Decimal(string: budgetAmount.replacingOccurrences(of: ",", with: ".")) else {
            return
        }

        category.monthlyBudget = amount
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    BudgetManagementView()
        .modelContainer(for: [
            Category.self, Transaction.self, Account.self,
            BudgetPeriod.self, TransactionSplit.self,
            RecurringTransaction.self, TransactionAuditLog.self,
            RuleGroup.self, Rule.self, RuleTrigger.self, RuleAction.self
        ])
        .frame(width: 900, height: 700)
}
