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
import Charts
@preconcurrency import SwiftData

// MARK: - Design Tokens (App Store Quality Design System)

struct DesignTokens {
    struct Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
    }

    struct CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
    }

    struct Shadow {
        static let primary = ShadowStyle(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        static let secondary = ShadowStyle(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        static let elevated = ShadowStyle(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    struct Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
        static let springFast = SwiftUI.Animation.spring(response: 0.2, dampingFraction: 0.8)
        static let springSlow = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let numberTicker = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.7)
    }

    struct Opacity {
        static let light: Double = 0.1
        static let medium: Double = 0.2
        static let strong: Double = 0.3
        static let overlay: Double = 0.8
    }

    struct Typography {
        static let display = Font.system(size: 32, weight: .bold)
        static let largeTitle = Font.system(size: 28, weight: .bold)
        static let title = Font.system(size: 24, weight: .semibold)
        static let headline = Font.headline.weight(.semibold)
        static let body = Font.body
        static let subheadline = Font.subheadline
        static let caption = Font.caption
        static let caption2 = Font.caption2
        static let currencyLarge = Font.title2.monospacedDigit().weight(.bold)
    }

    struct Colors {
        static let income = Color.green
        static let expense = Color.red.opacity(0.85)
        static let success = Color.green
        static let error = Color.red
        static let cardBackground = Color(nsColor: .controlBackgroundColor)
        static let windowBackground = Color(nsColor: .windowBackgroundColor)
    }
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func primaryCard() -> some View {
        self
            .background(DesignTokens.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large))
            .shadow(
                color: DesignTokens.Shadow.primary.color,
                radius: DesignTokens.Shadow.primary.radius,
                x: DesignTokens.Shadow.primary.x,
                y: DesignTokens.Shadow.primary.y
            )
    }

    func staggeredAppearance(index: Int, totalItems: Int) -> some View {
        self
            .opacity(1)
            .offset(y: 0)
            .animation(
                DesignTokens.Animation.spring.delay(Double(index) * 0.05),
                value: true
            )
    }
}

struct AnimatedNumber: View {
    let value: Decimal
    let font: Font

    @State private var displayValue: Decimal = 0

    var body: some View {
        Text(displayValue.toCurrencyString())
            .font(font)
            .monospacedDigit()
            .onChange(of: value) { _, newValue in
                withAnimation(DesignTokens.Animation.numberTicker) {
                    displayValue = newValue
                }
            }
            .onAppear {
                withAnimation(DesignTokens.Animation.numberTicker.delay(0.3)) {
                    displayValue = value
                }
            }
    }
}

struct SkeletonCard: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.m) {
            HStack {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                    .fill(Color.gray.opacity(isAnimating ? 0.3 : 0.2))
                    .frame(width: 24, height: 24)

                Spacer()

                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                    .fill(Color.gray.opacity(isAnimating ? 0.2 : 0.1))
                    .frame(width: 60, height: 16)
            }

            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                .fill(Color.gray.opacity(isAnimating ? 0.4 : 0.3))
                .frame(height: 24)
                .frame(maxWidth: 120, alignment: .leading)

            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                .fill(Color.gray.opacity(isAnimating ? 0.2 : 0.1))
                .frame(height: 12)
                .frame(maxWidth: 80, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.l)
        .primaryCard()
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
            ) {
                isAnimating.toggle()
            }
        }
    }
}

@main
struct FamilyFinanceApp: App {

    // MARK: - Environment Detection

    /// Check if running in unit test environment
    private static var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }

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

        // Use in-memory database for tests to avoid file system issues
        let isInMemory = isRunningTests

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isInMemory,
            allowsSave: true
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            // Skip initialization for tests - they manage their own data
            if !isRunningTests {
                let context = ModelContext(container)
                Task { @MainActor in
                    try? await initializeDefaultData(context: context)

                    // Phase 2.2: Run data integrity validation on startup
                    let integrityService = DataIntegrityService(modelContext: context)
                    let report = try? await integrityService.performStartupValidation()
                    if let report = report, report.hasIssues {
                        print("Data integrity: \(report.summary)")
                    }
                }
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

        // NOTE: Removed auto-creation of default accounts for better empty state UX
        // Users should only see accounts after importing their own data
        // try loadDefaultAccounts(context: context)

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
            OptimizedTransactionsViewWrapper()
        case .transfers:
            TransfersListView()
        case .categories:
            CategoriesListView()
        case .budgets:
            BudgetsListView()
        case .accounts:
            AccountsListView()
        case .merchants:
            MerchantsListView()
        case .insights:
            InsightsViewWrapper()
        case .rules:
            RulesListView()
        case .import:
            ImportViewWrapper()
        }
    }
}

// MARK: - View Wrappers (Handle Service Initialization)

/// Wrapper to initialize DashboardView with required services
/// Uses @State to avoid recreating services on each render (fixes state mutation warning)
struct DashboardViewWrapper: View {
    @Environment(\.modelContext) private var modelContext
    @State private var queryService: TransactionQueryService?

    var body: some View {
        Group {
            if let service = queryService {
                DashboardView(queryService: service)
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        queryService = TransactionQueryService(modelContext: modelContext)
                    }
            }
        }
    }
}

/// Wrapper to initialize ImportView with required services
/// Uses @State to avoid recreating services on each render (fixes state mutation warning)
struct ImportViewWrapper: View {
    @Environment(\.modelContext) private var modelContext
    @State private var importService: CSVImportService?

    var body: some View {
        Group {
            if let service = importService {
                CSVImportView(importService: service)
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        let categorizationEngine = CategorizationEngine(modelContext: modelContext)
                        importService = CSVImportService(
                            modelContainer: modelContext.container,
                            categorizationEngine: categorizationEngine
                        )
                    }
            }
        }
    }
}

/// Wrapper to initialize InsightsView with required services
/// Uses @State to avoid recreating services on each render (fixes state mutation warning)
struct InsightsViewWrapper: View {
    @Environment(\.modelContext) private var modelContext
    @State private var queryService: TransactionQueryService?

    var body: some View {
        Group {
            if let service = queryService {
                InsightsView(queryService: service)
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        queryService = TransactionQueryService(modelContext: modelContext)
                    }
            }
        }
    }
}

