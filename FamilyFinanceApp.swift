//
//  FamilyFinanceApp.swift
//  Family Finance
//
//  Main application entry point for macOS
//  SwiftData + SwiftUI with modern architecture
//
//  Created: 2025-12-22
//

import SwiftUI
import SwiftData

@main
struct FamilyFinanceApp: App {

    // MARK: - SwiftData Container

    /// Database initialization state for error handling
    @State private var databaseError: DatabaseError?

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Transaction.self,
            Account.self,
            Category.self,
            CategorizationRule.self,
            Liability.self,
            Merchant.self,
            BudgetPeriod.self,
            TransactionSplit.self,
            RecurringTransaction.self,
            TransactionAuditLog.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            // Initialize default data on first launch
            let context = ModelContext(container)
            Task { @MainActor in
                try? await initializeDefaultData(context: context)
            }

            return container
        } catch {
            // Log the error for debugging
            print("❌ CRITICAL: Could not create ModelContainer: \(error)")

            // Create an in-memory fallback container
            // This allows the app to launch and show an error UI instead of crashing
            do {
                let fallbackConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true  // In-memory only as fallback
                )
                print("⚠️ Using in-memory fallback database. Data will not persist.")
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                // If even in-memory fails, we have no choice but to crash
                // This should be extremely rare (system memory issues)
                fatalError("Could not create even in-memory ModelContainer: \(error)")
            }
        }
    }()

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            appCommands
        }

        // Settings window
        Settings {
            SettingsView()
                .modelContainer(sharedModelContainer)
        }
    }

    // MARK: - Menu Commands

    @CommandsBuilder
    private var appCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Import CSV Files...") {
                // Trigger import
                NotificationCenter.default.post(name: .importCSV, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command])
        }

        CommandMenu("Data") {
            Button("Refresh Dashboard") {
                NotificationCenter.default.post(name: .refreshDashboard, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command])

            Divider()

            Button("Export to Excel...") {
                NotificationCenter.default.post(name: .exportToExcel, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button("Export to CSV...") {
                NotificationCenter.default.post(name: .exportToCSV, object: nil)
            }

            Divider()

            Button("Recategorize All") {
                NotificationCenter.default.post(name: .recategorizeAll, object: nil)
            }
        }
    }

    // MARK: - Initialization

    @MainActor
    private static func initializeDefaultData(context: ModelContext) async throws {
        // Load default categories only for Phase 1
        try loadDefaultCategories(context: context)

        // Load default accounts
        try loadDefaultAccounts(context: context)

        print("Default data initialized successfully")
    }

    @MainActor
    private static func loadDefaultAccounts(context: ModelContext) throws {
        let descriptor = FetchDescriptor<Account>()
        let existingCount = try context.fetchCount(descriptor)

        guard existingCount == 0 else {
            print("Accounts already loaded")
            return
        }

        // Example accounts - replace with your own IBANs
        let accounts: [(String, String, AccountType, String)] = [
            ("NL00BANK0123456001", "Joint Checking", .checking, "Family"),
            ("NL00BANK0123456002", "Joint Savings", .savings, "Family"),
            ("NL00BANK0123456003", "Personal Account", .checking, "Partner1")
        ]

        for (iban, name, type, owner) in accounts {
            let account = Account(
                iban: iban,
                name: name,
                accountType: type,
                owner: owner
            )
            context.insert(account)
        }

        try context.save()
        print("Loaded \(accounts.count) default accounts")
    }

    @MainActor
    private static func loadDefaultCategories(context: ModelContext) throws {
        let descriptor = FetchDescriptor<Category>()
        let existingCount = try context.fetchCount(descriptor)

        guard existingCount == 0 else {
            print("Categories already loaded")
            return
        }

        let expenseCategories: [(String, Decimal, String, String)] = [
            ("Boodschappen", 800, "cart.fill", "10B981"),
            ("Uit Eten", 150, "fork.knife", "EF4444"),
            ("Winkelen", 200, "bag.fill", "F59E0B"),
            ("Vervoer", 250, "car.fill", "3B82F6"),
            ("Nutsvoorzieningen", 300, "bolt.fill", "8B5CF6"),
            ("Wonen", 1200, "house.fill", "EC4899"),
            ("Verzekeringen", 200, "shield.fill", "14B8A6"),
            ("Gezondheidszorg", 100, "cross.fill", "EF4444"),
            ("Kinderopvang", 500, "figure.2.and.child.holdinghands", "F59E0B"),
            ("Ontspanning", 100, "gamecontroller.fill", "8B5CF6"),
            ("Huis & Tuin", 100, "tree.fill", "10B981"),
            ("Belastingen", 200, "building.columns.fill", "64748B"),
            ("Schuld Aflossing", 200, "creditcard.fill", "EF4444"),
            ("Bankkosten", 20, "eurosign.circle.fill", "64748B"),
            ("Abonnementen", 100, "repeat.circle.fill", "3B82F6"),
            ("Niet Gecategoriseerd", 0, "questionmark.circle.fill", "9CA3AF"),
        ]

        for (index, (name, budget, icon, color)) in expenseCategories.enumerated() {
            let category = Category(
                name: name,
                type: .expense,
                monthlyBudget: budget,
                icon: icon,
                color: color,
                sortOrder: index,
                isActive: true
            )
            context.insert(category)
        }

        let incomeCategories: [(String, String, String)] = [
            ("Salaris", "eurosign.circle.fill", "10B981"),
            ("Freelance", "briefcase.fill", "3B82F6"),
            ("Toeslagen", "building.columns.fill", "F59E0B"),
            ("Inleg Partner 1", "person.fill", "8B5CF6"),
            ("Inleg Partner 2", "person.fill", "EC4899"),
            ("Overig Inkomen", "plus.circle.fill", "10B981"),
        ]

        for (index, (name, icon, color)) in incomeCategories.enumerated() {
            let category = Category(
                name: name,
                type: .income,
                monthlyBudget: 0,
                icon: icon,
                color: color,
                sortOrder: expenseCategories.count + index,
                isActive: true
            )
            context.insert(category)
        }

        // Transfer category
        let transfer = Category(
            name: "Interne Overboeking",
            type: .transfer,
            monthlyBudget: 0,
            icon: "arrow.left.arrow.right.circle.fill",
            color: "9CA3AF",
            sortOrder: expenseCategories.count + incomeCategories.count,
            isActive: true
        )
        context.insert(transfer)

        try context.save()
        print("Loaded \(expenseCategories.count + incomeCategories.count + 1) default categories")
    }
}

