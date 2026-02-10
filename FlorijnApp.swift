//
//  FlorijnApp.swift
//  Florijn
//
//  Main application entry point for macOS
//  SwiftData + SwiftUI with modern architecture
//
//  Created: 2025-12-22
//

import SwiftUI
import Charts
@preconcurrency import SwiftData

@main
struct FlorijnApp: App {

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
            Liability.self,
            Merchant.self,
            BudgetPeriod.self,
            TransactionSplit.self,
            RecurringTransaction.self,
            TransactionAuditLog.self,
            // New Rules System Models
            RuleGroup.self,
            Rule.self,
            RuleTrigger.self,
            RuleAction.self
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

    // MARK: - Data Migration

    /// Migrate user data from "Family Finance" to "Florijn" on first launch
    private func migrateUserDataIfNeeded() {
        let fileManager = FileManager.default
        let oldPath = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Family Finance")
        let newPath = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Florijn")

        guard let oldURL = oldPath, let newURL = newPath,
              fileManager.fileExists(atPath: oldURL.path),
              !fileManager.fileExists(atPath: newURL.path) else { return }

        do {
            try fileManager.moveItem(at: oldURL, to: newURL)
            print("✅ Successfully migrated user data from Family Finance to Florijn")
        } catch {
            print("⚠️ Failed to migrate user data: \(error)")
            // Fallback: copy instead of move
            try? fileManager.copyItem(at: oldURL, to: newURL)
        }
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                .frame(minWidth: 1200, minHeight: 800)
                .onAppear {
                    migrateUserDataIfNeeded()
                }
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
            ("Groceries", 800, "cart.fill", "10B981"),
            ("Dining", 150, "fork.knife", "EF4444"),
            ("Shopping", 200, "bag.fill", "F59E0B"),
            ("Transportation", 250, "car.fill", "3B82F6"),
            ("Utilities", 300, "bolt.fill", "8B5CF6"),
            ("Housing", 1200, "house.fill", "EC4899"),
            ("Insurance", 200, "shield.fill", "14B8A6"),
            ("Healthcare", 100, "cross.fill", "EF4444"),
            ("Childcare", 500, "figure.2.and.child.holdinghands", "F59E0B"),
            ("Entertainment", 100, "gamecontroller.fill", "8B5CF6"),
            ("Home & Garden", 100, "tree.fill", "10B981"),
            ("Taxes", 200, "building.columns.fill", "64748B"),
            ("Debt Payments", 200, "creditcard.fill", "EF4444"),
            ("Bank Fees", 20, "eurosign.circle.fill", "64748B"),
            ("Subscriptions", 100, "repeat.circle.fill", "3B82F6"),
            ("Uncategorized", 0, "questionmark.circle.fill", "9CA3AF"),
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
            ("Salary", "eurosign.circle.fill", "10B981"),
            ("Freelance", "briefcase.fill", "3B82F6"),
            ("Benefits", "building.columns.fill", "F59E0B"),
            ("Contribution Partner 1", "person.fill", "8B5CF6"),
            ("Contribution Partner 2", "person.fill", "EC4899"),
            ("Other Income", "plus.circle.fill", "10B981"),
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
        VStack(spacing: 0) {
            // Professional trust-building header
            ProfessionalAppHeader(
                "Florijn",
                subtitle: "Personal Finance Manager"
            )

            NavigationSplitView {
                SidebarView(selection: $appState.selectedTab)
                    .professionalSidebar()
                    .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 280)
            } detail: {
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .professionalWindowBackground()
            }
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
            SimpleRulesView()  // Firefly III-style: Rules first, groups optional
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
                        let ruleService = RuleService(modelContext: modelContext)
                        importService = CSVImportService(
                            modelContainer: modelContext.container,
                            ruleService: ruleService
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

// MARK: - Sidebar View

struct SidebarView: View {

    @Binding var selection: AppTab

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("Dashboard", systemImage: "chart.bar.fill")
                    .tag(AppTab.dashboard)
                    .professionalSidebarItem(isSelected: selection == .dashboard)

                Label("Transactions", systemImage: "list.bullet.rectangle.fill")
                    .tag(AppTab.transactions)
                    .professionalSidebarItem(isSelected: selection == .transactions)

                Label("Transfers", systemImage: "arrow.left.arrow.right")
                    .tag(AppTab.transfers)
                    .professionalSidebarItem(isSelected: selection == .transfers)

                Label("Merchants", systemImage: "building.2.fill")
                    .tag(AppTab.merchants)
                    .professionalSidebarItem(isSelected: selection == .merchants)
            } header: {
                Text("Overview")
                    .professionalSidebarSection()
            }

            Section {
                Label("Budgets", systemImage: "chart.pie.fill")
                    .tag(AppTab.budgets)
                    .professionalSidebarItem(isSelected: selection == .budgets)

                Label("Categories", systemImage: "square.grid.2x2.fill")
                    .tag(AppTab.categories)
                    .professionalSidebarItem(isSelected: selection == .categories)

                Label("Insights", systemImage: "chart.bar.xaxis")
                    .tag(AppTab.insights)
                    .professionalSidebarItem(isSelected: selection == .insights)
            } header: {
                Text("Planning")
                    .professionalSidebarSection()
            }

            Section {
                Label("All Accounts", systemImage: "creditcard.fill")
                    .tag(AppTab.accounts)
                    .professionalSidebarItem(isSelected: selection == .accounts)
            } header: {
                Text("Accounts")
                    .professionalSidebarSection()
            }

            Section {
                Label("Rules", systemImage: "slider.horizontal.3")
                    .tag(AppTab.rules)
                    .professionalSidebarItem(isSelected: selection == .rules)

                Label("Import", systemImage: "square.and.arrow.down.fill")
                    .tag(AppTab.import)
                    .professionalSidebarItem(isSelected: selection == .import)
            } header: {
                Text("Settings")
                    .professionalSidebarSection()
            }
        }
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

// MARK: - Views extracted to separate files
// NOTE: TransactionsListView, TransactionEditorSheet, TransactionRowView -> Views/TransactionsView.swift
// NOTE: AccountsListView, AccountCardView -> Views/AccountsView.swift

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
                    .font(.headingLarge)

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
    @State private var categorySummaries: [CategorySummary] = []
    @State private var showingAddBudget = false

    private var expenseCategories: [Category] {
        categories.filter { $0.type == .expense && $0.monthlyBudget > 0 }
    }

    private var categoriesWithoutBudgets: [Category] {
        categories.filter { $0.type == .expense && $0.monthlyBudget == 0 }
    }

    private var totalBudget: Decimal {
        expenseCategories.reduce(Decimal.zero) { $0 + $1.monthlyBudget }
    }

    private var totalSpent: Decimal {
        categorySummaries.reduce(Decimal.zero) { $0 + $1.totalAmount }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Budgets")
                        .font(.headingLarge)

                    Spacer()

                    // Add budget button
                    Button(action: {
                        showingAddBudget = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Add Budget")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .disabled(categoriesWithoutBudgets.isEmpty)

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
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Budget")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(totalBudget.toCurrencyString())
                                .font(.title2)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Spent")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(totalSpent.toCurrencyString())
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(totalSpent > totalBudget ? .red : .primary)
                        }
                    }

                    // Overall progress bar
                    if totalBudget > 0 {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(totalSpent > totalBudget ? Color.red : Color.blue)
                                    .frame(width: min(geometry.size.width, geometry.size.width * CGFloat(truncating: (totalSpent / totalBudget) as NSNumber)), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                .padding(.horizontal)

                // Budget categories
                LazyVStack(spacing: 12) {
                    ForEach(expenseCategories) { category in
                        let summary = categorySummaries.first { $0.category == category.name }
                        BudgetCategoryCard(category: category, summary: summary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            Task {
                await loadBudgetData()
            }
        }
        .onChange(of: selectedYear) { _, _ in
            Task {
                await loadBudgetData()
            }
        }
        .onChange(of: selectedMonth) { _, _ in
            Task {
                await loadBudgetData()
            }
        }
        .sheet(isPresented: $showingAddBudget) {
            AddBudgetSheet(categories: categoriesWithoutBudgets)
        }
    }

    private func monthName(_ month: Int) -> String {
        guard month >= 1 && month <= 12 else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.monthSymbols[month - 1].capitalized
    }

    @MainActor
    private func loadBudgetData() async {
        let filter = TransactionFilter(year: selectedYear, month: selectedMonth)
        let queryService = TransactionQueryService(modelContext: modelContext)

        do {
            categorySummaries = try await queryService.getCategorySummaries(filter: filter)
        } catch {
            print("Error loading budget data: \(error)")
            categorySummaries = []
        }
    }
}

struct BudgetCategoryCard: View {
    let category: Category
    let summary: CategorySummary?

    @State private var isEditing = false
    @State private var editedBudget = ""
    @Environment(\.modelContext) private var modelContext

    private var spentAmount: Decimal {
        summary?.totalAmount ?? 0
    }

    private var progressPercentage: Double {
        guard category.monthlyBudget > 0 else { return 0 }
        return min(1.0, Double(truncating: (spentAmount / category.monthlyBudget) as NSNumber))
    }

    private var isOverBudget: Bool {
        spentAmount > category.monthlyBudget
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: category.icon ?? "square.grid.2x2")
                    .foregroundStyle(Color(hex: category.color ?? "3B82F6"))

                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(spentAmount.toCurrencyString()) /")
                            .font(.caption)
                            .foregroundStyle(isOverBudget ? .red : .secondary)

                        if isEditing {
                            TextField("Budget", text: $editedBudget)
                                .font(.caption)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .onSubmit {
                                    saveBudgetEdit()
                                }
                        } else {
                            Button(action: {
                                startEditing()
                            }) {
                                Text(category.monthlyBudget.toCurrencyString())
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if isEditing {
                        HStack(spacing: 4) {
                            Button("Save") {
                                saveBudgetEdit()
                            }
                            .font(.caption2)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)

                            Button("Cancel") {
                                cancelEditing()
                            }
                            .font(.caption2)
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    } else if let transactionCount = summary?.transactionCount, transactionCount > 0 {
                        Text("\(transactionCount) transactions")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Real progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOverBudget ? Color.red : Color(hex: category.color ?? "3B82F6"))
                        .frame(width: geometry.size.width * progressPercentage, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .contextMenu {
            Button("Remove Budget") {
                removeBudget()
            }
        }
    }

    private func startEditing() {
        isEditing = true
        editedBudget = String(describing: category.monthlyBudget)
    }

    private func saveBudgetEdit() {
        guard let newBudget = Decimal(string: editedBudget) else {
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

struct AddBudgetSheet: View {
    let categories: [Category]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedCategory: Category?
    @State private var budgetAmount: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add Budget")
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.headline)

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
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Monthly Budget Amount")
                        .font(.headline)

                    TextField("€0.00", text: $budgetAmount)
                        .textFieldStyle(.roundedBorder)
                }

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBudget()
                    }
                    .disabled(selectedCategory == nil || budgetAmount.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 300)
    }

    private func saveBudget() {
        guard let category = selectedCategory,
              let amount = Decimal(string: budgetAmount) else {
            return
        }

        category.monthlyBudget = amount
        try? modelContext.save()
        dismiss()
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
                    .font(.headingLarge)

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
                    .font(.headingLarge)

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
        formatter.locale = Locale.current
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
                        .font(.headingLarge)

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
        name: "Uncategorized",
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
                    .font(.headingLarge)

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

// MARK: - Transaction Row

struct HighPerformanceTransactionRow: View {
    let transaction: Transaction
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.transactionType.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(typeColor)
                .frame(width: 32)
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.standardizedName ?? transaction.counterName ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 8) {
                    Text(transaction.effectiveCategory)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(categoryBadgeBackground)
                        .foregroundStyle(categoryBadgeColor)
                        .clipShape(Capsule())
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)

                    Text(transaction.date.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.amount.toCurrencyString())
                    .font(.title2.monospacedDigit().weight(.bold))
                    .foregroundStyle(amountColor)
                    .scaleEffect(isHovered ? 1.02 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)

                if let account = transaction.account {
                    Text(account.name.prefix(4))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .opacity(isHovered ? 1.0 : 0.7)
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color.accentColor.opacity(isHovered ? 0.3 : 0.0),
                    lineWidth: 1
                )
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        )
        .scaleEffect(isSelected ? 1.01 : (isHovered ? 1.005 : 1.0))
        .shadow(
            color: isHovered ? .black.opacity(0.05) : .clear,
            radius: isHovered ? 2 : 0,
            x: 0,
            y: isHovered ? 1 : 0
        )
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isSelected)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
    }

    private var typeColor: Color {
        switch transaction.transactionType {
        case .income: return .green
        case .expense: return .red.opacity(0.85)
        case .transfer: return .blue
        case .unknown: return .gray
        }
    }

    private var amountColor: Color {
        transaction.amount >= 0 ? .green : .primary
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.1)
        } else if isHovered {
            return Color(nsColor: .controlBackgroundColor).opacity(0.8)
        } else {
            return Color(nsColor: .controlBackgroundColor).opacity(0.4)
        }
    }

    private var categoryBadgeBackground: Color {
        if isHovered {
            return Color.accentColor.opacity(0.2)
        } else {
            return Color.accentColor.opacity(0.1)
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

// MARK: - UI Components

/// Search field with hover effects
struct EnhancedSearchField: View {
    @Binding var text: String
    let placeholder: String

    @State private var isHovered = false
    @State private var isFocused = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(iconColor)
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isFocused)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .onFocus { focused in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        isFocused = focused
                    }
                }

            if !text.isEmpty {
                Button(action: clearText) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        isHovered = hovering
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(10)
        .background(searchFieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .scaleEffect(isFocused ? 1.005 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isFocused)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: !text.isEmpty)
    }

    private var iconColor: Color {
        isFocused ? Color.accentColor : .secondary
    }

    private var searchFieldBackground: Color {
        if isFocused {
            return Color(nsColor: .controlBackgroundColor)
        } else {
            return Color(nsColor: .controlBackgroundColor).opacity(0.8)
        }
    }

    private var borderColor: Color {
        isFocused ? Color.accentColor.opacity(0.5) : Color.clear
    }

    private var borderWidth: CGFloat {
        isFocused ? 1 : 0
    }

    private func clearText() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            text = ""
        }
    }
}

/// Button with hover and press feedback
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
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(buttonBackground)
            .foregroundStyle(buttonForeground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.02 : 1.0))
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
    }

    private var buttonBackground: Color {
        switch style {
        case .primary:
            return isPressed ? Color.accentColor.opacity(0.9) : (isHovered ? Color.accentColor.opacity(0.9) : Color.accentColor)
        case .secondary:
            return isPressed ? Color(nsColor: .controlBackgroundColor).opacity(0.8) : (isHovered ? Color(nsColor: .controlBackgroundColor) : Color(nsColor: .controlBackgroundColor).opacity(0.8))
        case .clear:
            return isHovered ? Color(nsColor: .controlBackgroundColor).opacity(0.5) : Color.clear
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

    private func performAction() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            isPressed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
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

    class Coordinator: NSObject, @unchecked Sendable {
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
            ) { [weak self] _ in
                self?.onFocusChange(true)
            }

            NotificationCenter.default.addObserver(
                forName: NSControl.textDidEndEditingNotification,
                object: textField,
                queue: .main
            ) { [weak self] _ in
                self?.onFocusChange(false)
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
                    Text("~/Library/Application Support/Florijn")
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
            .appendingPathComponent("Florijn")
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

