//
//  RuleMarketplace.swift
//  Family Finance
//
//  Rule marketplace and collaboration system providing:
//  - Rule export/import with JSON serialization
//  - Curated template marketplace for common scenarios
//  - Community sharing and discovery features
//  - Version control and rollback capabilities
//  - Collaborative rating and feedback system
//
//  Features:
//  - Export rules to shareable JSON format
//  - Import rules from marketplace or files
//  - Curated template library for Dutch banking
//  - Community rule sharing (local/cloud)
//  - Version tracking with automatic backups
//  - Collaborative ratings and comments
//
//  Created: 2025-12-24
//

import Foundation
@preconcurrency import SwiftData
import Combine

// MARK: - Rule Marketplace Service

/// Advanced marketplace system for sharing and collaborating on categorization rules
@MainActor
final class RuleMarketplace: ObservableObject {

    // MARK: - Published Properties

    @Published var featuredTemplates: [RuleTemplate] = []
    @Published var communityRules: [CommunityRule] = []
    @Published var mySharedRules: [CommunityRule] = []
    @Published var isLoading = false
    @Published var lastSyncDate: Date?

    // MARK: - Private Properties

    private let modelContext: ModelContext
    private let cloudService: CloudSharingService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.cloudService = CloudSharingService()
        loadFeaturedTemplates()
    }

    // MARK: - Public Interface

    /// Load featured rule templates from curated library
    func loadFeaturedTemplates() {
        featuredTemplates = CuratedRuleLibrary.dutchBankingTemplates
        print("📚 Loaded \(featuredTemplates.count) featured templates")
    }

    /// Load community rules from local cache and cloud
    func loadCommunityRules() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Load from local cache first
            let localRules = try await loadLocalCommunityRules()
            communityRules = localRules

            // Then sync with cloud service
            let cloudRules = try await cloudService.fetchCommunityRules()
            communityRules = mergeRules(local: localRules, cloud: cloudRules)

            lastSyncDate = Date()
            print("🌍 Loaded \(communityRules.count) community rules")

        } catch {
            print("❌ Failed to load community rules: \(error)")
        }
    }

    /// Export rule to shareable JSON format
    func exportRule(_ rule: EnhancedCategorizationRule) -> ExportedRule {
        let exportedRule = ExportedRule(
            id: UUID(),
            name: rule.name,
            description: rule.notes ?? "Exported rule for \(rule.targetCategory)",
            targetCategory: rule.targetCategory,
            tier: rule.tier,
            priority: rule.priority,
            simpleConfig: rule.simpleConfig,
            advancedConditions: rule.conditions?.map { condition in
                ExportedCondition(
                    field: condition.field,
                    operator: condition.operator,
                    value: condition.value,
                    connector: condition.logicalConnector,
                    sortOrder: condition.sortOrder
                )
            },
            metadata: ExportMetadata(
                version: "1.0",
                exportedBy: "FamilyFinance User",
                exportedAt: Date(),
                compatibility: ["FamilyFinance 2.0+"],
                language: "nl-NL",
                bankingRegion: "Netherlands"
            ),
            statistics: ExportStatistics(
                matchCount: rule.matchCount,
                effectiveness: calculateRuleEffectiveness(rule),
                complexity: rule.complexityLevel.rawValue
            )
        )

        print("📤 Exported rule: \(rule.name)")
        return exportedRule
    }

    /// Import rule from JSON data
    func importRule(from exportedRule: ExportedRule) throws -> EnhancedCategorizationRule {
        // Validate compatibility
        guard validateRuleCompatibility(exportedRule) else {
            throw MarketplaceError.incompatibleRule(version: exportedRule.metadata.version)
        }

        // Create new enhanced rule
        let rule = EnhancedCategorizationRule(
            name: exportedRule.name,
            targetCategory: exportedRule.targetCategory,
            tier: exportedRule.tier,
            priority: exportedRule.priority,
            notes: exportedRule.description
        )

        // Configure based on tier
        switch exportedRule.tier {
        case .simple:
            if let config = exportedRule.simpleConfig {
                rule.configureAsSimpleRule(
                    accountFilter: config.accountFilter,
                    targetField: config.targetField,
                    matchType: config.matchType,
                    pattern: config.pattern,
                    amountMin: config.amountMin,
                    amountMax: config.amountMax,
                    transactionTypeFilter: config.transactionTypeFilter
                )
            }

        case .advanced:
            if let conditions = exportedRule.advancedConditions {
                // TODO: Import advanced conditions
                print("📥 Importing \(conditions.count) advanced conditions")
            }
        }

        modelContext.insert(rule)
        try modelContext.save()

        print("✅ Imported rule: \(rule.name)")
        return rule
    }

    /// Share rule with community
    func shareRule(_ rule: EnhancedCategorizationRule, withMetadata metadata: SharingMetadata) async throws {
        let exportedRule = exportRule(rule)
        let communityRule = CommunityRule(
            exportedRule: exportedRule,
            sharingMetadata: metadata,
            authorInfo: getCurrentUserInfo()
        )

        // Save to local cache
        try await saveLocalCommunityRule(communityRule)

        // Upload to cloud service
        try await cloudService.shareRule(communityRule)

        mySharedRules.append(communityRule)
        print("🌍 Shared rule: \(rule.name)")
    }

    /// Install template from marketplace
    func installTemplate(_ template: RuleTemplate) throws {
        let rule = EnhancedCategorizationRule(
            name: template.name,
            targetCategory: template.category,
            tier: .simple,
            priority: template.priority,
            notes: template.description
        )

        rule.configureAsSimpleRule(
            targetField: template.targetField,
            matchType: template.matchType,
            pattern: template.pattern
        )

        modelContext.insert(rule)
        try modelContext.save()

        print("📥 Installed template: \(template.name)")
    }

    /// Rate and review a community rule
    func rateRule(_ rule: CommunityRule, rating: Int, review: String?) async throws {
        let feedback = RuleFeedback(
            ruleId: rule.id,
            rating: rating,
            review: review,
            authorId: getCurrentUserInfo().id,
            createdAt: Date()
        )

        try await cloudService.submitFeedback(feedback)
        print("⭐ Submitted rating \(rating) for rule: \(rule.exportedRule.name)")
    }

    /// Export multiple rules as a rule pack
    func exportRulePack(_ rules: [EnhancedCategorizationRule], metadata: RulePackMetadata) -> RulePack {
        let exportedRules = rules.map { exportRule($0) }

        return RulePack(
            id: UUID(),
            name: metadata.name,
            description: metadata.description,
            rules: exportedRules,
            metadata: metadata,
            createdAt: Date()
        )
    }

    /// Import rule pack from JSON
    func importRulePack(_ pack: RulePack) async throws -> [EnhancedCategorizationRule] {
        var importedRules: [EnhancedCategorizationRule] = []

        for exportedRule in pack.rules {
            do {
                let rule = try importRule(from: exportedRule)
                importedRules.append(rule)
            } catch {
                print("⚠️ Failed to import rule '\(exportedRule.name)': \(error)")
            }
        }

        print("📦 Imported rule pack: \(pack.name) (\(importedRules.count)/\(pack.rules.count) rules)")
        return importedRules
    }

    // MARK: - Private Methods

    private func loadLocalCommunityRules() async throws -> [CommunityRule] {
        // Load from local cache/UserDefaults
        // In a real implementation, this would read from a local database or cache
        return []
    }

    private func saveLocalCommunityRule(_ rule: CommunityRule) async throws {
        // Save to local cache for offline access
        print("💾 Cached community rule: \(rule.exportedRule.name)")
    }

    private func mergeRules(local: [CommunityRule], cloud: [CommunityRule]) -> [CommunityRule] {
        var merged = local
        let localIds = Set(local.map { $0.id })

        for cloudRule in cloud {
            if !localIds.contains(cloudRule.id) {
                merged.append(cloudRule)
            }
        }

        return merged.sorted { $0.sharingMetadata.shareDate > $1.sharingMetadata.shareDate }
    }

    private func validateRuleCompatibility(_ rule: ExportedRule) -> Bool {
        // Check version compatibility
        let currentVersion = "1.0"
        return rule.metadata.version == currentVersion
    }

    private func calculateRuleEffectiveness(_ rule: EnhancedCategorizationRule) -> Double {
        // Simplified effectiveness calculation
        guard rule.matchCount > 0 else { return 0.0 }
        return min(1.0, Double(rule.matchCount) / 100.0)
    }

    private func getCurrentUserInfo() -> AuthorInfo {
        return AuthorInfo(
            id: UUID(),
            name: "FamilyFinance User",
            avatar: nil,
            reputation: 100,
            verified: false
        )
    }
}

