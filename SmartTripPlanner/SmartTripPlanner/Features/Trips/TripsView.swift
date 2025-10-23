import SwiftUI

// MARK: - Trip Domain Models

struct TripSegment: Identifiable, Codable, Equatable {
    let id: UUID
    let type: TripSegmentType
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let metadata: [String: String]
    let sourceMessageIDs: [String]
    
    init(
        id: UUID = UUID(),
        type: TripSegmentType,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String?,
        metadata: [String: String] = [:],
        sourceMessageIDs: [String] = []
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.metadata = metadata
        self.sourceMessageIDs = sourceMessageIDs
    }
    
    var durationDescription: String {
        let start = startDate.formatted(date: .abbreviated, time: .shortened)
        let end = endDate.formatted(date: .abbreviated, time: .shortened)
        return "\(start) → \(end)"
    }
    
    var subtitle: String? {
        switch type {
        case .flight:
            let origin = metadata["origin"] ?? metadata["departureAirport"] ?? metadata["from"]
            let destination = metadata["destination"] ?? metadata["arrivalAirport"] ?? metadata["to"]
            if let origin = origin, let destination = destination {
                return "\(origin) → \(destination)"
            }
            return metadata["route"]
        case .hotel:
            guard let checkIn = metadata["checkIn"], let checkOut = metadata["checkOut"] else {
                return nil
            }
            return "Check-in \(checkIn) • Check-out \(checkOut)"
        case .rental:
            guard let pickUp = metadata["pickup"], let dropOff = metadata["dropoff"] else {
                return nil
            }
            return "Pick-up \(pickUp) • Drop-off \(dropOff)"
        case .event:
            return metadata["summary"]
        }
    }
    
    var fingerprint: String {
        let iso = ISO8601DateFormatter()
        let start = iso.string(from: startDate)
        let end = iso.string(from: endDate)
        return "\(type.rawValue)|\(title)|\(start)|\(end)|\(location ?? "-")"
    }
}

enum TripSegmentType: String, Codable, CaseIterable {
    case flight
    case hotel
    case rental
    case event
    
    var symbolName: String {
        switch self {
        case .flight: "airplane"
        case .hotel: "bed.double"
        case .rental: "car"
        case .event: "calendar"
        }
    }
    
    var displayName: String {
        switch self {
        case .flight: "Flight"
        case .hotel: "Hotel"
        case .rental: "Rental"
        case .event: "Event"
        }
    }
    
    var tintColor: Color {
        switch self {
        case .flight: .blue
        case .hotel: .purple
        case .rental: .green
        case .event: .orange
        }
    }
}

struct TripImportCandidate: Identifiable, Equatable {
    let id: UUID
    let tripName: String
    let destination: String
    let segments: [TripSegment]
    let sourceMessageIDs: [String]
    
    init(id: UUID = UUID(), tripName: String, destination: String, segments: [TripSegment], sourceMessageIDs: [String]) {
        self.id = id
        self.tripName = tripName
        self.destination = destination
        self.segments = segments
        self.sourceMessageIDs = sourceMessageIDs
    }
    
    var startDate: Date {
        segments.map(\.startDate).min() ?? Date()
    }
    
    var endDate: Date {
        segments.map(\.endDate).max() ?? Date()
    }
    
    var summary: String {
        let counts = Dictionary(grouping: segments, by: \.type).mapValues { $0.count }
        return TripSegmentType.allCases
            .compactMap { type -> String? in
                guard let count = counts[type] else { return nil }
                return "\(count) \(type.displayName.lowercased())\(count > 1 ? "s" : "")"
            }
            .joined(separator: ", ")
    }
}

struct Trip: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var segments: [TripSegment]
    var sourceMessageIDs: [String]
    
    init(
        id: UUID = UUID(),
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        segments: [TripSegment] = [],
        sourceMessageIDs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.segments = segments
        self.sourceMessageIDs = sourceMessageIDs
    }
    
    mutating func merge(with candidate: TripImportCandidate) {
        addSegments(candidate.segments)
        destination = destination == "Destination" ? candidate.destination : destination
        startDate = min(startDate, candidate.startDate)
        endDate = max(endDate, candidate.endDate)
        sourceMessageIDs = Array(Set(sourceMessageIDs + candidate.sourceMessageIDs)).sorted()
    }
    
    mutating func addSegments(_ newSegments: [TripSegment]) {
        var existingFingerprints = Set(segments.map(\.fingerprint))
        var combined = segments
        for segment in newSegments where !existingFingerprints.contains(segment.fingerprint) {
            combined.append(segment)
            existingFingerprints.insert(segment.fingerprint)
        }
        segments = combined.sorted(by: { $0.startDate < $1.startDate })
    }
    
    var dateRangeDescription: String {
        "\(startDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))"
    }
}

// MARK: - Trips View

