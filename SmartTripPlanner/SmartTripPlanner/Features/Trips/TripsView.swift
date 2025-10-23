import SwiftUI
import UniformTypeIdentifiers

struct TripsView: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @StateObject private var viewModel = TripsViewModel()
    @State private var navigationPath = NavigationPath()
    
    private var importContentTypes: [UTType] {
        switch viewModel.activeImportKind {
        case .ics:
            let type = UTType(filenameExtension: "ics") ?? .data
            return [type]
        case .pkpass:
            let type = UTType(filenameExtension: "pkpass") ?? .data
            return [type]
        case .template:
            return [.json]
        case .none:
            return [.data]
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.displayedTrips.isEmpty {
                    emptyState
                } else {
                    tripList
                }
            }
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip) {
                    viewModel.beginEditing(trip)
                } onDelete: {
                    viewModel.confirmDeletion(of: trip)
                }
                .environmentObject(appEnvironment)
            }
            .navigationTitle("Trips")
            .toolbar { toolbar }
            .searchable(text: $viewModel.searchText, prompt: "Search trips")
        }
        .onAppear {
            viewModel.configure(with: container, appEnvironment: appEnvironment)
        }
        .onChange(of: viewModel.focusTrip) { newTrip in
            guard let newTrip else { return }
            if let lastTrip = navigationPath.last as? Trip, lastTrip.id == newTrip.id {
                navigationPath.removeLast()
            }
            navigationPath.append(newTrip)
            viewModel.focusTrip = nil
        }
        .alert(item: $viewModel.presentedError) { error in
            Alert(title: Text("Oops"), message: Text(error.localizedDescription), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $viewModel.isPresentingDraft) {
            TripCreationWizard(draft: $viewModel.draft, mode: viewModel.draftMode, onCancel: {
                viewModel.cancelDraft()
            }, onSave: {
                viewModel.saveDraft()
            })
            .environmentObject(appEnvironment)
            .presentationDetents([.medium, .large])
        }
        .fileImporter(isPresented: $viewModel.isShowingFileImporter, allowedContentTypes: importContentTypes, allowsMultipleSelection: false) { result in
            switch result {
            case let .success(url):
                handleImportedURL(url)
            case let .failure(error):
                viewModel.presentedError = .persistenceFailed(error.localizedDescription)
            }
            viewModel.activeImportKind = nil
        }
        .confirmationDialog("Delete trip?", isPresented: Binding(get: {
            viewModel.deletionTarget != nil
        }, set: { value in
            if !value {
                viewModel.deletionTarget = nil
            }
        }), titleVisibility: .visible) {
            if let trip = viewModel.deletionTarget {
                Button("Delete \(trip.name)", role: .destructive) {
                    viewModel.deleteConfirmedTrip()
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.deletionTarget = nil
            }
        } message: {
            Text("You can undo this action shortly after deleting.")
        }
        .overlay(alignment: .bottom) {
            if let undo = viewModel.undoState {
                UndoToastView(message: undo.message) {
                    viewModel.undoDeletion()
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.undoState)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "suitcase.fill")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("Plan your next adventure")
                .font(.title2.weight(.semibold))
            Text("Create a new trip or import an itinerary to get started.")
                .font(.body)
                .foregroundColor(.secondary)
            Button(action: viewModel.beginCreatingTrip) {
                Label("Create Trip", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            Button(action: viewModel.importSampleICS) {
                Label("Import Sample ICS", systemImage: "calendar.badge.plus")
            }
            Spacer()
        }
        .padding()
    }
    
    private var tripList: some View {
        List {
            filterSection
            Section {
                ForEach(viewModel.displayedTrips) { trip in
                    NavigationLink(value: trip) {
                        TripRowView(trip: trip)
                            .environmentObject(appEnvironment)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.confirmDeletion(of: trip)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            viewModel.beginEditing(trip)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var filterSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Date Filter", selection: $viewModel.selectedDateFilter) {
                    ForEach(TripsViewModel.DateFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TripTravelMode.allCases) { mode in
                            modeChip(for: mode)
                        }
                    }
                    .padding(.vertical, 4)
                }
                if let message = viewModel.infoMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !appEnvironment.isOnline {
                    Label("Offline mode", systemImage: "wifi.slash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Menu {
                Section("Create") {
                    Button(action: viewModel.beginCreatingTrip) {
                        Label("Manual Trip", systemImage: "plus")
                    }
                }
                Section("Import") {
                    Button {
                        viewModel.presentImport(kind: .ics)
                    } label: {
                        Label("From Calendar (.ics)", systemImage: "calendar.badge.plus")
                    }
                    Button {
                        viewModel.presentImport(kind: .pkpass)
                    } label: {
                        Label("From Wallet Pass", systemImage: "wallet.pass")
                    }
                    Button {
                        viewModel.presentImport(kind: .template)
                    } label: {
                        Label("From Template", systemImage: "doc.text")
                    }
                    Button {
                        viewModel.importSampleICS()
                    } label: {
                        Label("Sample ICS", systemImage: "sparkles")
                    }
                    Button {
                        viewModel.importSampleTemplate()
                    } label: {
                        Label("Sample Template", systemImage: "doc.badge.plus")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            Button(action: viewModel.beginCreatingTrip) {
                Image(systemName: "plus")
            }
        }
    }
    
    private func modeChip(for mode: TripTravelMode) -> some View {
        let isSelected = viewModel.selectedModes.contains(mode)
        return Button {
            if isSelected {
                viewModel.selectedModes.remove(mode)
            } else {
                viewModel.selectedModes.insert(mode)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: mode.systemImage)
                Text(mode.displayName)
            }
            .font(.caption)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isSelected ? appEnvironment.theme.primaryColor.opacity(0.2) : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? appEnvironment.theme.primaryColor : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private func handleImportedURL(_ url: URL) {
        do {
            let data = try readData(from: url)
            viewModel.handleImportedData(data, reference: url.lastPathComponent)
        } catch {
            viewModel.presentedError = .persistenceFailed(error.localizedDescription)
        }
    }
    
    private func readData(from url: URL) throws -> Data {
        var shouldStop = false
        if url.startAccessingSecurityScopedResource() {
            shouldStop = true
        }
        defer {
            if shouldStop {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
    }
}

private struct UndoToastView: View {
    let message: String
    let onUndo: () -> Void
    
    var body: some View {
        HStack {
            Text(message)
                .font(.footnote)
            Spacer()
            Button("Undo", action: onUndo)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 6, y: 2)
        .padding(.horizontal)
    }
}

#Preview {
    TripsView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}
