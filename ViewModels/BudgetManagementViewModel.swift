//
//  BudgetManagementViewModel.swift
//  Florijn
//
//  Modern @Observable view model for budget management
//  with month/year navigation and spending level tracking
//
//  Created: 2026-02-10
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class BudgetManagementViewModel {

    // MARK: - State

    var selectedYear: Int
    var selectedMonth: Int
    var categorySummaries: [CategorySummary] = []
    var showingAddBudget = false
    var isLoading = false

    // MARK: - Spending Level

    enum SpendingLevel: String, CaseIterable {
        case healthy = "On Track"
        case caution = "Approaching Limit"
        case over = "Over Budget"

        var color: Color {
            switch self {
            case .healthy: return .blue
            case .caution: return .orange
            case .over: return .red
            }
        }

        var icon: String {
            switch self {
            case .healthy: return "checkmark.circle.fill"
            case .caution: return "exclamationmark.triangle.fill"
            case .over: return "xmark.octagon.fill"
            }
        }

        var label: String { rawValue }
    }

    // MARK: - Initialization

    init() {
        let calendar = Calendar.current
        let now = Date()
        self.selectedYear = calendar.component(.year, from: now)
        self.selectedMonth = calendar.component(.month, from: now)
    }

    // MARK: - Month Navigation

    func navigateForward() {
        if selectedMonth == 12 {
            selectedMonth = 1
            selectedYear += 1
        } else {
            selectedMonth += 1
        }
    }

    func navigateBackward() {
        if selectedMonth == 1 {
            selectedMonth = 12
            selectedYear -= 1
        } else {
            selectedMonth -= 1
        }
    }

    func navigateToCurrentMonth() {
        let calendar = Calendar.current
        let now = Date()
        selectedYear = calendar.component(.year, from: now)
        selectedMonth = calendar.component(.month, from: now)
    }

    // MARK: - Display Helpers

    /// Returns the localized month name for a 1-based month number.
    func monthName(_ month: Int) -> String {
        guard month >= 1, month <= 12 else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.monthSymbols[month - 1].capitalized
    }

    /// Returns a display string like "February 2026" for the current selection.
    var periodDisplayString: String {
        "\(monthName(selectedMonth)) \(selectedYear)"
    }

    // MARK: - Progress Calculations

    /// Calculates the percentage of budget spent (0.0 = 0%, 1.0 = 100%, >1.0 = over budget).
    func progressPercentage(spent: Decimal, budget: Decimal) -> Double {
        guard budget > 0 else { return 0 }
        return Double(truncating: (spent / budget) as NSNumber)
    }

    /// Determines the spending level based on percentage.
    /// - healthy: < 80%
    /// - caution: 80% to < 100%
    /// - over: >= 100%
    func spendingLevel(percentage: Double) -> SpendingLevel {
        switch percentage {
        case ..<0.8:
            return .healthy
        case 0.8..<1.0:
            return .caution
        default:
            return .over
        }
    }

    // MARK: - Summary Calculations

    /// Total budget across all expense categories with budgets.
    func totalBudget(for categories: [Category]) -> Decimal {
        expenseCategoriesWithBudget(categories)
            .reduce(Decimal.zero) { $0 + $1.monthlyBudget }
    }

    /// Total spent across all category summaries.
    func totalSpent(for summaries: [CategorySummary]) -> Decimal {
        summaries.reduce(Decimal.zero) { $0 + $1.totalAmount }
    }

    // MARK: - Category Filtering

    /// Returns expense categories that have a budget set.
    func expenseCategoriesWithBudget(_ categories: [Category]) -> [Category] {
        categories.filter { $0.type == .expense && $0.monthlyBudget > 0 }
    }

    /// Returns expense categories without a budget (for "Add Budget" sheet).
    func expenseCategoriesWithoutBudget(_ categories: [Category]) -> [Category] {
        categories.filter { $0.type == .expense && $0.monthlyBudget == 0 }
    }
}
