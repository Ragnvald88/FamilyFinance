//
//  TransactionDetailView.swift
//  Florijn
//
//  Transaction detail sheet with editing capabilities
//  Displays: all fields, category picker, notes, splits, recurring, audit log
//
//  Created: 2025-12-23
//

import SwiftUI
@preconcurrency import SwiftData

// MARK: - Transaction Detail View

struct TransactionDetailView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Data

    @Bindable var transaction: Transaction
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    // MARK: - State

    @State private var selectedCategory: String
    @State private var editedNotes: String
    @State private var showCategoryReason = false
    @State private var categoryChangeReason = ""
    @State private var hasUnsavedChanges = false

    // MARK: - Initialization

    init(transaction: Transaction) {
        self.transaction = transaction
        _selectedCategory = State(initialValue: transaction.effectiveCategory)
        _editedNotes = State(initialValue: transaction.notes ?? "")
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Main content
                VStack(spacing: 16) {
                    counterPartySection
                    categorySection
                    descriptionsSection
                    notesSection

                    if transaction.isSplit {
                        splitBreakdownSection
                    }

                    if transaction.recurringTransaction != nil {
                        recurringSection
                    }

                    if let auditLog = transaction.auditLog, !auditLog.isEmpty {
                        auditHistorySection(logs: auditLog)
                    }

                    metadataSection
                }
            }
            .padding(PremiumSpacing.large)
        }
        .frame(minWidth: 600, minHeight: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    saveChangesIfNeeded()
                    dismiss()
                }
                .buttonStyle(PremiumSecondaryButtonStyle())
            }

            if hasUnsavedChanges {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .buttonStyle(PremiumPrimaryButtonStyle())
                }
            }
        }
        .onChange(of: selectedCategory) { _, newValue in
            if newValue != transaction.effectiveCategory {
                hasUnsavedChanges = true
            }
        }
        .onChange(of: editedNotes) { _, newValue in
            if newValue != (transaction.notes ?? "") {
                hasUnsavedChanges = true
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: PremiumSpacing.medium) {
            HStack(alignment: .top) {
                // Type indicator
                Image(systemName: transaction.transactionType.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(typeColor)
                    .frame(width: 60, height: 60)
                    .background(typeColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    // Merchant name
                    Text(transaction.standardizedName ?? transaction.counterName ?? "Unknown")
                        .font(.title2)
                        .fontWeight(.bold)

                    // Date
                    Text(transaction.date.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Amount
                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.amount.toCurrencyString())
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(transaction.amount >= 0 ? .green : .primary)

                    Text("Balance: \(transaction.balance.toCurrencyString())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Type badge
            HStack {
                Label(transaction.transactionType.displayName, systemImage: transaction.transactionType.icon)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(typeColor.opacity(0.1))
                    .foregroundStyle(typeColor)
                    .clipShape(Capsule())

                if let code = transaction.transactionCode {
                    transactionCodeBadge(code: code)
                }

                if transaction.isSplit {
                    Label("Split", systemImage: "divide")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.florijnLightBlue.opacity(0.1))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                }

                if transaction.recurringTransaction != nil {
                    Label("Recurring", systemImage: "repeat")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Counter Party Section

    private var counterPartySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if let counterIBAN = transaction.counterIBAN, !counterIBAN.isEmpty {
                    DetailRow(label: "Counter IBAN", value: counterIBAN, monospace: true)
                }

                if let counterName = transaction.counterName {
                    DetailRow(label: "Counter Name", value: counterName)
                }

                if let standardizedName = transaction.standardizedName,
                   standardizedName != transaction.counterName {
                    DetailRow(label: "Standardized Name", value: standardizedName)
                }

                DetailRow(label: "Own IBAN", value: transaction.iban, monospace: true)
            }
        } label: {
            Label("Counter Party", systemImage: "person.2.fill")
                .font(.headline)
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Current category display
                HStack {
                    Text("Current Category")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(transaction.effectiveCategory)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }

                Divider()

                // Category picker
                HStack {
                    Text("Change Category")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categoryNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }

                // Show reason field when category changed
                if selectedCategory != transaction.effectiveCategory {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reason for change (optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("Why are you changing this category?", text: $categoryChangeReason)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.top, 8)
                }

                // Auto vs Override indicator
                if transaction.categoryOverride != nil {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.orange)
                        Text("Manual override active")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Clear Override") {
                            clearCategoryOverride()
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                    .padding(.top, 4)
                } else if transaction.autoCategory != nil {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .foregroundStyle(.blue)
                        Text("Auto-categorized")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
        } label: {
            Label("Category", systemImage: "square.grid.2x2.fill")
                .font(.headline)
        }
    }

    // MARK: - Descriptions Section

    private var descriptionsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if let desc1 = transaction.description1, !desc1.isEmpty {
                    DetailRow(label: "Description 1", value: desc1)
                }

                if let desc2 = transaction.description2, !desc2.isEmpty {
                    DetailRow(label: "Description 2", value: desc2)
                }

                if let desc3 = transaction.description3, !desc3.isEmpty {
                    DetailRow(label: "Description 3", value: desc3)
                }

                if !transaction.fullDescription.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Full Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(transaction.fullDescription)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
            }
        } label: {
            Label("Description", systemImage: "text.alignleft")
                .font(.headline)
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $editedNotes)
                    .font(.body)
                    .frame(minHeight: 80, maxHeight: 150)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )

                if editedNotes.isEmpty {
                    Text("Add notes about this transaction...")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } label: {
            Label("Notes", systemImage: "note.text")
                .font(.headline)
        }
    }

    // MARK: - Split Breakdown Section

    private var splitBreakdownSection: some View {
        GroupBox {
            VStack(spacing: 8) {
                if let splits = transaction.splits?.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                    // Use enumerated() for unique identifier since splits may have duplicate categories
                    ForEach(Array(splits.enumerated()), id: \.offset) { index, split in
                        HStack {
                            Text(split.category)
                                .fontWeight(.medium)

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text(split.amount.toCurrencyString())
                                    .fontWeight(.semibold)

                                Text(String(format: "%.1f%%", split.percentageOfParent))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)

                        if index < splits.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        } label: {
            Label("Split Breakdown", systemImage: "divide")
                .font(.headline)
        }
    }

    // MARK: - Recurring Section

    private var recurringSection: some View {
        GroupBox {
            if let recurring = transaction.recurringTransaction {
                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(label: "Name", value: recurring.name)
                    DetailRow(label: "Frequency", value: recurring.frequency.displayName)
                    DetailRow(label: "Expected Amount", value: recurring.expectedAmount.toCurrencyString())

                    HStack {
                        Text("Next Due")
                            .foregroundStyle(.secondary)

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text(recurring.nextDueDate.formatted(date: .abbreviated, time: .omitted))
                                .fontWeight(.medium)

                            if recurring.isOverdue {
                                Text("Overdue!")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else {
                                Text("in \(recurring.daysUntilDue) days")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if recurring.occurrenceCount > 0 {
                        DetailRow(
                            label: "Total Occurrences",
                            value: "\(recurring.occurrenceCount)"
                        )
                    }
                }
            }
        } label: {
            HStack {
                Label("Recurring Transaction", systemImage: "repeat")
                    .font(.headline)

                Spacer()

                Image(systemName: transaction.recurringTransaction?.isActive == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(transaction.recurringTransaction?.isActive == true ? .green : .red)
            }
        }
    }

    // MARK: - Audit History Section

    private func auditHistorySection(logs: [TransactionAuditLog]) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(logs.sorted(by: { $0.changedAt > $1.changedAt }).enumerated()), id: \.offset) { index, log in
                    HStack(alignment: .top, spacing: 12) {
                        // Timeline indicator
                        VStack {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 10, height: 10)

                            if index < logs.count - 1 {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 2)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: log.action.icon)
                                    .foregroundStyle(.secondary)

                                Text(log.action.displayName)
                                    .fontWeight(.medium)

                                Spacer()

                                Text(log.changedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let previousValue = log.previousValue {
                                HStack(spacing: 4) {
                                    Text(previousValue)
                                        .font(.caption)
                                        .strikethrough()
                                        .foregroundStyle(.red)

                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    Text(log.newValue)
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            } else {
                                Text(log.newValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let reason = log.reason, !reason.isEmpty {
                                Text("Reason: \(reason)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .italic()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        } label: {
            Label("Change History (\(logs.count))", systemImage: "clock.arrow.circlepath")
                .font(.headline)
        }
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(label: "Unique Key", value: transaction.uniqueKey, monospace: true)
                DetailRow(label: "Sequence Number", value: "\(transaction.sequenceNumber)")
                DetailRow(label: "Imported At", value: transaction.importedAt.formatted(date: .abbreviated, time: .shortened))

                if let sourceFile = transaction.sourceFile {
                    DetailRow(label: "Source File", value: sourceFile)
                }

                if let valueDate = transaction.valueDate {
                    DetailRow(label: "Value Date", value: valueDate.formatted(date: .abbreviated, time: .omitted))
                }

                if let returnReason = transaction.returnReason, !returnReason.isEmpty {
                    DetailRow(label: "Return Reason", value: returnReason)
                }

                if let mandateRef = transaction.mandateReference, !mandateRef.isEmpty {
                    DetailRow(label: "Mandate Reference", value: mandateRef)
                }
            }
        } label: {
            Label("Metadata", systemImage: "info.circle")
                .font(.headline)
        }
    }

    // MARK: - Helper Views

    private func transactionCodeBadge(code: String) -> some View {
        let description = transactionCodeDescription(code)

        return HStack(spacing: 4) {
            Text(code.uppercased())
                .fontWeight(.semibold)
            Text(description)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .foregroundStyle(.blue)
        .clipShape(Capsule())
    }

    private func transactionCodeDescription(_ code: String) -> String {
        switch code.lowercased() {
        case "bg": return "Transfer"
        case "bc": return "Debit Card"
        case "id": return "iDEAL"
        case "ei": return "Direct Debit"
        case "tb": return "Telebanking"
        case "cb": return "Int'l Incoming"
        case "db": return "Bank Fee"
        case "ba": return "ATM"
        default: return ""
        }
    }

    // MARK: - Computed Properties

    private var typeColor: Color {
        switch transaction.transactionType {
        case .income: return .green
        case .expense: return .red
        case .transfer: return .blue
        case .unknown: return .gray
        }
    }

    private var categoryNames: [String] {
        // Get category names based on transaction type
        let relevantCategories = categories.filter { category in
            category.type == transaction.transactionType || category.type == .expense || category.type == .income
        }

        var names = relevantCategories.map(\.name)

        // Add current category if not in list
        if !names.contains(transaction.effectiveCategory) {
            names.insert(transaction.effectiveCategory, at: 0)
        }

        // Add common fallback
        if !names.contains("Niet Gecategoriseerd") {
            names.append("Niet Gecategoriseerd")
        }

        return names.sorted()
    }

    // MARK: - Actions

    private func saveChanges() {
        // Save category change if different
        if selectedCategory != transaction.effectiveCategory {
            let reason = categoryChangeReason.isEmpty ? nil : categoryChangeReason
            transaction.updateCategoryOverride(selectedCategory, reason: reason)
            categoryChangeReason = ""
        }

        // Save notes change
        let trimmedNotes = editedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNotes != (transaction.notes ?? "") {
            transaction.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        }

        do {
            try modelContext.save()
            hasUnsavedChanges = false
        } catch {
            print("Failed to save transaction: \(error)")
        }
    }

    private func saveChangesIfNeeded() {
        if hasUnsavedChanges {
            saveChanges()
        }
    }

    private func clearCategoryOverride() {
        transaction.updateCategoryOverride(nil, reason: "Cleared manual override")
        selectedCategory = transaction.effectiveCategory
        do {
            try modelContext.save()
        } catch {
            print("Failed to clear override: \(error)")
        }
    }
}

// MARK: - Detail Row Component

private struct DetailRow: View {
    let label: String
    let value: String
    var monospace: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            if monospace {
                Text(value)
                    .monospaced()
                    .textSelection(.enabled)
            } else {
                Text(value)
                    .textSelection(.enabled)
            }
        }
    }
}

// MARK: - Preview Helper

private struct TransactionDetailPreview: View {
    @State private var container: ModelContainer?
    @State private var transaction: Transaction?
    @State private var error: String?

    var body: some View {
        Group {
            if let container = container, let transaction = transaction {
                TransactionDetailView(transaction: transaction)
                    .modelContainer(container)
            } else if let error = error {
                Text("Preview Error: \(error)")
            } else {
                ProgressView("Loading preview...")
            }
        }
        .task {
            await setupPreview()
        }
    }

    private func setupPreview() async {
        do {
            let schema = Schema([
                Transaction.self, Account.self, Category.self,
                TransactionSplit.self, RecurringTransaction.self, TransactionAuditLog.self,
                Liability.self, Merchant.self, BudgetPeriod.self
            ])
            let newContainer = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )

            let context = newContainer.mainContext

            let newTransaction = Transaction(
                iban: "NL00BANK0123456001",
                sequenceNumber: 42,
                date: Date(),
                amount: Decimal(-45.50),
                balance: Decimal(1234.56),
                counterIBAN: "NL00TEST9999999999",
                counterName: "ALBERT HEIJN 1308",
                standardizedName: "Albert Heijn",
                description1: "Betaalautomaat",
                description2: "12:34 AMSTERDAM",
                transactionCode: "bc",
                autoCategory: "Boodschappen",
                transactionType: .expense
            )
            context.insert(newTransaction)

            let categories = ["Boodschappen", "Uit Eten", "Winkelen", "Vervoer"]
            for (i, name) in categories.enumerated() {
                let cat = Category(name: name, type: .expense, monthlyBudget: 500, sortOrder: i)
                context.insert(cat)
            }

            try context.save()

            await MainActor.run {
                self.container = newContainer
                self.transaction = newTransaction
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
}

#Preview {
    TransactionDetailPreview()
}
