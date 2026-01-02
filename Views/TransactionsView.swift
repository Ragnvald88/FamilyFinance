//
//  TransactionsView.swift
//  Florijn
//
//  Extracted from FlorijnApp.swift for better code organization
//
//  Created: 2025-01-02
//

import SwiftUI
import SwiftData

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
                            Text(account.name.isEmpty ? account.iban : account.name)
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
            autoCategory: selectedCategory.isEmpty ? "Uncategorized" : selectedCategory,
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
