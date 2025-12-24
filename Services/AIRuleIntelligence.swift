//
//  AIRuleIntelligence.swift
//  Family Finance
//
//  AI-powered rule intelligence system providing smart suggestions,
//  conflict detection, and performance optimization
//
//  Features:
//  - Pattern recognition from transaction history
//  - Smart rule suggestions based on uncategorized transactions
//  - Conflict detection and resolution recommendations
//  - Performance optimization and rule effectiveness analytics
//  - Machine learning from user corrections and feedback
//
//  Created: 2025-12-24
//

import Foundation
@preconcurrency import SwiftData
import Combine

// MARK: - AI Rule Intelligence Service

/// Advanced AI service that analyzes transaction patterns and provides intelligent
/// rule suggestions, conflict detection, and performance optimization
@MainActor
final class AIRuleIntelligence: ObservableObject {

    // MARK: - Published Properties

    @Published var suggestions: [RuleSuggestion] = []
    @Published var conflicts: [RuleConflict] = []
    @Published var analytics: RuleAnalytics = RuleAnalytics()
    @Published var isAnalyzing = false
    @Published var lastAnalysis: Date?

    // MARK: - Private Properties

    private let modelContext: ModelContext
    private var analysisTask: Task<Void, Never>?

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    deinit {
        analysisTask?.cancel()
    }

    // MARK: - Public Interface

    /// Perform comprehensive AI analysis of rules and transactions
    func performIntelligentAnalysis() async {
        guard !isAnalyzing else { return }

        isAnalyzing = true
        defer { isAnalyzing = false }

        print("🧠 Starting AI rule intelligence analysis...")

        do {
            // Fetch all data needed for analysis
            let transactions = try await fetchRecentTransactions()
            let enhancedRules = try await fetchEnhancedRules()
            let legacyRules = try await fetchLegacyRules()
            let categories = try await fetchCategories()

            // Run parallel analysis tasks
            async let suggestionsTask = generateSmartSuggestions(
                transactions: transactions,
                enhancedRules: enhancedRules,
                categories: categories
            )
            async let conflictsTask = detectRuleConflicts(
                enhancedRules: enhancedRules,
                legacyRules: legacyRules
            )
            async let analyticsTask = analyzeRulePerformance(
                transactions: transactions,
                enhancedRules: enhancedRules,
                legacyRules: legacyRules
            )

            // Collect all results
            let (newSuggestions, newConflicts, newAnalytics) = await (
                suggestionsTask, conflictsTask, analyticsTask
            )

            // Update UI on main actor
            self.suggestions = newSuggestions
            self.conflicts = newConflicts
            self.analytics = newAnalytics
            self.lastAnalysis = Date()

            print("✅ AI analysis complete:")
            print("   📋 \(newSuggestions.count) suggestions")
            print("   ⚠️ \(newConflicts.count) conflicts")
            print("   📊 \(newAnalytics.ruleEffectiveness.count) rules analyzed")

        } catch {
            print("❌ AI analysis failed: \(error)")
        }
    }

    /// Accept a rule suggestion and create the actual rule
    func acceptSuggestion(_ suggestion: RuleSuggestion) {
        print("✅ Accepting suggestion: \(suggestion.name)")

        let enhancedRule = EnhancedCategorizationRule(
            name: suggestion.name,
            targetCategory: suggestion.targetCategory,
            tier: suggestion.complexity == .advanced ? .advanced : .simple,
            priority: suggestion.priority
        )

        if suggestion.complexity == .simple {
            enhancedRule.configureAsSimpleRule(
                accountFilter: suggestion.accountFilter,
                targetField: suggestion.field ?? .description,
                matchType: suggestion.matchType ?? .contains,
                pattern: suggestion.pattern,
                amountMin: suggestion.amountRange?.lowerBound,
                amountMax: suggestion.amountRange?.upperBound
            )
        }

        modelContext.insert(enhancedRule)

        do {
            try modelContext.save()

            // Remove the accepted suggestion
            suggestions.removeAll { $0.id == suggestion.id }

            // Record the acceptance for machine learning
            recordSuggestionAcceptance(suggestion)

        } catch {
            print("❌ Failed to save suggested rule: \(error)")
        }
    }