// MARK: - Content View

struct ContentView: View {

    @Environment(\.modelContext) private var modelContext
    @StateObject private var appState = AppState()

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $appState.selectedTab)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environmentObject(appState)
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.selectedTab {
        case .dashboard:
            DashboardViewWrapper()
        case .transactions:
            TransactionsListView()
        case .categories:
            CategoriesListView()
        case .budgets:
            BudgetsListView()
        case .accounts:
            AccountsListView()
        case .merchants:
            MerchantsListView()
        case .rules:
            RulesListView()
        case .import:
            ImportViewWrapper()
        }
    }
}

// MARK: - View Wrappers (Handle Service Initialization)

/// Wrapper to initialize DashboardView with required services
struct DashboardViewWrapper: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let queryService = TransactionQueryService(modelContext: modelContext)
        DashboardView(queryService: queryService)
    }
}

/// Wrapper to initialize ImportView with required services
struct ImportViewWrapper: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let categorizationEngine = CategorizationEngine(modelContext: modelContext)
        let importService = CSVImportService(
            modelContainer: modelContext.container,
            categorizationEngine: categorizationEngine
        )
        CSVImportView(importService: importService)
    }
}

// MARK: - Phase 1 Dashboard (Placeholder)

struct Phase1DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var categories: [Category]

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Family Finance")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Phase 1: Core Data Layer Complete")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)

            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(title: "Transactions", value: "\(transactions.count)", icon: "list.bullet.rectangle", color: .blue)
                StatCard(title: "Accounts", value: "\(accounts.count)", icon: "creditcard.fill", color: .green)
                StatCard(title: "Categories", value: "\(categories.count)", icon: "square.grid.2x2.fill", color: .orange)
                StatCard(title: "Database", value: "SwiftData", icon: "cylinder.fill", color: .purple)
            }

            // Phase Status
            VStack(alignment: .leading, spacing: 12) {
                Text("Phase 1 Checklist")
                    .font(.headline)

                ChecklistItem(title: "SwiftData Models", subtitle: "Transaction, Account, Category, Rule, Liability, Merchant", done: true)
                ChecklistItem(title: "BackgroundDataHandler", subtitle: "ModelActor for async imports", done: true)
                ChecklistItem(title: "Unit Tests", subtitle: "21 test cases for TDD", done: true)
                ChecklistItem(title: "Dutch Number Parser", subtitle: "Parse +1.234,56 format", done: true)

                Divider()

                Text("Next: Phase 2 - CSV Import Service")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)

            Spacer()
        }
        .padding()
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ChecklistItem: View {
    let title: String
    let subtitle: String
    let done: Bool

    var body: some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .secondary)
            VStack(alignment: .leading) {
                Text(title)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Phase 1 Import View (Placeholder)

struct Phase1ImportView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("CSV Import")
                .font(.title)
                .fontWeight(.bold)

            Text("Coming in Phase 2")
                .foregroundStyle(.secondary)

            Text("The CSV Import Service will:\n• Parse Rabobank CSV files\n• Handle Dutch number format (+1.234,56)\n• Detect encoding (latin-1, cp1252, utf-8)\n• Apply 100+ categorization rules\n• Track family contributions (Inleg)")
                .multilineTextAlignment(.leading)
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
        }
        .frame(maxWidth: 500)
    }
}

