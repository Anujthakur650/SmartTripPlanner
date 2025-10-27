import SwiftUI

struct AssociationEditorView: View {
    let place: Place
    var onSave: (String, Date?, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var tripName: String = ""
    @State private var includeDate: Bool = false
    @State private var dayPlanDate: Date = .now
    @State private var bookmarked: Bool = true
    
    init(place: Place, onSave: @escaping (String, Date?, Bool) -> Void) {
        self.place = place
        self.onSave = onSave
        _tripName = State(initialValue: place.association?.tripName ?? "")
        if let day = place.association?.dayPlanDate {
            _includeDate = State(initialValue: true)
            _dayPlanDate = State(initialValue: day)
        }
        _bookmarked = State(initialValue: place.isBookmarked)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Trip or Day Plan", text: $tripName)
                    Toggle("Include day plan", isOn: $includeDate.animation())
                    if includeDate {
                        DatePicker("Day", selection: $dayPlanDate, displayedComponents: .date)
                    }
                }
                Section("Bookmark") {
                    Toggle("Bookmark this place", isOn: $bookmarked)
                }
            }
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(tripName, includeDate ? dayPlanDate : nil, bookmarked)
                        dismiss()
                    }
                }
            }
        }
    }
}