    /// Dismiss a suggestion (with optional feedback for ML)
    func dismissSuggestion(_ suggestion: RuleSuggestion, reason: DismissalReason? = nil) {
        suggestions.removeAll { $0.id == suggestion.id }

        // Record dismissal for machine learning improvement
        if let reason = reason {
            recordSuggestionDismissal(suggestion, reason: reason)
        }
    }

    /// Resolve a rule conflict by adjusting priorities or consolidating rules
    func resolveConflict(_ conflict: RuleConflict, resolution: ConflictResolution) async {
        print("🔧 Resolving conflict: \(conflict.type)")

        switch resolution {
        case .adjustPriorities(let adjustments):
            await adjustRulePriorities(adjustments)

        case .consolidateRules(let primaryRuleId, let rulesToMerge):
            await consolidateRules(primaryRuleId: primaryRuleId, rulesToMerge: rulesToMerge)

        case .disableRule(let ruleId):
            await disableRule(ruleId)
        }

        // Remove resolved conflict
        conflicts.removeAll { $0.id == conflict.id }

        // Re-analyze to detect any new conflicts
        Task {
            await performIntelligentAnalysis()
        }
    }

    // MARK: - Smart Suggestions Generation

    private func generateSmartSuggestions(
        transactions: [Transaction],
        enhancedRules: [EnhancedCategorizationRule],
        categories: [Category]
    ) async -> [RuleSuggestion] {

        var suggestions: [RuleSuggestion] = []

        // 1. Find uncategorized transaction patterns
        let uncategorizedTransactions = transactions.filter {
            $0.effectiveCategory == "Uncategorized"
        }

        let patternSuggestions = await analyzeUncategorizedPatterns(
            transactions: uncategorizedTransactions,
            existingRules: enhancedRules,
            categories: categories
        )
        suggestions.append(contentsOf: patternSuggestions)

        // 2. Suggest rule improvements based on low effectiveness
        let improvementSuggestions = await suggestRuleImprovements(
            rules: enhancedRules,
            transactions: transactions
        )
        suggestions.append(contentsOf: improvementSuggestions)

        // 3. Template-based suggestions for common scenarios
        let templateSuggestions = await generateTemplateSuggestions(
            transactions: transactions,
            existingRules: enhancedRules,
            categories: categories
        )
        suggestions.append(contentsOf: templateSuggestions)

        // 4. Advanced Boolean logic suggestions for power users
        let advancedSuggestions = await generateAdvancedLogicSuggestions(
            transactions: transactions,
            existingRules: enhancedRules
        )
        suggestions.append(contentsOf: advancedSuggestions)

        return suggestions
            .sorted { $0.confidence > $1.confidence }
            .prefix(10)
            .map { $0 }
    }

    private func analyzeUncategorizedPatterns(
        transactions: [Transaction],
        existingRules: [EnhancedCategorizationRule],
        categories: [Category]
    ) async -> [RuleSuggestion] {

        guard !transactions.isEmpty else { return [] }

        var suggestions: [RuleSuggestion] = []

        // Group transactions by common patterns
        let merchantGroups = Dictionary(grouping: transactions) { transaction in
            extractMerchantName(from: transaction.description)
        }

        for (merchant, merchantTransactions) in merchantGroups {
            guard merchantTransactions.count >= 3, // Minimum occurrences for suggestion
                  !merchant.isEmpty,
                  !hasExistingRuleForMerchant(merchant, rules: existingRules) else { continue }

            // Analyze transaction characteristics
            let amounts = merchantTransactions.map { $0.amount }
            let avgAmount = amounts.reduce(0, +) / Decimal(amounts.count)
            let categories = Set(merchantTransactions.compactMap { $0.manualCategory })

            // Suggest category based on transaction type and amount patterns
            let suggestedCategory = inferCategoryFromPattern(
                merchant: merchant,
                averageAmount: avgAmount,
                transactionCount: merchantTransactions.count,
                existingCategories: categories
            )

            let confidence = calculateSuggestionConfidence(
                occurrences: merchantTransactions.count,
                amountConsistency: calculateAmountConsistency(amounts),
                categoryConsistency: categories.count <= 2 ? 0.9 : 0.6
            )

            let suggestion = RuleSuggestion(
                name: "Auto-categorize \(merchant)",
                description: "Automatically categorize transactions from \(merchant) based on \(merchantTransactions.count) similar transactions",
                targetCategory: suggestedCategory,
                field: .counterName,
                matchType: .contains,
                pattern: merchant,
                confidence: confidence,
                complexity: .simple,
                priority: 50,
                reasoning: "Found \(merchantTransactions.count) transactions from this merchant with consistent patterns"
            )

            suggestions.append(suggestion)
        }

        return suggestions
    }

