//
//  OptimizedTransactionsListView.swift
//  Family Finance
//
//  High-performance transaction list optimized for 15k+ records
//  Features: Database-level filtering, pagination, virtualized scrolling, search debouncing
//
//  Created: 2025-12-24
//

import SwiftUI
@preconcurrency import SwiftData

// MARK: - High-Performance Transactions List View

struct OptimizedTransactionsListView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: TransactionsListViewModel

    // MARK: - State

    @State private var searchText = ""
    @State private var selectedType: TransactionType? = nil
    @State private var selectedCategory: String? = nil
    @State private var selectedAccount: String? = nil
    @State private var selectedTransaction: Transaction?
    @State private var showingAddSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var transactionToDelete: Transaction?
    @State private var searchDebouncer = Debouncer()

    // MARK: - Data

    @Query(sort: \Account.iban) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    // MARK: - Computed Properties

    private var expenseCategories: [String] {
        categories.filter { $0.type == .expense }.map(\.name)
    }

    private var incomeCategories: [String] {
        categories.filter { $0.type == .income }.map(\.name)
    }

    // MARK: - Initialization

    init() {
        // Initialize with placeholder - will be set in onAppear
        let placeholder = TransactionQueryService(modelContext: ModelContext(try! ModelContainer(for: Transaction.self)))
        _viewModel = StateObject(wrappedValue: TransactionsListViewModel(queryService: placeholder))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header with search and filters
            headerSection

            Divider()

            // Main content
            ZStack {
                if viewModel.isLoading && viewModel.transactions.isEmpty {
                    // Initial loading state
                    ProgressView("Loading transactions...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.transactions.isEmpty {
                    // Empty state
                    ContentUnavailableView(
                        "No Transactions Found",
                        systemImage: "list.bullet.rectangle",
                        description: Text(hasActiveFilters ? "Try adjusting your filters" : "Import CSV files to get started")
                    )
                } else {
                    // Optimized transaction list
                    transactionsList
                }

                // Loading overlay for pagination
                if viewModel.isLoading && !viewModel.transactions.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading more...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            setupViewModel()
        }
        .onChange(of: searchText) { _, newValue in
            // Debounced search
            searchDebouncer.debounce(delay: 0.3) {
                Task { @MainActor in
                    await applyFilters()
                }
            }
        }
        .onChange(of: selectedType) { _, _ in
            Task { await applyFilters() }
        }
        .onChange(of: selectedCategory) { _, _ in
            Task { await applyFilters() }
        }
        .onChange(of: selectedAccount) { _, _ in
            Task { await applyFilters() }
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
        }
        .sheet(isPresented: $showingAddSheet) {
            TransactionEditorSheet(accounts: accounts, categories: categories) { newTransaction in
                modelContext.insert(newTransaction)
                try? modelContext.save()
                Task { await viewModel.refresh() }
            }
        }
        .alert("Delete Transaction", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let transaction = transactionToDelete {
                    modelContext.delete(transaction)
                    try? modelContext.save()
                    Task { await viewModel.refresh() }
                }
            }
        } message: {
            Text("Are you sure you want to delete this transaction? This cannot be undone.")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Transactions")
                    .font(.system(size: 28, weight: .bold))

                Spacer()

                // Statistics
                Group {
                    if viewModel.hasMorePages {
                        Text("\(viewModel.transactions.count)+ of \(viewModel.totalCount ?? 0)")
                    } else {
                        Text("\(viewModel.transactions.count) transactions")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Button(action: { showingAddSheet = true }) {
                    Label("Add Transaction", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            // Filter controls
            VStack(spacing: 12) {
                // Search and quick filters
                HStack(spacing: 12) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search transactions...", text: $searchText)
                            .textFieldStyle(.plain)

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty)

                    // Type filter
                    Picker("Type", selection: $selectedType) {
                        Text("All Types").tag(nil as TransactionType?)
                        Text("Income").tag(TransactionType.income as TransactionType?)
                        Text("Expenses").tag(TransactionType.expense as TransactionType?)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                // Advanced filters
                HStack(spacing: 12) {
                    // Category filter
                    Picker("Category", selection: $selectedCategory) {
                        Text("All Categories").tag(nil as String?)
                        if !expenseCategories.isEmpty {
                            Section("Expense Categories") {
                                ForEach(expenseCategories, id: \.self) { category in
                                    Text(category).tag(category as String?)
                                }
                            }
                        }
                        if !incomeCategories.isEmpty {
                            Section("Income Categories") {
                                ForEach(incomeCategories, id: \.self) { category in
                                    Text(category).tag(category as String?)
                                }
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 180)

                    // Account filter
                    Picker("Account", selection: $selectedAccount) {
                        Text("All Accounts").tag(nil as String?)
                        ForEach(accounts, id: \.iban) { account in
                            Text(account.name).tag(account.iban as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)

                    Spacer()

                    // Clear filters button
                    if hasActiveFilters {
                        Button("Clear Filters") {
                            clearAllFilters()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Transactions List

    private var transactionsList: some View {
        ScrollViewReader { proxy in
            List {
                // Performance Note: LazyVStack inside List provides virtual scrolling
                // for large datasets while maintaining SwiftUI's List benefits
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.transactions) { transaction in
                        OptimizedTransactionRowView(
                            transaction: transaction,
                            isSelected: selectedTransaction?.id == transaction.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTransaction = transaction
                        }
                        .contextMenu {
                            contextMenuItems(for: transaction)
                        }
                        .onAppear {
                            // Pagination trigger
                            if transaction == viewModel.transactions.last {
                                Task { await viewModel.loadNextPage() }
                            }
                        }
                    }

                    // Load more indicator
                    if viewModel.hasMorePages {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading more transactions...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding()
                        .onAppear {
                            Task { await viewModel.loadNextPage() }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.transactions.count)
            }
            .listStyle(.plain)
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for transaction: Transaction) -> some View {
        Button("View Details") {
            selectedTransaction = transaction
        }

        Button("Duplicate") {
            duplicateTransaction(transaction)
        }

        Divider()

        Button("Delete", role: .destructive) {
            transactionToDelete = transaction
            showingDeleteConfirmation = true
        }
    }

    // MARK: - Computed Properties

    private var hasActiveFilters: Bool {
        !searchText.isEmpty || selectedType != nil ||
        selectedCategory != nil || selectedAccount != nil
    }

    // MARK: - Helper Methods

    private func setupViewModel() {
        let queryService = TransactionQueryService(modelContext: modelContext)
        viewModel.queryService = queryService
        Task { await viewModel.initialLoad() }
    }

    @MainActor
    private func applyFilters() async {
        let filter = buildCurrentFilter()
        await viewModel.applyFilter(filter)
    }

    private func buildCurrentFilter() -> TransactionFilter {
        var filter = TransactionFilter()

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            filter.searchText = searchText
        }

        if let type = selectedType {
            filter.transactionType = type
        }

        if let category = selectedCategory {
            filter.categories = [category]
        }

        if let account = selectedAccount {
            filter.accounts = [account]
        }

        return filter
    }

    private func clearAllFilters() {
        searchText = ""
        selectedType = nil
        selectedCategory = nil
        selectedAccount = nil
    }

    private func duplicateTransaction(_ transaction: Transaction) {
        let duplicate = Transaction(
            iban: transaction.iban,
            sequenceNumber: Int(Date().timeIntervalSince1970 * 1000) % 1000000,
            date: Date(),
            amount: transaction.amount,
            balance: transaction.balance,
            counterIBAN: transaction.counterIBAN,
            counterName: transaction.counterName,
            standardizedName: transaction.standardizedName,
            description1: transaction.description1,
            description2: transaction.description2,
            description3: transaction.description3,
            transactionCode: transaction.transactionCode,
            categoryOverride: transaction.categoryOverride,
            transactionType: transaction.transactionType,
            account: transaction.account
        )

        modelContext.insert(duplicate)
        try? modelContext.save()
        Task { await viewModel.refresh() }
    }
}

// MARK: - Optimized Transaction Row View

struct OptimizedTransactionRowView: View {
    let transaction: Transaction
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Type indicator with optimized rendering
            Image(systemName: transaction.transactionType.icon)
                .font(.title3)
                .foregroundStyle(typeColor)
                .frame(width: 32)

            // Main content
            VStack(alignment: .leading, spacing: 4) {
                // Transaction description
                Text(transaction.standardizedName ?? transaction.counterName ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                // Category and date info
                HStack(spacing: 8) {
                    // Category badge
                    Text(transaction.effectiveCategory)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())

                    // Date
                    Text(transaction.date.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 16)

            // Amount with optimized currency formatting
            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.amount.toCurrencyString())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(amountColor)
                    .monospacedDigit()

                // Account indicator for multi-account scenarios
                if let account = transaction.account {
                    Text(account.name.prefix(4))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var typeColor: Color {
        switch transaction.transactionType {
        case .income: return .green
        case .expense: return .red.opacity(0.8)
        case .transfer: return .blue
        case .unknown: return .gray
        }
    }

    private var amountColor: Color {
        transaction.amount >= 0 ? .green : .primary
    }

    private var rowBackground: Color {
        isSelected ?
            Color.accentColor.opacity(0.1) :
            Color(nsColor: .controlBackgroundColor).opacity(0.5)
    }
}

// MARK: - View Model

@MainActor
class TransactionsListViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var hasMorePages = true
    @Published var totalCount: Int?

    private let pageSize = 100 // Optimize for smooth scrolling
    private var currentPage = 0
    private var currentFilter = TransactionFilter()

    var queryService: TransactionQueryService?

    init(queryService: TransactionQueryService) {
        self.queryService = queryService
    }

    func initialLoad() async {
        currentPage = 0
        transactions = []
        hasMorePages = true
        await loadNextPage()
    }

    func loadNextPage() async {
        guard !isLoading && hasMorePages, let queryService = queryService else { return }

        isLoading = true

        do {
            // Use query service with pagination
            var paginatedFilter = currentFilter
            let skip = currentPage * pageSize

            let newTransactions = try await queryService.getTransactionsPaginated(
                filter: paginatedFilter,
                offset: skip,
                limit: pageSize
            )

            if newTransactions.isEmpty || newTransactions.count < pageSize {
                hasMorePages = false
            }

            transactions.append(contentsOf: newTransactions)
            currentPage += 1

            // Get total count on first load
            if totalCount == nil {
                totalCount = try await queryService.getTransactionsCount(filter: currentFilter)
            }

        } catch {
            print("Failed to load transactions: \(error)")
        }

        isLoading = false
    }

    func applyFilter(_ filter: TransactionFilter) async {
        currentFilter = filter
        currentPage = 0
        transactions = []
        hasMorePages = true
        totalCount = nil
        await loadNextPage()
    }

    func refresh() async {
        currentPage = 0
        transactions = []
        hasMorePages = true
        totalCount = nil
        await loadNextPage()
    }
}

// MARK: - Search Debouncer

class Debouncer {
    private var workItem: DispatchWorkItem?

    func debounce(delay: TimeInterval, action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }
}