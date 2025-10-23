import SwiftUI

struct PackingView: View {
    @EnvironmentObject var container: DependencyContainer
    @EnvironmentObject var tripStore: TripStore
    @EnvironmentObject var appEnvironment: AppEnvironment
    
    @State private var selectedTripID: UUID?
    @State private var session: PackingService.PackingSession?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddItemSheet = false
    @State private var itemName = ""
    @State private var quantity = 1
    @State private var selectedCategory: PackingCategory = .essentials
    @State private var customCategoryName = ""
    @State private var notes = ""
    @State private var editingItem: PackingListItem?
    
    var body: some View {
        NavigationStack {
            Group {
                if tripStore.trips.isEmpty {
                    ContentUnavailableView(
                        "No Trips",
                        systemImage: "suitcase",
                        description: Text("Create a trip to generate a weather-aware packing list.")
                    )
                } else {
                    ZStack {
                        List {
                            if let trip = currentTrip {
                                tripSection(for: trip)
                                if let weather = session?.weather {
                                    weatherSection(weather)
                                }
                                if let list = session?.list {
                                    itemSections(for: list, trip: trip)
                                } else if !isLoading {
                                    Section {
                                        ContentUnavailableView(
                                            "No Packing Items",
                                            systemImage: "tray",
                                            description: Text("Generate a packing list using the toolbar actions.")
                                        )
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .disabled(isLoading)
                        
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                    }
                }
            }
            .navigationTitle("Packing")
            .toolbar { toolbarContent }
            .task(id: selectedTripID) {
                await loadSession(forceWeatherRefresh: false, regenerate: session == nil)
            }
            .onAppear {
                initializeSelection()
            }
            .onChange(of: tripStore.trips) { _ in
                initializeSelection()
            }
            .refreshable {
                await loadSession(forceWeatherRefresh: true, regenerate: false)
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .sheet(isPresented: $showAddItemSheet) {
                addItemSheet
            }
        }
    }
    
    private var currentTrip: Trip? {
        if let selectedTripID {
            return tripStore.trips.first { $0.id == selectedTripID }
        }
        return tripStore.trips.first
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if currentTrip != nil {
                Menu {
                    Button("Regenerate Packing List") {
                        regenerate(forceWeatherRefresh: false)
                    }
                    Button("Force Weather Refresh & Regenerate") {
                        regenerate(forceWeatherRefresh: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                Button {
                    prepareForAdd()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add packing item")
            }
        }
    }
    
    @ViewBuilder
    private func tripSection(for trip: Trip) -> some View {
        Section("Trip") {
            Picker("Active Trip", selection: Binding(
                get: { selectedTripID ?? trip.id },
                set: { newValue in selectedTripID = newValue }
            )) {
                ForEach(tripStore.trips) { trip in
                    Text(trip.name).tag(trip.id)
                }
            }
            .pickerStyle(.navigationLink)
            
            Label(trip.destination, systemImage: "mappin")
                .font(.subheadline)
            Label("\(trip.durationInDays) day trip", systemImage: "calendar")
                .font(.caption)
            Label(trip.tripType.displayName, systemImage: "tag")
                .font(.caption)
            if !trip.activities.isEmpty {
                Label(trip.activities.map { $0.displayName }.sorted().joined(separator: ", "), systemImage: "figure.walk")
                    .font(.caption)
            }
            if trip.coordinate == nil {
                Label("Add trip coordinates to enable live weather data.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    @ViewBuilder
    private func weatherSection(_ weather: WeatherReport) -> some View {
        Section("Forecast Summary") {
            HStack {
                Label(weather.source == .live ? "Live data" : "Cached data", systemImage: weather.source == .live ? "checkmark.circle" : "clock.arrow.circlepath")
                    .foregroundColor(weather.source == .live ? .green : .orange)
                Spacer()
                Text(weather.generatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            infoRow(label: "Average High", value: formatTemperature(weather.averageHighTemperature))
            infoRow(label: "Average Low", value: formatTemperature(weather.averageLowTemperature))
            infoRow(label: "Precipitation Chance", value: weather.highestPrecipitationChance.formatted(.percent))
            infoRow(label: "Dominant Condition", value: weather.dominantCondition.rawValue.capitalized)
            
            if !appEnvironment.isOnline {
                Label("Offline mode. Showing last known forecast.", systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    @ViewBuilder
    private func itemSections(for list: TripPackingList, trip: Trip) -> some View {
        ForEach(list.itemsGroupedByCategory(), id: \.0.id) { category, items in
            Section(header: Text(category.displayName)) {
                ForEach(items) { item in
                    packingRow(for: item, trip: trip)
                }
            }
        }
    }
    
    private func packingRow(for item: PackingListItem, trip: Trip) -> some View {
        HStack(spacing: 12) {
            Button {
                toggle(item, in: trip)
            } label: {
                Image(systemName: item.isPacked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isPacked ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
                    .strikethrough(item.isPacked)
                HStack(spacing: 8) {
                    if item.quantity > 1 {
                        Label("x\(item.quantity)", systemImage: "number")
                            .labelStyle(.titleAndIcon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let origin = originLabel(for: item) {
                        Text(origin)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.15), in: Capsule())
                    }
                }
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggle(item, in: trip)
        }
        .swipeActions(allowsFullSwipe: false) {
            Button(role: .destructive) {
                remove(item, from: trip)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                prepareForEdit(item)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.indigo)
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
    
    private func originLabel(for item: PackingListItem) -> String? {
        switch item.origin {
        case .manual:
            return "Manual"
        case .base:
            return "Suggested"
        case .rule:
            return "Auto"
        }
    }
    
    private func prepareForAdd() {
        guard currentTrip != nil else { return }
        editingItem = nil
        itemName = ""
        quantity = 1
        selectedCategory = session?.list.allCategories.first ?? .essentials
        if selectedCategory.isCustom {
            customCategoryName = selectedCategory.displayName
        } else {
            customCategoryName = ""
        }
        notes = ""
        showAddItemSheet = true
    }
    
    private func prepareForEdit(_ item: PackingListItem) {
        editingItem = item
        itemName = item.name
        quantity = item.quantity
        selectedCategory = item.category
        if case let .custom(name) = item.category {
            customCategoryName = name
        } else {
            customCategoryName = ""
        }
        notes = item.notes ?? ""
        showAddItemSheet = true
    }
    
    private func resetItemForm() {
        editingItem = nil
        itemName = ""
        quantity = 1
        selectedCategory = .essentials
        customCategoryName = ""
        notes = ""
    }
    
    private func loadSession(forceWeatherRefresh: Bool, regenerate: Bool) async {
        guard let trip = currentTrip else {
            await MainActor.run {
                session = nil
            }
            return
        }
        await MainActor.run {
            isLoading = true
        }
        do {
            let result = try await container.packingService.session(for: trip, regenerateList: regenerate, forceWeatherRefresh: forceWeatherRefresh)
            await MainActor.run {
                session = result
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func toggle(_ item: PackingListItem, in trip: Trip) {
        Task { @MainActor in
            do {
                let result = try await container.packingService.togglePacked(itemID: item.id, for: trip)
                session = result
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func remove(_ item: PackingListItem, from trip: Trip) {
        Task { @MainActor in
            do {
                let result = try await container.packingService.remove(itemID: item.id, for: trip)
                session = result
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func regenerate(forceWeatherRefresh: Bool) {
        guard let trip = currentTrip else { return }
        Task { @MainActor in
            do {
                let result = try await container.packingService.regenerateKeepingManualItems(for: trip, forceWeatherRefresh: forceWeatherRefresh)
                session = result
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func saveItem() {
        guard let trip = currentTrip else { return }
        let trimmedName = itemName.trimmed()
        guard !trimmedName.isEmpty else { return }
        let trimmedCategoryName = customCategoryName.trimmed()
        let resolvedCategory: PackingCategory
        if case .custom = selectedCategory {
            let name = trimmedCategoryName.isEmpty ? selectedCategory.displayName : trimmedCategoryName
            resolvedCategory = .custom(name)
        } else {
            resolvedCategory = selectedCategory
        }
        let resolvedNotes = notes.trimmed()
        Task { @MainActor in
            do {
                if var editing = editingItem {
                    editing.name = trimmedName
                    editing.quantity = max(quantity, 1)
                    editing.category = resolvedCategory
                    editing.notes = resolvedNotes.isEmpty ? nil : resolvedNotes
                    let result = try await container.packingService.updateItem(editing, trip: trip)
                    session = result
                } else {
                    let result = try await container.packingService.addManualItem(
                        name: trimmedName,
                        category: resolvedCategory,
                        quantity: max(quantity, 1),
                        notes: resolvedNotes.isEmpty ? nil : resolvedNotes,
                        trip: trip
                    )
                    session = result
                }
                showAddItemSheet = false
                resetItemForm()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func initializeSelection() {
        guard !tripStore.trips.isEmpty else {
            selectedTripID = nil
            session = nil
            return
        }
        if let selectedTripID, tripStore.trips.contains(where: { $0.id == selectedTripID }) {
            return
        }
        selectedTripID = tripStore.trips.first?.id
    }
    
    private var addItemSheet: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $itemName)
                }
                Section("Quantity") {
                    Stepper(value: $quantity, in: 1 ... 20) {
                        Text("Quantity: \(quantity)")
                    }
                }
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(availableCategories(), id: \.id) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    TextField("Custom Category", text: $customCategoryName)
                        .onChange(of: customCategoryName) { newValue in
                            let trimmed = newValue.trimmed()
                            if trimmed.isEmpty {
                                if selectedCategory.isCustom {
                                    selectedCategory = .essentials
                                }
                            } else {
                                selectedCategory = .custom(trimmed)
                            }
                        }
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(editingItem == nil ? "New Item" : "Edit Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddItemSheet = false
                        resetItemForm()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(itemName.trimmed().isEmpty)
                }
            }
        }
    }
    
    private func availableCategories() -> [PackingCategory] {
        var categories = session?.list.allCategories ?? PackingCategory.standardCategories
        if !categories.contains(selectedCategory) {
            categories.append(selectedCategory)
        }
        return categories.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
    
    private func formatTemperature(_ value: Double) -> String {
        Measurement(value: value, unit: UnitTemperature.celsius)
            .formatted(.measurement(width: .abbreviated, usage: .weather))
    }
}

private extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    let container = DependencyContainer()
    return PackingView()
        .environmentObject(container)
        .environmentObject(container.tripStore)
        .environmentObject(container.appEnvironment)
}
