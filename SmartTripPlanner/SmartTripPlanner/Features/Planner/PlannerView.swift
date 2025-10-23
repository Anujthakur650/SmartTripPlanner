import SwiftUI

struct PlannerView: View {
    @EnvironmentObject var dataStore: TravelDataStore
    @State private var selectedDate = Date()
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    DatePicker(String(localized: "Select Date"), selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text(title(for: selectedDate))
                            .font(.headline)
                        
                        let plan = plan(for: selectedDate)
                        let items = plan?.items ?? []
                        
                        if items.isEmpty {
                            Text(String(localized: "No events scheduled"))
                                .font(.body)
                                .foregroundColor(.secondary)
                        } else {
                            if let planTitle = plan?.title, !planTitle.isEmpty {
                                Text(planTitle)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(items) { item in
                                    DayPlanRow(item: item)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle(String(localized: "Planner"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addEvent) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "Add plan"))
                }
            }
        }
    }
    
    private func addEvent() {
        dataStore.addPlan(on: selectedDate)
    }
    
    private func plan(for date: Date) -> DayPlan? {
        dataStore.dayPlans.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    private func title(for date: Date) -> String {
        let formattedDate = date.formatted(date: .long, time: .omitted)
        return String(localized: "Events for \(formattedDate)")
    }
}

private struct DayPlanRow: View {
    let item: DayPlanItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                if let time = item.time,
                   let date = Calendar.current.date(from: time) {
                    Text(date.formatted(date: .omitted, time: .shortened))
                        .font(.caption.weight(.semibold))
                        .frame(width: 64, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                    if let location = item.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(item.details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

#Preview {
    PlannerView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
        .environmentObject(TravelDataStore())
}
