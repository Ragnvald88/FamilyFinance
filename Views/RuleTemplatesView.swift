//
//  RuleTemplatesView.swift
//  Florijn
//
//  Template browser for pre-built rule templates.
//  Provides search, category filtering, and one-click rule creation.
//
//  Created: 2026-02-10
//

import SwiftUI
import SwiftData

// MARK: - Rule Templates View

struct RuleTemplatesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: RuleTemplateCategory? = nil
    @State private var searchText = ""

    private var filteredTemplates: [RuleTemplate] {
        var templates = RuleTemplates.allTemplates

        // Filter by category
        if let category = selectedCategory {
            templates = templates.filter { $0.category == category }
        }

        // Filter by search
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            templates = templates.filter { template in
                template.name.localizedCaseInsensitiveContains(searchText) ||
                template.description.localizedCaseInsensitiveContains(searchText) ||
                template.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return templates
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                categoryPicker
                    .padding(.horizontal, PremiumSpacing.medium)
                    .padding(.top, PremiumSpacing.medium)
                    .padding(.bottom, PremiumSpacing.small)

                Divider()

                // Templates list
                if filteredTemplates.isEmpty {
                    emptyState
                } else {
                    templatesList
                }
            }
            .navigationTitle("Rule Templates")
            .searchable(text: $searchText, prompt: "Search templates...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(minWidth: 550, minHeight: 450)
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        HStack(spacing: PremiumSpacing.small) {
            categoryButton(nil, label: "All", icon: "square.grid.2x2")
            ForEach(RuleTemplateCategory.allCases, id: \.self) { category in
                categoryButton(category, label: category.rawValue, icon: category.icon)
            }
            Spacer()
        }
    }

    private func categoryButton(_ category: RuleTemplateCategory?, label: String, icon: String) -> some View {
        Button {
            withAnimation(.quickResponse) {
                selectedCategory = category
            }
        } label: {
            Label(label, systemImage: icon)
                .font(.caption)
                .padding(.horizontal, PremiumSpacing.small + 4)
                .padding(.vertical, PremiumSpacing.tiny + 2)
                .background(
                    selectedCategory == category
                        ? Color.florijnBlue.opacity(0.15)
                        : Color(nsColor: .controlBackgroundColor)
                )
                .foregroundStyle(
                    selectedCategory == category
                        ? Color.florijnBlue
                        : Color.secondary
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(
                            selectedCategory == category
                                ? Color.florijnBlue.opacity(0.3)
                                : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: PremiumSpacing.medium) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No Templates Found")
                .font(.headingMedium)
                .foregroundStyle(Color.florijnCharcoal)

            Text("Try a different search term or category")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Templates List

    private var templatesList: some View {
        List {
            ForEach(filteredTemplates, id: \.name) { template in
                RuleTemplateRow(template: template) {
                    createRuleFromTemplate(template)
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Actions

    private func createRuleFromTemplate(_ template: RuleTemplate) {
        let rule = template.createRule()
        modelContext.insert(rule)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Template Row

struct RuleTemplateRow: View {
    let template: RuleTemplate
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: PremiumSpacing.small) {
            // Header: name + add button
            HStack {
                Image(systemName: template.category.icon)
                    .foregroundStyle(Color.florijnBlue)
                    .font(.body)

                Text(template.name)
                    .font(.headingMedium)

                Spacer()

                Button("Add Rule") {
                    onSelect()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            // Description
            Text(template.description)
                .font(.body)
                .foregroundStyle(.secondary)

            // Tags + rule summary
            HStack(spacing: PremiumSpacing.small) {
                ForEach(template.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, PremiumSpacing.small)
                        .padding(.vertical, PremiumSpacing.tiny)
                        .background(Color.florijnBlue.opacity(0.08))
                        .foregroundStyle(Color.florijnBlue)
                        .clipShape(Capsule())
                }

                Spacer()

                Text("\(template.triggers.count) triggers, \(template.actions.count) actions")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, PremiumSpacing.tiny)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.subtleHover) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RuleTemplatesView()
        .modelContainer(for: [Rule.self, RuleGroup.self, RuleTrigger.self, RuleAction.self])
}
