//
//  CategoryManagementViewModel.swift
//  Florijn
//
//  Modern @Observable view model for category management
//  with financial health scoring and educational micro-tips
//
//  Created: 2026-02-10
//

import Foundation
import SwiftUI
import SwiftData

@Observable
@MainActor
final class CategoryManagementViewModel {

    // MARK: - State

    var searchText = ""
    var selectedFilter: CategoryFilter = .all
    var showingCategoryEditor = false
    var editingCategory: Category?
    var showingDeleteConfirmation = false
    var categoryToDelete: Category?
    var showingHealthDetails = false

    // MARK: - Filter Enum

    enum CategoryFilter: String, CaseIterable, Identifiable {
        case all = "All Categories"
        case income = "Income"
        case expense = "Expense"
        case overBudget = "Over Budget"
        case healthy = "Healthy"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .income: return "arrow.down.circle.fill"
            case .expense: return "arrow.up.circle.fill"
            case .overBudget: return "exclamationmark.triangle.fill"
            case .healthy: return "checkmark.seal.fill"
            }
        }
    }

    // MARK: - Category Health Model

    struct CategoryHealth {
        enum Rating: String, CaseIterable {
            case excellent = "Excellent"
            case good = "Good"
            case warning = "Warning"
            case critical = "Critical"

            var color: Color {
                switch self {
                case .excellent: return .green
                case .good: return .blue
                case .warning: return .orange
                case .critical: return .red
                }
            }

            var icon: String {
                switch self {
                case .excellent: return "checkmark.seal.fill"
                case .good: return "checkmark.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .critical: return "xmark.octagon.fill"
                }
            }

            var accessibilityLabel: String {
                switch self {
                case .excellent: return "Budget health: excellent"
                case .good: return "Budget health: good"
                case .warning: return "Budget health: warning"
                case .critical: return "Budget health: critical, over budget"
                }
            }
        }

        let percentage: Double
        let rating: Rating
        let microTip: String
    }

    // MARK: - Health Calculation

    /// Calculates financial health for a category based on spent amount vs budget.
    /// - Parameters:
    ///   - category: The category to evaluate
    ///   - spent: Absolute amount spent this month (positive value)
    /// - Returns: A CategoryHealth with rating, percentage, and educational micro-tip
    func calculateCategoryHealth(for category: Category, spent: Decimal) -> CategoryHealth {
        guard category.monthlyBudget > 0 else {
            return CategoryHealth(
                percentage: 0,
                rating: .good,
                microTip: "Set a budget to track your spending health."
            )
        }

        let percentage = Double(truncating: (spent / category.monthlyBudget) as NSNumber)
        let rating: CategoryHealth.Rating
        let microTip: String

        switch percentage {
        case ..<0.5:
            rating = .excellent
            microTip = "Great job! You're well within budget with room to spare."
        case 0.5..<0.8:
            rating = .good
            microTip = "You're on track. Consider setting money aside for next month."
        case 0.8..<1.0:
            rating = .warning
            microTip = "Approaching your limit. Consider reducing spending in this category."
        default:
            rating = .critical
            microTip = "Over budget! Review your spending patterns and adjust accordingly."
        }

        return CategoryHealth(
            percentage: percentage,
            rating: rating,
            microTip: microTip
        )
    }

    // MARK: - Filtering

    /// Filters and sorts categories based on current search text and selected filter.
    func filteredCategories(_ categories: [Category]) -> [Category] {
        let filtered = categories.filter { category in
            let matchesSearch = searchText.isEmpty ||
                category.name.localizedCaseInsensitiveContains(searchText)

            let matchesFilter: Bool
            switch selectedFilter {
            case .all:
                matchesFilter = true
            case .income:
                matchesFilter = category.type == .income
            case .expense:
                matchesFilter = category.type == .expense
            case .overBudget:
                // Show categories that have a budget set (filtering by actual spend
                // is done at the view level where transactions are available)
                matchesFilter = category.monthlyBudget > 0
            case .healthy:
                matchesFilter = category.monthlyBudget > 0
            }

            return matchesSearch && matchesFilter
        }

        return filtered.sorted { $0.name < $1.name }
    }
}