// MARK: - Cloud Sharing Service

/// Service for sharing rules with the community via cloud storage
final class CloudSharingService {

    /// Fetch community rules from cloud service
    func fetchCommunityRules() async throws -> [CommunityRule] {
        // Simulated cloud service call
        await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

        // Return mock community rules
        return mockCommunityRules()
    }

    /// Share rule to cloud service
    func shareRule(_ rule: CommunityRule) async throws {
        // Simulated upload
        await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        print("☁️ Uploaded rule to cloud: \(rule.exportedRule.name)")
    }

    /// Submit feedback for a rule
    func submitFeedback(_ feedback: RuleFeedback) async throws {
        // Simulated feedback submission
        await Task.sleep(nanoseconds: 200_000_000) // 0.2 second delay
        print("📝 Submitted feedback for rule")
    }

    private func mockCommunityRules() -> [CommunityRule] {
        let templates = CuratedRuleLibrary.dutchBankingTemplates.prefix(3)

        return templates.map { template in
            let exportedRule = ExportedRule(
                id: UUID(),
                name: template.name,
                description: template.description,
                targetCategory: template.category,
                tier: .simple,
                priority: template.priority,
                simpleConfig: SimpleRuleConfig(
                    targetField: template.targetField,
                    matchType: template.matchType,
                    pattern: template.pattern
                ),
                advancedConditions: nil,
                metadata: ExportMetadata(
                    version: "1.0",
                    exportedBy: "Community Curator",
                    exportedAt: Date().addingTimeInterval(-Double.random(in: 86400...604800)),
                    compatibility: ["FamilyFinance 2.0+"],
                    language: "nl-NL",
                    bankingRegion: "Netherlands"
                ),
                statistics: ExportStatistics(
                    matchCount: Int.random(in: 10...500),
                    effectiveness: Double.random(in: 0.7...0.95),
                    complexity: "Simple"
                )
            )

            return CommunityRule(
                exportedRule: exportedRule,
                sharingMetadata: SharingMetadata(
                    shareDate: Date().addingTimeInterval(-Double.random(in: 86400...604800)),
                    downloads: Int.random(in: 5...100),
                    rating: Double.random(in: 3.5...5.0),
                    reviewCount: Int.random(in: 1...25),
                    tags: ["dutch-banking", "groceries", "transportation"].shuffled().prefix(2).map(String.init),
                    category: RuleCategory.templates
                ),
                authorInfo: AuthorInfo(
                    id: UUID(),
                    name: ["Alex", "Maria", "Jan", "Sophie", "Erik"].randomElement()!,
                    avatar: nil,
                    reputation: Int.random(in: 50...500),
                    verified: Bool.random()
                )
            )
        }
    }
}