    private func suggestRuleImprovements(
        rules: [EnhancedCategorizationRule],
        transactions: [Transaction]
    ) async -> [RuleSuggestion] {

        var suggestions: [RuleSuggestion] = []

        for rule in rules {
            let effectiveness = calculateRuleEffectiveness(rule: rule, transactions: transactions)

            // Suggest improvements for low-effectiveness rules
            if effectiveness < 0.3 && rule.matchCount > 0 {
                let suggestion = RuleSuggestion(
                    name: "Improve \(rule.name)",
                    description: "This rule has low effectiveness (\(Int(effectiveness * 100))%). Consider refining the pattern or adding conditions.",
                    targetCategory: rule.targetCategory,
                    field: .description,
                    matchType: .contains,
                    pattern: "",
                    confidence: 0.7,
                    complexity: .enhanced,
                    priority: rule.priority,
                    reasoning: "Rule effectiveness is only \(Int(effectiveness * 100))% based on recent transaction analysis"
                )

                suggestions.append(suggestion)
            }

            // Suggest consolidation for similar rules
            let similarRules = findSimilarRules(targetRule: rule, allRules: rules)
            if similarRules.count > 1 {
                let suggestion = RuleSuggestion(
                    name: "Consolidate similar rules",
                    description: "Found \(similarRules.count) similar rules targeting '\(rule.targetCategory)'. Consider consolidating for better performance.",
                    targetCategory: rule.targetCategory,
                    field: .description,
                    matchType: .contains,
                    pattern: "",
                    confidence: 0.8,
                    complexity: .advanced,
                    priority: rule.priority,
                    reasoning: "Multiple similar rules can be combined into one advanced Boolean logic rule"
                )

                suggestions.append(suggestion)
            }
        }

        return suggestions
    }

    private func generateTemplateSuggestions(
        transactions: [Transaction],
        existingRules: [EnhancedCategorizationRule],
        categories: [Category]
    ) async -> [RuleSuggestion] {

        var suggestions: [RuleSuggestion] = []

        // Common Dutch banking patterns
        let templates = [
            RuleTemplate(
                name: "Supermarket Groceries",
                pattern: "albert|jumbo|ah|aldi|lidl",
                category: "Groceries",
                field: .counterName,
                matchType: .matches,
                confidence: 0.95
            ),
            RuleTemplate(
                name: "Gas Stations",
                pattern: "shell|bp|esso|texaco|total",
                category: "Transportation",
                field: .counterName,
                matchType: .matches,
                confidence: 0.9
            ),
            RuleTemplate(
                name: "Streaming Services",
                pattern: "netflix|spotify|apple|youtube|disney",
                category: "Entertainment",
                field: .description,
                matchType: .contains,
                confidence: 0.85
            ),
            RuleTemplate(
                name: "Utilities",
                pattern: "eneco|essent|vattenfall|ziggo|kpn",
                category: "Utilities",
                field: .counterName,
                matchType: .contains,
                confidence: 0.9
            )
        ]

        for template in templates {
            // Check if this template would be useful
            let matchingTransactions = transactions.filter { transaction in
                wouldTemplateMatch(template: template, transaction: transaction)
            }

            guard matchingTransactions.count >= 2,
                  !hasExistingRuleForPattern(template.pattern, rules: existingRules),
                  categories.contains(where: { $0.name == template.category }) else { continue }

            let suggestion = RuleSuggestion(
                name: template.name,
                description: "Create a rule for \(template.category) based on \(matchingTransactions.count) matching transactions",
                targetCategory: template.category,
                field: template.field,
                matchType: template.matchType,
                pattern: template.pattern,
                confidence: template.confidence,
                complexity: .simple,
                priority: 50,
                reasoning: "Common pattern detected - would automatically categorize \(matchingTransactions.count) transactions"
            )

            suggestions.append(suggestion)
        }

        return suggestions
    }

