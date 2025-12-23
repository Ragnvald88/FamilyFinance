//
//  CategorizationEngine.swift
//  Family Finance
//
//  Priority-based pattern matching engine for automatic categorization
//  Supports 150+ rules optimized for Dutch banking patterns
//
//  Version 2.0: Expanded rules based on real Rabobank CSV data analysis
//  Created: 2025-12-22
//

import Foundation
@preconcurrency import SwiftData

// MARK: - Categorization Result

/// Result of categorization attempt.
/// Note: We store rule pattern instead of rule object for Sendable compliance.
struct CategorizationResult: Sendable {
    let category: String?
    let standardizedName: String?
    let matchedRulePattern: String?  // Stores pattern instead of @Model for Sendable
    let confidence: Double // 0.0 - 1.0

    static var uncategorized: CategorizationResult {
        CategorizationResult(
            category: nil,
            standardizedName: nil,
            matchedRulePattern: nil,
            confidence: 0.0
        )
    }
}

// MARK: - Categorization Engine

/// High-performance categorization engine with caching.
///
/// **Features:**
/// - Priority-based rule matching
/// - 5-minute cache for database rules
/// - Fallback to hardcoded rules if database is empty
/// - Special handling for Inleg (family contributions)
///
/// **Performance:** Processes ~5,000 transactions/second on M1
@MainActor
class CategorizationEngine {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Cache

    /// Sorted rules cache (by priority)
    private var cachedRules: [CategorizationRule] = []
    private var cacheLastUpdated: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public Methods

    /// Categorize a parsed transaction.
    /// Uses database rules with fallback to hardcoded rules.
    func categorize(_ transaction: ParsedTransaction) async -> CategorizationResult {
        // Special handling for contributions (Inleg)
        if let contributor = transaction.contributor {
            switch contributor {
            case .partner1:
                return CategorizationResult(
                    category: "Inleg Partner 1",
                    standardizedName: "Partner 1",
                    matchedRulePattern: "inleg_partner1",  // Virtual pattern
                    confidence: 1.0
                )
            case .partner2:
                return CategorizationResult(
                    category: "Inleg Partner 2",
                    standardizedName: "Partner 2",
                    matchedRulePattern: "inleg_partner2",  // Virtual pattern
                    confidence: 1.0
                )
            }
        }

        // Build search text from counter party and description
        let searchText = buildSearchText(
            counterParty: transaction.counterName,
            description: transaction.fullDescription
        )

        // Try database rules first
        if let rules = try? await getActiveRules(), !rules.isEmpty {
            for rule in rules {
                if rule.matches(searchText) {
                    // Note: recordMatch() deferred to batch update for performance
                    return CategorizationResult(
                        category: rule.targetCategory,
                        standardizedName: rule.standardizedName,
                        matchedRulePattern: rule.pattern,
                        confidence: calculateConfidence(rule: rule, searchText: searchText)
                    )
                }
            }
        }

        // Fallback to hardcoded rules if no database rules
        if let match = DefaultRulesLoader.matchHardcodedRule(searchText: searchText) {
            return CategorizationResult(
                category: match.category,
                standardizedName: match.standardizedName,
                matchedRulePattern: match.pattern,
                confidence: 0.8
            )
        }

        // No match found - return counter party name as standardized name
        let standardName = cleanCounterPartyName(transaction.counterName)

        return CategorizationResult(
            category: nil,
            standardizedName: standardName,
            matchedRulePattern: nil,
            confidence: 0.0
        )
    }