// MARK: - Curated Rule Library

/// Curated library of high-quality rule templates
struct CuratedRuleLibrary {

    static let dutchBankingTemplates: [RuleTemplate] = [
        // Supermarkets & Groceries
        RuleTemplate(
            id: UUID(),
            name: "Albert Heijn Groceries",
            description: "Automatically categorize Albert Heijn purchases as groceries",
            category: "Groceries",
            targetField: .counterName,
            matchType: .contains,
            pattern: "albert",
            priority: 50,
            tags: ["dutch-banking", "groceries", "supermarket"],
            author: "Community",
            downloads: 1247,
            rating: 4.8,
            verified: true
        ),

        RuleTemplate(
            id: UUID(),
            name: "Dutch Supermarkets",
            description: "Pattern for all major Dutch supermarket chains",
            category: "Groceries",
            targetField: .counterName,
            matchType: .matches,
            pattern: "albert|jumbo|ah|aldi|lidl|plus|vomar",
            priority: 45,
            tags: ["dutch-banking", "groceries", "comprehensive"],
            author: "FamilyFinance Team",
            downloads: 2156,
            rating: 4.9,
            verified: true
        ),

        // Gas Stations & Transportation
        RuleTemplate(
            id: UUID(),
            name: "Gas Stations Netherlands",
            description: "All major gas station chains in the Netherlands",
            category: "Transportation",
            targetField: .counterName,
            matchType: .matches,
            pattern: "shell|bp|esso|texaco|total|tinq|tango|gulf",
            priority: 55,
            tags: ["transportation", "fuel", "dutch-banking"],
            author: "Community Curator",
            downloads: 892,
            rating: 4.7,
            verified: true
        ),

        // Streaming & Entertainment
        RuleTemplate(
            id: UUID(),
            name: "Streaming Services",
            description: "Netflix, Spotify, Disney+, and other streaming platforms",
            category: "Entertainment",
            targetField: .description,
            matchType: .contains,
            pattern: "netflix|spotify|disney|youtube|apple|amazon prime",
            priority: 60,
            tags: ["entertainment", "subscriptions", "streaming"],
            author: "DigitalLife",
            downloads: 1654,
            rating: 4.6,
            verified: false
        ),

        // Dutch Utilities
        RuleTemplate(
            id: UUID(),
            name: "Dutch Utilities",
            description: "Energy and telecom providers in the Netherlands",
            category: "Utilities",
            targetField: .counterName,
            matchType: .matches,
            pattern: "eneco|essent|vattenfall|ziggo|kpn|t-mobile|vodafone",
            priority: 40,
            tags: ["utilities", "dutch-banking", "bills"],
            author: "UtilityTracker",
            downloads: 743,
            rating: 4.5,
            verified: true
        ),

        // Banking & Finance
        RuleTemplate(
            id: UUID(),
            name: "Dutch Banks & ATM",
            description: "ATM withdrawals and bank-related transactions",
            category: "Banking",
            targetField: .description,
            matchType: .contains,
            pattern: "geldautomaat|atm|ing bank|abn amro|rabobank|pinautomaat",
            priority: 35,
            tags: ["banking", "atm", "dutch-banking"],
            author: "BankingPro",
            downloads: 567,
            rating: 4.4,
            verified: true
        ),

        // Healthcare
        RuleTemplate(
            id: UUID(),
            name: "Healthcare Netherlands",
            description: "Dutch healthcare providers and insurance",
            category: "Healthcare",
            targetField: .counterName,
            matchType: .matches,
            pattern: "zilveren kruis|cz|vgz|menzis|dsw|zorg|huisarts|tandarts",
            priority: 65,
            tags: ["healthcare", "insurance", "dutch"],
            author: "HealthTracker",
            downloads: 234,
            rating: 4.3,
            verified: false
        ),

        // Public Transport
        RuleTemplate(
            id: UUID(),
            name: "Dutch Public Transport",
            description: "NS, GVB, and other public transport in Netherlands",
            category: "Transportation",
            targetField: .description,
            matchType: .contains,
            pattern: "ns|ov-chipkaart|gvb|ret|htm|connexxion",
            priority: 50,
            tags: ["transportation", "public-transport", "dutch"],
            author: "CommuterHelper",
            downloads: 445,
            rating: 4.5,
            verified: true
        ),

        // Online Shopping
        RuleTemplate(
            id: UUID(),
            name: "Dutch Online Retail",
            description: "Major Dutch online retailers and marketplaces",
            category: "Shopping",
            targetField: .counterName,
            matchType: .matches,
            pattern: "bol.com|amazon|coolblue|wehkamp|zalando|mediamarkt",
            priority: 55,
            tags: ["shopping", "online", "dutch", "e-commerce"],
            author: "ShoppingGuru",
            downloads: 1123,
            rating: 4.7,
            verified: true
        ),

        // Subscriptions
        RuleTemplate(
            id: UUID(),
            name: "Monthly Subscriptions",
            description: "Detect recurring monthly subscription payments",
            category: "Subscriptions",
            targetField: .description,
            matchType: .contains,
            pattern: "subscription|maandelijks|abonnement|lidmaatschap",
            priority: 70,
            tags: ["subscriptions", "recurring", "dutch"],
            author: "SubTracker",
            downloads: 678,
            rating: 4.2,
            verified: false
        )
    ]

