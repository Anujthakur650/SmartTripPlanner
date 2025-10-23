import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var container: DependencyContainer
    @State private var position: MapCameraPosition = .automatic
    
    var body: some View {
        NavigationStack {
            Map(position: $position) {
            }
            .navigationTitle("Map")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: centerMap) {
                        Image(systemName: "location.fill")
                    }
                }
            }
        }
    }
    
    private func centerMap() {
    }
}

#Preview {
    MapView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}
