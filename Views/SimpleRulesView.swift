//
//  SimpleRulesView.swift
//  Family Finance
//
//  Firefly III-inspired rules interface - Rules First, Groups Optional
//
//  Design Philosophy:
//  - Rules are the primary entity (not groups)
//  - Users should be able to create rules immediately
//  - Groups are optional organization folders
//  - Simple, sequential rule processing
//
//  Created: 2025-12-27
//

import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: "FamilyFinance", category: "SimpleRulesView")

// MARK: - Main View

struct SimpleRulesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Rule.createdAt, order: .reverse) private var allRules: [Rule]
    @Query(sort: \RuleGroup.executionOrder) private var groups: [RuleGroup]

    @State private var selectedFilter: RuleFilter = .all
    @State private var searchText = ""
    @State private var showingCreateRule = false
    @State private var editingRule: Rule?
    @State private var showingManageGroups = false

    private var filteredRules: [Rule] {
        var rules = allRules

        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .active:
            rules = rules.filter(\.isActive)
        case .inactive:
            rules = rules.filter { !$0.isActive }
        case .ungrouped:
            rules = rules.filter { $0.group == nil }
        case .group(let groupUUID):
            rules = rules.filter { $0.group?.uuid == groupUUID }
        }

        // Apply search
        if !searchText.isEmpty {
            rules = rules.filter { rule in
                rule.name.localizedCaseInsensitiveContains(searchText) ||
                rule.triggers.contains { $0.value.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return rules
    }

    var body: some View {
        NavigationSplitView {
            // MARK: - Sidebar (Filters)
            List(selection: $selectedFilter) {
                Section("Rules") {
                    FilterRow(filter: .all, count: allRules.count)
                    FilterRow(filter: .active, count: allRules.filter(\.isActive).count)
                    FilterRow(filter: .inactive, count: allRules.filter { !$0.isActive }.count)
                    FilterRow(filter: .ungrouped, count: allRules.filter { $0.group == nil }.count)
                }

                if !groups.isEmpty {
                    Section("Groups") {
                        ForEach(groups) { group in
                            FilterRow(
                                filter: .group(group.uuid),
                                label: group.name,
                                icon: "folder",
                                count: group.rules.count
                            )
                        }
                    }
                }

                Section {
                    Button {
                        showingManageGroups = true
                    } label: {
                        Label("Manage Groups", systemImage: "folder.badge.gearshape")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Rules")
            .searchable(text: $searchText, prompt: "Search rules...")
        } detail: {
            // MARK: - Main Content
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Text(filterTitle)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    Button {
                        showingCreateRule = true
                    } label: {
                        Label("Create Rule", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

                Divider()

                // Rules List
                if filteredRules.isEmpty {
                    emptyState
                } else {
                    rulesList
                }
            }
            .navigationTitle("")
        }
        .sheet(isPresented: $showingCreateRule) {
            SimpleRuleEditorView(
                rule: nil,
                groups: groups,
                onSave: { newRule in
                    modelContext.insert(newRule)
                    try? modelContext.save()
                    showingCreateRule = false
                },
                onCancel: {
                    showingCreateRule = false
                }
            )
        }
        .sheet(item: $editingRule) { rule in
            SimpleRuleEditorView(
                rule: rule,
                groups: groups,
                onSave: { _ in
                    try? modelContext.save()
                    editingRule = nil
                },
                onCancel: {
                    editingRule = nil
                }
            )
        }
        .sheet(isPresented: $showingManageGroups) {
            GroupsManagerView(groups: groups)
        }
    }

    // MARK: - Filter Title

    private var filterTitle: String {
        switch selectedFilter {
        case .all: return "All Rules"
        case .active: return "Active Rules"
        case .inactive: return "Inactive Rules"
        case .ungrouped: return "Ungrouped Rules"
        case .group(let uuid):
            return groups.first { $0.uuid == uuid }?.name ?? "Group"
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.l) {
            Spacer()

            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)

            Text("No Rules Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create your first rule to start automating\ntransaction categorization")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingCreateRule = true
            } label: {
                Label("Create First Rule", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Rules List

    private var rulesList: some View {
        List {
            ForEach(filteredRules) { rule in
                SimpleRuleRow(rule: rule) {
                    editingRule = rule
                }
                .contextMenu {
                    Button("Edit") { editingRule = rule }

                    Button(rule.isActive ? "Disable" : "Enable") {
                        rule.isActive.toggle()
                        try? modelContext.save()
                    }

                    Divider()

                    Button("Duplicate") { duplicateRule(rule) }

                    Button("Delete", role: .destructive) { deleteRule(rule) }
                }
            }
            .onDelete(perform: deleteRules)
        }
        .listStyle(.inset)
    }

    // MARK: - Actions

    private func duplicateRule(_ rule: Rule) {
        let newRule = Rule(name: "\(rule.name) Copy")
        newRule.isActive = false
        newRule.triggerLogic = rule.triggerLogic
        newRule.stopProcessing = rule.stopProcessing
        newRule.group = rule.group

        // Duplicate triggers
        for trigger in rule.triggers {
            let newTrigger = trigger.duplicate()
            newTrigger.rule = newRule
            newRule.triggers.append(newTrigger)
        }

        // Duplicate actions
        for action in rule.actions {
            let newAction = action.duplicate()
            newAction.rule = newRule
            newRule.actions.append(newAction)
        }

        modelContext.insert(newRule)
        try? modelContext.save()
    }

    private func deleteRule(_ rule: Rule) {
        modelContext.delete(rule)
        try? modelContext.save()
    }

    private func deleteRules(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredRules[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Filter Types

enum RuleFilter: Hashable {
    case all
    case active
    case inactive
    case ungrouped
    case group(UUID)
}

// MARK: - Filter Row

struct FilterRow: View {
    let filter: RuleFilter
    var label: String?
    var icon: String?
    let count: Int

    init(filter: RuleFilter, count: Int) {
        self.filter = filter
        self.count = count

        switch filter {
        case .all:
            self.label = "All Rules"
            self.icon = "list.bullet"
        case .active:
            self.label = "Active"
            self.icon = "checkmark.circle.fill"
        case .inactive:
            self.label = "Inactive"
            self.icon = "pause.circle"
        case .ungrouped:
            self.label = "Ungrouped"
            self.icon = "tray"
        case .group:
            self.label = nil
            self.icon = nil
        }
    }

    init(filter: RuleFilter, label: String, icon: String, count: Int) {
        self.filter = filter
        self.label = label
        self.icon = icon
        self.count = count
    }

    var body: some View {
        NavigationLink(value: filter) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                }

                Text(label ?? "")

                Spacer()

                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(Capsule())
            }
        }
    }

    private var iconColor: Color {
        switch filter {
        case .active: return .green
        case .inactive: return .orange
        default: return .secondary
        }
    }
}

// MARK: - Simple Rule Row

struct SimpleRuleRow: View {
    let rule: Rule
    let onEdit: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.m) {
            // Active indicator
            Circle()
                .fill(rule.isActive ? Color.green : Color.orange)
                .frame(width: 8, height: 8)

            // Rule info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rule.name)
                        .font(.headline)

                    if rule.stopProcessing {
                        Image(systemName: "stop.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .help("Stops processing other rules when matched")
                    }
                }

                Text(ruleSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Group badge (if any)
            if let group = rule.group {
                Text(group.name)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            // Stats
            if rule.matchCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text("\(rule.matchCount)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Edit button (visible on hover)
            Button("Edit") {
                onEdit()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            onEdit()
        }
    }

    private var ruleSummary: String {
        let triggerCount = rule.triggers.count
        let actionCount = rule.actions.count

        var parts: [String] = []

        // Trigger summary
        if triggerCount == 1, let trigger = rule.triggers.first {
            parts.append("IF \(trigger.field.displayName) \(trigger.triggerOperator.displayName) \"\(trigger.value.prefix(20))\"")
        } else if triggerCount > 1 {
            let logic = rule.triggerLogic == .all ? "ALL" : "ANY"
            parts.append("IF \(triggerCount) conditions (\(logic))")
        }

        // Action summary
        if actionCount == 1, let action = rule.actions.first {
            parts.append("THEN \(action.type.displayName)")
        } else if actionCount > 1 {
            parts.append("THEN \(actionCount) actions")
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Simple Rule Editor

struct SimpleRuleEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.name) private var accounts: [Account]

    let rule: Rule?
    let groups: [RuleGroup]
    let onSave: (Rule) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var isActive: Bool = true
    @State private var selectedGroupUUID: UUID?
    @State private var triggerLogic: TriggerLogic = .all
    @State private var stopProcessing: Bool = false
    @State private var triggers: [TriggerData] = []
    @State private var actions: [ActionData] = []

    init(rule: Rule?, groups: [RuleGroup], onSave: @escaping (Rule) -> Void, onCancel: @escaping () -> Void) {
        self.rule = rule
        self.groups = groups
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section("Rule") {
                    TextField("Name", text: $name)

                    Toggle("Active", isOn: $isActive)

                    Picker("Group (Optional)", selection: $selectedGroupUUID) {
                        Text("No Group").tag(nil as UUID?)
                        ForEach(groups) { group in
                            Text(group.name).tag(group.uuid as UUID?)
                        }
                    }
                }

                // Triggers
                Section {
                    // Always show AND/OR picker with explanation
                    HStack {
                        Text("When")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $triggerLogic) {
                            Text("ALL").tag(TriggerLogic.all)
                            Text("ANY").tag(TriggerLogic.any)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                        Text("of these conditions match:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 4)

                    if triggers.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                            Text("Add conditions below. Multiple conditions will be combined with \(triggerLogic == .all ? "AND" : "OR") logic.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        // Use indices to safely bind - avoids crash when deleting
                        ForEach($triggers) { $trigger in
                            let index = triggers.firstIndex(where: { $0.id == trigger.id }) ?? 0
                            VStack(spacing: 0) {
                                if index > 0 {
                                    Text(triggerLogic == .all ? "AND" : "OR")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.orange)
                                        .padding(.vertical, 4)
                                }
                                TriggerEditor(data: $trigger, onDelete: {
                                    withAnimation {
                                        triggers.removeAll { $0.id == trigger.id }
                                    }
                                })
                            }
                        }
                    }

                    Button {
                        triggers.append(TriggerData())
                    } label: {
                        Label("Add Condition", systemImage: "plus")
                    }
                } header: {
                    Text("When (Triggers)")
                }

                // Actions
                Section {
                    if actions.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                            Text("Add at least one action to execute when conditions match.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach($actions) { $action in
                            ActionEditor(data: $action, onDelete: {
                                withAnimation {
                                    actions.removeAll { $0.id == action.id }
                                }
                            })
                        }
                    }

                    Button {
                        actions.append(ActionData())
                    } label: {
                        Label("Add Action", systemImage: "plus")
                    }
                } header: {
                    Text("Then (Actions)")
                }

                // Options
                Section("Options") {
                    Toggle("Stop processing other rules after match", isOn: $stopProcessing)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(rule == nil ? "New Rule" : "Edit Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRule()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadRule()
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    private var isValid: Bool {
        // Name required
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }

        // At least one trigger
        guard !triggers.isEmpty else { return false }

        // All triggers with value-requiring operators must have values
        guard triggers.allSatisfy({ trigger in
            !trigger.op.requiresValue || !trigger.value.trimmingCharacters(in: .whitespaces).isEmpty
        }) else { return false }

        // At least one action
        guard !actions.isEmpty else { return false }

        // All actions with value-requiring types must have values
        guard actions.allSatisfy({ action in
            !action.type.requiresValue || !action.value.trimmingCharacters(in: .whitespaces).isEmpty
        }) else { return false }

        return true
    }

    private func loadRule() {
        guard let rule = rule else { return }

        name = rule.name
        isActive = rule.isActive
        selectedGroupUUID = rule.group?.uuid
        triggerLogic = rule.triggerLogic
        stopProcessing = rule.stopProcessing

        triggers = rule.triggers.map { trigger in
            TriggerData(
                field: trigger.field,
                op: trigger.triggerOperator,
                value: trigger.value,
                isInverted: trigger.isInverted
            )
        }

        actions = rule.actions.map { action in
            ActionData(
                type: action.type,
                value: action.value
            )
        }
    }

    private func saveRule() {
        let ruleToSave: Rule

        if let existingRule = rule {
            ruleToSave = existingRule

            // Clear existing triggers and actions
            existingRule.triggers.forEach { modelContext.delete($0) }
            existingRule.actions.forEach { modelContext.delete($0) }
            existingRule.triggers.removeAll()
            existingRule.actions.removeAll()
        } else {
            ruleToSave = Rule(name: name)
        }

        // Update properties
        ruleToSave.name = name
        ruleToSave.isActive = isActive
        ruleToSave.triggerLogic = triggerLogic
        ruleToSave.stopProcessing = stopProcessing
        ruleToSave.group = groups.first { $0.uuid == selectedGroupUUID }
        ruleToSave.touch()

        // Add triggers
        for (index, triggerData) in triggers.enumerated() {
            let trigger = RuleTrigger(
                field: triggerData.field,
                triggerOperator: triggerData.op,
                value: triggerData.value,
                isInverted: triggerData.isInverted
            )
            trigger.sortOrder = index
            trigger.rule = ruleToSave
            ruleToSave.triggers.append(trigger)
        }

        // Add actions
        for (index, actionData) in actions.enumerated() {
            let action = RuleAction(
                type: actionData.type,
                value: actionData.value
            )
            action.sortOrder = index
            action.rule = ruleToSave
            ruleToSave.actions.append(action)
        }

        onSave(ruleToSave)
    }
}

// MARK: - Trigger/Action Data Models (for editing)

struct TriggerData: Identifiable, Equatable {
    let id = UUID()
    var field: TriggerField = .description
    var op: TriggerOperator = .contains
    var value: String = ""
    var isInverted: Bool = false

    static func == (lhs: TriggerData, rhs: TriggerData) -> Bool {
        lhs.id == rhs.id &&
        lhs.field == rhs.field &&
        lhs.op == rhs.op &&
        lhs.value == rhs.value &&
        lhs.isInverted == rhs.isInverted
    }
}

struct ActionData: Identifiable, Equatable {
    let id = UUID()
    var type: ActionType = .setCategory
    var value: String = ""

    static func == (lhs: ActionData, rhs: ActionData) -> Bool {
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.value == rhs.value
    }
}

// MARK: - Trigger Editor

struct TriggerEditor: View {
    @Binding var data: TriggerData
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                // Main condition row
                HStack(spacing: 8) {
                    // Field picker
                    Picker("", selection: $data.field) {
                        ForEach(TriggerField.allCases, id: \.self) { field in
                            HStack {
                                Image(systemName: field.icon)
                                Text(field.displayName)
                            }
                            .tag(field)
                        }
                    }
                    .frame(width: 160)
                    .onChange(of: data.field) { _, newField in
                        // Reset operator when field changes
                        if !newField.validOperators.contains(data.op) {
                            data.op = newField.validOperators.first ?? .contains
                        }
                    }

                    // Operator picker
                    Picker("", selection: $data.op) {
                        ForEach(data.field.validOperators, id: \.self) { op in
                            Text(op.displayName).tag(op)
                        }
                    }
                    .frame(width: 140)

                    // Value field (only if required)
                    if data.op.requiresValue {
                        TextField(data.op.valuePlaceholder, text: $data.value)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text("(no value needed)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // NOT toggle
                HStack {
                    Toggle(isOn: $data.isInverted) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.caption2)
                            Text("NOT (invert)")
                                .font(.caption)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .foregroundStyle(data.isInverted ? .red : .secondary)

                    Spacer()
                }
            }

            // Delete button
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove condition")
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Action Editor

struct ActionEditor: View {
    @Binding var data: ActionData
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Grouped action picker
            Picker("Action", selection: $data.type) {
                ForEach(ActionCategory.allCases, id: \.self) { category in
                    if let actions = ActionType.categorized[category], !actions.isEmpty {
                        Section(category.rawValue) {
                            ForEach(actions, id: \.self) { type in
                                Label(type.displayName, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                    }
                }
            }
            .frame(width: 220)
            .onChange(of: data.type) { _, newType in
                // Clear value when switching to action that doesn't need one
                if !newType.requiresValue {
                    data.value = ""
                }
            }

            // Value field (only if required)
            if data.type.requiresValue {
                TextField(data.type.valuePlaceholder, text: $data.value)
                    .textFieldStyle(.roundedBorder)
            } else {
                Spacer()
            }

            // Delete button
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove action")
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Groups Manager

struct GroupsManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let groups: [RuleGroup]

    @State private var newGroupName = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Create New Group") {
                    HStack {
                        TextField("Group name", text: $newGroupName)

                        Button("Create") {
                            createGroup()
                        }
                        .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if !groups.isEmpty {
                    Section("Existing Groups") {
                        ForEach(groups) { group in
                            HStack {
                                Image(systemName: "folder")
                                Text(group.name)
                                Spacer()
                                Text("\(group.rules.count) rules")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: deleteGroups)
                    }
                }
            }
            .navigationTitle("Manage Groups")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private func createGroup() {
        let group = RuleGroup(name: newGroupName, executionOrder: groups.count)
        modelContext.insert(group)
        try? modelContext.save()
        newGroupName = ""
    }

    private func deleteGroups(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(groups[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Preview

#Preview {
    SimpleRulesView()
        .modelContainer(for: [Rule.self, RuleGroup.self, RuleTrigger.self, RuleAction.self])
}
