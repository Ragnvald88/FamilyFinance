//
//  CSVImportService.swift
//  Family Finance
//
//  Production-grade CSV import service for Rabobank statements
//  Handles encoding detection, Dutch number parsing, duplicate detection
//
//  Version 2.0: Fixed architecture - UI coordination only, heavy work on BackgroundDataHandler
//  Created: 2025-12-22
//

import Foundation
@preconcurrency import SwiftData

// MARK: - CSV Import Result (Extended)

/// Result of CSV import operation with detailed statistics
struct CSVImportResult: Sendable {
    let totalRows: Int
    let imported: Int
    let duplicates: Int
    let errors: [CSVImportError]
    let duration: TimeInterval
    let categorized: Int
    let uncategorized: Int
    let batchID: UUID
    let filesProcessed: Int

    var successRate: Double {
        guard totalRows > 0 else { return 0 }
        return Double(imported) / Double(totalRows) * 100
    }

    var categorizationRate: Double {
        guard imported > 0 else { return 0 }
        return Double(categorized) / Double(imported) * 100
    }

    var hasErrors: Bool {
        !errors.isEmpty
    }

    /// Summary for display
    var summary: String {
        """
        Imported: \(imported) transactions
        Duplicates skipped: \(duplicates)
        Categorized: \(categorized) (\(String(format: "%.1f", categorizationRate))%)
        Duration: \(String(format: "%.2f", duration))s
        """
    }
}

// MARK: - Import Progress

/// Real-time import progress for UI updates
struct CSVImportProgress: Sendable {
    let processedRows: Int
    let totalRows: Int
    let currentFile: String
    let stage: CSVImportStage

    var percentage: Double {
        guard totalRows > 0 else { return 0 }
        return Double(processedRows) / Double(totalRows) * 100
    }
}

enum CSVImportStage: String, Sendable {
    case reading = "Reading files..."
    case parsing = "Parsing CSV..."
    case categorizing = "Categorizing..."
    case saving = "Saving to database..."
    case complete = "Import complete"