/// High-performance wrapper for optimized transactions list (15k+ records)
/// Uses pagination, virtualized scrolling, and database-level filtering
struct OptimizedTransactionsViewWrapper: View {
    @Environment(\.modelContext) private var modelContext
    @State private var queryService: TransactionQueryService?

    var body: some View {
        Group {
            if let service = queryService {
                OptimizedTransactionsView(queryService: service)
            } else {
                ProgressView("Loading transactions...")
                    .onAppear {
                        queryService = TransactionQueryService(modelContext: modelContext)
                    }
            }
        }
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

                Label("Transfers", systemImage: "arrow.left.arrow.right")
                    .tag(AppTab.transfers)

                Label("Merchants", systemImage: "building.2.fill")
                    .tag(AppTab.merchants)
            }

            Section("Planning") {
                Label("Budgets", systemImage: "chart.pie.fill")
                    .tag(AppTab.budgets)

                Label("Categories", systemImage: "square.grid.2x2.fill")
                    .tag(AppTab.categories)

                Label("Insights", systemImage: "chart.bar.xaxis")
                    .tag(AppTab.insights)
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
    case transfers
    case categories
    case budgets
    case accounts
    case merchants
    case insights
    case rules
    case `import`
}

// MARK: - Transactions List View

struct TransactionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Account.iban) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var searchText = ""
    @State private var selectedType: TransactionType? = nil
    @State private var selectedCategory: String? = nil
    @State private var selectedTransaction: Transaction?
    @State private var showingAddSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var transactionToDelete: Transaction?

    private var filteredTransactions: [Transaction] {
        transactions.filter { transaction in
            // Exclude transfers from this view (they have their own tab)
            guard transaction.transactionType != .transfer else { return false }

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
                    description: Text(searchText.isEmpty ? "Import CSV files to get started or add a transaction manually" : "No transactions match your search")
                )
            } else {
                List(selection: $selectedTransaction) {
                    ForEach(filteredTransactions) { transaction in
                        TransactionRowView(transaction: transaction)
                            .tag(transaction)
                            .contextMenu {
                                Button("View Details") {
                                    selectedTransaction = transaction
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    transactionToDelete = transaction
                                    showingDeleteConfirmation = true
                                }
                            }
                    }
                    .onDelete(perform: deleteTransactions)
                }
                .listStyle(.inset)
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
        }
        .sheet(isPresented: $showingAddSheet) {
            TransactionEditorSheet(accounts: accounts, categories: categories) { newTransaction in
                modelContext.insert(newTransaction)
                try? modelContext.save()
            }
        }
        .alert("Delete Transaction", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let transaction = transactionToDelete {
                    modelContext.delete(transaction)
                    try? modelContext.save()
                }
            }
        } message: {
            Text("Are you sure you want to delete this transaction? This cannot be undone.")
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

                Button(action: { showingAddSheet = true }) {
                    Label("Add Transaction", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
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

                // Type filter (exclude transfers since they have their own tab)
                Picker("Type", selection: $selectedType) {
                    Text("All Types").tag(nil as TransactionType?)
                    Text("Expenses").tag(TransactionType.expense as TransactionType?)
                    Text("Income").tag(TransactionType.income as TransactionType?)
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

    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredTransactions[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Transaction Editor Sheet

struct TransactionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let accounts: [Account]
    let categories: [Category]
    let onSave: (Transaction) -> Void

    @State private var selectedAccount: Account?
    @State private var date = Date()
    @State private var amount: String = ""
    @State private var transactionType: TransactionType = .expense
    @State private var counterName: String = ""
    @State private var description: String = ""
    @State private var selectedCategory: String = ""
    @State private var notes: String = ""

    private var isValid: Bool {
        selectedAccount != nil && !amount.isEmpty && amountValue != 0
    }

    private var amountValue: Decimal {
        Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var categoryNames: [String] {
        categories.filter { $0.type == transactionType }.map(\.name).sorted()
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

                Text("New Transaction")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    saveTransaction()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Account") {
                    Picker("Account", selection: $selectedAccount) {
                        Text("Select Account").tag(nil as Account?)
                        ForEach(accounts) { account in
                            Text("\(account.name ?? account.iban)")
                                .tag(account as Account?)
                        }
                    }
                }

                Section("Transaction Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    Picker("Type", selection: $transactionType) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)

                    TextField("Amount", text: $amount)
                        .help("Enter a positive number")

                    TextField("Counter Party Name", text: $counterName)
                        .help("Name of the merchant or person")

                    TextField("Description", text: $description)
                }

                Section("Categorization") {
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select Category").tag("")
                        ForEach(categoryNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 550)
        .onAppear {
            // Default to first account if available
            selectedAccount = accounts.first
        }
    }

    private func saveTransaction() {
        guard let account = selectedAccount else { return }

        // Calculate the actual amount (negative for expenses)
        var finalAmount = amountValue
        if transactionType == .expense && finalAmount > 0 {
            finalAmount = -finalAmount
        } else if transactionType == .income && finalAmount < 0 {
            finalAmount = -finalAmount
        }

        // Generate a unique sequence number based on timestamp
        let sequenceNumber = Int(Date().timeIntervalSince1970 * 1000) % 1000000

        let transaction = Transaction(
            iban: account.iban,
            sequenceNumber: sequenceNumber,
            date: date,
            amount: finalAmount,
            balance: account.currentBalance + finalAmount,
            counterName: counterName.isEmpty ? nil : counterName,
            autoCategory: selectedCategory.isEmpty ? "Niet Gecategoriseerd" : selectedCategory,
            transactionType: transactionType
        )

        transaction.description1 = description.isEmpty ? nil : description
        transaction.notes = notes.isEmpty ? nil : notes
        transaction.account = account

        onSave(transaction)
        dismiss()
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
    @State private var showingAddSheet = false
    @State private var editingCategory: Category?
    @State private var showingDeleteConfirmation = false
    @State private var categoryToDelete: Category?

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

                Button(action: { showingAddSheet = true }) {
                    Label("Add Category", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Categories list
            List {
                ForEach(filteredCategories) { category in
                    CategoryRowView(category: category)
                        .contextMenu {
                            Button("Edit") {
                                editingCategory = category
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                categoryToDelete = category
                                showingDeleteConfirmation = true
                            }
                        }
                        .onTapGesture(count: 2) {
                            editingCategory = category
                        }
                }
                .onDelete(perform: deleteCategories)
            }
            .listStyle(.inset)
        }
        .sheet(isPresented: $showingAddSheet) {
            CategoryEditorSheet(category: nil) { newCategory in
                modelContext.insert(newCategory)
                try? modelContext.save()
            }
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditorSheet(category: category) { _ in
                try? modelContext.save()
            }
        }
        .alert("Delete Category", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let category = categoryToDelete {
                    modelContext.delete(category)
                    try? modelContext.save()
                }
            }
        } message: {
            Text("Are you sure you want to delete this category? Transactions using this category will be set to 'Uncategorized'.")
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredCategories[index])
        }
        try? modelContext.save()
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

// MARK: - Category Editor Sheet

struct CategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let category: Category?
    let onSave: (Category) -> Void

    @State private var name: String = ""
    @State private var type: TransactionType = .expense
    @State private var monthlyBudget: String = ""
    @State private var icon: String = "square.grid.2x2"
    @State private var color: String = "3B82F6"
    @State private var sortOrder: Int = 100

    private var isValid: Bool {
        !name.isEmpty
    }

    private var budgetValue: Decimal {
        Decimal(string: monthlyBudget.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    // Common SF Symbols for categories
    private let availableIcons = [
        "cart.fill", "fork.knife", "bag.fill", "car.fill", "house.fill",
        "bolt.fill", "shield.fill", "heart.fill", "gamecontroller.fill",
        "figure.walk", "airplane", "gift.fill", "dollarsign.circle.fill",
        "building.2.fill", "briefcase.fill", "graduationcap.fill",
        "stethoscope", "pawprint.fill", "leaf.fill", "drop.fill",
        "flame.fill", "snowflake", "sun.max.fill", "moon.fill",
        "star.fill", "bell.fill", "tag.fill", "creditcard.fill",
        "banknote.fill", "percent", "chart.bar.fill", "square.grid.2x2"
    ]

    private let availableColors = [
        "3B82F6", "EF4444", "10B981", "F59E0B", "6366F1",
        "EC4899", "8B5CF6", "14B8A6", "F97316", "84CC16"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Text(category == nil ? "New Category" : "Edit Category")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    saveCategory()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $name)

                    Picker("Type", selection: $type) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                    }

                    TextField("Monthly Budget", text: $monthlyBudget)
                        .help("Leave empty for no budget")
                }

                Section("Appearance") {
                    // Icon picker
                    Picker("Icon", selection: $icon) {
                        ForEach(availableIcons, id: \.self) { iconName in
                            Label {
                                Text(iconName.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " ").capitalized)
                            } icon: {
                                Image(systemName: iconName)
                            }
                            .tag(iconName)
                        }
                    }

                    // Color picker
                    HStack {
                        Text("Color")
                        Spacer()
                        ForEach(availableColors, id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: color == colorHex ? 2 : 0)
                                )
                                .onTapGesture {
                                    color = colorHex
                                }
                        }
                    }
                }

                Section("Options") {
                    Stepper("Sort Order: \(sortOrder)", value: $sortOrder, in: 1...1000)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 500)
        .onAppear {
            if let category = category {
                name = category.name
                type = category.type
                if category.monthlyBudget > 0 {
                    monthlyBudget = "\(category.monthlyBudget)"
                }
                icon = category.icon ?? "square.grid.2x2"
                color = category.color ?? "3B82F6"
                sortOrder = category.sortOrder
            }
        }
    }

    private func saveCategory() {
        if let existing = category {
            existing.name = name
            existing.type = type
            existing.monthlyBudget = budgetValue
            existing.icon = icon
            existing.color = color
            existing.sortOrder = sortOrder
            onSave(existing)
        } else {
            let newCategory = Category(
                name: name,
                type: type,
                monthlyBudget: budgetValue,
                sortOrder: sortOrder
            )
            newCategory.icon = icon
            newCategory.color = color
            onSave(newCategory)
        }
        dismiss()
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

// MARK: - Transfers List View

struct TransfersListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var searchText = ""
    @State private var selectedTransaction: Transaction?

    // Filter to only transfers (enum comparison not allowed in @Query predicate)
    private var transfers: [Transaction] {
        allTransactions.filter { $0.transactionType == .transfer }
    }

    private var filteredTransfers: [Transaction] {
        if searchText.isEmpty {
            return transfers
        }
        return transfers.filter { transaction in
            transaction.counterName?.localizedCaseInsensitiveContains(searchText) == true ||
            transaction.standardizedName?.localizedCaseInsensitiveContains(searchText) == true ||
            transaction.effectiveCategory.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Internal Transfers")
                    .font(.system(size: 28, weight: .bold))

                Spacer()

                Text("\(filteredTransfers.count) of \(transfers.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search transfers...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom)

            Divider()

            // Transfers list
            if filteredTransfers.isEmpty {
                ContentUnavailableView(
                    "No Transfers",
                    systemImage: "arrow.left.arrow.right",
                    description: Text("Internal transfers between your accounts will appear here")
                )
            } else {
                List(selection: $selectedTransaction) {
                    ForEach(filteredTransfers) { transaction in
                        TransferRowView(transaction: transaction)
                            .tag(transaction)
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
        }
    }
}

struct TransferRowView: View {
    let transaction: Transaction

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter
    }

    var body: some View {
        HStack(spacing: 12) {
            // Transfer icon
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.standardizedName ?? transaction.counterName ?? "Transfer")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(dateFormatter.string(from: transaction.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Amount (show both directions)
            Text(transaction.amount.toCurrencyString())
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(transaction.amount >= 0 ? .green : .primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Rules List View

struct RulesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CategorizationRule.priority) private var rules: [CategorizationRule]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var editingRule: CategorizationRule?
    @State private var showingDeleteConfirmation = false
    @State private var ruleToDelete: CategorizationRule?

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

                Button(action: { showingAddSheet = true }) {
                    Label("Add Rule", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search rules...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom)

            Divider()

            // Rules list
            if rules.isEmpty {
                ContentUnavailableView(
                    "No Custom Rules",
                    systemImage: "slider.horizontal.3",
                    description: Text("Click 'Add Rule' to create a custom categorization rule.\nThe app also uses built-in rules automatically.")
                )
            } else {
                List {
                    ForEach(filteredRules) { rule in
                        RuleRowView(rule: rule)
                            .contextMenu {
                                Button("Edit") {
                                    editingRule = rule
                                }
                                Button("Duplicate") {
                                    duplicateRule(rule)
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    ruleToDelete = rule
                                    showingDeleteConfirmation = true
                                }
                            }
                            .onTapGesture(count: 2) {
                                editingRule = rule
                            }
                    }
                    .onDelete(perform: deleteRules)
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            RuleEditorSheet(rule: nil, categories: categories) { newRule in
                modelContext.insert(newRule)
                try? modelContext.save()
            }
        }
        .sheet(item: $editingRule) { rule in
            RuleEditorSheet(rule: rule, categories: categories) { _ in
                try? modelContext.save()
            }
        }
        .alert("Delete Rule", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let rule = ruleToDelete {
                    modelContext.delete(rule)
                    try? modelContext.save()
                }
            }
        } message: {
            Text("Are you sure you want to delete this rule? This cannot be undone.")
        }
    }

    private func deleteRules(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredRules[index])
        }
        try? modelContext.save()
    }

    private func duplicateRule(_ rule: CategorizationRule) {
        let newRule = CategorizationRule(
            pattern: rule.pattern + " (copy)",
            matchType: rule.matchType,
            standardizedName: rule.standardizedName,
            targetCategory: rule.targetCategory,
            priority: rule.priority + 1
        )
        modelContext.insert(newRule)
        try? modelContext.save()
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

                HStack(spacing: 4) {
                    if let standardized = rule.standardizedName {
                        Text("→ \(standardized)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(rule.targetCategory)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
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

// MARK: - Rule Editor Sheet

struct RuleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let rule: CategorizationRule?
    let categories: [Category]
    let onSave: (CategorizationRule) -> Void

    @State private var pattern: String = ""
    @State private var matchType: RuleMatchType = .contains
    @State private var standardizedName: String = ""
    @State private var targetCategory: String = ""
    @State private var priority: Int = 50
    @State private var isActive: Bool = true

    private var isValid: Bool {
        !pattern.isEmpty && !targetCategory.isEmpty
    }

    private var categoryNames: [String] {
        categories.map(\.name).sorted()
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

                Text(rule == nil ? "New Rule" : "Edit Rule")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    saveRule()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Pattern Matching") {
                    TextField("Pattern", text: $pattern)
                        .help("The text pattern to match against transaction names")

                    Picker("Match Type", selection: $matchType) {
                        ForEach(RuleMatchType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section("Categorization") {
                    Picker("Category", selection: $targetCategory) {
                        Text("Select Category").tag("")
                        ForEach(categoryNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

                    TextField("Standardized Name (optional)", text: $standardizedName)
                        .help("A cleaned-up merchant name to use instead of the original")
                }

                Section("Options") {
                    Stepper("Priority: \(priority)", value: $priority, in: 1...1000)
                        .help("Lower numbers = higher priority (matched first)")

                    Toggle("Active", isOn: $isActive)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 400)
        .onAppear {
            if let rule = rule {
                pattern = rule.pattern
                matchType = rule.matchType
                standardizedName = rule.standardizedName ?? ""
                targetCategory = rule.targetCategory
                priority = rule.priority
                isActive = rule.isActive
            }
        }
    }

    private func saveRule() {
        if let existing = rule {
            existing.pattern = pattern
            existing.matchType = matchType
            existing.standardizedName = standardizedName.isEmpty ? nil : standardizedName
            existing.targetCategory = targetCategory
            existing.priority = priority
            existing.isActive = isActive
            onSave(existing)
        } else {
            let newRule = CategorizationRule(
                pattern: pattern,
                matchType: matchType,
                standardizedName: standardizedName.isEmpty ? nil : standardizedName,
                targetCategory: targetCategory,
                priority: priority
            )
            newRule.isActive = isActive
            onSave(newRule)
        }
        dismiss()
    }
}

// MARK: - Insights View

struct InsightsView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @StateObject private var viewModel: InsightsViewModel
    @State private var selectedTimeframe: TimeframeFilter = .year
    @State private var isLoading = false

    // MARK: - Initialization

    init(queryService: TransactionQueryService) {
        _viewModel = StateObject(wrappedValue: InsightsViewModel(queryService: queryService))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Key metrics cards
                    metricsSection

                    // Spending trends chart
                    spendingTrendsSection

                    // Category breakdown
                    categoryBreakdownSection

                    // Month-over-month comparison
                    monthComparisonSection

                    // Top merchants
                    topMerchantsSection

                    Spacer(minLength: 40)
                }
                .padding(24)
            }
            .background(Color(nsColor: .windowBackgroundColor))

            // Loading overlay
            if isLoading {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView("Analyzing data...")
                            .padding(24)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 4)
                    }
            }
        }
        .task {
            await loadInsights()
        }
        .onChange(of: selectedTimeframe) { _, _ in
            Task { await loadInsights() }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Financial Insights")
                        .font(.system(size: 28, weight: .bold))

                    Text("Analyze your spending patterns and track your financial goals")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Timeframe picker
                Picker("Timeframe", selection: $selectedTimeframe) {
                    Text("6 Months").tag(TimeframeFilter.sixMonths)
                    Text("Year").tag(TimeframeFilter.year)
                    Text("All Time").tag(TimeframeFilter.allTime)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }
        }
    }

    // MARK: - Metrics Section

    private var metricsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            MetricCard(
                title: "Monthly Average",
                value: viewModel.monthlyAverage.toCurrencyString(),
                change: viewModel.monthlyAverageChange,
                icon: "calendar",
                color: .blue
            )

            MetricCard(
                title: "Savings Rate",
                value: String(format: "%.1f%%", viewModel.savingsRate),
                change: viewModel.savingsRateChange,
                icon: "banknote",
                color: .green
            )

            MetricCard(
                title: "Top Category",
                value: viewModel.topCategory.name,
                change: nil,
                icon: "square.grid.2x2",
                color: Color(hex: viewModel.topCategory.color)
            )

            MetricCard(
                title: "Transactions",
                value: "\(viewModel.totalTransactions)",
                change: viewModel.transactionCountChange,
                icon: "list.bullet.rectangle",
                color: .purple
            )
        }
    }

    // MARK: - Spending Trends Section

    private var spendingTrendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending Trends")
                .font(.title2)
                .fontWeight(.semibold)

            Chart(viewModel.monthlySpending) { data in
                BarMark(
                    x: .value("Month", data.month),
                    y: .value("Amount", abs(data.amount))
                )
                .foregroundStyle(.red.opacity(0.8))
                .cornerRadius(4)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let month = value.as(String.self) {
                            Text(month)
                                .font(.caption)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(Decimal(amount).toCurrencyString())
                                .font(.caption)
                        }
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
    }

    // MARK: - Category Breakdown Section

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Category Breakdown")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Text("Top 10 categories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.topCategories) { category in
                    CategoryBreakdownRow(
                        category: category,
                        totalSpending: viewModel.totalCategorySpending
                    )
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
    }

    // MARK: - Month Comparison Section

    private var monthComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Month-over-Month Changes")
                .font(.title2)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.monthOverMonthComparisons) { comparison in
                    MonthComparisonCard(comparison: comparison)
                }
            }
        }
    }

    // MARK: - Top Merchants Section

    private var topMerchantsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Top Merchants")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Text("By total spending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVStack(spacing: 8) {
                ForEach(viewModel.topMerchants) { merchant in
                    TopMerchantRow(merchant: merchant)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
    }

    // MARK: - Loading Function

    @MainActor
    private func loadInsights() async {
        isLoading = true
        await viewModel.loadInsights(timeframe: selectedTimeframe)
        isLoading = false
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let change: Double?
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)

                Spacer()

                if let change = change {
                    HStack(spacing: 2) {
                        Image(systemName: change >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.caption2)
                        Text(String(format: "%.1f%%", abs(change)))
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(change >= 0 ? .green : .red)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

struct CategoryBreakdownRow: View {
    let category: CategoryInsight
    let totalSpending: Decimal

    private var percentage: Double {
        guard totalSpending > 0 else { return 0 }
        return Double(truncating: (category.amount / totalSpending * 100) as NSNumber)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category icon and name
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .foregroundStyle(Color(hex: category.color))
                    .frame(width: 20)

                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(width: 150, alignment: .leading)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: category.color))
                        .frame(width: geometry.size.width * (percentage / 100), height: 6)
                }
            }
            .frame(height: 6)

            // Amount and percentage
            VStack(alignment: .trailing, spacing: 2) {
                Text(category.amount.toCurrencyString())
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(String(format: "%.1f%%", percentage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80, alignment: .trailing)
        }
    }
}

struct MonthComparisonCard: View {
    let comparison: MonthComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: comparison.icon)
                    .foregroundStyle(Color(hex: comparison.color))

                Text(comparison.category)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()
            }

            Text(comparison.currentAmount.toCurrencyString())
                .font(.title3)
                .fontWeight(.bold)

            HStack(spacing: 4) {
                if comparison.changeAmount != 0 {
                    Image(systemName: comparison.changeAmount > 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.caption2)
                        .foregroundStyle(comparison.changeAmount > 0 ? .red : .green)

                    Text("\(String(format: "%.1f%%", abs(comparison.changePercentage))) vs last month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No change")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

struct TopMerchantRow: View {
    let merchant: MerchantInsight

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(merchant.rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            // Merchant info
            VStack(alignment: .leading, spacing: 2) {
                Text(merchant.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(merchant.transactionCount) transactions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Amount
            Text(merchant.totalAmount.toCurrencyString())
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Models and Data Structures

@MainActor
class InsightsViewModel: ObservableObject {
    @Published var monthlyAverage: Decimal = 0
    @Published var monthlyAverageChange: Double? = nil
    @Published var savingsRate: Double = 0
    @Published var savingsRateChange: Double? = nil
    @Published var topCategory: CategoryInsight = CategoryInsight.placeholder
    @Published var totalTransactions: Int = 0
    @Published var transactionCountChange: Double? = nil
    @Published var monthlySpending: [MonthlySpendingData] = []
    @Published var topCategories: [CategoryInsight] = []
    @Published var totalCategorySpending: Decimal = 0
    @Published var monthOverMonthComparisons: [MonthComparison] = []
    @Published var topMerchants: [MerchantInsight] = []

    private let queryService: TransactionQueryService

    init(queryService: TransactionQueryService) {
        self.queryService = queryService
    }

    func loadInsights(timeframe: TimeframeFilter) async {
        let endDate = Date()
        let startDate: Date

        switch timeframe {
        case .sixMonths:
            startDate = Calendar.current.date(byAdding: .month, value: -6, to: endDate) ?? endDate
        case .year:
            startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .allTime:
            startDate = Calendar.current.date(byAdding: .year, value: -10, to: endDate) ?? endDate
        }

        // Load all insights in parallel
        async let monthlyData = queryService.getMonthlySpending(from: startDate, to: endDate)
        async let categoryData = queryService.getCategoryBreakdown(from: startDate, to: endDate)
        async let merchantData = queryService.getMerchantStats(from: startDate, to: endDate)
        async let monthComparisons = queryService.getMonthOverMonthComparisons()

        do {
            let monthly = try await monthlyData
            let categories = try await categoryData
            let merchants = try await merchantData
            let comparisons = try await monthComparisons

            // Update UI data
            updateMonthlyMetrics(monthly)
            updateCategoryData(categories)
            updateMerchantData(merchants)
            updateMonthComparisons(comparisons)

        } catch {
            print("Failed to load insights: \(error)")
        }
    }

    private func updateMonthlyMetrics(_ monthlyData: [MonthlySpendingData]) {
        monthlySpending = monthlyData

        let expenses = monthlyData.filter { $0.amount < 0 }
        let totalExpenses = expenses.reduce(Decimal.zero) { $0 + abs($1.amount) }
        monthlyAverage = expenses.count > 0 ? totalExpenses / Decimal(expenses.count) : 0

        // Calculate savings rate (simplified)
        let totalIncome = monthlyData.filter { $0.amount > 0 }.reduce(Decimal.zero) { $0 + $1.amount }
        if totalIncome > 0 {
            savingsRate = Double(truncating: ((totalIncome - totalExpenses) / totalIncome * 100) as NSNumber)
        }

        totalTransactions = monthlyData.reduce(0) { $0 + $1.transactionCount }

        // Calculate changes (simplified - compare with previous period)
        if expenses.count >= 2 {
            let recent = expenses.prefix(3).reduce(Decimal.zero) { $0 + abs($1.amount) } / 3
            let older = expenses.dropFirst(3).prefix(3).reduce(Decimal.zero) { $0 + abs($1.amount) } / 3
            if older > 0 {
                monthlyAverageChange = Double(truncating: ((recent - older) / older * 100) as NSNumber)
            }
        }
    }

    private func updateCategoryData(_ categories: [CategoryInsight]) {
        topCategories = Array(categories.prefix(10))
        totalCategorySpending = categories.reduce(Decimal.zero) { $0 + $1.amount }
        topCategory = categories.first ?? CategoryInsight.placeholder
    }

    private func updateMerchantData(_ merchants: [MerchantInsight]) {
        topMerchants = Array(merchants.prefix(10))
    }

    private func updateMonthComparisons(_ comparisons: [MonthComparison]) {
        monthOverMonthComparisons = Array(comparisons.prefix(6))
    }
}

struct MonthlySpendingData: Identifiable {
    let id = UUID()
    let month: String
    let amount: Decimal
    let transactionCount: Int
}

struct CategoryInsight: Identifiable {
    let id = UUID()
    let name: String
    let amount: Decimal
    let icon: String
    let color: String
    let transactionCount: Int

    static let placeholder = CategoryInsight(
        name: "Niet Gecategoriseerd",
        amount: 0,
        icon: "questionmark.circle.fill",
        color: "9CA3AF",
        transactionCount: 0
    )
}

struct MonthComparison: Identifiable {
    let id = UUID()
    let category: String
    let currentAmount: Decimal
    let previousAmount: Decimal
    let changeAmount: Decimal
    let changePercentage: Double
    let icon: String
    let color: String
}

struct MerchantInsight: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let totalAmount: Decimal
    let transactionCount: Int
    let category: String
}

enum TimeframeFilter: CaseIterable {
    case sixMonths
    case year
    case allTime

    var displayName: String {
        switch self {
        case .sixMonths: return "6 Months"
        case .year: return "Year"
        case .allTime: return "All Time"
        }
    }
}

// MARK: - High-Performance Optimized Transactions View (15k+ Records)

struct OptimizedTransactionsView: View {

    // MARK: - Environment & State

    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: OptimizedTransactionsViewModel

    @State private var searchText = ""
    @State private var selectedType: TransactionType? = nil
    @State private var selectedCategory: String? = nil
    @State private var selectedTransaction: Transaction?
    @State private var searchDebouncer = SearchDebouncer()

    // MARK: - Data Queries (Light-weight)

    @Query(sort: \Account.iban) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    // MARK: - Initialization

    init(queryService: TransactionQueryService) {
        _viewModel = StateObject(wrappedValue: OptimizedTransactionsViewModel(queryService: queryService))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Optimized header with filters
            optimizedHeader

            Divider()

            // High-performance transaction list with virtualization
            mainContent
        }
        .onAppear { Task { await viewModel.initialLoad() } }
        .onChange(of: searchText) { _, newValue in
            searchDebouncer.debounce(delay: 0.3) { Task { await applyFilters() } }
        }
        .onChange(of: selectedType) { _, _ in Task { await applyFilters() } }
        .onChange(of: selectedCategory) { _, _ in Task { await applyFilters() } }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
        }
    }

    // MARK: - Optimized Header

    private var optimizedHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Transactions")
                    .font(.system(size: 28, weight: .bold))

                Spacer()

                // Performance counter
                if viewModel.hasMorePages {
                    Text("\(viewModel.transactions.count)+ of \(viewModel.totalCount ?? 0)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(viewModel.transactions.count) transactions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Compact filter row
            HStack(spacing: 12) {
                // Enhanced search field with animations
                EnhancedSearchField(
                    text: $searchText,
                    placeholder: "Search transactions..."
                )

                // Type filter
                Picker("Type", selection: $selectedType) {
                    Text("All").tag(nil as TransactionType?)
                    Text("Income").tag(TransactionType.income as TransactionType?)
                    Text("Expenses").tag(TransactionType.expense as TransactionType?)
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                // Category filter
                Picker("Category", selection: $selectedCategory) {
                    Text("All Categories").tag(nil as String?)
                    ForEach(categories.filter { $0.type == .expense }, id: \.name) { category in
                        Text(category.name).tag(category.name as String?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)

                // Clear filters
                if hasActiveFilters {
                    Button("Clear") { clearFilters() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding()
    }

    // MARK: - Main Content with Virtualization

    private var mainContent: some View {
        ZStack {
            if viewModel.isLoading && viewModel.transactions.isEmpty {
                ProgressView("Loading transactions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.transactions.isEmpty {
                ContentUnavailableView(
                    "No Transactions Found",
                    systemImage: "list.bullet.rectangle",
                    description: Text(hasActiveFilters ? "Try adjusting your filters" : "Import CSV files to get started")
                )
            } else {
                virtualizedTransactionsList
            }

            // Pagination loading overlay
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

    // MARK: - Virtualized List (Key Performance Feature)

    private var virtualizedTransactionsList: some View {
        ScrollView {
            LazyVStack(spacing: 1) { // Minimal spacing for performance
                ForEach(viewModel.transactions) { transaction in
                    HighPerformanceTransactionRow(
                        transaction: transaction,
                        isSelected: selectedTransaction?.id == transaction.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selectedTransaction = transaction }
                    .onAppear {
                        // Pagination trigger
                        if transaction == viewModel.transactions.last {
                            Task { await viewModel.loadNextPage() }
                        }
                    }
                }

                // Load more indicator
                if viewModel.hasMorePages && !viewModel.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading more...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .onAppear {
                        Task { await viewModel.loadNextPage() }
                    }
                }
            }
            .animation(.easeOut(duration: 0.25), value: viewModel.transactions.count)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Helper Methods

    private var hasActiveFilters: Bool {
        !searchText.isEmpty || selectedType != nil || selectedCategory != nil
    }

    private func clearFilters() {
        searchText = ""
        selectedType = nil
        selectedCategory = nil
    }

    @MainActor
    private func applyFilters() async {
        let filter = buildFilter()
        await viewModel.applyFilter(filter)
    }

    private func buildFilter() -> TransactionFilter {
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

        return filter
    }
}

// MARK: - Enhanced High-Performance Transaction Row (Desktop Polish)

struct HighPerformanceTransactionRow: View {
    let transaction: Transaction
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.m) {
            // Type indicator with enhanced styling
            Image(systemName: transaction.transactionType.icon)
                .font(DesignTokens.Typography.title)
                .foregroundStyle(typeColor)
                .frame(width: 32)
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(DesignTokens.Animation.springFast, value: isHovered)

            // Main content with improved spacing
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(transaction.standardizedName ?? transaction.counterName ?? "Unknown")
                    .font(DesignTokens.Typography.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: DesignTokens.Spacing.s) {
                    // Enhanced category badge
                    Text(transaction.effectiveCategory)
                        .font(DesignTokens.Typography.caption2)
                        .padding(.horizontal, DesignTokens.Spacing.s)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(categoryBadgeBackground)
                        .foregroundStyle(categoryBadgeColor)
                        .clipShape(Capsule())
                        .animation(DesignTokens.Animation.springFast, value: isHovered)

                    Text(transaction.date.formatted(.dateTime.day().month(.abbreviated)))
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Enhanced amount display
            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
                Text(transaction.amount.toCurrencyString())
                    .font(DesignTokens.Typography.currencyLarge)
                    .foregroundStyle(amountColor)
                    .scaleEffect(isHovered ? 1.02 : 1.0)
                    .animation(DesignTokens.Animation.springFast, value: isHovered)

                // Account indicator (subtle)
                if let account = transaction.account {
                    Text(account.name.prefix(4))
                        .font(DesignTokens.Typography.caption2)
                        .foregroundStyle(.tertiary)
                        .opacity(isHovered ? 1.0 : 0.7)
                        .animation(DesignTokens.Animation.springFast, value: isHovered)
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.s)
        .padding(.horizontal, DesignTokens.Spacing.l)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
        .overlay(
            // Subtle border highlight on hover
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                .stroke(
                    Color.accentColor.opacity(isHovered ? 0.3 : 0.0),
                    lineWidth: 1
                )
                .animation(DesignTokens.Animation.springFast, value: isHovered)
        )
        .scaleEffect(isSelected ? 1.01 : (isHovered ? 1.005 : 1.0))
        .shadow(
            color: isHovered ? DesignTokens.Shadow.secondary.color : Color.clear,
            radius: isHovered ? DesignTokens.Shadow.secondary.radius : 0,
            x: 0,
            y: isHovered ? DesignTokens.Shadow.secondary.y : 0
        )
        .animation(DesignTokens.Animation.springFast, value: isHovered)
        .animation(DesignTokens.Animation.springFast, value: isSelected)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.springFast) {
                isHovered = hovering
            }
        }
    }

    // MARK: - Computed Properties

    private var typeColor: Color {
        switch transaction.transactionType {
        case .income: return DesignTokens.Colors.income
        case .expense: return DesignTokens.Colors.expense
        case .transfer: return .blue
        case .unknown: return .gray
        }
    }

    private var amountColor: Color {
        transaction.amount >= 0 ? DesignTokens.Colors.income : .primary
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(DesignTokens.Opacity.light)
        } else if isHovered {
            return DesignTokens.Colors.cardBackground.opacity(0.8)
        } else {
            return DesignTokens.Colors.cardBackground.opacity(0.4)
        }
    }

    private var categoryBadgeBackground: Color {
        if isHovered {
            return Color.accentColor.opacity(DesignTokens.Opacity.medium)
        } else {
            return Color.accentColor.opacity(DesignTokens.Opacity.light)
        }
    }

    private var categoryBadgeColor: Color {
        isHovered ? .white : Color.accentColor
    }
}

// MARK: - High-Performance View Model

@MainActor
class OptimizedTransactionsViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var hasMorePages = true
    @Published var totalCount: Int?

    private let pageSize = 100
    private var currentPage = 0
    private var currentFilter = TransactionFilter()
    private let queryService: TransactionQueryService

    init(queryService: TransactionQueryService) {
        self.queryService = queryService
    }

    func initialLoad() async {
        currentPage = 0
        transactions = []
        hasMorePages = true
        totalCount = nil
        await loadNextPage()
    }

    func loadNextPage() async {
        guard !isLoading && hasMorePages else { return }

        isLoading = true

        do {
            let skip = currentPage * pageSize
            let newTransactions = try await queryService.getTransactionsPaginated(
                filter: currentFilter,
                offset: skip,
                limit: pageSize
            )

            if newTransactions.isEmpty || newTransactions.count < pageSize {
                hasMorePages = false
            }

            transactions.append(contentsOf: newTransactions)
            currentPage += 1

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
        await initialLoad()
    }
}

// MARK: - Enhanced UI Components

/// Enhanced search field with hover effects and smooth animations
struct EnhancedSearchField: View {
    @Binding var text: String
    let placeholder: String

    @State private var isHovered = false
    @State private var isFocused = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(iconColor)
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .animation(DesignTokens.Animation.springFast, value: isFocused)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .onFocus { focused in
                    withAnimation(DesignTokens.Animation.springFast) {
                        isFocused = focused
                    }
                }

            if !text.isEmpty {
                Button(action: clearText) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                        .animation(DesignTokens.Animation.springFast, value: isHovered)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(DesignTokens.Animation.springFast) {
                        isHovered = hovering
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(DesignTokens.Spacing.s + 2)
        .background(searchFieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .scaleEffect(isFocused ? 1.005 : 1.0)
        .animation(DesignTokens.Animation.springFast, value: isFocused)
        .animation(DesignTokens.Animation.springFast, value: !text.isEmpty)
    }

    // MARK: - Computed Properties

    private var iconColor: Color {
        isFocused ? Color.accentColor : .secondary
    }

    private var searchFieldBackground: Color {
        if isFocused {
            return DesignTokens.Colors.cardBackground
        } else {
            return DesignTokens.Colors.cardBackground.opacity(0.8)
        }
    }

    private var borderColor: Color {
        isFocused ? Color.accentColor.opacity(0.5) : Color.clear
    }

    private var borderWidth: CGFloat {
        isFocused ? 1 : 0
    }

    // MARK: - Actions

    private func clearText() {
        withAnimation(DesignTokens.Animation.springFast) {
            text = ""
        }
    }
}

/// Enhanced button with hover and press feedback
struct EnhancedButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let style: ButtonStyleType

    @State private var isHovered = false
    @State private var isPressed = false

    enum ButtonStyleType {
        case primary, secondary, clear
    }

    init(_ title: String, icon: String? = nil, style: ButtonStyleType = .secondary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: performAction) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(DesignTokens.Typography.caption)
                }
                Text(title)
                    .font(DesignTokens.Typography.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, DesignTokens.Spacing.m)
            .padding(.vertical, DesignTokens.Spacing.s)
            .background(buttonBackground)
            .foregroundStyle(buttonForeground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.02 : 1.0))
        .animation(DesignTokens.Animation.springFast, value: isHovered)
        .animation(DesignTokens.Animation.springFast, value: isPressed)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.springFast) {
                isHovered = hovering
            }
        }
    }

    // MARK: - Computed Properties

    private var buttonBackground: Color {
        switch style {
        case .primary:
            return isPressed ? Color.accentColor.opacity(0.9) : (isHovered ? Color.accentColor.opacity(0.9) : Color.accentColor)
        case .secondary:
            return isPressed ? DesignTokens.Colors.cardBackground.opacity(0.8) : (isHovered ? DesignTokens.Colors.cardBackground : DesignTokens.Colors.cardBackground.opacity(0.8))
        case .clear:
            return isHovered ? DesignTokens.Colors.cardBackground.opacity(0.5) : Color.clear
        }
    }

    private var buttonForeground: Color {
        switch style {
        case .primary:
            return .white
        case .secondary, .clear:
            return .primary
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:
            return Color.clear
        case .secondary:
            return isHovered ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2)
        case .clear:
            return Color.clear
        }
    }

    private var borderWidth: CGFloat {
        style == .secondary ? 1 : 0
    }

    // MARK: - Actions

    private func performAction() {
        withAnimation(DesignTokens.Animation.springFast) {
            isPressed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(DesignTokens.Animation.springFast) {
                isPressed = false
            }
            action()
        }
    }
}

// MARK: - Focus Detection Extension

extension View {
    func onFocus(_ action: @escaping (Bool) -> Void) -> some View {
        self.background(
            FocusDetector(onFocusChange: action)
        )
    }
}

struct FocusDetector: NSViewRepresentable {
    let onFocusChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let textField = nsView.superview?.subviews.first(where: { $0 is NSTextField }) as? NSTextField {
                context.coordinator.observeTextField(textField)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFocusChange: onFocusChange)
    }

    class Coordinator: NSObject {
        let onFocusChange: (Bool) -> Void
        private var textField: NSTextField?

        init(onFocusChange: @escaping (Bool) -> Void) {
            self.onFocusChange = onFocusChange
        }

        func observeTextField(_ textField: NSTextField) {
            guard self.textField != textField else { return }
            self.textField = textField

            NotificationCenter.default.addObserver(
                forName: NSControl.textDidBeginEditingNotification,
                object: textField,
                queue: .main
            ) { _ in
                self.onFocusChange(true)
            }

            NotificationCenter.default.addObserver(
                forName: NSControl.textDidEndEditingNotification,
                object: textField,
                queue: .main
            ) { _ in
                self.onFocusChange(false)
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// MARK: - Search Debouncer for Performance

class SearchDebouncer {
    private var workItem: DispatchWorkItem?

    func debounce(delay: TimeInterval, action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
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
    @Environment(\.modelContext) private var modelContext
    @State private var isExporting = false
    @State private var exportMessage: String?
    @State private var showExportAlert = false

    var body: some View {
        Form {
            Section("Database") {
                LabeledContent("Location") {
                    Text("~/Library/Application Support/Family Finance")
                        .foregroundStyle(.secondary)
                }
                Button("Open Database Folder") {
                    openDatabaseFolder()
                }
            }

            Section("Import") {
                Toggle("Auto-detect encoding", isOn: .constant(true))
                Toggle("Skip duplicates", isOn: .constant(true))
            }

            Section("Export") {
                Button("Export Transactions to CSV...") {
                    exportTransactionsToCSV()
                }
                .disabled(isExporting)

                Button("Export Rules to CSV...") {
                    exportRulesToCSV()
                }
                .disabled(isExporting)

                Button("Export to JSON (Backup)...") {
                    exportToJSON()
                }
                .disabled(isExporting)

                if isExporting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Exporting...")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .alert("Export", isPresented: $showExportAlert) {
            Button("OK") { }
        } message: {
            Text(exportMessage ?? "Export completed successfully")
        }
    }

    private func openDatabaseFolder() {
        let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Family Finance")
        if let path = path {
            NSWorkspace.shared.open(path)
        }
    }

    private func exportTransactionsToCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "transactions_\(dateStamp()).csv"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    isExporting = true
                    let exportService = ExportService(modelContext: modelContext)
                    do {
                        try await exportService.exportToCSV(url: url)
                        exportMessage = "Transactions exported successfully"
                        showExportAlert = true
                    } catch {
                        exportMessage = "Export failed: \(error.localizedDescription)"
                        showExportAlert = true
                    }
                    isExporting = false
                }
            }
        }
    }

    private func exportRulesToCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "categorization_rules_\(dateStamp()).csv"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    isExporting = true
                    let exportService = ExportService(modelContext: modelContext)
                    do {
                        try await exportService.exportRulesToCSV(url: url)
                        exportMessage = "Rules exported successfully"
                        showExportAlert = true
                    } catch {
                        exportMessage = "Export failed: \(error.localizedDescription)"
                        showExportAlert = true
                    }
                    isExporting = false
                }
            }
        }
    }

    private func exportToJSON() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "family_finance_backup_\(dateStamp()).json"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    isExporting = true
                    let exportService = ExportService(modelContext: modelContext)
                    do {
                        try await exportService.exportToJSON(url: url)
                        exportMessage = "Backup exported successfully"
                        showExportAlert = true
                    } catch {
                        exportMessage = "Export failed: \(error.localizedDescription)"
                        showExportAlert = true
                    }
                    isExporting = false
                }
            }
        }
    }

    private func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
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