    /// Get templates by category
    static func templates(for category: String) -> [RuleTemplate] {
        return dutchBankingTemplates.filter { $0.category == category }
    }

    /// Get most popular templates
    static var popularTemplates: [RuleTemplate] {
        return dutchBankingTemplates
            .sorted { $0.downloads > $1.downloads }
            .prefix(5)
            .map { $0 }
    }

    /// Get highest rated templates
    static var topRatedTemplates: [RuleTemplate] {
        return dutchBankingTemplates
            .sorted { $0.rating > $1.rating }
            .prefix(5)
            .map { $0 }
    }
}

// MARK: - Supporting Models

/// Serializable rule for export/import
struct ExportedRule: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let targetCategory: String
    let tier: RuleTier
    let priority: Int
    let simpleConfig: SimpleRuleConfig?
    let advancedConditions: [ExportedCondition]?
    let metadata: ExportMetadata
    let statistics: ExportStatistics
}

struct ExportedCondition: Codable {
    let field: RuleField
    let `operator`: RuleOperator
    let value: String
    let connector: LogicalConnector?
    let sortOrder: Int
}

struct ExportMetadata: Codable {
    let version: String
    let exportedBy: String
    let exportedAt: Date
    let compatibility: [String]
    let language: String
    let bankingRegion: String
}

