//
//  ThreadSafeCategorization.swift
//  Family Finance
//
//  Thread-safe categorization infrastructure for background processing.
//  Solves the @MainActor bottleneck by providing Sendable types that can
//  cross actor boundaries safely.
//
//  Architecture:
//  - CachedRule: Sendable copy of CategorizationRule with pre-compiled regex
//  - RulesCache: Thread-safe cache that can be passed to BackgroundDataHandler
//  - Categorization happens inside @ModelActor, not on MainActor
//
//  Created: 2025-12-23
//

import Foundation

// MARK: - Cached Rule (Sendable)

/// Lightweight, Sendable copy of a CategorizationRule.
/// Pre-compiles regex patterns for performance.
/// Can be safely passed across actor boundaries.
struct CachedRule: Sendable {
    let pattern: String
    let matchType: RuleMatchType
    let standardizedName: String?
    let targetCategory: String
    let priority: Int

    /// Pre-compiled regex (nil for non-regex rules)
    /// NSRegularExpression is thread-safe for matching after compilation
    private let compiledRegex: NSRegularExpression?

    init(
        pattern: String,
        matchType: RuleMatchType,
        standardizedName: String?,
        targetCategory: String,
        priority: Int
    ) {
        self.pattern = pattern.lowercased()
        self.matchType = matchType
        self.standardizedName = standardizedName
        self.targetCategory = targetCategory
        self.priority = priority

        // Pre-compile regex if needed (expensive operation done once)
        if matchType == .regex {
            self.compiledRegex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            )
        } else {
            self.compiledRegex = nil
        }
    }

    /// Create from a CategorizationRule model object
    init(from rule: CategorizationRule) {
        self.init(
            pattern: rule.pattern,
            matchType: rule.matchType,
            standardizedName: rule.standardizedName,
            targetCategory: rule.targetCategory,
            priority: rule.priority
        )
    }

    /// Check if this rule matches the given text.
    /// Uses pre-compiled regex for O(1) lookup instead of O(n) compilation.
    func matches(_ text: String) -> Bool {
        let searchText = text.lowercased()

        switch matchType {
        case .contains:
            return searchText.contains(pattern)

        case .startsWith:
            return searchText.hasPrefix(pattern)

        case .endsWith:
            return searchText.hasSuffix(pattern)

        case .exact:
            return searchText == pattern

        case .regex:
            guard let regex = compiledRegex else { return false }
            let range = NSRange(searchText.startIndex..<searchText.endIndex, in: searchText)
            return regex.firstMatch(in: searchText, range: range) != nil
        }
    }
}

// MARK: - Rules Cache (Sendable)

/// Thread-safe cache of categorization rules.
/// Designed to be created on MainActor and passed to BackgroundDataHandler.
struct RulesCache: Sendable {
    /// Rules sorted by priority (lower = higher priority)
    let rules: [CachedRule]

    /// When the cache was created
    let createdAt: Date

    /// Number of rules in cache
    var count: Int { rules.count }

    /// Whether the cache is empty
    var isEmpty: Bool { rules.isEmpty }

    /// Create an empty cache
    static var empty: RulesCache {
        RulesCache(rules: [], createdAt: Date())
    }

    /// Find the first matching rule for the given search text.
    /// Returns the rule and its categorization result.
    func findMatch(for searchText: String) -> CachedRule? {
        // Rules are already sorted by priority
        for rule in rules {
            if rule.matches(searchText) {
                return rule
            }
        }
        return nil
    }
}

// MARK: - Background Categorization Result

/// Result of categorizing a single transaction in background.
/// Sendable for safe transfer back to main actor.
struct BackgroundCategorizationResult: Sendable {
    let category: String?
    let standardizedName: String?
    let matchedPattern: String?
    let confidence: Double

    static var uncategorized: BackgroundCategorizationResult {
        BackgroundCategorizationResult(
            category: nil,
            standardizedName: nil,
            matchedPattern: nil,
            confidence: 0.0
        )
    }
}

// MARK: - Background Categorizer

