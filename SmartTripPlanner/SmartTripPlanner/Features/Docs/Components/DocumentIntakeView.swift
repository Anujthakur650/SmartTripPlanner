import SwiftUI

struct DocumentIntakeView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var tripName: String
    @State private var tagsText: String
    
    let context: PendingDocumentContext
    let existingTrips: [String]
    let onSave: (PendingDocumentContext) -> Void
    
    init(context: PendingDocumentContext, existingTrips: [String], onSave: @escaping (PendingDocumentContext) -> Void) {
        self.context = context
        self.existingTrips = existingTrips
        self.onSave = onSave
        _title = State(initialValue: context.title)
        _tripName = State(initialValue: context.tripName)
        _tagsText = State(initialValue: context.tags.joined(separator: ", "))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Document") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    TextField("Trip (optional)", text: $tripName)
                    if !existingTrips.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(existingTrips, id: \.self) { trip in
                                    Button {
                                        tripName = trip
                                    } label: {
                                        Text(trip)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                Section("Tags") {
                    TextField("Comma separated", text: $tagsText)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("Add Document")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let tags = tagsText
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        var updated = context
                        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? context.title : title
                        updated.tripName = tripName
                        updated.tags = tags
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