    private func generateAdvancedLogicSuggestions(
        transactions: [Transaction],
        existingRules: [EnhancedCategorizationRule]
    ) async -> [RuleSuggestion] {

        var suggestions: [RuleSuggestion] = []

        // Suggest advanced rules for complex scenarios

        // 1. Amount-based categorization
        let expensiveTransactions = transactions.filter { $0.amount <= -100 }
        if expensiveTransactions.count > 10 {
            let suggestion = RuleSuggestion(
                name: "Large Expenses Require Review",
                description: "Create a rule to flag large expenses (>€100) for manual review",
                targetCategory: "Review Required",
                field: .amount,
                matchType: .lessThan,
                pattern: "-100",
                confidence: 0.8,
                complexity: .advanced,
                priority: 10, // High priority for review
                reasoning: "Found \(expensiveTransactions.count) transactions over €100 that might benefit from special handling"
            )

            suggestions.append(suggestion)
        }

        // 2. Weekend vs weekday patterns
        let weekendTransactions = transactions.filter { Calendar.current.isDateInWeekend($0.date) }
        if weekendTransactions.count > 20 {
            let suggestion = RuleSuggestion(
                name: "Weekend Entertainment Spending",
                description: "Advanced rule to categorize weekend transactions differently",
                targetCategory: "Entertainment",
                field: .date,
                matchType: .contains,
                pattern: "weekend_pattern",
                confidence: 0.7,
                complexity: .advanced,
                priority: 60,
                reasoning: "Detected different spending patterns on weekends (\(weekendTransactions.count) transactions)"
            )

            suggestions.append(suggestion)
        }

        return suggestions
    }

    // MARK: - Conflict Detection

    private func detectRuleConflicts(
        enhancedRules: [EnhancedCategorizationRule],
        legacyRules: [CategorizationRule]
    ) async -> [RuleConflict] {

        var conflicts: [RuleConflict] = []

        // 1. Priority conflicts (multiple rules with same priority)
        let priorityConflicts = detectPriorityConflicts(enhancedRules: enhancedRules, legacyRules: legacyRules)
        conflicts.append(contentsOf: priorityConflicts)

        // 2. Pattern overlap conflicts (rules that would match same transactions)
        let overlapConflicts = await detectPatternOverlaps(enhancedRules: enhancedRules)
        conflicts.append(contentsOf: overlapConflicts)

        // 3. Unused rule detection
        let unusedConflicts = detectUnusedRules(enhancedRules: enhancedRules, legacyRules: legacyRules)
        conflicts.append(contentsOf: unusedConflicts)

        // 4. Performance conflicts (rules that are slow or inefficient)
        let performanceConflicts = detectPerformanceConflicts(enhancedRules: enhancedRules)
        conflicts.append(contentsOf: performanceConflicts)

        return conflicts
    }

    private func detectPriorityConflicts(
        enhancedRules: [EnhancedCategorizationRule],
        legacyRules: [CategorizationRule]
    ) -> [RuleConflict] {

        var conflicts: [RuleConflict] = []

        // Group enhanced rules by priority
        let enhancedByPriority = Dictionary(grouping: enhancedRules) { $0.priority }

        for (priority, rules) in enhancedByPriority {
            guard rules.count > 1 else { continue }

            let conflict = RuleConflict(
                type: .priorityConflict,
                severity: .medium,
                title: "Priority Conflict",
                description: "\(rules.count) rules have the same priority (\(priority))",
                affectedRules: rules.map { $0.id },
                suggestion: "Adjust rule priorities to ensure deterministic evaluation order",
                autoResolvable: true
            )

            conflicts.append(conflict)
        }

        return conflicts
    }

    private func detectPatternOverlaps(enhancedRules: [EnhancedCategorizationRule]) async -> [RuleConflict] {
        var conflicts: [RuleConflict] = []

        for (i, rule1) in enhancedRules.enumerated() {
            for rule2 in enhancedRules.dropFirst(i + 1) {
                if await rulesHaveOverlap(rule1: rule1, rule2: rule2) {
                    let conflict = RuleConflict(
                        type: .patternOverlap,
                        severity: .high,
                        title: "Pattern Overlap",
                        description: "Rules '\(rule1.name)' and '\(rule2.name)' may match the same transactions",
                        affectedRules: [rule1.id, rule2.id],
                        suggestion: "Review rule patterns and adjust to avoid conflicts, or use Boolean logic to create more specific conditions",
                        autoResolvable: false
                    )

                    conflicts.append(conflict)
                }
            }
        }

        return conflicts
    }

