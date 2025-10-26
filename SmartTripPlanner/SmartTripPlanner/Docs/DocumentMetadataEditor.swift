import SwiftUI

struct DocumentMetadataEditor: View {
    @Binding var metadata: TravelDocumentMetadata
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case title
        case note
        case tags
        case reference
    }
    
    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $metadata.title)
                    .focused($focusedField, equals: .title)
                Picker("Type", selection: $metadata.type) {
                    ForEach(TravelDocumentType.allCases) { type in
                        Label(type.displayName, systemImage: type.systemImage)
                            .tag(type)
                    }
                }
                TextField("Reference", text: Binding($metadata.referenceNumber, replacingNilWith: ""))
                    .focused($focusedField, equals: .reference)
            }
            
            Section("Trip Association") {
                TextField("Trip Name", text: Binding($metadata.tripName, replacingNilWith: ""))
                TextField("Trip ID", text: Binding(
                    get: {
                        metadata.tripId?.uuidString ?? ""
                    },
                    set: { newValue in
                        metadata.tripId = UUID(uuidString: newValue)
                    }
                ))
            }
            
            Section("Validity") {
                DatePicker("Valid From", selection: Binding($metadata.validFrom, defaultValue: Date()), displayedComponents: .date)
                DatePicker("Valid To", selection: Binding($metadata.validTo, defaultValue: Date().addingTimeInterval(86_400)), displayedComponents: .date)
            }
            
            Section("Tags & Notes") {
                TextField("Tags (comma separated)", text: Binding(
                    get: {
                        metadata.tags.joined(separator: ", ")
                    },
                    set: { newValue in
                        metadata.tags = newValue
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                    }
                ))
                .focused($focusedField, equals: .tags)
                TextEditor(text: Binding($metadata.notes, replacingNilWith: ""))
                    .frame(minHeight: 120)
                    .focused($focusedField, equals: .note)
            }
        }
        .navigationTitle("Document Details")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
    }
}

private extension Binding where Value == String? {
    init(_ source: Binding<String?>, replacingNilWith emptyValue: String) {
        self.init(get: {
            source.wrappedValue ?? emptyValue
        }, set: { newValue in
            source.wrappedValue = newValue.isEmpty ? nil : newValue
        })
    }
}

private extension Binding where Value == Date? {
    init(_ source: Binding<Date?>, defaultValue: Date) {
        self.init(get: {
            source.wrappedValue ?? defaultValue
        }, set: { newValue in
            source.wrappedValue = newValue
        })
    }
}

#Preview {
    NavigationStack {
        DocumentMetadataEditor(metadata: .constant(TravelDocumentMetadata(title: "Passport", type: .passport)))
    }
}
