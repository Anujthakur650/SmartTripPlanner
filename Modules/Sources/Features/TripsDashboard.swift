import Foundation
import SwiftUI
import Core
import Services
import UIComponents

public struct TripsDashboard: View {
    private let registry: ServiceRegistry

    @State private var headline: String = ""

    public init(registry: ServiceRegistry) {
        self.registry = registry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("SmartTripPlanner")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            if !headline.isEmpty {
                Text(headline)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Button("Plan Next Trip") {}
                .buttonStyle(PrimaryButtonStyle(theme: registry.environment.theme))
        }
        .padding(24)
        .task {
            await fetchHeadline()
        }
    }

    private func fetchHeadline() async {
        do {
            let conditions = try await registry.weatherService.currentConditions(for: "Cupertino")
            await MainActor.run {
                headline = conditions
            }
        } catch {
            await MainActor.run {
                headline = "Weather unavailable"
            }
        }
    }
}