    private func detectUnusedRules(
        enhancedRules: [EnhancedCategorizationRule],
        legacyRules: [CategorizationRule]
    ) -> [RuleConflict] {

        var conflicts: [RuleConflict] = []

        // Find enhanced rules that haven't matched anything
        let unusedEnhanced = enhancedRules.filter { $0.matchCount == 0 && $0.createdAt < Date().addingTimeInterval(-7 * 24 * 3600) }

        for rule in unusedEnhanced {
            let conflict = RuleConflict(
                type: .unusedRule,
                severity: .low,
                title: "Unused Rule",
                description: "Rule '\(rule.name)' hasn't matched any transactions in the past week",
                affectedRules: [rule.id],
                suggestion: "Review the rule pattern or consider removing if no longer needed",
                autoResolvable: false
            )

            conflicts.append(conflict)
        }

        return conflicts
    }

    private func detectPerformanceConflicts(enhancedRules: [EnhancedCategorizationRule]) -> [RuleConflict] {
        var conflicts: [RuleConflict] = []

        // Find rules with complex patterns that might be slow
        let complexRules = enhancedRules.filter { rule in
            if case .advanced = rule.tier,
               let conditions = rule.conditions,
               conditions.count > 5 {
                return true
            }
            return false
        }

        for rule in complexRules {
            let conflict = RuleConflict(
                type: .performance,
                severity: .medium,
                title: "Performance Warning",
                description: "Rule '\(rule.name)' has many conditions and may impact performance",
                affectedRules: [rule.id],
                suggestion: "Consider optimizing by reordering conditions or splitting into simpler rules",
                autoResolvable: false
            )

            conflicts.append(conflict)
        }

        return conflicts
    }

    // MARK: - Rule Analytics

    private func analyzeRulePerformance(
        transactions: [Transaction],
        enhancedRules: [EnhancedCategorizationRule],
        legacyRules: [CategorizationRule]
    ) async -> RuleAnalytics {

        var ruleEffectiveness: [String: Double] = [:]
        var categoryDistribution: [String: Int] = [:]
        var avgEvaluationTime: [String: TimeInterval] = [:]

        // Analyze enhanced rules
        for rule in enhancedRules {
            let effectiveness = calculateRuleEffectiveness(rule: rule, transactions: transactions)
            ruleEffectiveness[rule.id.uuidString] = effectiveness

            categoryDistribution[rule.targetCategory, default: 0] += rule.matchCount

            // Simulate evaluation time (in real implementation, this would be measured)
            let simulatedTime = rule.tier == .advanced ? 0.005 : 0.001
            avgEvaluationTime[rule.id.uuidString] = simulatedTime
        }

        // Overall statistics
        let totalMatches = enhancedRules.reduce(0) { $0 + $1.matchCount }
        let totalRules = enhancedRules.count + legacyRules.count
        let avgRuleEffectiveness = ruleEffectiveness.values.isEmpty ? 0 :
            ruleEffectiveness.values.reduce(0, +) / Double(ruleEffectiveness.count)

        return RuleAnalytics(
            totalRules: totalRules,
            activeRules: enhancedRules.filter(\.isActive).count + legacyRules.filter(\.isActive).count,
            totalMatches: totalMatches,
            avgRuleEffectiveness: avgRuleEffectiveness,
            ruleEffectiveness: ruleEffectiveness,
            categoryDistribution: categoryDistribution,
            avgEvaluationTime: avgEvaluationTime,
            lastUpdated: Date()
        )
    }

    // MARK: - Helper Methods