/// Performs categorization logic that can run on any actor.
/// Uses RulesCache (Sendable) to avoid actor-crossing issues.
///
/// Usage:
/// ```swift
/// let cache = await categorizationEngine.buildRulesCache()
/// let categorizer = BackgroundCategorizer(rulesCache: cache)
/// let result = categorizer.categorize(parsed)
/// ```
struct BackgroundCategorizer: Sendable {

    let rulesCache: RulesCache

    init(rulesCache: RulesCache) {
        self.rulesCache = rulesCache
    }

    /// Categorize a parsed transaction using cached rules.
    /// Safe to call from any actor context.
    func categorize(_ transaction: ParsedTransaction) -> BackgroundCategorizationResult {
        // Special handling for contributions (Inleg)
        if let contributor = transaction.contributor {
            switch contributor {
            case .partner1:
                return BackgroundCategorizationResult(
                    category: "Inleg Partner 1",
                    standardizedName: "Partner 1",
                    matchedPattern: "inleg_partner1",
                    confidence: 1.0
                )
            case .partner2:
                return BackgroundCategorizationResult(
                    category: "Inleg Partner 2",
                    standardizedName: "Partner 2",
                    matchedPattern: "inleg_partner2",
                    confidence: 1.0
                )
            }
        }

        // Build search text from counter party and description
        let searchText = buildSearchText(
            counterParty: transaction.counterName,
            description: transaction.fullDescription
        )

        // Try cached rules first
        if let match = rulesCache.findMatch(for: searchText) {
            return BackgroundCategorizationResult(
                category: match.targetCategory,
                standardizedName: match.standardizedName,
                matchedPattern: match.pattern,
                confidence: calculateConfidence(matchType: match.matchType, searchText: searchText)
            )
        }

        // Fallback to hardcoded rules (always available)
        if let match = DefaultRulesLoader.matchHardcodedRule(searchText: searchText) {
            return BackgroundCategorizationResult(
                category: match.category,
                standardizedName: match.standardizedName,
                matchedPattern: match.pattern,
                confidence: 0.8
            )
        }

        // No match - return cleaned counter party name
        let standardName = cleanCounterPartyName(transaction.counterName)

        return BackgroundCategorizationResult(
            category: nil,
            standardizedName: standardName,
            matchedPattern: nil,
            confidence: 0.0
        )
    }

    /// Categorize multiple transactions in batch.
    /// Optimized for bulk processing.
    func categorizeBatch(_ transactions: [ParsedTransaction]) -> [BackgroundCategorizationResult] {
        transactions.map { categorize($0) }
    }

    // MARK: - Private Helpers

    private func buildSearchText(counterParty: String?, description: String) -> String {
        var parts: [String] = []

        if let party = counterParty, !party.isEmpty {
            parts.append(party)
        }

        if !description.isEmpty {
            parts.append(description)
        }

        return parts
            .joined(separator: " ")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanCounterPartyName(_ name: String?) -> String? {
        guard let name = name, !name.isEmpty else { return nil }

        var cleaned = name

        // Remove store numbers and terminal codes
        let patterns = [
            #"\s+\d{2,}$"#,           // Trailing numbers
            #"\s+[A-Z]{2}\d+$"#,      // Terminal codes
            #"\s*\*\s*"#,             // Asterisks
            #"^CCV\*"#,               // CCV prefix
            #"^Zettle_\*"#,           // Zettle prefix
            #"^BCK\*"#,               // BCK prefix
        ]

        for pattern in patterns {
            // Note: Regex compilation here is acceptable - this is per-transaction,
            // not per-rule, and only for unmatched transactions
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
                cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
            }
        }

        return cleaned
            .trimmingCharacters(in: .whitespaces)
            .capitalized
            .prefix(40)
            .description
    }

    private func calculateConfidence(matchType: RuleMatchType, searchText: String) -> Double {
        switch matchType {
        case .exact:
            return 1.0
        case .regex:
            return 0.95
        case .startsWith:
            return 0.85
        case .endsWith:
            return 0.80
        case .contains:
            let baseConfidence = 0.75
            let lengthPenalty = min(0.25, Double(searchText.count) / 1000.0)
            return max(0.5, baseConfidence - lengthPenalty)
        }
    }
}
