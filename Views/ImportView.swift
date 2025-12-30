//
//  ImportView.swift
//  Florijn
//
//  Beautiful CSV import interface with drag-and-drop support
//  Real-time progress tracking and detailed results
//
//  Created: 2025-12-22
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

struct CSVImportView: View {

    // MARK: - State

    @StateObject private var viewModel: CSVImportViewModel
    @State private var isTargeted = false
    @State private var showFilePicker = false
    @State private var showResults = false

    // MARK: - Initialization

    init(importService: CSVImportService) {
        _viewModel = StateObject(wrappedValue: CSVImportViewModel(importService: importService))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if viewModel.isImporting {
                importingView
            } else if showResults, let result = viewModel.lastResult {
                resultsView(result: result)
            } else {
                dropZoneView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.commaSeparatedText, .text],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
        .onReceive(NotificationCenter.default.publisher(for: .importCSV)) { _ in
            showFilePicker = true
        }
    }

    // MARK: - Drop Zone View

    private var dropZoneView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 64))
                .foregroundStyle(isTargeted ? .blue : .secondary)
                .scaleEffect(isTargeted ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isTargeted)

            VStack(spacing: 12) {
                Text("Import Rabobank CSV Files")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Drop CSV files here or click to browse")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Action buttons
            HStack(spacing: 16) {
                Button(action: { showFilePicker = true }) {
                    Label("Choose Files", systemImage: "folder.fill")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: { importDefaultLocation() }) {
                    Label("Import from Default Location", systemImage: "folder.badge.gearshape")
                        .frame(minWidth: 240)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            // Info box
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Import Information")
                        .font(.headline)
                }

                VStack(alignment: .leading, spacing: 6) {
                    InfoRow(icon: "checkmark.circle.fill", text: "Supports latin-1, cp1252, and UTF-8 encoding")
                    InfoRow(icon: "checkmark.circle.fill", text: "Automatic duplicate detection")
                    InfoRow(icon: "checkmark.circle.fill", text: "95%+ automatic categorization")
                    InfoRow(icon: "checkmark.circle.fill", text: "Dutch number format support")
                }
            }
            .padding()
            .frame(maxWidth: 500)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .padding(40)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    // MARK: - Importing View

    private var importingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: (viewModel.progress?.percentage ?? 0) / 100)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 8) {
                Text(viewModel.progress?.stage.displayName ?? "Importing...")
                    .font(.title2)
                    .fontWeight(.semibold)

                if let progress = viewModel.progress {
                    Text("\(progress.processedRows) of \(progress.totalRows) rows")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Text(progress.currentFile)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            if let progress = viewModel.progress {
                ProgressView(value: progress.percentage, total: 100)
                    .frame(width: 400)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
            }

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Results View

    private func resultsView(result: CSVImportResult) -> some View {
        VStack(spacing: 32) {
            Spacer()

            // Success/Warning icon
            Image(systemName: result.hasErrors ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(result.hasErrors ? .orange : .green)

            VStack(spacing: 12) {
                Text(result.hasErrors ? "Import Completed with Warnings" : "Import Successful!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Processed \(result.totalRows) transactions in \(String(format: "%.1f", result.duration)) seconds")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Stats cards
            HStack(spacing: 16) {
                ImportStatCard(
                    title: "Imported",
                    value: "\(result.imported)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                ImportStatCard(
                    title: "Duplicates",
                    value: "\(result.duplicates)",
                    icon: "doc.on.doc.fill",
                    color: .orange
                )

                ImportStatCard(
                    title: "Categorized",
                    value: "\(result.categorized)",
                    icon: "tag.fill",
                    color: .blue
                )

                ImportStatCard(
                    title: "Errors",
                    value: "\(result.errors.count)",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
            }

            // Success rate
            VStack(spacing: 8) {
                HStack {
                    Text("Success Rate")
                        .font(.headline)

                    Spacer()

                    Text(String(format: "%.1f%%", result.successRate))
                        .font(.headline)
                        .foregroundStyle(.green)
                }

                ProgressView(value: result.successRate, total: 100)
                    .tint(.green)

                HStack {
                    Text("Categorization Rate")
                        .font(.headline)

                    Spacer()

                    Text(String(format: "%.1f%%", result.categorizationRate))
                        .font(.headline)
                        .foregroundStyle(.blue)
                }

                ProgressView(value: result.categorizationRate, total: 100)
                    .tint(.blue)
            }
            .frame(width: 400)

            // Error details (if any)
            if !result.errors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Errors (\(result.errors.count))")
                            .font(.headline)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(result.errors.prefix(10).enumerated()), id: \.offset) { _, error in
                                Text(error.localizedDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if result.errors.count > 10 {
                                Text("... and \(result.errors.count - 10) more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(height: 100)
                }
                .padding()
                .frame(width: 500)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Actions
            HStack(spacing: 16) {
                Button("Import More Files") {
                    showResults = false
                    viewModel.reset()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("Go to Dashboard") {
                    NotificationCenter.default.post(name: .refreshDashboard, object: nil)
                    showResults = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Helper Views

    private struct InfoRow: View {
        let icon: String
        let text: String

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .frame(width: 16)

                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private struct ImportStatCard: View {
        let title: String
        let value: String
        let icon: String
        let color: Color

        var body: some View {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(value)
                    .font(.title)
                    .fontWeight(.bold)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helper Methods

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                guard let url = url else { return }
                Task { @MainActor in
                    await importFiles([url])
                }
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                await importFiles(urls)
            }
        case .failure(let error):
            print("File selection error: \(error)")
        }
    }

    private func importDefaultLocation() {
        // NOTE: Configure default import path in FamilyAccountsConfig.swift or use file picker
        // This is a dev-only feature - shows file picker for production use
        showFilePicker = true
    }

    private func importFiles(_ urls: [URL]) async {
        await viewModel.importFiles(urls)
        showResults = true
    }
}

// MARK: - Import View Model

@MainActor
class CSVImportViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isImporting = false
    @Published var progress: CSVImportProgress?
    @Published var lastResult: CSVImportResult?

    // MARK: - Dependencies

    private let importService: CSVImportService
    private var progressObserver: AnyCancellable?

    // MARK: - Initialization

    init(importService: CSVImportService) {
        self.importService = importService

        // Bind to service's progress updates
        progressObserver = importService.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newProgress in
                self?.progress = newProgress
            }
    }

    // MARK: - Methods

    func importFiles(_ urls: [URL]) async {
        isImporting = true
        progress = nil

        do {
            let result = try await importService.importFiles(urls)
            lastResult = result
        } catch {
            print("Import error: \(error)")
            // Create error result
            lastResult = CSVImportResult(
                totalRows: 0,
                imported: 0,
                duplicates: 0,
                errors: [CSVImportError.saveFailed(error.localizedDescription)],
                duration: 0,
                categorized: 0,
                uncategorized: 0,
                batchID: UUID(),
                filesProcessed: 0
            )
        }

        isImporting = false
    }

    func reset() {
        lastResult = nil
        progress = nil
    }
}

// MARK: - Extensions

extension CSVImportStage {
    var displayName: String {
        switch self {
        case .reading: return "Reading files..."
        case .parsing: return "Parsing CSV..."
        case .categorizing: return "Categorizing..."
        case .saving: return "Saving to database..."
        case .complete: return "Complete!"
        }
    }
}