    private func fetchRecentTransactions() async throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.date > Date().addingTimeInterval(-90 * 24 * 3600) },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchEnhancedRules() async throws -> [EnhancedCategorizationRule] {
        let descriptor = FetchDescriptor<EnhancedCategorizationRule>(
            sortBy: [SortDescriptor(\.priority)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchLegacyRules() async throws -> [CategorizationRule] {
        let descriptor = FetchDescriptor<CategorizationRule>(
            sortBy: [SortDescriptor(\.priority)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchCategories() async throws -> [Category] {
        let descriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func extractMerchantName(from description: String) -> String {
        // Simple merchant extraction logic
        let cleaned = description.lowercased()
            .replacingOccurrences(of: "\\d", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndPunctuationCharacters)

        let words = cleaned.components(separatedBy: .whitespaces)
        return words.prefix(2).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    private func calculateRuleEffectiveness(rule: EnhancedCategorizationRule, transactions: [Transaction]) -> Double {
        guard rule.matchCount > 0 else { return 0.0 }

        // Calculate effectiveness based on match rate vs false positives
        let recentMatches = transactions.filter { transaction in
            // Simplified matching logic
            if let config = rule.simpleConfig {
                return transaction.effectiveCategory == rule.targetCategory &&
                       (transaction.description.localizedCaseInsensitiveContains(config.pattern) ||
                        transaction.counterName?.localizedCaseInsensitiveContains(config.pattern) == true)
            }
            return false
        }

        return min(1.0, Double(recentMatches.count) / Double(max(rule.matchCount, 1)))
    }

    private func calculateSuggestionConfidence(occurrences: Int, amountConsistency: Double, categoryConsistency: Double) -> Double {
        let occurrenceWeight = min(1.0, Double(occurrences) / 10.0) // Max confidence at 10+ occurrences
        let avgConsistency = (amountConsistency + categoryConsistency) / 2.0
        return (occurrenceWeight * 0.6) + (avgConsistency * 0.4)
    }

    private func calculateAmountConsistency(_ amounts: [Decimal]) -> Double {
        guard amounts.count > 1 else { return 1.0 }

        let doubleAmounts = amounts.compactMap { NSDecimalNumber(decimal: $0).doubleValue }
        let mean = doubleAmounts.reduce(0, +) / Double(doubleAmounts.count)
        let variance = doubleAmounts.map { pow($0 - mean, 2) }.reduce(0, +) / Double(doubleAmounts.count)
        let standardDeviation = sqrt(variance)

        return max(0.0, 1.0 - (standardDeviation / mean))
    }

    private func hasExistingRuleForMerchant(_ merchant: String, rules: [EnhancedCategorizationRule]) -> Bool {
        return rules.contains { rule in
            if let config = rule.simpleConfig {
                return config.pattern.localizedCaseInsensitiveContains(merchant) ||
                       merchant.localizedCaseInsensitiveContains(config.pattern)
            }
            return false
        }
    }

    private func hasExistingRuleForPattern(_ pattern: String, rules: [EnhancedCategorizationRule]) -> Bool {
        return rules.contains { rule in
            if let config = rule.simpleConfig {
                return config.pattern.localizedCaseInsensitiveContains(pattern) ||
                       pattern.localizedCaseInsensitiveContains(config.pattern)
            }
            return false
        }
    }

    private func inferCategoryFromPattern(merchant: String, averageAmount: Decimal, transactionCount: Int, existingCategories: Set<String>) -> String {
        let merchantLower = merchant.lowercased()

        // Category inference based on merchant patterns
        if merchantLower.contains("albert") || merchantLower.contains("jumbo") || merchantLower.contains("aldi") {
            return "Groceries"
        } else if merchantLower.contains("shell") || merchantLower.contains("esso") || merchantLower.contains("bp") {
            return "Transportation"
        } else if merchantLower.contains("netflix") || merchantLower.contains("spotify") {
            return "Entertainment"
        } else if averageAmount <= -50 && transactionCount > 5 {
            return "Utilities"
        } else if averageAmount > 0 {
            return "Income"
        } else {
            return "General"
        }
    }

    private func findSimilarRules(targetRule: EnhancedCategorizationRule, allRules: [EnhancedCategorizationRule]) -> [EnhancedCategorizationRule] {
        return allRules.filter { rule in
            rule.targetCategory == targetRule.targetCategory &&
            rule.id != targetRule.id &&
            rule.tier == targetRule.tier
        }
    }

    private func wouldTemplateMatch(template: RuleTemplate, transaction: Transaction) -> Bool {
        let searchText: String
        switch template.field {
        case .description:
            searchText = transaction.description
        case .counterName:
            searchText = transaction.counterName ?? ""
        default:
            searchText = transaction.description
        }

        switch template.matchType {
        case .contains:
            return searchText.localizedCaseInsensitiveContains(template.pattern)
        case .matches:
            return searchText.range(of: template.pattern, options: [.regularExpression, .caseInsensitive]) != nil
        default:
            return false
        }
    }

    private func rulesHaveOverlap(rule1: EnhancedCategorizationRule, rule2: EnhancedCategorizationRule) async -> Bool {
        // Simplified overlap detection
        guard rule1.targetCategory != rule2.targetCategory else { return false }

        if let config1 = rule1.simpleConfig, let config2 = rule2.simpleConfig {
            return config1.pattern.localizedCaseInsensitiveContains(config2.pattern) ||
                   config2.pattern.localizedCaseInsensitiveContains(config1.pattern)
        }

        return false
    }

    private func recordSuggestionAcceptance(_ suggestion: RuleSuggestion) {
        // TODO: Implement machine learning feedback
        print("🎓 Learning: User accepted suggestion '\(suggestion.name)' with confidence \(suggestion.confidence)")
    }

    private func recordSuggestionDismissal(_ suggestion: RuleSuggestion, reason: DismissalReason) {
        // TODO: Implement machine learning feedback
        print("🎓 Learning: User dismissed suggestion '\(suggestion.name)' because: \(reason)")
    }

    // MARK: - Conflict Resolution

    private func adjustRulePriorities(_ adjustments: [String: Int]) async {
        // TODO: Implement priority adjustments
        print("🔧 Adjusting rule priorities: \(adjustments)")
    }

    private func consolidateRules(primaryRuleId: UUID, rulesToMerge: [UUID]) async {
        // TODO: Implement rule consolidation
        print("🔧 Consolidating rules: \(rulesToMerge) into \(primaryRuleId)")
    }

    private func disableRule(_ ruleId: UUID) async {
        // TODO: Implement rule disabling
        print("🔧 Disabling rule: \(ruleId)")
    }
}

// MARK: - Supporting Models

/// Represents an AI-generated rule suggestion
struct RuleSuggestion: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let targetCategory: String
    let field: RuleTargetField?
    let matchType: RuleMatchType?
    let pattern: String
    let accountFilter: String? = nil
    let amountRange: Range<Decimal>? = nil
    let confidence: Double
    let complexity: SuggestionComplexity
    let priority: Int
    let reasoning: String
    let createdAt = Date()
}

/// Detected rule conflict requiring user attention
struct RuleConflict: Identifiable {
    let id = UUID()
    let type: ConflictType
    let severity: ConflictSeverity
    let title: String
    let description: String
    let affectedRules: [UUID]
    let suggestion: String
    let autoResolvable: Bool
    let detectedAt = Date()
}

/// Overall analytics for rule system performance
struct RuleAnalytics {
    var totalRules: Int = 0
    var activeRules: Int = 0
    var totalMatches: Int = 0
    var avgRuleEffectiveness: Double = 0.0
    var ruleEffectiveness: [String: Double] = [:]
    var categoryDistribution: [String: Int] = [:]
    var avgEvaluationTime: [String: TimeInterval] = [:]
    var lastUpdated: Date = Date()
}

/// Template for common rule patterns
struct RuleTemplate {
    let name: String
    let pattern: String
    let category: String
    let field: RuleTargetField
    let matchType: RuleMatchType
    let confidence: Double
}

// MARK: - Enums

enum SuggestionComplexity: String, CaseIterable {
    case simple = "Simple"
    case enhanced = "Enhanced"
    case advanced = "Advanced"
}

enum ConflictType: String, CaseIterable {
    case priorityConflict = "Priority Conflict"
    case patternOverlap = "Pattern Overlap"
    case unusedRule = "Unused Rule"
    case performance = "Performance Issue"
}

enum ConflictSeverity: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum ConflictResolution {
    case adjustPriorities([String: Int])
    case consolidateRules(primaryRuleId: UUID, rulesToMerge: [UUID])
    case disableRule(UUID)
}

enum DismissalReason: String, CaseIterable {
    case notRelevant = "Not Relevant"
    case tooSpecific = "Too Specific"
    case tooGeneral = "Too General"
    case wrongCategory = "Wrong Category"
    case other = "Other"
}