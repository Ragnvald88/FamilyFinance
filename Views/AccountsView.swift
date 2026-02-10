//
//  AccountsView.swift
//  Florijn
//
//  Extracted from FlorijnApp.swift for better code organization
//
//  Created: 2025-01-02
//

import SwiftUI
import SwiftData

// MARK: - Accounts List View

struct AccountsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Accounts")
                        .font(.headingLarge)
                    Spacer()
                    Text("\(accounts.count) accounts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Total balance card
                totalBalanceCard

                // Account cards
                LazyVStack(spacing: 12) {
                    ForEach(accounts) { account in
                        AccountCardView(account: account)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var totalBalanceCard: some View {
        let totalBalance = accounts.reduce(Decimal.zero) { $0 + $1.currentBalance }

        return VStack(spacing: 8) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(totalBalance.toCurrencyString())
                .font(.currencyHero)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Account Card View

struct AccountCardView: View {
    let account: Account

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: account.accountType.icon)
                .font(.title2)
                .foregroundStyle(Color(hex: account.color ?? "3B82F6"))
                .frame(width: 44, height: 44)
                .background(Color(hex: account.color ?? "3B82F6").opacity(0.1))
                .cornerRadius(12)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.headline)

                Text(account.owner)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(account.iban)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }

            Spacer()

            // Balance
            VStack(alignment: .trailing, spacing: 4) {
                Text(account.currentBalance.toCurrencyString())
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("\(account.transactionCount) transactions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}