struct TripsView: View {
    @EnvironmentObject var container: DependencyContainer
    @State private var trips: [Trip] = []
    @State private var isImporting = false
    @State private var importCandidates: [TripImportCandidate] = []
    @State private var isPresentingReview = false
    @State private var importError: String?
    @State private var isShowingErrorAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if trips.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "suitcase.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        
                        Text("No trips yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Start planning your next adventure")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(trips) { trip in
                            TripCard(trip: trip)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isImporting {
                        ProgressView()
                    } else {
                        Button {
                            importFromGmail()
                        } label: {
                            Image(systemName: "tray.and.arrow.down")
                        }
                        .accessibilityLabel("Import from Gmail")
                    }
                    
                    Button(action: addTrip) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add trip")
                }
            }
            .alert("Import Error", isPresented: $isShowingErrorAlert, presenting: importError) { _ in
                Button("OK", role: .cancel) {
                    importError = nil
                }
            } message: { message in
                Text(message)
            }
            .sheet(isPresented: $isPresentingReview, onDismiss: { importCandidates.removeAll() }) {
                TripImportReviewView(
                    candidates: $importCandidates,
                    existingTrips: trips,
                    onCreateTrip: { candidate in
                        withAnimation {
                            createTrip(from: candidate)
                        }
                    },
                    onMerge: { candidate, trip in
                        withAnimation {
                            merge(candidate: candidate, into: trip)
                        }
                    },
                    onDismissCandidate: { candidate in
                        dismiss(candidate: candidate)
                    }
                )
                .environmentObject(container.appEnvironment)
            }
        }
    }
    
    private func importFromGmail() {
        guard !isImporting else { return }
        isImporting = true
        importError = nil
        Task {
            do {
                try await container.emailService.ensureSignedIn()
                let candidates = try await container.emailService.fetchTravelImports()
                await MainActor.run {
                    self.importCandidates = candidates
                    self.isPresentingReview = !candidates.isEmpty
                }
            } catch {
                await MainActor.run {
                    importError = error.localizedDescription
                    isShowingErrorAlert = true
                }
            }
            await MainActor.run {
                isImporting = false
            }
        }
    }
    
    private func addTrip() {
        let newTrip = Trip(
            name: "New Trip",
            destination: "Destination",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7),
            segments: []
        )
        trips.append(newTrip)
    }
    
    private func createTrip(from candidate: TripImportCandidate) {
        var trip = Trip(
            name: candidate.tripName,
            destination: candidate.destination,
            startDate: candidate.startDate,
            endDate: candidate.endDate,
            segments: candidate.segments,
            sourceMessageIDs: candidate.sourceMessageIDs
        )
        trip.segments.sort(by: { $0.startDate < $1.startDate })
        trips.append(trip)
        removeCandidate(candidate)
        Task { try? await container.emailService.markProcessed(for: candidate) }
    }
    
    private func merge(candidate: TripImportCandidate, into trip: Trip) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        var updatedTrip = trips[index]
        updatedTrip.merge(with: candidate)
        trips[index] = updatedTrip
        removeCandidate(candidate)
        Task { try? await container.emailService.markProcessed(for: candidate) }
    }
    
    private func dismiss(candidate: TripImportCandidate) {
        removeCandidate(candidate)
        container.emailService.dismiss(candidate: candidate)
    }
    
    private func removeCandidate(_ candidate: TripImportCandidate) {
        importCandidates.removeAll(where: { $0.id == candidate.id })
        if importCandidates.isEmpty {
            isPresentingReview = false
        }
    }
}

// MARK: - Trip Card & Segment Views

struct TripCard: View {
    let trip: Trip
    @EnvironmentObject var theme: AppEnvironment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(trip.name)
                .font(.headline)
            
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(theme.theme.primaryColor)
                Text(trip.destination)
                    .font(.subheadline)
            }
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(theme.theme.secondaryColor)
                Text(trip.dateRangeDescription)
                    .font(.caption)
            }
            
            if !trip.segments.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(trip.segments.prefix(3)) { segment in
                        TripSegmentRow(segment: segment)
                    }
                    if trip.segments.count > 3 {
                        Text("+ \(trip.segments.count - 3) more segments")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle(theme: theme.theme)
    }
}

struct TripSegmentRow: View {
    let segment: TripSegment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: segment.type.symbolName)
                .foregroundColor(segment.type.tintColor)
                .font(.title3)
                .padding(6)
                .background(segment.type.tintColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(segment.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if let subtitle = segment.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(segment.durationDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Import Review

struct TripImportReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var candidates: [TripImportCandidate]
    let existingTrips: [Trip]
    let onCreateTrip: (TripImportCandidate) -> Void
    let onMerge: (TripImportCandidate, Trip) -> Void
    let onDismissCandidate: (TripImportCandidate) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                if candidates.isEmpty {
                    ContentUnavailableView("No new confirmations", systemImage: "envelope.open", description: Text("Everything is up to date. Check back later for new travel emails."))
                } else {
                    ForEach(candidates) { candidate in
                        Section(header: Text(candidate.tripName).font(.headline)) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(candidate.summary)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                ForEach(candidate.segments) { segment in
                                    TripSegmentRow(segment: segment)
                                }
                                
                                HStack {
                                    Button("Create Trip") {
                                        onCreateTrip(candidate)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    
                                    Menu {
                                        if existingTrips.isEmpty {
                                            Text("No existing trips available")
                                        } else {
                                            ForEach(existingTrips) { trip in
                                                Button(trip.name) {
                                                    onMerge(candidate, trip)
                                                }
                                            }
                                        }
                                    } label: {
                                        Label("Merge", systemImage: "arrow.triangle.merge")
                                    }
                                    .disabled(existingTrips.isEmpty)
                                    
                                    Spacer()
                                    
                                    Button("Dismiss", role: .destructive) {
                                        onDismissCandidate(candidate)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Review Imports")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TripsView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}
