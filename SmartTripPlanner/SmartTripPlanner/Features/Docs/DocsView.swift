import SwiftUI
import UIKit
import VisionKit

struct DocsView: View {
    @EnvironmentObject private var documentService: DocumentService
    @EnvironmentObject private var theme: AppEnvironment
    
    @State private var selectedTrip: String?
    @State private var pendingDocument: PendingDocumentContext?
    @State private var selectedDocument: DocumentAsset?
    @State private var tagEditorDocument: DocumentAsset?
    @State private var shareURL: URL?
    @State private var isPresentingShareSheet = false
    @State private var isShowingDocumentPicker = false
    @State private var isShowingScanner = false
    @State private var alertContext: DocumentErrorContext?
    @State private var hasLoaded = false
    
    var body: some View {
        NavigationStack {
            Group {
                if documentService.isLoading && documentService.documents.isEmpty {
                    ProgressView("Loading documents…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(theme.theme.backgroundColor)
                } else if filteredDocuments.isEmpty {
                    ContentUnavailableView(
                        "No Documents",
                        systemImage: "folder",
                        description: Text("Import confirmations, passes, and scans to keep them handy offline.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.theme.backgroundColor)
                } else {
                    listView
                }
            }
            .navigationTitle("Documents")
            .toolbar { toolbarContent }
            .refreshable { await refreshDocuments() }
            .sheet(isPresented: $isPresentingShareSheet) {
                if let shareURL {
                    ShareSheet(activityItems: [shareURL])
                }
            }
            .sheet(isPresented: $isShowingDocumentPicker) {
                DocumentPickerView { result in
                    handleDocumentPickerResult(result)
                }
            }
            .sheet(isPresented: $isShowingScanner) {
                if VNDocumentCameraViewController.isSupported {
                    DocumentScannerView { result in
                        handleScannerResult(result)
                    }
                } else {
                    UnsupportedScannerView()
                }
            }
            .sheet(item: $pendingDocument) { context in
                DocumentIntakeView(context: context, existingTrips: documentService.availableTripNames()) { updated in
                    handleIntakeSave(updated)
                }
            }
            .sheet(item: $selectedDocument) { document in
                DocumentViewerView(document: document)
                    .environmentObject(documentService)
            }
            .sheet(item: $tagEditorDocument) { document in
                TagEditorView(title: document.title, initialTags: document.tags) { tags in
                    Task {
                        await updateTags(for: document, tags: tags)
                    }
                }
            }
            .alert(item: $alertContext) { context in
                if let retry = context.retryAction {
                    return Alert(
                        title: Text("Something went wrong"),
                        message: Text(context.message),
                        primaryButton: .default(Text("Retry")) {
                            handleRetry(retry)
                        },
                        secondaryButton: .cancel()
                    )
                } else {
                    return Alert(
                        title: Text("Something went wrong"),
                        message: Text(context.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .task {
                guard !hasLoaded else { return }
                hasLoaded = true
                await refreshDocuments()
            }
        }
    }
    
    // MARK: - Views
    
    private var listView: some View {
        List {
            ForEach(groupedDocuments) { group in
                Section(group.title) {
                    ForEach(group.documents) { document in
                        DocumentListRow(document: document)
                            .onTapGesture {
                                selectedDocument = document
                            }
                            .contextMenu {
                                Button {
                                    selectedDocument = document
                                } label: {
                                    Label("View", systemImage: "doc.text.magnifyingglass")
                                }
                                Button {
                                    Task { await share(document: document) }
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                Button {
                                    tagEditorDocument = document
                                } label: {
                                    Label("Edit Tags", systemImage: "tag")
                                }
                                Button {
                                    Task { await recalculateMetadata(for: document) }
                                } label: {
                                    Label("Re-extract Metadata", systemImage: "text.viewfinder")
                                }
                                Button(role: .destructive) {
                                    Task { await delete(document: document) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await delete(document: document) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    tagEditorDocument = document
                                } label: {
                                    Label("Tags", systemImage: "tag")
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    Task { await share(document: document) }
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(theme.theme.backgroundColor)
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
            if !documentService.documents.isEmpty {
                Menu {
                    Button(action: { selectedTrip = nil }) {
                        Label("All Trips", systemImage: selectedTrip == nil ? "checkmark" : "")
                    }
                    ForEach(documentService.availableTripNames(), id: \.self) { trip in
                        Button(action: { selectedTrip = trip }) {
                            Label(trip, systemImage: selectedTrip == trip ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label(selectedTrip ?? "All Trips", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                presentImportMenu()
            } label: {
                Image(systemName: "plus")
            }
        }
    }
    
    // MARK: - Actions
    
    private func presentImportMenu() {
        let alert = UIAlertController(title: "Add Document", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Import from Files", style: .default) { _ in
            isShowingDocumentPicker = true
        })
        if VNDocumentCameraViewController.isSupported {
            alert.addAction(UIAlertAction(title: "Scan with Camera", style: .default) { _ in
                isShowingScanner = true
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let presenter = UIApplication.topMostViewController(), let popover = alert.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.maxY, width: 0, height: 0)
            popover.permittedArrowDirections = []
            presenter.present(alert, animated: true)
        } else {
            UIApplication.topMostViewController()?.present(alert, animated: true)
        }
    }
    
    private func handleDocumentPickerResult(_ result: Result<URL, Error>) {
        isShowingDocumentPicker = false
        switch result {
        case .success(let url):
            let title = url.deletingPathExtension().lastPathComponent
            pendingDocument = PendingDocumentContext(
                source: .imported(url),
                title: title,
                tripName: selectedTrip ?? ""
            )
        case .failure(let error):
            if let importError = error as? DocumentImportError, importError == .cancelled {
                return
            }
            presentError(error, retry: nil)
        }
    }
    
    private func handleScannerResult(_ result: Result<DocumentScannerResult, Error>) {
        isShowingScanner = false
        switch result {
        case .success(let scan):
            pendingDocument = PendingDocumentContext(
                source: .scanned(scan),
                title: scan.suggestedTitle,
                tripName: selectedTrip ?? ""
            )
        case .failure(let error):
            if let importError = error as? DocumentImportError, importError == .cancelled {
                return
            }
            presentError(error, retry: nil)
        }
    }
    
    private func handleIntakeSave(_ context: PendingDocumentContext) {
        Task {
            do {
                switch context.source {
                case .imported(let url):
                    _ = try await documentService.addImportedDocument(from: url, title: context.title, tripName: context.tripName, tags: context.tags)
                case .scanned(let result):
                    _ = try await documentService.addScannedDocument(images: result.images, suggestedTitle: context.title, tripName: context.tripName, tags: context.tags)
                }
                pendingDocument = nil
            } catch {
                pendingDocument = context
                presentError(error, retry: .resumeIntake(context))
            }
        }
    }
    
    private func delete(document: DocumentAsset) async {
        do {
            try await documentService.delete(document)
        } catch {
            presentError(error, retry: .delete(document))
        }
    }
    
    private func updateTags(for document: DocumentAsset, tags: [String]) async {
        do {
            try await documentService.updateTags(for: document, tags: tags)
        } catch {
            presentError(error, retry: .updateTags(document, tags))
        }
    }
    
    private func recalculateMetadata(for document: DocumentAsset) async {
        do {
            try await documentService.recalculateMetadata(for: document)
        } catch {
            presentError(error, retry: .recalculate(document))
        }
    }
    
    private func share(document: DocumentAsset) async {
        let url = await documentService.documentURL(for: document)
        shareURL = url
        isPresentingShareSheet = true
    }
    
    private func refreshDocuments() async {
        await documentService.refresh()
    }
    
    // MARK: - Helpers
    
    private var filteredDocuments: [DocumentAsset] {
        documentService.documents.filter { $0.matchesTrip(selectedTrip) }
    }
    
    private var groupedDocuments: [DocumentTripGroup] {
        let groups = Dictionary(grouping: filteredDocuments) { $0.displayTripName }
        return groups.keys
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { key in
                let documents = groups[key]?.sorted(by: { $0.updatedAt > $1.updatedAt }) ?? []
                return DocumentTripGroup(title: key, documents: documents)
            }
    }
    
    private func presentError(_ error: Error, retry: RetryAction?) {
        alertContext = DocumentErrorContext(message: error.localizedDescription, retryAction: retry)
    }
    
    private func handleRetry(_ action: RetryAction) {
        switch action {
        case .resumeIntake(let context):
            pendingDocument = context
        case .delete(let document):
            Task { await delete(document: document) }
        case .updateTags(let document, let tags):
            Task { await updateTags(for: document, tags: tags) }
        case .recalculate(let document):
            Task { await recalculateMetadata(for: document) }
        case .refresh:
            Task { await refreshDocuments() }
        }
    }
}

// MARK: - Supporting Models

private struct DocumentTripGroup: Identifiable {
    let id = UUID()
    let title: String
    let documents: [DocumentAsset]
}

private struct DocumentErrorContext: Identifiable {
    let id = UUID()
    let message: String
    let retryAction: RetryAction?
}

private enum RetryAction {
    case resumeIntake(PendingDocumentContext)
    case delete(DocumentAsset)
    case updateTags(DocumentAsset, [String])
    case recalculate(DocumentAsset)
    case refresh
}

private struct DocumentListRow: View {
    let document: DocumentAsset
    @EnvironmentObject private var theme: AppEnvironment
    
    private var metadata: DocumentMetadata { document.metadata }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: document.kind.iconName)
                    .font(.title3)
                    .foregroundColor(theme.theme.primaryColor)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(document.kind.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(document.updatedAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if metadata.hasMetadata {
                HStack(spacing: 12) {
                    if let date = metadata.primaryDate {
                        Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                    }
                    if let code = metadata.confirmationCodes.first {
                        Label(code, systemImage: "character.textbox")
                            .font(.caption)
                    }
                }
            }
            if !document.normalizedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(document.normalizedTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(theme.theme.primaryColor.opacity(0.15)))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct UnsupportedScannerView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Document scanning is not supported on this device.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

#if DEBUG
struct DocsView_Previews: PreviewProvider {
    static var previews: some View {
        let container = DependencyContainer()
        let documentService = DocumentService(initialDocuments: [DocumentAsset.sample], shouldAutoRefresh: false)
        return DocsView()
            .environmentObject(container.appEnvironment)
            .environmentObject(documentService)
    }
}
#endif
