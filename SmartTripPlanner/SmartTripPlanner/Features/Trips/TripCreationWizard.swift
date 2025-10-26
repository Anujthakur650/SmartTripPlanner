import SwiftUI

struct TripCreationWizard: View {
    enum Step: Int, CaseIterable {
        case basics
        case destinations
        case participants
        case travel
        
        var title: String {
            switch self {
            case .basics: return "Basics"
            case .destinations: return "Destinations"
            case .participants: return "Participants"
            case .travel: return "Travel"
            }
        }
    }
    
    @Binding var draft: TripDraft
    let mode: TripsViewModel.DraftMode
    var onCancel: () -> Void
    var onSave: () -> Void
    
    @State private var step: Step = .basics
    @State private var validationMessage: String?
    @EnvironmentObject private var appEnvironment: AppEnvironment
    
    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .basics:
                    basicsStep
                case .destinations:
                    destinationsStep
                case .participants:
                    participantsStep
                case .travel:
                    travelStep
                }
                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(mode == .create ? "New Trip" : "Edit Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(step == .travel ? "Save" : "Next") {
                        handleNextAction()
                    }
                    .disabled(step == .travel && !canSave)
                }
            }
        }
    }
    
    private var basicsStep: some View {
        Section("Trip Details") {
            TextField("Trip name", text: $draft.name)
            DatePicker("Start date", selection: $draft.startDate, displayedComponents: [.date])
            DatePicker("End date", selection: $draft.endDate, in: draft.startDate...Date.distantFuture, displayedComponents: [.date])
            TextEditor(text: $draft.notes)
                .frame(minHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2))
                )
                .padding(.vertical, 4)
        }
    }
    
    private var destinationsStep: some View {
        Section(header: Text("Destinations")) {
            if draft.destinations.isEmpty {
                ContentUnavailableView("No destinations", systemImage: "mappin.slash", description: Text("Add at least one destination"))
            }
            ForEach($draft.destinations) { $destination in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Destination name", text: $destination.name)
                    DatePicker("Arrival", selection: $destination.arrival, displayedComponents: [.date])
                    DatePicker("Departure", selection: $destination.departure, in: destination.arrival...Date.distantFuture, displayedComponents: [.date])
                    TextField("Notes", text: $destination.notes)
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        removeDestination(destination.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete { indexSet in
                draft.destinations.remove(atOffsets: indexSet)
            }
            Button {
                let newDestination = TripDestinationDraft(name: "", arrival: draft.startDate, departure: draft.endDate, notes: "")
                draft.destinations.append(newDestination)
            } label: {
                Label("Add Destination", systemImage: "plus")
            }
        }
    }
    
    private var participantsStep: some View {
        Section("Participants") {
            if draft.participants.isEmpty {
                ContentUnavailableView("No participants", systemImage: "person.2.slash", description: Text("Add travel companions"))
            }
            ForEach($draft.participants) { $participant in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Name", text: $participant.name)
                    TextField("Contact", text: $participant.contact)
                        .keyboardType(.emailAddress)
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        removeParticipant(participant.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete { indexSet in
                draft.participants.remove(atOffsets: indexSet)
            }
            Button {
                draft.participants.append(TripParticipantDraft(name: "", contact: ""))
            } label: {
                Label("Add Participant", systemImage: "plus")
            }
        }
    }
    
    private var travelStep: some View {
        Section("Preferred Travel Modes") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)]) {
                ForEach(TripTravelMode.allCases) { mode in
                    Button {
                        toggleMode(mode)
                    } label: {
                        HStack {
                            Image(systemName: mode.systemImage)
                            Text(mode.displayName)
                        }
                        .font(.subheadline)
                        .foregroundColor(draft.preferredTravelModes.contains(mode) ? appEnvironment.theme.primaryColor : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(draft.preferredTravelModes.contains(mode) ? appEnvironment.theme.primaryColor.opacity(0.2) : Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        Section("Segments") {
            if draft.segments.isEmpty {
                ContentUnavailableView("No segments", systemImage: "list.bullet.rectangle", description: Text("Add itinerary segments"))
            }
            ForEach($draft.segments) { $segment in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Title", text: $segment.title)
                    TextField("Location", text: $segment.location)
                    Picker("Type", selection: $segment.segmentType) {
                        ForEach(TripSegmentType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    Picker("Travel Mode", selection: Binding<TripTravelMode?>(get: {
                        segment.travelMode
                    }, set: { newValue in
                        segment.travelMode = newValue
                    })) {
                        Text("None").tag(Optional<TripTravelMode>.none)
                        ForEach(TripTravelMode.allCases) { mode in
                            Text(mode.displayName).tag(Optional(mode))
                        }
                    }
                    DatePicker("Start", selection: $segment.startDate)
                        .onChange(of: segment.startDate) { newValue in
                            if let end = segment.endDate, end < newValue {
                                segment.endDate = newValue
                            }
                        }
                    DatePicker("End", selection: Binding(get: {
                        segment.endDate ?? segment.startDate
                    }, set: { newValue in
                        if newValue < segment.startDate {
                            segment.endDate = segment.startDate
                        } else {
                            segment.endDate = newValue
                        }
                    }), displayedComponents: [.date, .hourAndMinute])
                    TextField("Notes", text: $segment.notes)
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        removeSegment(segment.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete { indexSet in
                draft.segments.remove(atOffsets: indexSet)
            }
            Button {
                let segment = TripSegmentDraft(title: "New Segment", notes: "", location: "", startDate: draft.startDate, endDate: draft.startDate, segmentType: .activity, travelMode: nil)
                draft.segments.append(segment)
            } label: {
                Label("Add Segment", systemImage: "plus")
            }
        }
    }
    
    private var canSave: Bool {
        !draft.trimmedName.isEmpty && !draft.makeDestinations().isEmpty && draft.startDate <= draft.endDate
    }
    
    private func handleNextAction() {
        validationMessage = nil
        switch step {
        case .basics:
            guard !draft.trimmedName.isEmpty else {
                validationMessage = "Add a trip name to continue."
                return
            }
            proceedToNext()
        case .destinations:
            guard !draft.makeDestinations().isEmpty else {
                validationMessage = "Add at least one destination."
                return
            }
            proceedToNext()
        case .participants:
            proceedToNext()
        case .travel:
            onSave()
        }
    }
    
    private func proceedToNext() {
        if let nextStep = Step(rawValue: step.rawValue + 1) {
            step = nextStep
        }
    }
    
    private func removeDestination(_ id: UUID) {
        draft.destinations.removeAll { $0.id == id }
    }
    
    private func removeParticipant(_ id: UUID) {
        draft.participants.removeAll { $0.id == id }
    }
    
    private func removeSegment(_ id: UUID) {
        draft.segments.removeAll { $0.id == id }
    }
    
    private func toggleMode(_ mode: TripTravelMode) {
        if draft.preferredTravelModes.contains(mode) {
            draft.preferredTravelModes.remove(mode)
        } else {
            draft.preferredTravelModes.insert(mode)
        }
    }
}
