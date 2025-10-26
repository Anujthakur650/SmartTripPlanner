import SwiftUI
import UIKit
import VisionKit

struct DocsView: View {
    @EnvironmentObject var container: DependencyContainer
    @StateObject private var viewModel = DocsViewModel()
    @State private var isPresentingScanner = false
    @State private var isPresentingEditor = false
    @State private var selectedDocument: TravelDocument?
    @State private var metadataDraft = TravelDocumentMetadata(title: "", type: .other)
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.documents.isEmpty {
                    ContentUnavailableView(
                        "No Documents",
                        systemImage: "folder",
                        description: Text("Add travel documents like passports, tickets, and reservations")
                    )
                } else {
                    ForEach(viewModel.documents) { document in
                        Button {
                            selectedDocument = document
                            metadataDraft = document.metadata
                            isPresentingEditor = true
                        } label: {
                            DocumentRow(document: document)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteDocuments)
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.lastError != nil {
                    errorBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding()
                }
            }
            .refreshable {
                viewModel.refresh()
            }
            .navigationTitle("Documents")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            addPlaceholderDocument()
                        } label: {
                            Label("Add Placeholder", systemImage: "doc.badge.plus")
                        }
                        Button {
                            isPresentingScanner = true
                        } label: {
                            Label("Scan Document", systemImage: "camera.viewfinder")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingScanner) {
                DocumentScannerContainer { result in
                    switch result {
                    case let .success(images):
                        Task {
                            await importScannedImages(images)
                        }
                    case let .failure(error):
                        viewModel.lastError = error
                    }
                }
            }
            .sheet(isPresented: $isPresentingEditor) {
                NavigationStack {
                    DocumentMetadataEditor(metadata: $metadataDraft)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    isPresentingEditor = false
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    if let selectedDocument {
                                        viewModel.update(documentId: selectedDocument.id) { metadata in
                                            metadata = metadataDraft
                                        }
                                    }
                                    isPresentingEditor = false
                                }
                                .disabled(metadataDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                }
            }
        }
    }
    
    private var errorBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Document Error")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.white)
                if let error = viewModel.lastError {
                    Text(error.localizedDescription)
                        .foregroundColor(.white.opacity(0.9))
                        .font(.caption)
                }
            }
            Spacer()
            Button {
                withAnimation {
                    viewModel.lastError = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func addPlaceholderDocument() {
        let metadata = TravelDocumentMetadata(title: "Sample Document", type: .other, notes: "Generated placeholder.")
        Task {
            await viewModel.importDocument(data: Data("Sample Document".utf8), metadata: metadata, preferredFilename: "SampleDocument.txt")
        }
    }
    
    private func importScannedImages(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        let pageSize = images.first?.size ?? CGSize(width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let data = renderer.pdfData { context in
            for image in images {
                context.beginPage()
                let drawRect = CGRect(origin: .zero, size: pageSize)
                image.draw(in: drawRect, blendMode: .normal, alpha: 1)
            }
        }
        let metadata = TravelDocumentMetadata(title: "Scanned Document", type: .other)
        await viewModel.importDocument(data: data, metadata: metadata, preferredFilename: "ScannedDocument.pdf")
    }
    
    private func deleteDocuments(at offsets: IndexSet) {
        for index in offsets {
            let document = viewModel.documents[index]
            viewModel.delete(documentId: document.id)
        }
    }
}

private struct DocumentScannerContainer: View {
    let completion: (Result<[UIImage], Error>) -> Void
    
    var body: some View {
        if DocumentScannerView.isSupported {
            DocumentScannerView { result in
                completion(result)
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text("Document scanning is not supported on this device.")
                    .multilineTextAlignment(.center)
                Button("Dismiss") {
                    completion(.success([]))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

struct DocumentRow: View {
    let document: TravelDocument
    @EnvironmentObject var theme: AppEnvironment
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: document.metadata.type.systemImage)
                .foregroundColor(theme.theme.primaryColor)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(document.metadata.title)
                    .font(.headline)
                if let reference = document.metadata.referenceNumber, !reference.isEmpty {
                    Label(reference, systemImage: "number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !document.metadata.tags.isEmpty {
                    Text(document.metadata.tags.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(theme.theme.secondaryColor)
                }
            }
            Spacer()
            Text(document.updatedAt, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DocsView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}
