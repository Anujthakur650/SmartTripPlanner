import SwiftUI
import UIKit

struct DocumentViewerView: View {
    @EnvironmentObject private var documentService: DocumentService
    @Environment(\.dismiss) private var dismiss
    
    let document: DocumentAsset
    
    @State private var fileURL: URL?
    @State private var isPresentingShare = false
    @State private var alertContext: DocumentAlertContext?
    
    var body: some View {
        NavigationStack {
            List {
                Section("Preview") {
                    preview
                        .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 400)
                        .frame(alignment: .center)
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                }
                metadataSection
                detailsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        Task { await presentShareSheet() }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button {
                        Task { await openExternally() }
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                }
            }
            .task {
                if fileURL == nil {
                    fileURL = await documentService.documentURL(for: document)
                }
            }
            .sheet(isPresented: $isPresentingShare) {
                if let fileURL {
                    ShareSheet(activityItems: [fileURL]) { _, _, _, error in
                        if let error {
                            alertContext = DocumentAlertContext(message: error.localizedDescription)
                        }
                    }
                }
            }
            .alert(item: $alertContext) { context in
                Alert(title: Text("Error"), message: Text(context.message), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    // MARK: - Preview
    
    @ViewBuilder
    private var preview: some View {
        Group {
            switch document.kind {
            case .pdf:
                if let fileURL {
                    PDFKitView(url: fileURL)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    ProgressView("Loading PDF…")
                }
            case .image:
                if let fileURL, let image = UIImage(contentsOfFile: fileURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    ContentUnavailableView("Image unavailable", systemImage: "photo")
                }
            case .pass, .unknown:
                VStack(spacing: 12) {
                    if let fileURL {
                        QuickLookPreview(url: fileURL)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        ProgressView()
                    }
                    Text("Open in an external app for the best experience.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Metadata
    
    @ViewBuilder
    private var metadataSection: some View {
        let metadata = document.metadata
        let tags = document.normalizedTags
        if metadata.hasMetadata || !tags.isEmpty {
            Section("Metadata") {
                if let summary = metadata.summary {
                    LabeledContent("Summary") {
                        Text(summary)
                    }
                }
                if let date = metadata.primaryDate {
                    LabeledContent("Date") {
                        Text(date.formatted(date: .long, time: .omitted))
                    }
                }
                if !metadata.confirmationCodes.isEmpty {
                    LabeledContent("Confirmation Codes") {
                        Text(metadata.confirmationCodes.joined(separator: ", "))
                    }
                }
                if !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    TagBadge(label: tag)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Trip") {
                Text(document.displayTripName)
            }
            LabeledContent("Type") {
                Text(document.kind.localizedDescription)
            }
            LabeledContent("Source") {
                Text(document.source == .scanned ? "Scanned" : "Imported")
            }
            LabeledContent("Size") {
                Text(document.formattedSize)
            }
            LabeledContent("Added") {
                Text(document.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            LabeledContent("Updated") {
                Text(document.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }
    
    // MARK: - Actions
    
    private func presentShareSheet() async {
        if fileURL == nil {
            fileURL = await documentService.documentURL(for: document)
        }
        guard fileURL != nil else { return }
        isPresentingShare = true
    }
    
    private func openExternally() async {
        if fileURL == nil {
            fileURL = await documentService.documentURL(for: document)
        }
        guard let fileURL else { return }
        ExternalDocumentOpener.open(url: fileURL)
    }
}

private struct DocumentAlertContext: Identifiable {
    let id = UUID()
    let message: String
}

private struct TagBadge: View {
    let label: String
    
    var body: some View {
        Text(label)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
    }
}