    var icon: String {
        switch self {
        case .reading: return "doc.text"
        case .parsing: return "list.bullet.rectangle"
        case .categorizing: return "tag"
        case .saving: return "externaldrive.fill"
        case .complete: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Parsed Transaction (Public - shared with CategorizationEngine)

/// Intermediate parsed transaction before categorization.
/// Public to allow CategorizationEngine access.
struct ParsedTransaction: Sendable {
    let iban: String
    let sequenceNumber: Int
    let date: Date
    let amount: Decimal
    let balance: Decimal
    let counterIBAN: String?
    let counterName: String?
    let description1: String?
    let description2: String?
    let description3: String?
    let transactionCode: String?      // Rabobank code (bg, tb, bc, id, ei, cb, db, ba)
    let valueDate: Date?              // Rentedatum
    let returnReason: String?         // Reden retour
    let mandateReference: String?     // Machtigingskenmerk (SEPA mandate)
    let transactionType: TransactionType
    let contributor: Contributor?
    let sourceFile: String

    var fullDescription: String {
        [description1, description2, description3]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: " ")
    }

    /// Unique key for duplicate detection
    /// Format: "IBAN-YYYYMMDD-sequence" (matches Transaction.generateUniqueKey)
    var uniqueKey: String {
        Transaction.generateUniqueKey(iban: iban, date: date, sequenceNumber: sequenceNumber)
    }

    /// Legacy unique key (for compatibility with v1.x databases)
    var legacyUniqueKey: String {
        "\(iban)-\(sequenceNumber)"
    }

    /// Helper: Is this likely a subscription/recurring (based on code)
    var isLikelyRecurring: Bool {
        transactionCode == "ei"  // Euro Incasso = SEPA Direct Debit
    }
}

/// Categorized transaction ready for saving
struct CategorizedTransaction: Sendable {
    let parsed: ParsedTransaction
    let autoCategory: String?
    let standardizedName: String?
}

// MARK: - CSV Import Service

/// Service for importing Rabobank CSV files.
///
/// **Architecture (v2.1 - Fixed MainActor Blocking):**
/// - `@Published` properties require MainActor for SwiftUI observation
/// - CSV parsing runs in background via `nonisolated` methods
/// - Progress updates hop to MainActor explicitly
/// - Heavy categorization/import delegated to BackgroundDataHandler
///
/// **Why not full @MainActor?**
/// CSV parsing (string operations on 15k rows) takes 200-500ms.
/// Running this synchronously on MainActor freezes the UI.
/// By making parsing `nonisolated`, we keep the UI responsive.
///
/// **Usage:**
/// ```swift
/// let service = CSVImportService(modelContainer: container)
/// let result = try await service.importFiles([url1, url2])
/// print(result.summary)
/// ```
@MainActor
class CSVImportService: ObservableObject {

    // MARK: - Published Properties (MainActor-bound for SwiftUI)

    @Published var isImporting = false
    @Published var progress: CSVImportProgress?
    @Published var lastError: CSVImportError?

    // MARK: - Dependencies

    private let modelContainer: ModelContainer
    private let categorizationEngine: CategorizationEngine

    // MARK: - Configuration
    // NOTE: IBANs are centralized in FamilyAccountsConfig.swift for privacy

    /// Maximum file size for CSV import (50MB)
    static let maxFileSizeBytes = 50_000_000

    /// Supported encodings for CSV files (try in order)
    /// Made nonisolated static for background thread access
    private static let supportedEncodings: [String.Encoding] = [
        .isoLatin1,     // Primary encoding for Rabobank
        .windowsCP1252, // Fallback for Windows
        .utf8           // Modern fallback
    ]

    /// Rabobank CSV column indices (26 columns total)
    private enum CSVColumn {
        static let iban = 0
        static let currency = 1
        static let bic = 2
        static let sequenceNumber = 3
        static let date = 4
        static let valueDate = 5
        static let amount = 6
        static let balance = 7
        static let counterIBAN = 8
        static let counterName = 9
        static let ultimatePartyName = 10
        static let initiatingPartyName = 11
        static let counterBIC = 12
        static let code = 13              // Transaction code (bg, tb, bc, id, ei, cb, db, ba)
        static let batchID = 14
        static let transactionReference = 15
        static let mandateReference = 16  // SEPA mandate ID for recurring
        static let creditorID = 17
        static let paymentReference = 18
        static let description1 = 19
        static let description2 = 20
        static let description3 = 21
        static let returnReason = 22      // Reden retour
        static let originalAmount = 23
        static let originalCurrency = 24
        static let exchangeRate = 25
    }

    // MARK: - Thread-Safe DateFormatter (static for safety)

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return formatter
    }()

    // MARK: - Initialization

    init(modelContainer: ModelContainer, categorizationEngine: CategorizationEngine) {
        self.modelContainer = modelContainer
        self.categorizationEngine = categorizationEngine
    }

    // MARK: - Public Import Methods

    /// Import multiple CSV files with progress tracking.
    /// - CSV parsing runs in BACKGROUND (not MainActor) to keep UI responsive
    /// - Progress updates hop to MainActor for SwiftUI
    /// - Categorization + database writes run on BackgroundDataHandler actor
    func importFiles(_ urls: [URL]) async throws -> CSVImportResult {
        let startTime = Date()
        let batchID = UUID()

        isImporting = true
        lastError = nil
        defer { isImporting = false }

        // Phase 1: Parse all CSV files in BACKGROUND
        // This is the critical fix - parsing 15k rows no longer blocks UI
        progress = CSVImportProgress(
            processedRows: 0,
            totalRows: urls.count,
            currentFile: "Reading files...",
            stage: .reading
        )

        // Run parsing on background thread, collect results
        let parsingResult = await parseFilesInBackground(urls)

        // Check for empty result
        guard !parsingResult.transactions.isEmpty else {
            return CSVImportResult(
                totalRows: 0,
                imported: 0,
                duplicates: 0,
                errors: parsingResult.errors,
                duration: Date().timeIntervalSince(startTime),
                categorized: 0,
                uncategorized: 0,
                batchID: batchID,
                filesProcessed: urls.count
            )
        }

        let allParsedTransactions = parsingResult.transactions
        let totalRows = allParsedTransactions.count
        let errors = parsingResult.errors

        // Phase 2: Build rules cache (fast, on MainActor - needs ModelContext)
        progress = CSVImportProgress(
            processedRows: 0,
            totalRows: totalRows,
            currentFile: "Preparing categorization...",
            stage: .categorizing
        )

        let rulesCache: RulesCache
        do {
            rulesCache = try await categorizationEngine.buildRulesCache()
        } catch {
            // Fallback to hardcoded rules if database fetch fails
            rulesCache = categorizationEngine.buildHardcodedRulesCache()
        }

        // Phase 3: Delegate to BackgroundDataHandler for categorization + import
        progress = CSVImportProgress(
            processedRows: 0,
            totalRows: totalRows,
            currentFile: "Categorizing & saving...",
            stage: .saving
        )

        let handler = BackgroundDataHandler(modelContainer: modelContainer)
        let importResult = try await handler.importWithCategorization(
            allParsedTransactions,
            rulesCache: rulesCache
        )

        progress = CSVImportProgress(
            processedRows: importResult.imported,
            totalRows: totalRows,
            currentFile: "Import complete",
            stage: .complete
        )

        let duration = Date().timeIntervalSince(startTime)

        return CSVImportResult(
            totalRows: totalRows,
            imported: importResult.imported,
            duplicates: importResult.duplicates,
            errors: errors,
            duration: duration,
            categorized: importResult.categorized,
            uncategorized: importResult.uncategorized,
            batchID: batchID,
            filesProcessed: urls.count
        )
    }

    // MARK: - Background Parsing

    /// Result of background parsing operation
    private struct ParsingResult: Sendable {
        let transactions: [ParsedTransaction]
        let errors: [CSVImportError]
    }

    /// Parse all CSV files in background to avoid blocking MainActor.
    /// Updates progress on MainActor via explicit hops.
    private func parseFilesInBackground(_ urls: [URL]) async -> ParsingResult {
        // Capture what we need for background work
        let urlCount = urls.count

        // Run parsing in detached task (off MainActor)
        let result = await Task.detached(priority: .userInitiated) { [self] in
            var transactions: [ParsedTransaction] = []
            var errors: [CSVImportError] = []

            for (index, url) in urls.enumerated() {
                // Update progress on MainActor
                await MainActor.run {
                    self.progress = CSVImportProgress(
                        processedRows: index,
                        totalRows: urlCount,
                        currentFile: url.lastPathComponent,
                        stage: .reading
                    )
                }

                do {
                    // parseCSVFile is nonisolated - runs on this background thread
                    let parsed = try Self.parseCSVFile(url, sourceFile: url.lastPathComponent)
                    transactions.append(contentsOf: parsed)
                } catch let error as CSVImportError {
                    errors.append(error)
                } catch {
                    errors.append(.fileReadFailed(url.lastPathComponent, error.localizedDescription))
                }
            }

            return ParsingResult(transactions: transactions, errors: errors)
        }.value

        return result
    }

    // MARK: - CSV Parsing (nonisolated static - runs on background thread)

    /// Parse a single CSV file with automatic encoding detection.
    /// Made `nonisolated static` to allow calling from background Task.detached
    private nonisolated static func parseCSVFile(_ url: URL, sourceFile: String) throws -> [ParsedTransaction] {
        // Check file size before loading (prevent memory exhaustion)
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let fileSize = fileAttributes?[.size] as? Int, fileSize > Self.maxFileSizeBytes {
            throw CSVImportError.fileTooLarge(
                url.lastPathComponent,
                fileSize,
                Self.maxFileSizeBytes
            )
        }

        // Try each encoding until one works
        var csvContent: String?

        for encoding in supportedEncodings {
            if let content = try? String(contentsOf: url, encoding: encoding) {
                // Validate the content looks like valid CSV
                if content.contains("IBAN") || content.contains("Volgnr") || content.contains("Datum") {
                    csvContent = content
                    break
                }
            }
        }

        guard let content = csvContent else {
            throw CSVImportError.encodingNotSupported(url.lastPathComponent)
        }

        // Parse CSV lines
        let lines = content.components(separatedBy: .newlines)
        var transactions: [ParsedTransaction] = []

        for (lineIndex, line) in lines.enumerated() {
            // Skip header and empty lines
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if lineIndex == 0 || trimmedLine.isEmpty {
                continue
            }

            // Skip if it looks like a header row (contains IBAN/BBAN)
            if trimmedLine.contains("IBAN/BBAN") {
                continue
            }

            do {
                if let transaction = try parseCSVLine(trimmedLine, rowNumber: lineIndex + 1, sourceFile: sourceFile) {
                    transactions.append(transaction)
                }
            } catch {
                // Log but continue - don't abort entire import for one bad row
                print("⚠️ Row \(lineIndex + 1): \(error.localizedDescription)")
            }
        }

        return transactions
    }

    /// Parse a single CSV line using custom parser (handles Rabobank quirks).
    private nonisolated static func parseCSVLine(_ line: String, rowNumber: Int, sourceFile: String) throws -> ParsedTransaction? {
        let fields = parseCSVFields(line)

        // Rabobank CSVs should have 22+ columns
        guard fields.count >= 22 else {
            throw CSVImportError.invalidFormat("Row \(rowNumber): Expected 22+ columns, got \(fields.count)")
        }

        // Extract and validate required fields
        let iban = fields[CSVColumn.iban].trimmingCharacters(in: .whitespaces)
        guard !iban.isEmpty, iban.hasPrefix("NL") else {
            return nil // Skip invalid rows
        }

        let sequenceStr = fields[CSVColumn.sequenceNumber].trimmingCharacters(in: .whitespaces)
        guard let sequenceNumber = Int(sequenceStr) else {
            throw CSVImportError.invalidField("Row \(rowNumber): Invalid sequence number '\(sequenceStr)'")
        }

        let dateStr = fields[CSVColumn.date].trimmingCharacters(in: .whitespaces)
        guard let date = Self.dateFormatter.date(from: dateStr) else {
            throw CSVImportError.invalidField("Row \(rowNumber): Invalid date '\(dateStr)'")
        }

        let amountStr = fields[CSVColumn.amount].trimmingCharacters(in: .whitespaces)
        let amount = parseDutchAmount(amountStr)

        let balanceStr = fields[CSVColumn.balance].trimmingCharacters(in: .whitespaces)
        let balance = parseDutchAmount(balanceStr)

        // Core optional fields
        let counterIBAN = fields[CSVColumn.counterIBAN].trimmingCharacters(in: .whitespaces)
        let counterName = fields[CSVColumn.counterName].trimmingCharacters(in: .whitespaces)
        let desc1 = fields[CSVColumn.description1].trimmingCharacters(in: .whitespaces)
        let desc2 = fields[CSVColumn.description2].trimmingCharacters(in: .whitespaces)
        let desc3 = fields[CSVColumn.description3].trimmingCharacters(in: .whitespaces)

        // Rabobank-specific fields (Phase 2.1)
        let transactionCode = fields[CSVColumn.code].trimmingCharacters(in: .whitespaces)
        let valueDateStr = fields[CSVColumn.valueDate].trimmingCharacters(in: .whitespaces)
        let valueDate = valueDateStr.isEmpty ? nil : Self.dateFormatter.date(from: valueDateStr)
        let mandateRef = fields[CSVColumn.mandateReference].trimmingCharacters(in: .whitespaces)

        // Return reason - safely extract if column exists
        let returnReason: String? = fields.count > CSVColumn.returnReason
            ? fields[CSVColumn.returnReason].trimmingCharacters(in: .whitespaces)
            : nil

        // Detect transaction type
        let transactionType = Self.determineTransactionType(
            amount: amount,
            counterIBAN: counterIBAN,
            iban: iban
        )

        // Detect contributor (for Inleg tracking)
        let contributor = Self.detectContributor(
            counterIBAN: counterIBAN,
            counterName: counterName,
            description: desc1,
            sourceIBAN: iban,
            amount: amount
        )

        return ParsedTransaction(
            iban: iban,
            sequenceNumber: sequenceNumber,
            date: date,
            amount: amount,
            balance: balance,
            counterIBAN: counterIBAN.isEmpty ? nil : counterIBAN,
            counterName: counterName.isEmpty ? nil : counterName,
            description1: desc1.isEmpty ? nil : desc1,
            description2: desc2.isEmpty ? nil : desc2,
            description3: desc3.isEmpty ? nil : desc3,
            transactionCode: transactionCode.isEmpty ? nil : transactionCode,
            valueDate: valueDate,
            returnReason: returnReason?.isEmpty == true ? nil : returnReason,
            mandateReference: mandateRef.isEmpty ? nil : mandateRef,
            transactionType: transactionType,
            contributor: contributor,
            sourceFile: sourceFile
        )
    }

    /// Parse CSV fields handling quoted strings and escaped quotes correctly.
    /// Handles: "field", "field with ""quotes""", empty fields, etc.
    private nonisolated static func parseCSVFields(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]

            if char == "\"" {
                if insideQuotes {
                    // Check if this is an escaped quote ("")
                    let nextIndex = line.index(after: i)
                    if nextIndex < line.endIndex && line[nextIndex] == "\"" {
                        // Escaped quote - add single quote and skip next char
                        currentField.append("\"")
                        i = nextIndex  // Skip the second quote
                    } else {
                        // End of quoted field
                        insideQuotes = false
                    }
                } else {
                    // Start of quoted field
                    insideQuotes = true
                }
            } else if char == "," && !insideQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }

