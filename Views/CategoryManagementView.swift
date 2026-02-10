//
//  CategoryManagementView.swift
//  Florijn
//
//  Enhanced category management with financial health indicators,
//  search/filtering, and educational micro-tips
//
//  Replaces CategoriesListView from FlorijnApp.swift
//
//  Created: 2026-02-10
//

import SwiftUI
import SwiftData

// MARK: - Category Management View

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var transactions: [Transaction]

    @State private var viewModel = CategoryManagementViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header with search and filter
            headerSection

            Divider()

            // Main content
            if viewModel.filteredCategories(categories).isEmpty {
                emptyState
            } else {
                categoryList
            }
        }
        .sheet(isPresented: $viewModel.showingCategoryEditor) {
            CategoryEditorSheet(category: viewModel.editingCategory) { savedCategory in
                if viewModel.editingCategory == nil {
                    modelContext.insert(savedCategory)
                }
                try? modelContext.save()
                viewModel.editingCategory = nil
            }
        }
        .alert("Delete Category", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.categoryToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let category = viewModel.categoryToDelete {
                    modelContext.delete(category)
                    try? modelContext.save()
                }
                viewModel.categoryToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this category? Transactions using this category will be set to 'Uncategorized'.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: PremiumSpacing.medium) {
            HStack {
                Text("Categories")
                    .font(.headingLarge)
                    .foregroundStyle(Color.adaptivePrimary)

                Spacer()

                Button {
                    viewModel.editingCategory = nil
                    viewModel.showingCategoryEditor = true
                } label: {
                    Label("Add Category", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Add new category")
            }

            HStack(spacing: PremiumSpacing.medium) {
                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.adaptiveTertiary)
                    TextField("Search categories...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .accessibilityLabel("Search categories")

                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.adaptiveTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(8)
                .background(Color.adaptiveSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.subtleBorder, lineWidth: 0.5)
                }

                // Filter picker
                Picker("Filter", selection: $viewModel.selectedFilter) {
                    ForEach(CategoryManagementViewModel.CategoryFilter.allCases) { filter in
                        Label(filter.rawValue, systemImage: filter.icon)
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 450)
                .accessibilityLabel("Category filter")
            }
        }
        .padding()
    }

    // MARK: - Category List

    private var categoryList: some View {
        List {
            ForEach(viewModel.filteredCategories(categories)) { category in
                CategoryHealthRow(
                    category: category,
                    health: healthForCategory(category),
                    onEdit: {
                        viewModel.editingCategory = category
                        viewModel.showingCategoryEditor = true
                    }
                )
                .contextMenu {
                    Button("Edit") {
                        viewModel.editingCategory = category
                        viewModel.showingCategoryEditor = true
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        viewModel.categoryToDelete = category
                        viewModel.showingDeleteConfirmation = true
                    }
                }
            }
            .onDelete(perform: deleteCategories)
        }
        .listStyle(.inset)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: PremiumSpacing.medium) {
            Spacer()

            Image(systemName: "square.grid.2x2")
                .font(.system(size: 56))
                .foregroundStyle(Color.adaptiveTertiary)

            Text("No Categories Found")
                .font(.headingLarge)
                .foregroundStyle(Color.adaptivePrimary)

            if !viewModel.searchText.isEmpty {
                Text("No categories match \"\(viewModel.searchText)\"")
                    .font(.body)
                    .foregroundStyle(Color.adaptiveSecondary)
            } else {
                Text("Create your first category to organize your transactions")
                    .font(.body)
                    .foregroundStyle(Color.adaptiveSecondary)
                    .multilineTextAlignment(.center)
            }

            if viewModel.searchText.isEmpty {
                Button("Create Category") {
                    viewModel.editingCategory = nil
                    viewModel.showingCategoryEditor = true
                }
                .buttonStyle(PremiumPrimaryButtonStyle())
                .padding(.top, PremiumSpacing.small)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Helpers

    /// Calculates the health for a category based on current month's transactions.
    private func healthForCategory(_ category: Category) -> CategoryManagementViewModel.CategoryHealth {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        // Sum absolute amounts for expense transactions matching this category in current month
        let spent = transactions
            .filter { transaction in
                transaction.effectiveCategory == category.name &&
                transaction.year == currentYear &&
                transaction.month == currentMonth &&
                transaction.amount < 0
            }
            .reduce(Decimal.zero) { $0 + abs($1.amount) }

        return viewModel.calculateCategoryHealth(for: category, spent: spent)
    }

    private func deleteCategories(at offsets: IndexSet) {
        let filtered = viewModel.filteredCategories(categories)
        for index in offsets {
            modelContext.delete(filtered[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Category Health Row

struct CategoryHealthRow: View {
    let category: Category
    let health: CategoryManagementViewModel.CategoryHealth
    let onEdit: () -> Void

    @State private var isHovered = false
    @State private var showTip = false

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: category.icon ?? "square.grid.2x2")
                .font(.title3)
                .foregroundStyle(Color(hex: category.color ?? "3B82F6"))
                .frame(width: 36, height: 36)
                .background(Color(hex: category.color ?? "3B82F6").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            // Category info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(category.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptivePrimary)

                    Text(category.type.displayName)
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.adaptiveSurface)
                        .clipShape(Capsule())
                }

                if category.monthlyBudget > 0 {
                    Text("Budget: \(category.monthlyBudget.toCurrencyString())")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveSecondary)
                }
            }

            Spacer()

            // Health indicator (only for categories with budgets)
            if category.monthlyBudget > 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    FinancialHealthIndicator(health: health, compact: true)

                    if showTip {
                        Text(health.microTip)
                            .font(.caption2)
                            .foregroundStyle(Color.adaptiveSecondary)
                            .frame(maxWidth: 200, alignment: .trailing)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .onTapGesture {
                    withAnimation(.premiumSpring) {
                        showTip.toggle()
                    }
                }
                .accessibilityLabel(health.rating.accessibilityLabel)
                .accessibilityHint("Tap to show financial tip")
            }

            // Edit button on hover
            Button("Edit") {
                onEdit()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .opacity(isHovered ? 1 : 0)
            .accessibilityLabel("Edit \(category.name)")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.subtleHover) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            onEdit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.name), \(category.type.displayName)")
        .accessibilityValue(category.monthlyBudget > 0 ?
            "Budget \(category.monthlyBudget.toCurrencyString()), \(health.rating.rawValue)" :
            "No budget set")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double-tap to edit")
    }
}

// MARK: - Preview

#Preview {
    CategoryManagementView()
        .modelContainer(for: [
            Category.self, Transaction.self, Account.self,
            RuleGroup.self, Rule.self, RuleTrigger.self, RuleAction.self
        ])
        .frame(width: 900, height: 600)
}
