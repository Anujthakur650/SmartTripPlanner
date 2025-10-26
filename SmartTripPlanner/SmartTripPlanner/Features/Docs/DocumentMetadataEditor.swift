import SwiftUI

struct DocumentMetadataEditor: View {
    let state: DocsViewModel.MetadataEditorState
    var onSave: (TravelDocument.Metadata) -> Void
    var onCancel: () -> Void
    
    @State private var metadata: TravelDocument.Metadata
    @State private var tagsText: String
    
    init(state: DocsViewModel.MetadataEditorState, onSave: @escaping (TravelDocument.Metadata) -> Void, onCancel: @escaping () -> Void) {
        self.state = state
        self.onSave = onSave
        self.onCancel = onCancel
        _metadata = State(initialValue: state.metadata)
        _tagsText = State(initialValue: state.metadata.tags.joined(separator: ", "))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Document Info") {
                    TextField("Title", text: $metadata.title)
                        .textInputAutocapitalization(.words)
                    Picker("Type", selection: $metadata.type) {
                        ForEach(TravelDocument.DocumentType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: $metadata.notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
                Section("Tags") {
                    TextField("Tags (comma separated)", text: $tagsText)
                }
            }
            .navigationTitle(state.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        metadata.tags = normalizedTags()
                        onSave(metadata)
                    }
                    .disabled(metadata.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func normalizedTags() -> [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
