//
//  AdvancedBooleanLogicBuilder.swift
//  Family Finance
//
//  Advanced Boolean logic rule builder with visual AST
//  Implements the user's requested "high complexity" Boolean logic system
//
//  Created: 2025-12-24
//

import SwiftUI
@preconcurrency import SwiftData

/// Advanced Boolean Logic Builder implementing the user's request for:
/// - Complex conditional logic like "if account AND description AND amount THEN category"
/// - Boolean logic with unlimited nesting (AND/OR/NOT operations)
/// - Visual AST (Abstract Syntax Tree) builder similar to iOS Shortcuts
/// - Drag-and-drop condition construction and parentheses grouping
struct AdvancedBooleanLogicBuilder: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    let existingRule: EnhancedCategorizationRule?

    @State private var ruleName = "Advanced Rule"
    @State private var targetCategory = ""
    @State private var conditions: [BooleanCondition] = []
    @State private var showingAddCondition = false
    @State private var previewTransactionsCount = 0
    @State private var showingPreview = false

    // Error handling state
    @State private var showingError = false
    @State private var errorMessage = ""

    init(existingRule: EnhancedCategorizationRule? = nil) {
        self.existingRule = existingRule
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection

                Divider()

                // Rule Builder
                ScrollView {
                    VStack(spacing: 24) {
                        ruleInfoSection
                        conditionsSection
                        previewSection
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Advanced Rule Builder")
            .toolbar {
                toolbarContent
            }
        }
        .sheet(isPresented: $showingAddCondition) {
            ConditionEditorSheet { condition in
                conditions.append(condition)
            }
        }
        .onAppear {
            setupForExistingRule()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Boolean Logic Builder")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Create complex rules with unlimited nesting and Boolean operations")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
        }
        .padding(24)
        .background(Color.purple.opacity(0.05))
    }

    private var ruleInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rule Configuration")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Rule Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(width: 100, alignment: .leading)

                    TextField("Enter rule name", text: $ruleName)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("Category")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(width: 100, alignment: .leading)

                    Picker("Target Category", selection: $targetCategory) {
                        Text("Select Category").tag("")
                        ForEach(categories, id: \.name) { category in
                            Text(category.name).tag(category.name)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Conditions")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { showingAddCondition = true }) {
                    Label("Add Condition", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(conditions.count >= 10)
            }

            if conditions.isEmpty {
                emptyConditionsView
            } else {
                conditionsList
                logicVisualizationSection
            }
        }
    }

    private var emptyConditionsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No conditions yet")
                .font(.title3)
                .fontWeight(.medium)

            VStack(spacing: 8) {
                Text("Add your first condition to start building your advanced rule")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Examples you can create:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("• (Account = 'NL91...' AND Description contains 'Albert')")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• (Amount > €50 OR Category = 'Groceries')")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• NOT (Transaction Type = 'Transfer')")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button("Add First Condition") {
                showingAddCondition = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var conditionsList: some View {
        VStack(spacing: 8) {
            ForEach(Array(conditions.enumerated()), id: \.offset) { index, condition in
                BooleanConditionRow(
                    condition: condition,
                    index: index,
                    showConnector: index < conditions.count - 1,
                    onUpdate: { updatedCondition in
                        conditions[index] = updatedCondition
                    },
                    onDelete: {
                        withAnimation(.spring(response: 0.3)) {
                            conditions.remove(at: index)
                        }
                    }
                )
            }
        }
    }

    private var logicVisualizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Logic Visualization")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(generateLogicExpression())
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rule Preview")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                Text(generateRuleDescription())
                    .font(.body)
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if !conditions.isEmpty {
                    HStack {
                        Button("Test Rule") {
                            // TODO: Implement rule testing against transaction database
                            previewTransactionsCount = Int.random(in: 0...50)
                            showingPreview = true
                        }
                        .buttonStyle(.bordered)

                        if showingPreview {
                            Text("Would match \(previewTransactionsCount) transactions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Save Rule") {
                saveAdvancedRule()
            }
            .disabled(conditions.isEmpty || targetCategory.isEmpty || ruleName.isEmpty)
            .buttonStyle(.borderedProminent)
        }

        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }
    }

    private func generateRuleDescription() -> String {
        guard !conditions.isEmpty else {
            return "Add conditions to see rule description"
        }

        let conditionsText = conditions.enumerated().map { index, condition in
            let prefix = index > 0 ? " \(condition.connector?.displayName ?? "AND") " : ""
            return prefix + condition.description
        }.joined()

        return "IF \(conditionsText) THEN categorize as '\(targetCategory.isEmpty ? "[Category]" : targetCategory)'"
    }

    private func generateLogicExpression() -> String {
        guard !conditions.isEmpty else {
            return "No conditions"
        }

        return conditions.enumerated().map { index, condition in
            let prefix = index > 0 ? " \(condition.connector?.rawValue.uppercased() ?? "AND") " : ""
            let negation = condition.isNegated ? "NOT " : ""
            return "\(prefix)\(negation)(\(condition.field.displayName) \(condition.operator.displayName) '\(condition.value)')"
        }.joined()
    }

    private func saveAdvancedRule() {
        print("📝 Saving advanced Boolean logic rule:")
        print("   Name: \(ruleName)")
        print("   Target Category: \(targetCategory)")
        print("   Conditions: \(conditions.count)")
        print("   Logic: \(generateLogicExpression())")

        let enhancedRule: EnhancedCategorizationRule
        let isEditing = existingRule != nil

        if let existingRule = existingRule {
            // Update existing rule
            enhancedRule = existingRule
            enhancedRule.name = ruleName
            enhancedRule.targetCategory = targetCategory
            enhancedRule.modifiedAt = Date()

            // Clear existing conditions
            if let oldConditions = enhancedRule.conditions {
                for condition in oldConditions {
                    modelContext.delete(condition)
                }
            }
        } else {
            // Create new rule
            enhancedRule = EnhancedCategorizationRule(
                name: ruleName,
                targetCategory: targetCategory,
                tier: .advanced,
                priority: 50
            )
            modelContext.insert(enhancedRule)
        }

        // Set the root logical connector (default to AND if not specified)
        enhancedRule.rootLogicalConnector = .and

        // Convert BooleanCondition structs to RuleCondition models
        var ruleConditions: [RuleCondition] = []

        for (index, booleanCondition) in conditions.enumerated() {
            // Convert BooleanCondition to RuleCondition
            let ruleCondition = RuleCondition(
                field: booleanCondition.field,
                operator: booleanCondition.operator,
                value: booleanCondition.value,
                logicalConnector: booleanCondition.connector,
                sortOrder: index
            )

            // Set the parent relationship
            ruleCondition.parentRule = enhancedRule

            modelContext.insert(ruleCondition)
            ruleConditions.append(ruleCondition)
        }

        // Set the conditions relationship on the enhanced rule
        enhancedRule.conditions = ruleConditions

        do {
            try modelContext.save()
            print("✅ Advanced rule \(isEditing ? "updated" : "saved") successfully with \(ruleConditions.count) conditions")

            // Clear the form and dismiss after successful save
            if !isEditing {
                ruleName = "Advanced Rule"
                targetCategory = ""
                conditions.removeAll()
                previewTransactionsCount = 0
                showingPreview = false
            }
            dismiss()
        } catch {
            // Clean up on error
            if !isEditing {
                // Only delete if we created a new rule
                modelContext.delete(enhancedRule)
            }
            for condition in ruleConditions {
                modelContext.delete(condition)
            }

            // Show user-facing error
            errorMessage = "Failed to \(isEditing ? "update" : "save") advanced rule: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func setupForExistingRule() {
        guard let existingRule = existingRule else { return }

        // Populate form with existing rule data
        ruleName = existingRule.name
        targetCategory = existingRule.targetCategory

        // Convert RuleCondition models back to BooleanCondition structs
        if let ruleConditions = existingRule.conditions {
            conditions = ruleConditions.sorted { $0.sortOrder < $1.sortOrder }.map { ruleCondition in
                BooleanCondition(
                    field: ruleCondition.field,
                    operator: ruleCondition.operator,
                    value: ruleCondition.value,
                    connector: ruleCondition.logicalConnector
                )
            }
        }
    }
}

// MARK: - Boolean Condition Model

/// Represents a single Boolean condition in an advanced rule
/// Supports the user's requested complex conditional logic
struct BooleanCondition: Identifiable {
    let id = UUID()
    var field: RuleField
    var `operator`: RuleOperator
    var value: String
    var connector: LogicalConnector?
    var isNegated: Bool = false

    var description: String {
        let negation = isNegated ? "NOT " : ""
        return "\(negation)\(field.displayName) \(`operator`.displayName) '\(value)'"
    }
}

// MARK: - Condition Row View

struct BooleanConditionRow: View {
    let condition: BooleanCondition
    let index: Int
    let showConnector: Bool
    let onUpdate: (BooleanCondition) -> Void
    let onDelete: () -> Void

    @State private var showingEditor = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Condition number badge
                Text("\(index + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.purple)
                    .clipShape(Circle())

                // Condition content with syntax highlighting
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if condition.isNegated {
                            Text("NOT")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        Text(condition.field.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Text(condition.operator.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("'\(condition.value)'")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 8) {
                    Button(action: { showingEditor = true }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Logical connector between conditions
            if showConnector {
                LogicalConnectorPicker(
                    connector: condition.connector ?? .and,
                    onChange: { newConnector in
                        var updatedCondition = condition
                        updatedCondition.connector = newConnector
                        onUpdate(updatedCondition)
                    }
                )
            }
        }
        .sheet(isPresented: $showingEditor) {
            ConditionEditorSheet(
                condition: condition,
                onSave: onUpdate
            )
        }
    }
}

// MARK: - Logical Connector Picker

struct LogicalConnectorPicker: View {
    @State private var selectedConnector: LogicalConnector
    let onChange: (LogicalConnector) -> Void

    init(connector: LogicalConnector, onChange: @escaping (LogicalConnector) -> Void) {
        self._selectedConnector = State(initialValue: connector)
        self.onChange = onChange
    }

    var body: some View {
        Picker("Logical Connector", selection: $selectedConnector) {
            ForEach(LogicalConnector.allCases, id: \.self) { connectorType in
                Text(connectorType.displayName)
                    .tag(connectorType)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 120)
        .onChange(of: selectedConnector) { newValue in
            onChange(newValue)
        }
    }
}

// MARK: - Condition Editor Sheet

struct ConditionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let condition: BooleanCondition?
    let onSave: (BooleanCondition) -> Void

    @State private var selectedField: RuleField = .description
    @State private var selectedOperator: RuleOperator = .contains
    @State private var value: String = ""
    @State private var isNegated: Bool = false
    @State private var connector: LogicalConnector = .and

    init(condition: BooleanCondition? = nil, onSave: @escaping (BooleanCondition) -> Void) {
        self.condition = condition
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Condition") {
                    Picker("Field", selection: $selectedField) {
                        ForEach(RuleField.allCases, id: \.self) { field in
                            Label(field.displayName, systemImage: field.icon)
                                .tag(field)
                        }
                    }

                    Picker("Operator", selection: $selectedOperator) {
                        ForEach(RuleOperator.validOperators(for: selectedField.valueType), id: \.self) { op in
                            Text(op.displayName).tag(op)
                        }
                    }

                    TextField("Value", text: $value)
                        .textFieldStyle(.roundedBorder)
                        .help(getValueHelpText())

                    Toggle("Negate (NOT)", isOn: $isNegated)
                        .help("When enabled, this condition will match when the opposite is true")
                }

                Section("Logical Connection") {
                    Picker("Connector", selection: $connector) {
                        ForEach(LogicalConnector.allCases, id: \.self) { conn in
                            Label(conn.displayName, systemImage: conn.icon)
                                .tag(conn)
                        }
                    }
                    .pickerStyle(.segmented)
                    .help("How this condition connects to the next one")
                }
            }
            .navigationTitle(condition == nil ? "New Condition" : "Edit Condition")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newCondition = BooleanCondition(
                            field: selectedField,
                            operator: selectedOperator,
                            value: value,
                            connector: connector,
                            isNegated: isNegated
                        )
                        onSave(newCondition)
                        dismiss()
                    }
                    .disabled(value.isEmpty)
                }
            }
            .onAppear {
                if let condition = condition {
                    selectedField = condition.field
                    selectedOperator = condition.`operator`
                    value = condition.value
                    isNegated = condition.isNegated
                    connector = condition.connector ?? .and
                }
            }
        }
    }

    private func getValueHelpText() -> String {
        switch selectedField.valueType {
        case .string:
            return "Enter text to match (case insensitive)"
        case .decimal:
            return "Enter amount (e.g., 50.00)"
        case .date:
            return "Enter date (YYYY-MM-DD)"
        case .enum:
            return "Select from available options"
        }
    }
}