//
//  RuleMarketplaceView.swift
//  Family Finance
//
//  Comprehensive rule marketplace and collaboration interface providing:
//  - Template gallery with curated Dutch banking rules
//  - Community rule sharing and discovery
//  - Import/export functionality with JSON serialization
//  - Social features (ratings, reviews, downloads)
//  - Collaborative rule development and feedback
//
//  Features:
//  - Browse and install rule templates
//  - Share custom rules with the community
//  - Import/export rule packs
//  - Rate and review community contributions
//  - Track downloads and popularity
//  - Collaborative curation and verification
//
//  Created: 2025-12-24
//

import SwiftUI
@preconcurrency import SwiftData
import UniformTypeIdentifiers

/// Comprehensive rule marketplace and collaboration hub
struct RuleMarketplaceView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var marketplace: RuleMarketplace
    @State private var selectedTab: MarketplaceTab = .templates
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showingImportSheet = false
    @State private var showingExportSheet = false

    private let categories = ["All", "Groceries", "Transportation", "Entertainment", "Utilities", "Banking", "Healthcare", "Shopping"]

    init(modelContext: ModelContext) {
        self._marketplace = StateObject(wrappedValue: RuleMarketplace(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with search and filters
                headerSection

                Divider()

                // Tab selector
                tabSelector

                Divider()

                // Content based on selected tab
                contentSection
            }
            .navigationTitle("Rule Marketplace")
            .toolbar {
                toolbarContent
            }
            .task {
                await marketplace.loadCommunityRules()
            }
            .fileImporter(
                isPresented: $showingImportSheet,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .fileExporter(
                isPresented: $showingExportSheet,
                document: RulePackDocument(pack: createSampleRulePack()),
                contentType: .json,
                defaultFilename: "FamilyFinanceRules"
            ) { result in
                handleFileExport(result)
            }
        }
    }

    // MARK: - UI Components

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Welcome message with statistics
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discover & Share Rules")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(marketplace.featuredTemplates.count) templates • \(marketplace.communityRules.count) community rules")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if marketplace.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if let syncDate = marketplace.lastSyncDate {
                    Text("Updated \(syncDate, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Search and filter controls
            HStack {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search rules and templates...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Category filter
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
        }
        .padding(16)
        .background(Color.blue.opacity(0.05))
    }

    private var tabSelector: some View {
        Picker("Marketplace Section", selection: $selectedTab) {
            ForEach(MarketplaceTab.allCases, id: \.self) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var contentSection: some View {
        Group {
            switch selectedTab {
            case .templates:
                TemplateGalleryView(
                    templates: filteredTemplates,
                    onInstall: { template in
                        installTemplate(template)
                    }
                )

            case .community:
                CommunityRulesView(
                    rules: filteredCommunityRules,
                    onInstall: { rule in
                        installCommunityRule(rule)
                    },
                    onRate: { rule, rating, review in
                        rateCommunityRule(rule, rating: rating, review: review)
                    }
                )

            case .myRules:
                MySharedRulesView(
                    sharedRules: marketplace.mySharedRules,
                    onShare: { rule in
                        shareRule(rule)
                    }
                )

            case .importExport:
                ImportExportView(
                    onImport: { showingImportSheet = true },
                    onExport: { showingExportSheet = true }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Import Rules") {
                showingImportSheet = true
            }
            .buttonStyle(.bordered)

            Button("Export Rules") {
                showingExportSheet = true
            }
            .buttonStyle(.bordered)

            Menu("More Actions") {
                Button("Refresh Marketplace") {
                    Task {
                        await marketplace.loadCommunityRules()
                    }
                }

                Button("Share Custom Rule") {
                    // TODO: Implement custom rule sharing
                }

                Button("Create Rule Pack") {
                    // TODO: Implement rule pack creation
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Computed Properties

    private var filteredTemplates: [RuleTemplate] {
        var templates = marketplace.featuredTemplates

        if selectedCategory != "All" {
            templates = templates.filter { $0.category == selectedCategory }
        }

        if !searchText.isEmpty {
            templates = templates.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return templates
    }

    private var filteredCommunityRules: [CommunityRule] {
        var rules = marketplace.communityRules

        if selectedCategory != "All" {
            rules = rules.filter { $0.exportedRule.targetCategory == selectedCategory }
        }

        if !searchText.isEmpty {
            rules = rules.filter {
                $0.exportedRule.name.localizedCaseInsensitiveContains(searchText) ||
                $0.exportedRule.description.localizedCaseInsensitiveContains(searchText) ||
                $0.sharingMetadata.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return rules
    }

    // MARK: - Actions

    private func installTemplate(_ template: RuleTemplate) {
        do {
            try marketplace.installTemplate(template)

            // Show success feedback
            print("✅ Installed template: \(template.name)")
        } catch {
            print("❌ Failed to install template: \(error)")
        }
    }

    private func installCommunityRule(_ rule: CommunityRule) {
        do {
            _ = try marketplace.importRule(from: rule.exportedRule)

            // Show success feedback
            print("✅ Installed community rule: \(rule.exportedRule.name)")
        } catch {
            print("❌ Failed to install community rule: \(error)")
        }
    }

    private func rateCommunityRule(_ rule: CommunityRule, rating: Int, review: String?) {
        Task {
            do {
                try await marketplace.rateRule(rule, rating: rating, review: review)
                print("⭐ Rated rule: \(rule.exportedRule.name)")
            } catch {
                print("❌ Failed to rate rule: \(error)")
            }
        }
    }

    private func shareRule(_ rule: EnhancedCategorizationRule) {
        // TODO: Implement rule sharing interface
        print("🌍 Sharing rule: \(rule.name)")
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                importRuleFromFile(url)
            }
        case .failure(let error):
            print("❌ Import failed: \(error)")
        }
    }

    private func importRuleFromFile(_ url: URL) {
        // TODO: Implement file-based rule import
        print("📥 Importing rule from: \(url.lastPathComponent)")
    }

    private func handleFileExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("📤 Exported rules to: \(url.lastPathComponent)")
        case .failure(let error):
            print("❌ Export failed: \(error)")
        }
    }

    private func createSampleRulePack() -> RulePack {
        // Create a sample rule pack for export
        return RulePack(
            id: UUID(),
            name: "My Custom Rules",
            description: "Exported from Family Finance",
            rules: [],
            metadata: RulePackMetadata(
                name: "My Custom Rules",
                description: "Personal rule collection",
                author: "FamilyFinance User",
                version: "1.0",
                tags: ["personal", "dutch-banking"],
                targetRegion: "Netherlands"
            ),
            createdAt: Date()
        )
    }
}

// MARK: - Template Gallery View

struct TemplateGalleryView: View {
    let templates: [RuleTemplate]
    let onInstall: (RuleTemplate) -> Void

    var body: some View {
        ScrollView {
            if templates.isEmpty {
                emptyTemplatesView
            } else {
                LazyVStack(spacing: 16) {
                    // Featured section
                    featuredSection

                    // Popular section
                    popularSection

                    // All templates
                    allTemplatesSection
                }
                .padding(16)
            }
        }
    }

    private var emptyTemplatesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Templates Found")
                .font(.title2)
                .fontWeight(.bold)

            Text("Try adjusting your search or category filter")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("✨ Featured Templates")
                .font(.headline)
                .fontWeight(.bold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(CuratedRuleLibrary.topRatedTemplates) { template in
                    TemplateCard(template: template, onInstall: onInstall)
                }
            }
        }
    }

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🔥 Most Popular")
                .font(.headline)
                .fontWeight(.bold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(CuratedRuleLibrary.popularTemplates) { template in
                    TemplateCard(template: template, onInstall: onInstall)
                }
            }
        }
    }

    private var allTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📚 All Templates")
                .font(.headline)
                .fontWeight(.bold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(templates) { template in
                    TemplateCard(template: template, onInstall: onInstall)
                }
            }
        }
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: RuleTemplate
    let onInstall: (RuleTemplate) -> Void

    @State private var isInstalling = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with verification badge
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)

                    Label(template.category, systemImage: "tag.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                Spacer()

                if template.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .help("Verified by FamilyFinance team")
                }
            }

            // Description
            Text(template.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            // Pattern preview
            VStack(alignment: .leading, spacing: 4) {
                Text("Pattern: \(template.pattern)")
                    .font(.caption)
                    .fontFamily(.monospaced)
                    .foregroundStyle(.tertiary)

                Text("\(template.targetField.displayName) • \(template.matchType.displayName)")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Statistics
            HStack(spacing: 12) {
                StatBadge(icon: "arrow.down.circle.fill", value: "\(template.downloads)", color: .blue)
                StatBadge(icon: "star.fill", value: String(format: "%.1f", template.rating), color: .yellow)

                Spacer()

                Text(template.author)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Tags
            if !template.tags.isEmpty {
                FlowLayout(template.tags.prefix(3).map(String.init), spacing: 4) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            // Install button
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isInstalling = true
                    onInstall(template)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isInstalling = false
                }
            }) {
                HStack {
                    if isInstalling {
                        ProgressView()
                            .controlSize(.small)
                        Text("Installing...")
                    } else {
                        Image(systemName: "plus")
                        Text("Install")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isInstalling)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Community Rules View

struct CommunityRulesView: View {
    let rules: [CommunityRule]
    let onInstall: (CommunityRule) -> Void
    let onRate: (CommunityRule, Int, String?) -> Void

    var body: some View {
        ScrollView {
            if rules.isEmpty {
                emptyCommunityView
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(rules) { rule in
                        CommunityRuleCard(
                            rule: rule,
                            onInstall: { onInstall(rule) },
                            onRate: { rating, review in
                                onRate(rule, rating, review)
                            }
                        )
                    }
                }
                .padding(16)
            }
        }
    }

    private var emptyCommunityView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Community Rules")
                .font(.title2)
                .fontWeight(.bold)

            Text("Be the first to share a rule with the community!")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Community Rule Card

struct CommunityRuleCard: View {
    let rule: CommunityRule
    let onInstall: () -> Void
    let onRate: (Int, String?) -> Void

    @State private var showingRatingSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with author info
            HStack {
                // Author avatar (placeholder)
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(rule.authorInfo.name.prefix(1)))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(rule.authorInfo.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if rule.authorInfo.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }

                    Text("Reputation: \(rule.authorInfo.reputation)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(rule.sharingMetadata.shareDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Rule info
            VStack(alignment: .leading, spacing: 8) {
                Text(rule.exportedRule.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(rule.exportedRule.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Statistics and metadata
            HStack(spacing: 16) {
                StatBadge(icon: "arrow.down.circle", value: "\(rule.sharingMetadata.downloads)", color: .blue)
                StatBadge(icon: "star.fill", value: String(format: "%.1f", rule.sharingMetadata.rating), color: .yellow)
                StatBadge(icon: "message", value: "\(rule.sharingMetadata.reviewCount)", color: .green)

                Spacer()

                Label(rule.exportedRule.targetCategory, systemImage: "tag.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            // Tags
            if !rule.sharingMetadata.tags.isEmpty {
                FlowLayout(rule.sharingMetadata.tags, spacing: 4) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            // Actions
            HStack {
                Button("Install Rule") {
                    onInstall()
                }
                .buttonStyle(.borderedProminent)

                Button("Rate & Review") {
                    showingRatingSheet = true
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .sheet(isPresented: $showingRatingSheet) {
            RatingReviewSheet { rating, review in
                onRate(rating, review)
                showingRatingSheet = false
            }
        }
    }
}

// MARK: - Supporting Views

struct StatBadge: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        Label(value, systemImage: icon)
            .font(.caption)
            .foregroundStyle(color)
    }
}

struct FlowLayout: Layout {
    let items: [String]
    let spacing: CGFloat
    let content: (String) -> AnyView

    init(_ items: [String], spacing: CGFloat = 8, @ViewBuilder content: @escaping (String) -> some View) {
        self.items = items
        self.spacing = spacing
        self.content = { AnyView(content($0)) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += size.height + spacing
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}

struct MySharedRulesView: View {
    let sharedRules: [CommunityRule]
    let onShare: (EnhancedCategorizationRule) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Feature coming soon...")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
        }
    }
}

struct ImportExportView: View {
    let onImport: () -> Void
    let onExport: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Import section
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)

                    VStack(spacing: 8) {
                        Text("Import Rules")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Import rules from JSON files, rule packs, or other FamilyFinance exports")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Choose Files to Import") {
                        onImport()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Divider()

                // Export section
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    VStack(spacing: 8) {
                        Text("Export Rules")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Export your custom rules to share with others or backup your configuration")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Export My Rules") {
                        onExport()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(40)
        }
    }
}

struct RatingReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSubmit: (Int, String?) -> Void

    @State private var rating = 5
    @State private var review = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Rate this rule")
                    .font(.headline)

                // Star rating
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Button(action: { rating = star }) {
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.title)
                                .foregroundStyle(star <= rating ? .yellow : .gray)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Review (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("Share your experience with this rule...", text: $review, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
            }
            .padding(20)
            .navigationTitle("Rate & Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        onSubmit(rating, review.isEmpty ? nil : review)
                    }
                }
            }
        }
    }
}

// MARK: - Document Types

struct RulePackDocument: FileDocument {
    static var readableContentTypes = [UTType.json]
    static var writableContentTypes = [UTType.json]

    let pack: RulePack

    init(pack: RulePack) {
        self.pack = pack
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        pack = try JSONDecoder().decode(RulePack.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(pack)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Supporting Types

enum MarketplaceTab: String, CaseIterable {
    case templates = "Templates"
    case community = "Community"
    case myRules = "My Rules"
    case importExport = "Import/Export"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .templates: return "doc.text.fill"
        case .community: return "person.3.fill"
        case .myRules: return "person.crop.circle.fill"
        case .importExport: return "arrow.up.arrow.down.circle.fill"
        }
    }
}