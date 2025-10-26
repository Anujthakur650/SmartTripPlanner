import Foundation
import GoogleSignIn
import UIKit

@MainActor
class EmailService: ObservableObject {
    @Published var isSignedIn = false
    @Published var userEmail: String?
    @Published private(set) var parsedReservations: [TravelReservation] = []
    @Published private(set) var tripsFromEmails: [Trip] = []
    
    private let gmailClient: GmailClientProtocol
    private let reservationParser = TravelReservationParser()
    private let syncService: SyncService?
    
    init(gmailClient: GmailClientProtocol = GmailClient(), syncService: SyncService? = nil) {
        self.gmailClient = gmailClient
        self.syncService = syncService
    }
    
    func signIn() async throws {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "EmailService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller"])
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        isSignedIn = true
        userEmail = result.user.profile?.email
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        userEmail = nil
        parsedReservations = []
        tripsFromEmails = []
    }
    
    func fetchEmails() async throws -> [EmailMessage] {
        guard isSignedIn else {
            throw NSError(domain: "EmailService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        
        let messages = try await gmailClient.fetchRecentMessages()
        var collectedReservations: [TravelReservation] = []
        var mappedTrips: [Trip] = []
        
        for message in messages {
            let reservations = reservationParser.parse(emailBody: message.body, subject: message.subject) ?? []
            collectedReservations.append(contentsOf: reservations)
            for reservation in reservations {
                if let trip = trip(from: reservation) {
                    mappedTrips.append(trip)
                }
            }
        }
        
        parsedReservations = collectedReservations
        tripsFromEmails = mappedTrips
        
        if let syncService {
            for reservation in collectedReservations {
                try? await syncService.syncToCloud(data: reservation, recordType: "TravelReservation", recordID: reservation.id.uuidString)
            }
            for trip in mappedTrips {
                try? await syncService.syncToCloud(data: trip, recordType: "Trip", recordID: trip.id.uuidString)
            }
        }
        
        return messages
    }
    
    private func trip(from reservation: TravelReservation) -> Trip? {
        switch reservation.type {
        case .flight:
            guard let startDate = reservation.startDate else { return nil }
            let endDate = reservation.endDate ?? startDate
            let destination = reservation.destinationCode ?? reservation.locationName ?? "Flight"
            var titleComponents: [String] = []
            if let provider = reservation.provider {
                titleComponents.append(provider)
            }
            if let confirmation = reservation.confirmationNumber {
                titleComponents.append("#\(confirmation)")
            }
            if let destinationCode = reservation.destinationCode {
                titleComponents.append(destinationCode)
            }
            let tripName = titleComponents.isEmpty ? "Flight" : titleComponents.joined(separator: " · ")
            var itineraryItems: [ItineraryItem] = []
            if let origin = reservation.originCode {
                itineraryItems.append(ItineraryItem(title: "Depart \(origin)", startTime: startDate))
            } else {
                itineraryItems.append(ItineraryItem(title: "Flight Departure", startTime: startDate))
            }
            if let arrival = reservation.destinationCode, let arrivalDate = reservation.endDate {
                itineraryItems.append(ItineraryItem(title: "Arrive \(arrival)", startTime: arrivalDate))
            }
            return Trip(name: tripName, destination: destination, startDate: startDate, endDate: endDate, itineraryItems: itineraryItems)
        case .hotel:
            guard let checkIn = reservation.startDate else { return nil }
            let checkOut = reservation.endDate ?? checkIn
            let name = reservation.provider ?? "Hotel Stay"
            let destination = reservation.locationName ?? reservation.provider ?? "Hotel"
            var itineraryItems = [ItineraryItem(title: "Check-in", startTime: checkIn)]
            if let end = reservation.endDate {
                itineraryItems.append(ItineraryItem(title: "Check-out", startTime: end))
            }
            return Trip(name: name, destination: destination, startDate: checkIn, endDate: checkOut, itineraryItems: itineraryItems)
        }
    }
}

protocol GmailClientProtocol {
    func fetchRecentMessages() async throws -> [EmailMessage]
}

struct GmailClient: GmailClientProtocol {
    func fetchRecentMessages() async throws -> [EmailMessage] {
        []
    }
}

struct EmailMessage: Identifiable {
    let id: String
    let subject: String
    let from: String
    let date: Date
    let body: String
}