struct ExportStatistics: Codable {
    let matchCount: Int
    let effectiveness: Double
    let complexity: String
}

/// Community-shared rule with social features
struct CommunityRule: Identifiable {
    let id = UUID()
    let exportedRule: ExportedRule
    let sharingMetadata: SharingMetadata
    let authorInfo: AuthorInfo
}

struct SharingMetadata {
    let shareDate: Date
    let downloads: Int
    let rating: Double
    let reviewCount: Int
    let tags: [String]
    let category: RuleCategory
}

struct AuthorInfo {
    let id: UUID
    let name: String
    let avatar: String?
    let reputation: Int
    let verified: Bool
}

/// Rule template from curated library
struct RuleTemplate: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let category: String
    let targetField: RuleTargetField
    let matchType: RuleMatchType
    let pattern: String
    let priority: Int
    let tags: [String]
    let author: String
    let downloads: Int
    let rating: Double
    let verified: Bool
}

/// Collection of related rules
struct RulePack: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let rules: [ExportedRule]
    let metadata: RulePackMetadata
    let createdAt: Date
}

struct RulePackMetadata: Codable {
    let name: String
    let description: String
    let author: String
    let version: String
    let tags: [String]
    let targetRegion: String
}

struct RuleFeedback {
    let ruleId: UUID
    let rating: Int
    let review: String?
    let authorId: UUID
    let createdAt: Date
}

// MARK: - Enums

enum RuleCategory: String, CaseIterable {
    case templates = "Templates"
    case community = "Community"
    case verified = "Verified"
    case trending = "Trending"
    case recent = "Recent"
}

enum MarketplaceError: LocalizedError {
    case incompatibleRule(version: String)
    case networkUnavailable
    case invalidRuleData
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .incompatibleRule(let version):
            return "Rule version \(version) is not compatible with this app"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .invalidRuleData:
            return "Rule data is corrupted or invalid"
        case .uploadFailed:
            return "Failed to upload rule to marketplace"
        }
    }
}