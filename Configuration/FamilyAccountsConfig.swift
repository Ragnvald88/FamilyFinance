//
//  FamilyAccountsConfig.swift
//  Family Finance
//
//  Centralized configuration for family account information.
//
//  IMPORTANT: Replace these example values with your own account data.
//  This file should be customized for your family's accounts.
//
//  Created: 2025-12-22
//

import Foundation

/// Centralized configuration for family bank accounts.
///
/// **Customization:** Replace the example IBANs and names below with your
/// own account information before using the app.
///
/// **Privacy:** Consider adding this file to `.gitignore` if you fork this repo.
enum FamilyAccountsConfig {

    // MARK: - Family Account IBANs

    /// All known family account IBANs for internal transfer detection.
    /// Transactions between these accounts are marked as "transfer" type.
    ///
    /// Replace these example IBANs with your actual account numbers.
    static let familyIBANs: Set<String> = [
        "NL00BANK0123456001",  // Joint Checking (Example)
        "NL00BANK0123456002",  // Joint Savings (Example)
        "NL00BANK0123456003",  // Partner 1 Personal (Example)
        "NL00BANK0123456004",  // Partner 2 Personal (Example)
        "NL00BANK0123456005",  // Partner 2 Savings (Example)
        "NL00BANK0123456006",  // Additional Account (Example)
    ]

    /// The main joint account IBAN - used for contribution (Inleg) detection.
    static let jointAccountIBAN = "NL00BANK0123456001"

    // MARK: - Contributor Configuration

    /// Partner 1's personal IBAN for contribution detection
    static let partner1IBAN = "NL00BANK0123456003"

    /// Partner 2's IBANs for contribution detection
    static let partner2IBANs: Set<String> = [
        "NL00BANK0123456004",
        "NL00BANK0123456005",
    ]

    /// Name patterns for Partner 1 (lowercase, used for fuzzy matching)
    /// Replace with actual name patterns
    static let partner1NamePatterns: [String] = [
        "j. doe",
        "john doe",
        "j doe",
    ]

    /// Name patterns for Partner 2 (lowercase, used for fuzzy matching)
    /// Replace with actual name patterns
    static let partner2NamePatterns: [String] = [
        "j. smith",
        "jane smith",
        "jane",
    ]

    /// Description patterns for Partner 1 contributions (handles typos)
    static let partner1InlegPatterns: [String] = [
        "inleg partner1",
        "contribution",
        "huishoudgeld",
    ]

    /// Description patterns for Partner 2 contributions
    static let partner2InlegPatterns: [String] = [
        "inleg partner2",
        "bijdrage",
    ]

    // MARK: - Default Account Definitions

    /// Default accounts to create when database is empty.
    /// Format: (iban, name, type, owner, color, sortOrder)
    ///
    /// Replace with your actual accounts.
    static let defaultAccounts: [(iban: String, name: String, type: String, owner: String, color: String, sortOrder: Int)] = [
        ("NL00BANK0123456001", "Joint Checking", "checking", "Family", "3B82F6", 1),
        ("NL00BANK0123456002", "Joint Savings", "savings", "Family", "10B981", 2),
        ("NL00BANK0123456003", "Partner 1 Personal", "checking", "Partner1", "F59E0B", 3),
        ("NL00BANK0123456004", "Partner 2 Personal", "checking", "Partner2", "EC4899", 4),
        ("NL00BANK0123456005", "Partner 2 Savings", "savings", "Partner2", "8B5CF6", 5),
        ("NL00BANK0123456006", "Extra Account", "savings", "Family", "6366F1", 6),
    ]

    // MARK: - Helper Methods

    /// Check if an IBAN belongs to the family.
    static func isFamilyAccount(_ iban: String) -> Bool {
        familyIBANs.contains(iban)
    }

    /// Get account owner by IBAN.
    static func getOwner(for iban: String) -> String? {
        defaultAccounts.first { $0.iban == iban }?.owner
    }
}
