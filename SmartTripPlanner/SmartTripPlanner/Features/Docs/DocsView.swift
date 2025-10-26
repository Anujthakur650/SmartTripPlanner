import SwiftUI

struct DocsView: View {
    @EnvironmentObject private var container: DependencyContainer
    @StateObject private var viewModel = DocsViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.documents.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Documents",
                        systemImage: "folder",
                        description: Text("Scan travel documents like passports, tickets, and reservations to keep them safe and synced.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    documentsList
                }
            }
            .overlay(alignment: .center) {
                if viewModel.isLoading && viewModel.documents.isEmpty {
                    ProgressView("Loading Documents…")
                }
            }
            .navigationTitle("Documents")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.presentScanner()
                    } label: {
                        Image(systemName: "doc.text.viewfinder")
                    }
                    .accessibilityIdentifier("scan_document_button")
                }
            }
            .task {
                viewModel.configure(with: container)
            }
            .refreshable {
                await viewModel.refreshDocuments()
            }
            .alert(item: $viewModel.alert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $viewModel.isScannerPresented) {
                DocumentScannerView { result in
                    viewModel.handleScannerResult(result)
                }
            }
            .sheet(item: $viewModel.metadataEditorState) { state in
                DocumentMetadataEditor(state: state) { metadata in
                    viewModel.performMetadataAction(metadata: metadata, state: state)
                } onCancel: {
                    viewModel.metadataEditorState = nil
                }
            }
        }
    }
    
    private var documentsList: some View {
        List {
            ForEach(viewModel.documents) { document in
                NavigationLink {
                    DocumentDetailView(
                        document: document,
                        fileURL: viewModel.url(for: document),
                        onEdit: { viewModel.editMetadata(for: document) },
                        onDelete: { viewModel.delete(document) }
                    )
                } label: {
                    DocumentRow(document: document)
                }
            }
            .onDelete(perform: viewModel.deleteDocuments)
        }
        .listStyle(.insetGrouped)
    }
}

struct DocumentRow: View {
    let document: TravelDocument
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    private let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: document.type.systemImage)
                .font(.system(size: 28))
                .foregroundColor(document.type.accentColor)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)
                Text(document.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Updated \(formatter.string(from: document.updatedAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(sizeFormatter.string(fromByteCount: Int64(document.fileSize)))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    let container = DependencyContainer()
    let sampleDocs: [TravelDocument] = {
        let metadata = TravelDocument.Metadata(title: "Passport", type: .passport, notes: "Expires 2032", tags: ["Essential"])
        return [
            TravelDocument(metadata: metadata, fileName: "sample.pdf", createdAt: Date(), updatedAt: Date(), pageCount: 3, fileSize: 245_000, checksum: "abcd1234"),
            TravelDocument(metadata: .init(title: "Flight UA88", type: .ticket, notes: "Seat 12A", tags: ["Flight", "Check-in"]), fileName: "sample2.pdf", createdAt: Date(), updatedAt: Date(), pageCount: 1, fileSize: 120_000, checksum: "efgh5678")
        ]
    }()
    return DocsView()
        .environmentObject(container)
        .task {
            container.documentStore // Force init
        }
}
