//
//  ExportService.swift
//  Family Finance
//
//  Export service for CSV and Excel exports with Dutch formatting
//  Mirror of Python export functionality
//
//  Created: 2025-12-22
//

import Foundation
import SwiftData

// MARK: - Export Format

enum ExportFormat {
    case csv
    case excel // Future: requires external library like XlsxWriter Swift wrapper
    case json
}

// MARK: - Export Service

@MainActor
class ExportService: ObservableObject {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Published State

    @Published var isExporting = false
    @Published var exportProgress: Double = 0

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Export Methods

    /// Export all transactions to CSV
    func exportToCSV(url: URL, filter: TransactionFilter? = nil) async throws {
        isExporting = true
        exportProgress = 0
        defer { isExporting = false }

        // Fetch transactions
        let transactions = try await fetchTransactions(filter: filter)

        // Build CSV content
        var csvContent = buildCSVHeader()

        for (index, transaction) in transactions.enumerated() {
            csvContent += buildCSVRow(transaction: transaction)

            if index % 100 == 0 {
                exportProgress = Double(index) / Double(transactions.count)
            }
        }

        // Write to file
        try csvContent.write(to: url, atomically: true, encoding: .utf8)
        exportProgress = 1.0
    }

    /// Export categorization rules to CSV
    func exportRulesToCSV(url: URL) async throws {
        isExporting = true
        defer { isExporting = false }

        let descriptor = FetchDescriptor<CategorizationRule>(
            sortBy: [SortDescriptor(\CategorizationRule.priority)]
        )

        let rules = try modelContext.fetch(descriptor)

        var csvContent = "Pattern,Standardized Name,Category,Priority,Active,Match Type,Match Count\n"

        for rule in rules {
            let row = [
                escapeCSV(rule.pattern),
                escapeCSV(rule.standardizedName ?? ""),
                escapeCSV(rule.targetCategory),
                String(rule.priority),
                rule.isActive ? "Yes" : "No",
                rule.matchType.rawValue,
                String(rule.matchCount)
            ].joined(separator: ",")

            csvContent += row + "\n"
        }

        try csvContent.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Export to JSON format (for analysis/backup)
    func exportToJSON(url: URL, filter: TransactionFilter? = nil) async throws {
        isExporting = true
        defer { isExporting = false }

        let transactions = try await fetchTransactions(filter: filter)

        let exportData = transactions.map { transaction -> [String: Any] in
            [
                "iban": transaction.iban,
                "sequenceNumber": transaction.sequenceNumber,
                "date": ISO8601DateFormatter().string(from: transaction.date),
                "amount": NSDecimalNumber(decimal: transaction.amount).doubleValue,
                "balance": NSDecimalNumber(decimal: transaction.balance).doubleValue,
                "counterIBAN": transaction.counterIBAN as Any,
                "counterName": transaction.counterName as Any,
                "description": transaction.fullDescription,
                "category": transaction.effectiveCategory,
                "type": transaction.transactionType.rawValue,
                "contributor": transaction.contributor?.rawValue as Any
            ]
        }

        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        try jsonData.write(to: url)
    }

    // MARK: - Private Helpers

    private func fetchTransactions(filter: TransactionFilter?) async throws -> [Transaction] {
        // Use denormalized year/month fields (not Calendar.current.component which doesn't work in predicates)
        let predicate: Predicate<Transaction>?

        switch (filter?.year, filter?.month) {
        case let (year?, month?):
            predicate = #Predicate<Transaction> { $0.year == year && $0.month == month }
        case let (year?, nil):
            predicate = #Predicate<Transaction> { $0.year == year }
        case let (nil, month?):
            predicate = #Predicate<Transaction> { $0.month == month }
        case (nil, nil):
            predicate = nil
        }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Transaction.date)]
        )

        return try modelContext.fetch(descriptor)
    }

    private func buildCSVHeader() -> String {
        let headers = [
            "IBAN",
            "Sequence Number",
            "Date",
            "Year",
            "Month",
            "Amount",
            "Balance",
            "Counter IBAN",
            "Counter Name",
            "Description",
            "Category",
            "Category Override",
            "Type",
            "Contributor",
            "Imported At"
        ]
        return headers.joined(separator: ",") + "\n"
    }

    private func buildCSVRow(transaction: Transaction) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let importFormatter = DateFormatter()
        importFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let fields = [
            escapeCSV(transaction.iban),
            String(transaction.sequenceNumber),
            dateFormatter.string(from: transaction.date),
            String(transaction.year),
            String(transaction.month),
            formatDutchAmount(transaction.amount),
            formatDutchAmount(transaction.balance),
            escapeCSV(transaction.counterIBAN ?? ""),
            escapeCSV(transaction.counterName ?? ""),
            escapeCSV(transaction.fullDescription),
            escapeCSV(transaction.effectiveCategory),
            escapeCSV(transaction.categoryOverride ?? ""),
            transaction.transactionType.rawValue,
            escapeCSV(transaction.contributor?.rawValue ?? ""),
            importFormatter.string(from: transaction.importedAt)
        ]

        return fields.joined(separator: ",") + "\n"
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private func formatDutchAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let sign = amount >= 0 ? "+" : ""
        return sign + (formatter.string(from: amount as NSNumber) ?? "0,00")
    }
}
