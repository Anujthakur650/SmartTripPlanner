import SwiftUI

struct DocumentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let document: TravelDocument
    let fileURL: URL?
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()
    
    var body: some View {
        List {
            Section("Document") {
                HStack {
                    Label(document.type.displayName, systemImage: document.type.systemImage)
                        .symbolRenderingMode(.multicolor)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Created")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(document.formattedCreatedAt)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Updated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(document.formattedUpdatedAt)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(document.pageCount)")
                }
                if document.fileSize > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("File Size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(byteFormatter.string(fromByteCount: Int64(document.fileSize)))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Checksum")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(document.checksum)
                        .textSelection(.enabled)
                        .font(.footnote.monospaced())
                }
            }
            if !document.notes.isEmpty {
                Section("Notes") {
                    Text(document.notes)
                        .font(.body)
                }
            }
            if !document.tags.isEmpty {
                Section("Tags") {
                    WrappingTagsView(tags: document.tags)
                }
            }
            if let fileURL {
                Section("Actions") {
                    ShareLink(item: fileURL) {
                        Label("Share Document", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .navigationTitle(document.title)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

private struct WrappingTagsView: View {
    let tags: [String]
    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8, alignment: .leading)]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.2)))
            }
        }
    }
}