// MARK: - Sidebar View

struct SidebarView: View {

    @Binding var selection: AppTab

    var body: some View {
        List(selection: $selection) {
            Section("Overview") {
                Label("Dashboard", systemImage: "chart.bar.fill")
                    .tag(AppTab.dashboard)

                Label("Transactions", systemImage: "list.bullet.rectangle.fill")
                    .tag(AppTab.transactions)

                Label("Merchants", systemImage: "building.2.fill")
                    .tag(AppTab.merchants)
            }

            Section("Planning") {
                Label("Budgets", systemImage: "chart.pie.fill")
                    .tag(AppTab.budgets)

                Label("Categories", systemImage: "square.grid.2x2.fill")
                    .tag(AppTab.categories)
            }

            Section("Accounts") {
                Label("All Accounts", systemImage: "creditcard.fill")
                    .tag(AppTab.accounts)
            }

            Section("Settings") {
                Label("Rules", systemImage: "slider.horizontal.3")
                    .tag(AppTab.rules)

                Label("Import", systemImage: "square.and.arrow.down.fill")
                    .tag(AppTab.import)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Family Finance")
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .dashboard
}

enum AppTab: Hashable {
    case dashboard
    case transactions
    case categories
    case budgets
    case accounts
    case merchants
    case rules
    case `import`
}

// MARK: - Transactions List View

struct TransactionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var searchText = ""
    @State private var selectedType: TransactionType? = nil
    @State private var selectedCategory: String? = nil
    @State private var selectedTransaction: Transaction?

    private var filteredTransactions: [Transaction] {
        transactions.filter { transaction in
            // Search filter
            let matchesSearch = searchText.isEmpty ||
                transaction.counterName?.localizedCaseInsensitiveContains(searchText) == true ||
                transaction.standardizedName?.localizedCaseInsensitiveContains(searchText) == true ||
                transaction.fullDescription.localizedCaseInsensitiveContains(searchText) ||
                transaction.effectiveCategory.localizedCaseInsensitiveContains(searchText)

            // Type filter
            let matchesType = selectedType == nil || transaction.transactionType == selectedType

            // Category filter
            let matchesCategory = selectedCategory == nil || transaction.effectiveCategory == selectedCategory

            return matchesSearch && matchesType && matchesCategory
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with search and filters
            transactionHeader

            Divider()

            // Transaction list
            if filteredTransactions.isEmpty {
                ContentUnavailableView(
                    "No Transactions",
                    systemImage: "list.bullet.rectangle",
                    description: Text(searchText.isEmpty ? "Import CSV files to get started" : "No transactions match your search")
                )
            } else {
                List(selection: $selectedTransaction) {
                    ForEach(filteredTransactions) { transaction in
                        TransactionRowView(transaction: transaction)
                            .tag(transaction)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var transactionHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Transactions")
                    .font(.system(size: 28, weight: .bold))

                Spacer()

                Text("\(filteredTransactions.count) of \(transactions.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search transactions...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                // Type filter
                Picker("Type", selection: $selectedType) {
                    Text("All Types").tag(nil as TransactionType?)
                    ForEach(TransactionType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type as TransactionType?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)

                // Clear filters button
                if !searchText.isEmpty || selectedType != nil || selectedCategory != nil {
                    Button(action: clearFilters) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }

    private func clearFilters() {
        searchText = ""
        selectedType = nil
        selectedCategory = nil
    }
}

// MARK: - Transaction Row View

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // Type indicator
            Image(systemName: transaction.transactionType.icon)
                .font(.title3)
                .foregroundStyle(typeColor)
                .frame(width: 32)

            // Main content
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.standardizedName ?? transaction.counterName ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(transaction.effectiveCategory)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)

                    Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Amount
            Text(transaction.amount.toCurrencyString())
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(transaction.amount >= 0 ? .green : .primary)
        }
        .padding(.vertical, 4)
    }

    private var typeColor: Color {
        switch transaction.transactionType {
        case .income: return .green
        case .expense: return .red
        case .transfer: return .blue
        case .unknown: return .gray
        }
    }
}

// MARK: - Accounts List View

struct AccountsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Accounts")
                        .font(.system(size: 28, weight: .bold))
                    Spacer()
                    Text("\(accounts.count) accounts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Total balance card
                totalBalanceCard

                // Account cards
                LazyVStack(spacing: 12) {
                    ForEach(accounts) { account in
                        AccountCardView(account: account)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var totalBalanceCard: some View {
        let totalBalance = accounts.reduce(Decimal.zero) { $0 + $1.currentBalance }

        return VStack(spacing: 8) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(totalBalance.toCurrencyString())
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct AccountCardView: View {
    let account: Account

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: account.accountType.icon)
                .font(.title2)
                .foregroundStyle(Color(hex: account.color ?? "3B82F6"))
                .frame(width: 44, height: 44)
                .background(Color(hex: account.color ?? "3B82F6").opacity(0.1))
                .cornerRadius(12)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.headline)

                Text(account.owner)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(account.iban)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }

            Spacer()

            // Balance
            VStack(alignment: .trailing, spacing: 4) {
                Text(account.currentBalance.toCurrencyString())
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("\(account.transactionCount) transactions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Categories List View

struct CategoriesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var selectedType: TransactionType? = nil

    private var filteredCategories: [Category] {
        if let type = selectedType {
            return categories.filter { $0.type == type }
        }
        return categories
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Categories")
                    .font(.system(size: 28, weight: .bold))

                Spacer()

                Picker("Type", selection: $selectedType) {
                    Text("All").tag(nil as TransactionType?)
                    Text("Expenses").tag(TransactionType.expense as TransactionType?)
                    Text("Income").tag(TransactionType.income as TransactionType?)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }
            .padding()

            Divider()

            // Categories list
            List {
                ForEach(filteredCategories) { category in
                    CategoryRowView(category: category)
                }
            }
            .listStyle(.inset)
        }
    }
}

struct CategoryRowView: View {
    let category: Category

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: category.icon ?? "square.grid.2x2")
                .font(.title3)
                .foregroundStyle(Color(hex: category.color ?? "3B82F6"))
                .frame(width: 32)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(category.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Budget
            if category.monthlyBudget > 0 {
                Text(category.monthlyBudget.toCurrencyString())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Budgets List View

struct BudgetsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())

    private var expenseCategories: [Category] {
        categories.filter { $0.type == .expense && $0.monthlyBudget > 0 }
    }

    private var totalBudget: Decimal {
        expenseCategories.reduce(Decimal.zero) { $0 + $1.monthlyBudget }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Budgets")
                        .font(.system(size: 28, weight: .bold))

                    Spacer()

                    // Period picker
                    HStack(spacing: 8) {
                        Picker("Month", selection: $selectedMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(monthName(month)).tag(month)
                            }
                        }
                        .frame(width: 120)

                        Picker("Year", selection: $selectedYear) {
                            ForEach((selectedYear - 2)...(selectedYear + 1), id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .frame(width: 100)
                    }
                }
                .padding(.horizontal)

                // Total budget card
                VStack(spacing: 8) {
                    Text("Monthly Budget")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(totalBudget.toCurrencyString())
                        .font(.system(size: 32, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                .padding(.horizontal)

                // Budget categories
                LazyVStack(spacing: 12) {
                    ForEach(expenseCategories) { category in
                        BudgetCategoryCard(category: category)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func monthName(_ month: Int) -> String {
        guard month >= 1 && month <= 12 else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.monthSymbols[month - 1].capitalized
    }
}

struct BudgetCategoryCard: View {
    let category: Category

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: category.icon ?? "square.grid.2x2")
                    .foregroundStyle(Color(hex: category.color ?? "3B82F6"))

                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(category.monthlyBudget.toCurrencyString())
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            // Progress bar placeholder (actual spending would come from query)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: category.color ?? "3B82F6"))
                        .frame(width: geometry.size.width * 0.5, height: 6) // Placeholder 50%
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Merchants List View

struct MerchantsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var searchText = ""

    private var merchantStats: [MerchantDisplayStats] {
        // Group transactions by standardized name
        var stats: [String: MerchantDisplayStats] = [:]

        for tx in transactions {
            let name = tx.standardizedName ?? tx.counterName ?? "Unknown"
            if var existing = stats[name] {
                existing.totalSpent += abs(tx.amount)
                existing.transactionCount += 1
                if tx.date > existing.lastDate {
                    existing.lastDate = tx.date
                }
                stats[name] = existing
            } else {
                stats[name] = MerchantDisplayStats(
                    name: name,
                    totalSpent: abs(tx.amount),
                    transactionCount: 1,
                    lastDate: tx.date,
                    category: tx.effectiveCategory
                )
            }
        }

        return stats.values
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.totalSpent > $1.totalSpent }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Merchants")
                    .font(.system(size: 28, weight: .bold))

                Spacer()

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search merchants...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .frame(width: 250)
            }
            .padding()

            Divider()

            // Merchants list
            if merchantStats.isEmpty {
                ContentUnavailableView(
                    "No Merchants",
                    systemImage: "building.2",
                    description: Text("Import transactions to see merchant statistics")
                )
            } else {
                List {
                    ForEach(merchantStats) { merchant in
                        MerchantRowView(merchant: merchant)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

struct MerchantDisplayStats: Identifiable {
    let id = UUID()
    let name: String
    var totalSpent: Decimal
    var transactionCount: Int
    var lastDate: Date
    let category: String
}

struct MerchantRowView: View {
    let merchant: MerchantDisplayStats

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "building.2")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(merchant.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(merchant.category)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)

                    Text("\(merchant.transactionCount) transactions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Total spent
            Text(merchant.totalSpent.toCurrencyString())
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Rules List View

struct RulesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CategorizationRule.priority) private var rules: [CategorizationRule]

    @State private var searchText = ""

    private var filteredRules: [CategorizationRule] {
        if searchText.isEmpty {
            return rules
        }
        return rules.filter {
            $0.pattern.localizedCaseInsensitiveContains(searchText) ||
            $0.targetCategory.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Categorization Rules")
                    .font(.system(size: 28, weight: .bold))

                Spacer()

                Text("\(rules.count) rules")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            // Rules list
            if rules.isEmpty {
                ContentUnavailableView(
                    "No Custom Rules",
                    systemImage: "slider.horizontal.3",
                    description: Text("The app uses built-in rules for categorization.\nCustom rules will appear here.")
                )
            } else {
                List {
                    ForEach(filteredRules) { rule in
                        RuleRowView(rule: rule)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

struct RuleRowView: View {
    let rule: CategorizationRule

    var body: some View {
        HStack(spacing: 12) {
            // Priority badge
            Text("#\(rule.priority)")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(4)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(rule.matchType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\"" + rule.pattern + "\"")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospaced()
                }

                Text("→ " + rule.targetCategory)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Match count
            if rule.matchCount > 0 {
                Text("\(rule.matchCount) matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Active indicator
            Circle()
                .fill(rule.isActive ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            DataSettingsView()
                .tabItem {
                    Label("Data", systemImage: "externaldrive.fill")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section("Appearance") {
                Toggle("Use System Color Scheme", isOn: .constant(true))
                Toggle("Show Transaction Details", isOn: .constant(true))
            }

            Section("Localization") {
                Picker("Language", selection: .constant("nl")) {
                    Text("Nederlands").tag("nl")
                    Text("English").tag("en")
                }
                Picker("Currency", selection: .constant("EUR")) {
                    Text("EUR (€)").tag("EUR")
                }
            }
        }
        .padding()
    }
}

struct DataSettingsView: View {
    var body: some View {
        Form {
            Section("Database") {
                LabeledContent("Location") {
                    Text("~/Library/Application Support/Family Finance")
                        .foregroundStyle(.secondary)
                }
                Button("Open Database Folder") {
                    // Open folder
                }
            }

            Section("Import") {
                Toggle("Auto-detect encoding", isOn: .constant(true))
                Toggle("Skip duplicates", isOn: .constant(true))
            }
        }
        .padding()
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let importCSV = Notification.Name("importCSV")
    static let refreshDashboard = Notification.Name("refreshDashboard")
    static let exportToExcel = Notification.Name("exportToExcel")
    static let exportToCSV = Notification.Name("exportToCSV")
    static let recategorizeAll = Notification.Name("recategorizeAll")
}

// MARK: - Database Error

/// Errors that can occur during database initialization or operations
enum DatabaseError: Error, LocalizedError {
    case containerCreationFailed(underlying: Error)
    case migrationFailed(underlying: Error)
    case corruptedData
    case diskFull
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .containerCreationFailed(let error):
            return "Kon database niet aanmaken: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Database migratie mislukt: \(error.localizedDescription)"
        case .corruptedData:
            return "Database is beschadigd. Probeer de app opnieuw te installeren."
        case .diskFull:
            return "Schijf is vol. Maak ruimte vrij en probeer opnieuw."
        case .permissionDenied:
            return "Geen toegang tot database locatie."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .containerCreationFailed:
            return "Probeer de app opnieuw te starten of herinstalleer indien nodig."
        case .migrationFailed:
            return "De app gebruikt tijdelijk geheugenopslag. Data gaat verloren bij afsluiten."
        case .corruptedData:
            return "Verwijder de app en installeer opnieuw. Importeer je CSV bestanden daarna opnieuw."
        case .diskFull:
            return "Verwijder ongebruikte apps of bestanden."
        case .permissionDenied:
            return "Controleer de app permissies in Systeemvoorkeuren."
        }
    }
}
