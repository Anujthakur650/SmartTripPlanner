import SwiftUI

struct TagEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tagsText: String
    let title: String
    let onSave: ([String]) -> Void
    
    init(title: String, initialTags: [String], onSave: @escaping ([String]) -> Void) {
        self.title = title
        self.onSave = onSave
        _tagsText = State(initialValue: initialTags.joined(separator: ", "))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tags") {
                    TextField("Comma separated", text: $tagsText)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                }
                Section {
                    Text("Tags help you quickly find important documents like boarding passes and confirmations.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Tags")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let tags = tagsText
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        onSave(tags)
                        dismiss()
                    }
                    .disabled(tagsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