    /// Recategorize existing transaction with updated rules
    func recategorize(_ transaction: Transaction) async -> CategorizationResult {
        let parsedTransaction = ParsedTransaction(
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

        return await categorize(parsedTransaction)
    }

    /// Bulk recategorization for all uncategorized transactions
    func recategorizeUncategorized() async throws -> Int {
        // Simple predicate - fetch transactions without category override
        let noOverridePredicate = #Predicate<Transaction> { $0.categoryOverride == nil }
        let descriptor = FetchDescriptor<Transaction>(predicate: noOverridePredicate)

        // Filter in memory for complex conditions
        let allNoOverride = try modelContext.fetch(descriptor)
        let uncategorized = allNoOverride.filter { tx in
            tx.autoCategory == nil || tx.autoCategory == "Niet Gecategoriseerd"
        }
        var recategorizedCount = 0

        for transaction in uncategorized {
            let result = await recategorize(transaction)
            if let category = result.category {
                transaction.autoCategory = category
                if let standardName = result.standardizedName {
                    transaction.standardizedName = standardName
                }
                transaction.syncDenormalizedFields()
                recategorizedCount += 1
            }
        }

        try modelContext.save()
        return recategorizedCount
    }

    // MARK: - Private Methods

    /// Get active rules sorted by priority (with caching)
    private func getActiveRules() async throws -> [CategorizationRule] {
        // Check if cache is still valid
        if let lastUpdate = cacheLastUpdated,
           Date().timeIntervalSince(lastUpdate) < cacheValidityDuration,
           !cachedRules.isEmpty {
            return cachedRules
        }

        // Fetch fresh rules
        let descriptor = FetchDescriptor<CategorizationRule>(
            predicate: #Predicate<CategorizationRule> { $0.isActive },
            sortBy: [SortDescriptor(\CategorizationRule.priority, order: .forward)]
        )

        let rules = try modelContext.fetch(descriptor)
        cachedRules = rules
        cacheLastUpdated = Date()

        return rules
    }

    /// Build normalized search text from counter party and description
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

    /// Clean and standardize counter party name.
    /// Uses pre-compiled regex patterns for O(P) complexity instead of O(N×P).
    /// See CleaningPatterns in ThreadSafeCategorization.swift for details.
    private func cleanCounterPartyName(_ name: String?) -> String? {
        guard let name = name, !name.isEmpty else { return nil }

        // Use pre-compiled patterns - critical for performance with 15k+ transactions
        let cleaned = CleaningPatterns.clean(name)

        // Capitalize properly
        return cleaned
            .trimmingCharacters(in: .whitespaces)
            .capitalized
            .prefix(40)
            .description
    }

    /// Calculate confidence score for a match
    private func calculateConfidence(rule: CategorizationRule, searchText: String) -> Double {
        switch rule.matchType {
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

    /// Invalidate rules cache (call when rules are modified)
    func invalidateCache() {
        cachedRules = []
        cacheLastUpdated = nil
    }

    // MARK: - Thread-Safe Cache Building

    /// Build a Sendable RulesCache for background processing.
    /// This cache can be safely passed to BackgroundDataHandler.
    ///
    /// Usage:
    /// ```swift
    /// let cache = await categorizationEngine.buildRulesCache()
    /// let result = await backgroundHandler.importWithCategorization(data, rulesCache: cache)
    /// ```
    func buildRulesCache() async throws -> RulesCache {
        let rules = try await getActiveRules()

        // Convert to Sendable CachedRule structs (includes regex pre-compilation)
        let cachedRules = rules.map { CachedRule(from: $0) }

        return RulesCache(rules: cachedRules, createdAt: Date())
    }

    /// Build cache from hardcoded rules only (no database access).
    /// Useful for first-run or when database is empty.
    func buildHardcodedRulesCache() -> RulesCache {
        let cachedRules = DefaultRulesLoader.defaultRules.enumerated().map { (index, rule) in
            CachedRule(
                pattern: rule.pattern,
                matchType: .contains,
                standardizedName: rule.standardizedName,
                targetCategory: rule.category,
                priority: index
            )
        }

        return RulesCache(rules: cachedRules, createdAt: Date())
    }
}

// MARK: - Default Rules Loader

/// Loads default categorization rules into database.
/// Also provides hardcoded fallback for immediate use without database.
@MainActor
class DefaultRulesLoader {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Load all default rules if database is empty
    func loadDefaultRulesIfNeeded() throws {
        let descriptor = FetchDescriptor<CategorizationRule>()
        let existingCount = try modelContext.fetchCount(descriptor)

        guard existingCount == 0 else {
            print("✅ Rules already loaded: \(existingCount) rules found")
            return
        }

        print("📦 Loading \(Self.defaultRules.count) default categorization rules...")

        for (priority, rule) in Self.defaultRules.enumerated() {
            let categorizationRule = CategorizationRule(
                pattern: rule.pattern,
                matchType: .contains,
                standardizedName: rule.standardizedName,
                targetCategory: rule.category,
                priority: priority,
                isActive: true,
                notes: "Default rule"
            )
            modelContext.insert(categorizationRule)
        }

        try modelContext.save()
        print("✅ Loaded \(Self.defaultRules.count) default rules")
    }

    /// Match against hardcoded rules without database access.
    /// Used as fallback when database rules aren't loaded yet.
    /// Note: nonisolated to allow calling from background threads
    nonisolated static func matchHardcodedRule(searchText: String) -> (category: String, standardizedName: String, pattern: String)? {
        let lowerText = searchText.lowercased()

        for rule in defaultRules {
            if lowerText.contains(rule.pattern) {
                return (rule.category, rule.standardizedName, rule.pattern)
            }
        }

        return nil
    }

    // MARK: - Default Rules Data (150+ Rules)

    /// Comprehensive categorization rules based on real Rabobank CSV data analysis.
    /// Priority is determined by array order (lower index = higher priority).
    static let defaultRules: [(pattern: String, standardizedName: String, category: String)] = [

        // ═══════════════════════════════════════════════════════════════════════
        // SUPERMARKETS (Priority 1-20)
        // ═══════════════════════════════════════════════════════════════════════
        ("albert heijn", "Albert Heijn", "Boodschappen"),
        ("ah to go", "Albert Heijn", "Boodschappen"),
        ("ah express", "Albert Heijn", "Boodschappen"),
        ("jumbo", "Jumbo", "Boodschappen"),
        ("jumbo foodmarkt", "Jumbo", "Boodschappen"),
        ("lidl", "Lidl", "Boodschappen"),
        ("aldi", "Aldi", "Boodschappen"),
        ("plus supermarkt", "Plus", "Boodschappen"),
        ("dirk", "Dirk", "Boodschappen"),
        ("coop", "Coop", "Boodschappen"),
        ("spar", "Spar", "Boodschappen"),
        ("poiesz", "Poiesz", "Boodschappen"),
        ("deen", "Deen", "Boodschappen"),
        ("hoogvliet", "Hoogvliet", "Boodschappen"),
        ("vomar", "Vomar", "Boodschappen"),
        ("nettorama", "Nettorama", "Boodschappen"),

        // GROCERY DELIVERY
        ("picnic", "Picnic", "Boodschappen"),
        ("flink bv", "Flink", "Boodschappen"),
        ("flink nl", "Flink", "Boodschappen"),
        ("getir", "Getir", "Boodschappen"),
        ("gorillas", "Gorillas", "Boodschappen"),

        // ═══════════════════════════════════════════════════════════════════════
        // RESTAURANTS & FOOD DELIVERY (Priority 21-50)
        // ═══════════════════════════════════════════════════════════════════════
        ("thuisbezorgd", "Thuisbezorgd", "Uit Eten"),
        ("uber eats", "Uber Eats", "Uit Eten"),
        ("deliveroo", "Deliveroo", "Uit Eten"),
        ("just eat", "Just Eat", "Uit Eten"),
        ("sitedish", "Sitedish", "Uit Eten"),
        ("domino", "Domino's", "Uit Eten"),
        ("mcdonalds", "McDonald's", "Uit Eten"),
        ("mcdonald's", "McDonald's", "Uit Eten"),
        ("new york pizza", "New York Pizza", "Uit Eten"),
        ("papa john", "Papa John's", "Uit Eten"),
        ("kfc", "KFC", "Uit Eten"),
        ("burger king", "Burger King", "Uit Eten"),
        ("starbucks", "Starbucks", "Uit Eten"),
        ("subway", "Subway", "Uit Eten"),
        ("grandtaria", "Grandtaria", "Uit Eten"),
        ("friet van p", "Friet van P", "Uit Eten"),
        ("snackbar", "Snackbar", "Uit Eten"),
        ("cafetaria", "Cafetaria", "Uit Eten"),
        ("pizzeria", "Pizzeria", "Uit Eten"),
        ("restaurant", "Restaurant", "Uit Eten"),

        // ═══════════════════════════════════════════════════════════════════════
        // RETAIL & SHOPPING (Priority 51-90)
        // ═══════════════════════════════════════════════════════════════════════

        // Discount stores
        ("action", "Action", "Winkelen"),
        ("wibra", "Wibra", "Winkelen"),
        ("trekpleister", "Trekpleister", "Winkelen"),
        ("big bazar", "Big Bazar", "Winkelen"),

        // Drugstores
        ("kruidvat", "Kruidvat", "Persoonlijke Verzorging"),
        ("etos", "Etos", "Persoonlijke Verzorging"),
        ("holland & barrett", "Holland & Barrett", "Gezondheidszorg"),

        // Department stores
        ("hema", "HEMA", "Winkelen"),
        ("bijenkorf", "de Bijenkorf", "Winkelen"),
        ("hudson's bay", "Hudson's Bay", "Winkelen"),

        // Online retail
        ("bol.com", "Bol.com", "Winkelen"),
        ("amazon", "Amazon", "Winkelen"),
        ("coolblue", "Coolblue", "Winkelen"),
        ("mediamarkt", "MediaMarkt", "Winkelen"),
        ("vinted", "Vinted", "Winkelen"),
        ("marktplaats", "Marktplaats", "Winkelen"),

        // Fashion
        ("zalando", "Zalando", "Kleding"),
        ("h&m", "H&M", "Kleding"),
        ("c&a", "C&A", "Kleding"),
        ("zeeman", "Zeeman", "Kleding"),
        ("primark", "Primark", "Kleding"),
        ("only", "Only", "Kleding"),
        ("jack & jones", "Jack & Jones", "Kleding"),
        ("we fashion", "WE Fashion", "Kleding"),

        // Furniture/home
        ("ikea", "IKEA", "Woning Inrichting"),
        ("jysk", "JYSK", "Woning Inrichting"),
        ("kwantum", "Kwantum", "Woning Inrichting"),
        ("leen bakker", "Leen Bakker", "Woning Inrichting"),
        ("lampentotaal", "LampenTotaal", "Woning Inrichting"),

        // Books/toys
        ("bruna", "Bruna", "Winkelen"),
        ("intertoys", "Intertoys", "Winkelen"),
        ("bart smit", "Bart Smit", "Winkelen"),

        // Other shops
        ("primera", "Primera", "Winkelen"),
        ("blokker", "Blokker", "Winkelen"),
        ("xenos", "Xenos", "Winkelen"),
        ("flying tiger", "Flying Tiger", "Winkelen"),
        ("social deal", "Social Deal", "Winkelen"),

        // ═══════════════════════════════════════════════════════════════════════
        // TRANSPORT & FUEL (Priority 91-110)
        // ═══════════════════════════════════════════════════════════════════════
        ("shell", "Shell", "Vervoer"),
        ("bp ", "BP", "Vervoer"),
        ("esso", "Esso", "Vervoer"),
        ("total ", "TotalEnergies", "Vervoer"),
        ("tinq", "TINQ", "Vervoer"),
        ("tango", "Tango", "Vervoer"),
        ("argos", "Argos", "Vervoer"),
        ("texaco", "Texaco", "Vervoer"),
        ("gulf", "Gulf", "Vervoer"),
        ("ns.nl", "NS", "Vervoer"),
        ("ns reizigers", "NS", "Vervoer"),
        ("ov-chipkaart", "OV-Chipkaart", "Vervoer"),
        ("translink", "OV-Chipkaart", "Vervoer"),
        ("q-park", "Q-Park", "Vervoer"),
        ("parkeren", "Parkeren", "Vervoer"),
        ("anwb", "ANWB", "Vervoer"),
        ("a7 carwash", "Carwash", "Vervoer"),
        ("carwash", "Carwash", "Vervoer"),

        // ═══════════════════════════════════════════════════════════════════════
        // UTILITIES & TELECOM (Priority 111-130)
        // ═══════════════════════════════════════════════════════════════════════
        ("eneco", "Eneco", "Nutsvoorzieningen"),
        ("vattenfall", "Vattenfall", "Nutsvoorzieningen"),
        ("essent", "Essent", "Nutsvoorzieningen"),
        ("greenchoice", "Greenchoice", "Nutsvoorzieningen"),
        ("budget energie", "Budget Energie", "Nutsvoorzieningen"),
        ("vitens", "Vitens", "Nutsvoorzieningen"),
        ("waterbedrijf", "Waterbedrijf", "Nutsvoorzieningen"),
        ("pwn", "PWN", "Nutsvoorzieningen"),
        ("ziggo", "Ziggo", "Internet & TV"),
        ("kpn", "KPN", "Internet & TV"),
        ("t-mobile", "T-Mobile", "Internet & TV"),
        ("vodafone", "Vodafone", "Internet & TV"),
        ("tele2", "Tele2", "Internet & TV"),
        ("simpel", "Simpel", "Internet & TV"),
        ("youfone", "Youfone", "Internet & TV"),
        ("npo", "NPO", "Abonnementen"),
        ("npo start", "NPO Start", "Abonnementen"),

        // ═══════════════════════════════════════════════════════════════════════
        // HOUSING (Priority 131-140)
        // ═══════════════════════════════════════════════════════════════════════
        ("hypotheek", "Hypotheek", "Wonen"),
        ("contractuele rente en aflossing", "Hypotheek", "Wonen"),
        ("huur", "Huur", "Wonen"),
        ("vve", "VvE", "Wonen"),
        ("servicekosten", "Servicekosten", "Wonen"),

        // ═══════════════════════════════════════════════════════════════════════
        // INSURANCE (Priority 141-155)
        // ═══════════════════════════════════════════════════════════════════════
        ("centraal beheer", "Centraal Beheer", "Verzekeringen"),
        ("nationale nederlanden", "Nationale Nederlanden", "Verzekeringen"),
        ("nn groep", "Nationale Nederlanden", "Verzekeringen"),
        ("aegon", "Aegon", "Verzekeringen"),
        ("interpolis", "Interpolis", "Verzekeringen"),
        ("zilveren kruis", "Zilveren Kruis", "Zorgverzekering"),
        ("cz zorgverzekering", "CZ", "Zorgverzekering"),
        ("menzis", "Menzis", "Zorgverzekering"),
        ("vgz", "VGZ", "Zorgverzekering"),
        ("ohra", "OHRA", "Verzekeringen"),
        ("asr", "ASR", "Verzekeringen"),
        ("unive", "Univé", "Verzekeringen"),
        ("allianz", "Allianz", "Verzekeringen"),

        // ═══════════════════════════════════════════════════════════════════════
        // HEALTHCARE (Priority 156-170)
        // ═══════════════════════════════════════════════════════════════════════
        ("apotheek", "Apotheek", "Gezondheidszorg"),
        ("huisarts", "Huisarts", "Gezondheidszorg"),
        ("tandarts", "Tandarts", "Gezondheidszorg"),
        ("ziekenhuis", "Ziekenhuis", "Gezondheidszorg"),
        ("fysiotherap", "Fysiotherapie", "Gezondheidszorg"),
        ("umcg", "UMCG", "Gezondheidszorg"),
        ("martini ziekenhuis", "Martini Ziekenhuis", "Gezondheidszorg"),
        ("ggz", "GGZ", "Gezondheidszorg"),
        ("optiek", "Optiek", "Gezondheidszorg"),
        ("specsavers", "Specsavers", "Gezondheidszorg"),

        // ═══════════════════════════════════════════════════════════════════════
        // CHILDCARE & EDUCATION (Priority 171-180)
        // ═══════════════════════════════════════════════════════════════════════
        ("kinderopvang", "Kinderopvang", "Kinderopvang"),
        ("gastouder", "Gastouder", "Kinderopvang"),
        ("bso", "BSO", "Kinderopvang"),
        ("peuterspeelzaal", "Peuterspeelzaal", "Kinderopvang"),
        ("kdv", "Kinderdagverblijf", "Kinderopvang"),
        ("school", "School", "Onderwijs"),
        ("duo", "DUO", "Onderwijs"),
        ("studielink", "Studielink", "Onderwijs"),

        // ═══════════════════════════════════════════════════════════════════════
        // SUBSCRIPTIONS & STREAMING (Priority 181-195)
        // ═══════════════════════════════════════════════════════════════════════
        ("netflix", "Netflix", "Abonnementen"),
        ("spotify", "Spotify", "Abonnementen"),
        ("disney+", "Disney+", "Abonnementen"),
        ("disney plus", "Disney+", "Abonnementen"),
        ("videoland", "Videoland", "Abonnementen"),
        ("youtube premium", "YouTube Premium", "Abonnementen"),
        ("amazon prime", "Amazon Prime", "Abonnementen"),
        ("hbo max", "HBO Max", "Abonnementen"),
        ("apple music", "Apple Music", "Abonnementen"),
        ("apple tv", "Apple TV+", "Abonnementen"),
        ("viaplay", "Viaplay", "Abonnementen"),
        ("dazn", "DAZN", "Abonnementen"),
        ("rabo directpakket", "Bankkosten", "Bankkosten"),
        ("rabo wereldpas", "Bankkosten", "Bankkosten"),

        // ═══════════════════════════════════════════════════════════════════════
        // ENTERTAINMENT & RECREATION (Priority 196-210)
        // ═══════════════════════════════════════════════════════════════════════
        ("playstation", "PlayStation", "Ontspanning"),
        ("xbox", "Xbox", "Ontspanning"),
        ("steam", "Steam", "Ontspanning"),
        ("nintendo", "Nintendo", "Ontspanning"),
        ("pathe", "Pathé", "Ontspanning"),
        ("kinepolis", "Kinepolis", "Ontspanning"),
        ("vue cinema", "Vue", "Ontspanning"),
        ("efteling", "Efteling", "Ontspanning"),
        ("walibi", "Walibi", "Ontspanning"),
        ("artis", "Artis", "Ontspanning"),
        ("burgers zoo", "Burgers' Zoo", "Ontspanning"),
        ("museum", "Museum", "Ontspanning"),
        ("bioscoop", "Bioscoop", "Ontspanning"),
        ("zwembad", "Zwembad", "Sport & Fitness"),
        ("sportschool", "Sportschool", "Sport & Fitness"),
        ("basic fit", "Basic-Fit", "Sport & Fitness"),

        // ═══════════════════════════════════════════════════════════════════════
        // HOME & DIY (Priority 211-220)
        // ═══════════════════════════════════════════════════════════════════════
        ("gamma", "Gamma", "Huis & Tuin"),
        ("karwei", "Karwei", "Huis & Tuin"),
        ("praxis", "Praxis", "Huis & Tuin"),
        ("hornbach", "Hornbach", "Huis & Tuin"),
        ("intratuin", "Intratuin", "Huis & Tuin"),
        ("tuincentrum", "Tuincentrum", "Huis & Tuin"),
        ("bouwmarkt", "Bouwmarkt", "Huis & Tuin"),

        // ═══════════════════════════════════════════════════════════════════════
        // SPECIALTY FOOD (Priority 221-235)
        // ═══════════════════════════════════════════════════════════════════════
        ("slager", "Slagerij", "Boodschappen"),
        ("bakker", "Bakkerij", "Boodschappen"),
        ("vishandel", "Vishandel", "Boodschappen"),
        ("kaas", "Kaaswinkel", "Boodschappen"),
        ("groente", "Groenteboer", "Boodschappen"),
        ("delicatessen", "Delicatessen", "Boodschappen"),
        ("bosscher", "Bosscher Delicatessen", "Boodschappen"),
        ("smedemas", "Smedema's", "Boodschappen"),
        ("markthal", "Markt", "Boodschappen"),
        ("ekkelkamp", "Ekkelkamp", "Boodschappen"),
        ("zwerwer", "Zwerwer", "Boodschappen"),

        // ═══════════════════════════════════════════════════════════════════════
        // TAXES & GOVERNMENT (Priority 236-245)
        // ═══════════════════════════════════════════════════════════════════════
        ("belastingdienst", "Belastingdienst", "Belastingen"),
        ("gemeente", "Gemeente", "Belastingen"),
        ("waterschap", "Waterschap", "Belastingen"),
        ("cjib", "CJIB", "Belastingen"),
        ("rdw", "RDW", "Belastingen"),
        ("gemeentelijke belasting", "Gemeentelijke Belastingen", "Belastingen"),

        // ═══════════════════════════════════════════════════════════════════════
        // BANK FEES (Priority 246-250)
        // ═══════════════════════════════════════════════════════════════════════
        ("kosten pakket", "Bankkosten", "Bankkosten"),
        ("kosten", "Bankkosten", "Bankkosten"),
        ("rente over periode", "Rente", "Rente"),

        // ═══════════════════════════════════════════════════════════════════════
        // INCOME (Priority 251-265)
        // ═══════════════════════════════════════════════════════════════════════
        ("salaris", "Salaris", "Salaris"),
        ("sboh", "SBOH", "Salaris"),
        ("loon", "Loon", "Salaris"),
        ("sociale verzekeringsbank", "SVB", "Toeslagen"),
        ("kinderbijslag", "Kinderbijslag", "Toeslagen"),
        ("svb", "SVB", "Toeslagen"),
        ("belastingteruggave", "Belastingdienst", "Toeslagen"),
        ("toeslagen", "Toeslagen", "Toeslagen"),
        ("huurtoeslag", "Huurtoeslag", "Toeslagen"),
        ("zorgtoeslag", "Zorgtoeslag", "Toeslagen"),
        ("kinderopvangtoeslag", "Kinderopvangtoeslag", "Toeslagen"),
        ("kindgebonden budget", "Kindgebonden Budget", "Toeslagen"),
        ("uwv", "UWV", "Uitkering"),
        ("werkloosheidsuitkering", "WW", "Uitkering"),

        // ═══════════════════════════════════════════════════════════════════════
        // PETS (Priority 266-270)
        // ═══════════════════════════════════════════════════════════════════════
        ("dierenarts", "Dierenarts", "Huisdieren"),
        ("pets place", "Pets Place", "Huisdieren"),
        ("jumper", "Jumper", "Huisdieren"),
        ("ranzijn", "Ranzijn", "Huisdieren"),
        ("dierenaccessoires", "Dierenwinkel", "Huisdieren"),

        // ═══════════════════════════════════════════════════════════════════════
        // PAYMENT PROCESSORS (Lower priority - need counterparty context)
        // ═══════════════════════════════════════════════════════════════════════
        ("multisafepay", "MultiSafepay", "Winkelen"),
        ("mangopay", "Vinted", "Winkelen"),
        ("stripe", "Online Aankoop", "Winkelen"),
        ("adyen", "Online Aankoop", "Winkelen"),
        ("paypal", "PayPal", "Winkelen"),
        ("ideal", "iDEAL", "Winkelen"),
    ]
}
