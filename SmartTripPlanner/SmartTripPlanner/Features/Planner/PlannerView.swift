import SwiftUI

struct PlannerView: View {
    @EnvironmentObject var container: DependencyContainer
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                    
                    VStack(spacing: 16) {
                        Text("Events for \(selectedDate.formatted(date: .long, time: .omitted))")
                            .font(.headline)
                        
                        Text("No events scheduled")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .navigationTitle("Planner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addEvent) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    private func addEvent() {
    }
}

#Preview {
    PlannerView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}
