//
//  SimpleRuleBuilderView.swift
//  Family Finance
//
//  Simple rule builder UI with intuitive dropdown interface
//  Handles 90% of categorization rule use cases with ease
//
//  Features:
//  - Account filtering (specific account or all accounts)
//  - Field targeting (description, counter party, IBAN, any field)
//  - Match type selection (contains, starts with, exact, regex)
//  - Amount range filtering (optional min/max)
//  - Transaction type filtering (income/expense/transfer)
//  - Live preview of matching transactions
//  - Rule testing and validation
//
//  Created: 2025-12-24
//

import SwiftUI
@preconcurrency import SwiftData

struct SimpleRuleBuilderView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var ruleName = ""
    @State private var targetCategory = ""
    @State private var selectedAccount: Account?
    @State private var targetField: RuleTargetField = .anyField
    @State private var matchType: RuleMatchType = .contains
    @State private var pattern = ""
    @State private var enableAmountFilter = false
    @State private var amountMin: String = ""
    @State private var amountMax: String = ""
    @State private var transactionTypeFilter: TransactionType?

    @State private var priority: Double = 100
    @State private var isActive = true
    @State private var notes = ""

    // MARK: - UI State

    @State private var showingPreview = false
    @State private var previewResults: [RuleTestResult] = []
    @State private var isLoadingPreview = false
    @State private var showingError = false
    @State private var errorMessage = ""

    // MARK: - Data

    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    // MARK: - Validation

    private var isValidRule: Bool {
        !ruleName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !targetCategory.trimmingCharacters(in: .whitespaces).isEmpty &&
        !pattern.trimmingCharacters(in: .whitespaces).isEmpty &&
        (!enableAmountFilter || isValidAmountRange)
    }

    private var isValidAmountRange: Bool {
        if !enableAmountFilter { return true }

        let minValid = amountMin.isEmpty || Decimal(string: amountMin) != nil
        let maxValid = amountMax.isEmpty || Decimal(string: amountMax) != nil

        if let min = Decimal(string: amountMin),
           let max = Decimal(string: amountMax) {
            return min <= max
        }

        return minValid && maxValid
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xl) {
                    headerSection
                    basicConfigurationSection
                    fieldMatchingSection
                    filtersSection
                    advancedOptionsSection
                    previewSection
                    actionButtonsSection
                }
                .padding(DesignTokens.Spacing.xl)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle("Create Simple Rule")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRule()
                    }
                    .disabled(!isValidRule)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingPreview) {
            RulePreviewView(results: previewResults)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.m) {
            Text("Simple Rule Configuration")
                .font(DesignTokens.Typography.title2)
                .fontWeight(.semibold)

            Text("Create a rule that automatically categorizes transactions based on pattern matching and optional filters.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Basic Configuration

    private var basicConfigurationSection: some View {
        GroupBox("Basic Information") {
            VStack(spacing: DesignTokens.Spacing.l) {
                // Rule Name
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                    Label("Rule Name", systemImage: "tag")
                        .font(DesignTokens.Typography.subheadline)
                        .fontWeight(.medium)

                    TextField("Enter a descriptive name", text: $ruleName)
                        .textFieldStyle(.roundedBorder)
                }

                // Target Category
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                    Label("Target Category", systemImage: "folder")
                        .font(DesignTokens.Typography.subheadline)
                        .fontWeight(.medium)

                    Menu {
                        ForEach(categories, id: \.name) { category in
                            Button(category.name) {
                                targetCategory = category.name
                            }
                        }
                        Divider()
                        Button("Custom Category...") {
                            // Open custom category input
                        }
                    } label: {
                        HStack {
                            Text(targetCategory.isEmpty ? "Select category" : targetCategory)
                                .foregroundStyle(targetCategory.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .padding(DesignTokens.Spacing.m)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .primaryCard()
    }

    // MARK: - Field Matching Section

    private var fieldMatchingSection: some View {
        GroupBox("Pattern Matching") {
            VStack(spacing: DesignTokens.Spacing.l) {
                // Target Field
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                    Label("Match Field", systemImage: "target")
                        .font(DesignTokens.Typography.subheadline)
                        .fontWeight(.medium)

                    Menu {
                        ForEach(RuleTargetField.allCases, id: \.self) { field in
                            Button {
                                withAnimation(DesignTokens.Animation.spring) {
                                    targetField = field
                                }
                            } label: {
                                Label(field.displayName, systemImage: field.icon)
                            }
                        }
                    } label: {
                        HStack {
                            Label(targetField.displayName, systemImage: targetField.icon)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .padding(DesignTokens.Spacing.m)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                    }
                }

                // Match Type
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                    Label("Match Method", systemImage: "magnifyingglass")
                        .font(DesignTokens.Typography.subheadline)
                        .fontWeight(.medium)

                    Menu {
                        ForEach(RuleMatchType.allCases, id: \.self) { type in
                            Button {
                                withAnimation(DesignTokens.Animation.spring) {
                                    matchType = type
                                }
                            } label: {
                                Text(type.displayName)
                            }
                        }
                    } label: {
                        HStack {
                            Text(matchType.displayName)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .padding(DesignTokens.Spacing.m)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                    }
                }

                // Pattern Input
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                    Label("Search Pattern", systemImage: "textformat")
                        .font(DesignTokens.Typography.subheadline)
                        .fontWeight(.medium)

                    TextField("Enter text to match", text: $pattern)
                        .textFieldStyle(.roundedBorder)

                    if matchType == .regex {
                        Text("Use regular expression syntax. Example: ^(albert|jumbo).*")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Case insensitive. Example: \"albert heijn\" matches transactions from Albert Heijn")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .primaryCard()
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        GroupBox("Optional Filters") {
            VStack(spacing: DesignTokens.Spacing.l) {
                // Account Filter
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                    Label("Specific Account", systemImage: "building.columns")
                        .font(DesignTokens.Typography.subheadline)
                        .fontWeight(.medium)

                    Menu {
                        Button("All Accounts") {
                            selectedAccount = nil
                        }
                        Divider()
                        ForEach(accounts, id: \.iban) { account in
                            Button {
                                selectedAccount = account
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(account.name)
                                        .fontWeight(.medium)
                                    Text("****\(account.iban.suffix(4))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            if let account = selectedAccount {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.name)
                                    Text("****\(account.iban.suffix(4))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("All Accounts")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .padding(DesignTokens.Spacing.m)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                    }
                }

                // Amount Range Filter
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                    Toggle(isOn: $enableAmountFilter.animation(DesignTokens.Animation.spring)) {
                        Label("Amount Range Filter", systemImage: "eurosign.circle")
                            .font(DesignTokens.Typography.subheadline)
                            .fontWeight(.medium)
                    }

                    if enableAmountFilter {
                        HStack(spacing: DesignTokens.Spacing.m) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Minimum")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("€0.00", text: $amountMin)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Text("to")
                                .foregroundStyle(.secondary)
                                .padding(.top, 16)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Maximum")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("€1000.00", text: $amountMax)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                // Transaction Type Filter
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                    Label("Transaction Type", systemImage: "arrow.up.arrow.down")
                        .font(DesignTokens.Typography.subheadline)
                        .fontWeight(.medium)

                    Menu {
                        Button("Any Type") {
                            transactionTypeFilter = nil
                        }
                        Divider()
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Button {
                                transactionTypeFilter = type
                            } label: {
                                Label(type.displayName, systemImage: type.icon)
                            }
                        }
                    } label: {
                        HStack {
                            if let type = transactionTypeFilter {
                                Label(type.displayName, systemImage: type.icon)
                            } else {
                                Text("Any Type")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .padding(DesignTokens.Spacing.m)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .primaryCard()
    }

    // MARK: - Advanced Options

    private var advancedOptionsSection: some View {
        GroupBox("Advanced Options") {
            VStack(spacing: DesignTokens.Spacing.l) {
                // Priority
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                    HStack {
                        Label("Priority", systemImage: "arrow.up.arrow.down.square")
                            .font(DesignTokens.Typography.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(priority))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $priority, in: 1...999, step: 1)
                        .tint(.blue)

                    Text("Lower numbers = higher priority. Rules with priority 1 are evaluated first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Active Toggle
                Toggle(isOn: $isActive) {
                    Label("Rule Active", systemImage: isActive ? "checkmark.circle.fill" : "circle")
                        .font(DesignTokens.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isActive ? .blue : .secondary)
                }

                // Notes
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                    Label("Notes", systemImage: "note.text")
                        .font(DesignTokens.Typography.subheadline)
                        .fontWeight(.medium)

                    TextField("Optional notes about this rule", text: $notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
            }
        }
        .primaryCard()
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        GroupBox("Rule Preview") {
            VStack(spacing: DesignTokens.Spacing.m) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rule Summary")
                            .font(DesignTokens.Typography.subheadline)
                            .fontWeight(.medium)

                        Text(generateRuleSummary())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }

                HStack(spacing: DesignTokens.Spacing.m) {
                    Button("Test Rule") {
                        testRule()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isValidRule || isLoadingPreview)

                    if isLoadingPreview {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
        }
        .primaryCard()
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        HStack(spacing: DesignTokens.Spacing.m) {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Save Rule") {
                saveRule()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValidRule)
        }
    }

    // MARK: - Methods

    private func generateRuleSummary() -> String {
        guard !pattern.isEmpty else { return "Enter a pattern to see preview" }

        var summary = "If \(targetField.displayName.lowercased()) \(matchType.displayName.lowercased()) \"\(pattern)\""

        if let account = selectedAccount {
            summary += " on \(account.name)"
        }

        if enableAmountFilter {
            if !amountMin.isEmpty && !amountMax.isEmpty {
                summary += " and amount between €\(amountMin)-€\(amountMax)"
            } else if !amountMin.isEmpty {
                summary += " and amount ≥ €\(amountMin)"
            } else if !amountMax.isEmpty {
                summary += " and amount ≤ €\(amountMax)"
            }
        }

        if let type = transactionTypeFilter {
            summary += " (\(type.displayName.lowercased()))"
        }

        summary += " → assign category \"\(targetCategory.isEmpty ? "[Select Category]" : targetCategory)\""

        return summary
    }

    private func testRule() {
        guard isValidRule else { return }

        isLoadingPreview = true

        Task {
            do {
                // Create test rule
                let testRule = EnhancedCategorizationRule(
                    name: ruleName.isEmpty ? "Test Rule" : ruleName,
                    targetCategory: targetCategory,
                    tier: .simple,
                    priority: Int(priority)
                )

                // Configure simple rule
                let config = SimpleRuleConfig(
                    accountFilter: selectedAccount?.iban,
                    targetField: targetField,
                    matchType: matchType,
                    pattern: pattern,
                    amountMin: amountMin.isEmpty ? nil : Decimal(string: amountMin),
                    amountMax: amountMax.isEmpty ? nil : Decimal(string: amountMax),
                    transactionTypeFilter: transactionTypeFilter
                )
                testRule.simpleConfig = config

                // Fetch sample transactions for testing
                let sampleTransactions = try await fetchSampleTransactions()

                // Test rule
                let engine = EnhancedCategorizationEngine(modelContext: modelContext)
                let results = await engine.testRule(testRule, against: sampleTransactions)

                await MainActor.run {
                    previewResults = results
                    showingPreview = true
                    isLoadingPreview = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to test rule: \(error.localizedDescription)"
                    showingError = true
                    isLoadingPreview = false
                }
            }
        }
    }

    private func fetchSampleTransactions() async throws -> [ParsedTransaction] {
        // Fetch recent transactions for testing
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )
        descriptor.fetchLimit = 100

        let transactions = try modelContext.fetch(descriptor)

        return transactions.map { transaction in
            ParsedTransaction(
                iban: transaction.iban,
                sequenceNumber: transaction.sequenceNumber,
                date: transaction.date,
                amount: transaction.amount,
                balance: transaction.balance,
                counterIBAN: transaction.counterIBAN,
                counterName: transaction.counterName,
                description1: transaction.description1,
                description2: transaction.description2,
                description3: transaction.description3,
                transactionCode: transaction.transactionCode,
                valueDate: transaction.valueDate,
                returnReason: transaction.returnReason,
                mandateReference: transaction.mandateReference,
                transactionType: transaction.transactionType,
                contributor: transaction.contributor,
                sourceFile: transaction.sourceFile ?? ""
            )
        }
    }

    private func saveRule() {
        guard isValidRule else { return }

        do {
            // Create enhanced rule
            let enhancedRule = EnhancedCategorizationRule(
                name: ruleName,
                targetCategory: targetCategory,
                tier: .simple,
                priority: Int(priority),
                isActive: isActive,
                notes: notes.isEmpty ? nil : notes,
                createdBy: "User"
            )

            // Configure simple rule
            let config = SimpleRuleConfig(
                accountFilter: selectedAccount?.iban,
                targetField: targetField,
                matchType: matchType,
                pattern: pattern,
                amountMin: amountMin.isEmpty ? nil : Decimal(string: amountMin),
                amountMax: amountMax.isEmpty ? nil : Decimal(string: amountMax),
                transactionTypeFilter: transactionTypeFilter
            )
            enhancedRule.simpleConfig = config

            modelContext.insert(enhancedRule)
            try modelContext.save()

            dismiss()
        } catch {
            errorMessage = "Failed to save rule: \(error.localizedDescription)"
            showingError = true
        }
    }
}