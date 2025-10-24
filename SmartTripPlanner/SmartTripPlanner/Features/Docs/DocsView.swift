import SwiftUI

struct DocsView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    @State private var documents: [TravelDocument] = TravelDocument.sampleData
    
    private var theme: Theme { appEnvironment.theme }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    SectionHeader(
                        title: "Travel documents",
                        caption: "Secure and accessible wherever you roam"
                    )
                    if let expiring = documents.first(where: { $0.status == .expiresSoon }) {
                        ErrorSurface(
                            title: "Check \(expiring.name)",
                            message: "Expires soon. Renew or upload the latest copy before your departure.",
                            actionTitle: "Review",
                            action: {}
                        )
                    }
                    if documents.isEmpty {
                        EmptyStateView(
                            icon: "folder",
                            title: "No documents yet",
                            message: "Keep passports, tickets, and insurance in one calm space.",
                            actionTitle: "Add a document",
                            action: addDocument
                        )
                    } else {
                        Card(style: .standard) {
                            VStack(spacing: theme.spacing.m) {
                                ForEach(documents) { document in
                                    ListRow(
                                        icon: document.type.icon,
                                        title: document.name,
                                        subtitle: document.type.description,
                                        tagText: document.status.label,
                                        tagStyle: document.status.tagStyle
                                    ) {
                                        Image(systemName: "chevron.right")
                                    }
                                }
                            }
                        }
                        AppButton(title: "Upload another", style: .tinted, action: addDocument)
                    }
                }
                .padding(.horizontal, theme.spacing.l)
                .padding(.vertical, theme.spacing.l)
            }
            .background(theme.colors.background.resolved(for: colorScheme))
            .navigationTitle("Documents")
        }
    }
    
    private func addDocument() {
        let newDocument = TravelDocument(
            id: UUID(),
            name: "Boarding Pass",
            type: .ticket,
            status: .valid
        )
        documents.append(newDocument)
    }
}

struct TravelDocument: Identifiable {
    let id: UUID
    var name: String
    var type: DocumentType
    var status: Status
    
    enum DocumentType: CaseIterable {
        case passport
        case visa
        case ticket
        case insurance
        case reservation
        case other
        
        var icon: String {
            switch self {
            case .passport: return "person.text.rectangle"
            case .visa: return "rectangle.and.pencil.and.ellipsis"
            case .ticket: return "ticket"
            case .insurance: return "shield.checkered"
            case .reservation: return "calendar.badge.clock"
            case .other: return "doc"
            }
        }
        
        var description: String {
            switch self {
            case .passport: return "Primary ID and citizenship"
            case .visa: return "Entry permissions and approvals"
            case .ticket: return "Flights, trains, or attractions"
            case .insurance: return "Policies and emergency info"
            case .reservation: return "Hotels, dining, tours"
            case .other: return "Miscellaneous travel files"
            }
        }
    }
    
    enum Status {
        case valid
        case expiresSoon
        case missing
        
        var label: String {
            switch self {
            case .valid: return "Ready"
            case .expiresSoon: return "Renew soon"
            case .missing: return "Upload"
            }
        }
        
        var tagStyle: TagLabel.Style {
            switch self {
            case .valid: return .success
            case .expiresSoon: return .warning
            case .missing: return .danger
            }
        }
    }
    
    static let sampleData: [TravelDocument] = [
        TravelDocument(
            id: UUID(),
            name: "Passport • Alex",
            type: .passport,
            status: .expiresSoon
        ),
        TravelDocument(
            id: UUID(),
            name: "Flight QR 38",
            type: .ticket,
            status: .valid
        ),
        TravelDocument(
            id: UUID(),
            name: "Hotel Splendido",
            type: .reservation,
            status: .valid
        ),
        TravelDocument(
            id: UUID(),
            name: "Travel Insurance",
            type: .insurance,
            status: .missing
        )
    ]
}

#Preview {
    DocsView()
        .environmentObject(AppEnvironment())
}
