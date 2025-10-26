import SwiftUI

struct TripDetailView: View {
    let trip: Trip
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @State private var isPresentingDeleteConfirmation = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        List {
            overviewSection
            destinationsSection
            participantsSection
            timelineSection
            notesSection
            sourceSection
            deleteSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(trip.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .confirmationDialog("Delete this trip?", isPresented: $isPresentingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                isPresentingDeleteConfirmation = false
                onDelete()
            }
            Button("Cancel", role: .cancel) {
                isPresentingDeleteConfirmation = false
            }
        } message: {
            Text("This action cannot be undone, but you can restore the trip immediately afterwards.")
        }
    }
    
    private var overviewSection: some View {
        Section("Overview") {
            VStack(alignment: .leading, spacing: 8) {
                Label("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                Label("Duration: \(trip.durationInDays) days", systemImage: "clock")
                if !trip.allTravelModes.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(trip.allTravelModes).sorted { $0.displayName < $1.displayName }, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.systemImage)
                                .font(.caption)
                                .padding(6)
                                .background(appEnvironment.theme.primaryColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundColor(appEnvironment.theme.primaryColor)
                }
            }
            .font(.subheadline)
        }
    }
    
    private var destinationsSection: some View {
        Section("Destinations") {
            if trip.destinations.isEmpty {
                ContentUnavailableView("No destinations", systemImage: "mappin.slash", description: Text("Add destinations to build an itinerary."))
            } else {
                ForEach(trip.destinations) { destination in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(destination.name)
                            .font(.headline)
                        Text("\(dayFormatter.string(from: destination.arrival)) → \(dayFormatter.string(from: destination.departure))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let notes = destination.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private var participantsSection: some View {
        Section("Participants") {
            if trip.participants.isEmpty {
                Text("No participants added")
                    .foregroundColor(.secondary)
            } else {
                ForEach(trip.participants) { participant in
                    VStack(alignment: .leading) {
                        Text(participant.name)
                            .font(.body)
                        if let contact = participant.contact, !contact.isEmpty {
                            Text(contact)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    private var timelineSection: some View {
        Section("Timeline") {
            if trip.segments.isEmpty {
                Text("No timeline segments yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(trip.segments) { segment in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            Image(systemName: icon(for: segment))
                                .foregroundColor(appEnvironment.theme.primaryColor)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(segment.title)
                                    .font(.body.weight(.semibold))
                                Text(segmentTimeRange(for: segment))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let location = segment.location, !location.isEmpty {
                                    Label(location, systemImage: "mappin")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let notes = segment.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }
    
    private var notesSection: some View {
        Section("Notes") {
            if let notes = trip.notes, !notes.isEmpty {
                Text(notes)
            } else {
                Text("No notes yet")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var sourceSection: some View {
        Section("Source") {
            HStack {
                Text("Origin")
                Spacer()
                Text(trip.source.kindTitle)
                    .foregroundColor(.secondary)
            }
            if let reference = trip.source.reference, !reference.isEmpty {
                HStack {
                    Text("Reference")
                    Spacer()
                    Text(reference)
                        .foregroundColor(.secondary)
                }
            }
            if let metadata = trip.source.metadata, !metadata.isEmpty {
                ForEach(metadata.keys.sorted(), id: \.self) { key in
                    HStack {
                        Text(key.capitalized)
                        Spacer()
                        Text(metadata[key] ?? "")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                isPresentingDeleteConfirmation = true
            } label: {
                Label("Delete Trip", systemImage: "trash")
            }
        }
    }
    
    private func icon(for segment: TripSegment) -> String {
        if let mode = segment.travelMode {
            return mode.systemImage
        }
        switch segment.segmentType {
        case .transport:
            return "arrowshape.turn.up.right"
        case .lodging:
            return "bed.double"
        case .activity:
            return "sparkles"
        case .note:
            return "note.text"
        }
    }
    
    private func segmentTimeRange(for segment: TripSegment) -> String {
        if let end = segment.endDate {
            return "\(dateFormatter.string(from: segment.startDate)) – \(dateFormatter.string(from: end))"
        }
        return dateFormatter.string(from: segment.startDate)
    }
}

private extension TripSource.Kind {
    var title: String {
        switch self {
        case .manual: return "Manual"
        case .ics: return "Calendar (ICS)"
        case .pkpass: return "Wallet Pass"
        case .template: return "Template"
        }
    }
}

private extension TripSource {
    var kindTitle: String {
        kind.title
    }
}