            i = line.index(after: i)
        }

        // Add last field
        fields.append(currentField)

        return fields
    }

    // MARK: - Parsing Helpers (nonisolated static)

    /// Parse Dutch number format (+1.234,56 → 1234.56).
    private nonisolated static func parseDutchAmount(_ amountStr: String) -> Decimal {
        guard !amountStr.isEmpty else { return 0 }

        // Remove thousands separator (dot), replace decimal comma with dot, remove +
        let cleaned = amountStr
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "+", with: "")

        return Decimal(string: cleaned) ?? 0
    }

    /// Validate Dutch IBAN format (NL + 2 check digits + 4 bank code + 10 account number).
    /// Returns nil if valid, or error message if invalid.
    static func validateDutchIBAN(_ iban: String) -> String? {
        let cleanIBAN = iban.uppercased().replacingOccurrences(of: " ", with: "")

        // Check length (Dutch IBANs are 18 characters)
        guard cleanIBAN.count == 18 else {
            return "Dutch IBAN must be 18 characters (got \(cleanIBAN.count))"
        }

        // Check country code
        guard cleanIBAN.hasPrefix("NL") else {
            return "Dutch IBAN must start with 'NL'"
        }

        // Check format: NL + 2 digits + 4 letters + 10 digits
        let pattern = "^NL[0-9]{2}[A-Z]{4}[0-9]{10}$"
        guard cleanIBAN.range(of: pattern, options: .regularExpression) != nil else {
            return "Invalid Dutch IBAN format"
        }

        // Validate check digits (IBAN mod 97 algorithm)
        let rearranged = String(cleanIBAN.dropFirst(4)) + String(cleanIBAN.prefix(4))
        var numericString = ""
        for char in rearranged {
            if let digit = char.wholeNumberValue {
                numericString += String(digit)
            } else if let ascii = char.asciiValue, char.isLetter {
                // A=10, B=11, ..., Z=35
                numericString += String(Int(ascii) - 55)
            }
        }

        // Check mod 97 (valid IBAN gives remainder 1)
        var remainder = 0
        for char in numericString {
            if let digit = char.wholeNumberValue {
                remainder = (remainder * 10 + digit) % 97
            }
        }

        if remainder != 1 {
            return "Invalid IBAN check digits"
        }

        return nil  // Valid
    }

    // MARK: - Static Detection Methods (nonisolated for background thread access)

    /// Determine transaction type based on amount and counter party.
    nonisolated static func determineTransactionType(
        amount: Decimal,
        counterIBAN: String,
        iban: String
    ) -> TransactionType {
        // Check if it's an internal transfer between family accounts
        if FamilyAccountsConfig.isFamilyAccount(counterIBAN) {
            return .transfer
        }

        // Income vs expense based on amount sign
        if amount > 0 {
            return .income
        } else if amount < 0 {
            return .expense
        } else {
            return .unknown
        }
    }

    /// Detect contributor for Inleg tracking with improved pattern matching.
    /// Detect which family member made a contribution to the joint account.
    /// Customize the patterns in FamilyAccountsConfig.swift for your family.
    nonisolated static func detectContributor(
        counterIBAN: String,
        counterName: String,
        description: String,
        sourceIBAN: String,
        amount: Decimal
    ) -> Contributor? {
        // Only detect contributions for incoming transactions to joint account
        guard amount > 0, sourceIBAN == FamilyAccountsConfig.jointAccountIBAN else {
            return nil
        }

        let nameLower = counterName.lowercased()
        let descLower = description.lowercased()

        // Partner 1: Check IBAN first (most reliable)
        if counterIBAN == FamilyAccountsConfig.partner1IBAN {
            return .partner1
        }

        // Partner 2: Check IBANs
        if FamilyAccountsConfig.partner2IBANs.contains(counterIBAN) {
            return .partner2
        }

        // Name-based detection for Partner 1
        for pattern in FamilyAccountsConfig.partner1NamePatterns {
            if nameLower.contains(pattern) {
                return .partner1
            }
        }

        // Name-based detection for Partner 2
        for pattern in FamilyAccountsConfig.partner2NamePatterns {
            if nameLower.contains(pattern) {
                return .partner2
            }
        }

        // Description-based detection
        if descLower.contains("inleg") || descLower.contains("contribution") || descLower.contains("bijdrage") {
            for pattern in FamilyAccountsConfig.partner1InlegPatterns {
                if descLower.contains(pattern) {
                    return .partner1
                }
            }
            for pattern in FamilyAccountsConfig.partner2InlegPatterns {
                if descLower.contains(pattern) {
                    return .partner2
                }
            }
        }

        return nil
    }
}

// MARK: - Errors

enum CSVImportError: Error, LocalizedError, Sendable {
    case encodingNotSupported(String)
    case invalidFormat(String)
    case invalidField(String)
    case fileReadFailed(String, String)
    case saveFailed(String)
    case fileTooLarge(String, Int, Int)
    case invalidIBAN(String, String)

    var errorDescription: String? {
        switch self {
        case .encodingNotSupported(let filename):
            return "Could not detect encoding for file: \(filename)"
        case .invalidFormat(let reason):
            return "Invalid CSV format: \(reason)"
        case .invalidField(let reason):
            return "Invalid field: \(reason)"
        case .fileReadFailed(let filename, let reason):
            return "Failed to read \(filename): \(reason)"
        case .saveFailed(let reason):
            return "Failed to save: \(reason)"
        case .fileTooLarge(let filename, let actualSize, let maxSize):
            let actualMB = Double(actualSize) / 1_000_000
            let maxMB = Double(maxSize) / 1_000_000
            return "File \(filename) is too large (\(String(format: "%.1f", actualMB))MB). Maximum size is \(String(format: "%.0f", maxMB))MB"
        case .invalidIBAN(let iban, let reason):
            return "Invalid IBAN '\(iban)': \(reason)"
        }
    }
}
