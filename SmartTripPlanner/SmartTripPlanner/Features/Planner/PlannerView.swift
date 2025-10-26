import SwiftUI
import UniformTypeIdentifiers

struct PlannerView: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @StateObject private var viewModel = DayPlannerViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    if let conflict = viewModel.conflict {
                        ConflictBanner(conflict: conflict)
                    }
                    plannerColumns
                    ActivityLogSection(entries: viewModel.activityLog, theme: appEnvironment.theme)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(appEnvironment.theme.backgroundColor)
            .navigationTitle("Planner")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: viewModel.undo) {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!viewModel.canUndo)
                    
                    Button(action: viewModel.redo) {
                        Label("Redo", systemImage: "arrow.uturn.forward")
                    }
                    .disabled(!viewModel.canRedo)
                }
            }
        }
        .onAppear {
            let dependencies = DayPlannerViewModel.Dependencies(
                repository: container.plannerRepository,
                environment: appEnvironment,
                suggestionProvider: container.quickAddSuggestionProvider,
                haptics: container.hapticFeedbackService
            )
            viewModel.configureIfNeeded(dependencies)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            DatePicker("Select Date", selection: $viewModel.selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(appEnvironment.theme.primaryColor)
            
            HStack {
                Picker("Trip Type", selection: $viewModel.tripType) {
                    ForEach(TripType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.menu)
                
                Spacer()
                
                if viewModel.isSyncing {
                    Label("Syncing", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            
            if !viewModel.suggestions.isEmpty {
                QuickAddSuggestionsView(
                    suggestions: viewModel.suggestions,
                    primaryColor: appEnvironment.theme.primaryColor,
                    action: { suggestion in
                        viewModel.quickAddSuggestion(suggestion, on: viewModel.selectedDate)
                    }
                )
            }
        }
        .padding()
        .cardStyle(theme: appEnvironment.theme)
    }
    
    private var plannerColumns: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(viewModel.visibleDays(around: viewModel.selectedDate), id: \.self) { day in
                    PlannerDayColumn(
                        day: day,
                        viewModel: viewModel,
                        theme: appEnvironment.theme
                    )
                }
            }
            .padding(.vertical, 12)
        }
    }
}

private struct PlannerDayColumn: View {
    let day: Date
    @ObservedObject var viewModel: DayPlannerViewModel
    let theme: Theme
    
    private var items: [DayPlanItem] {
        viewModel.items(for: day)
    }
    
    private var dayTitle: String {
        day.formatted(.dateTime.month(.abbreviated).day())
    }
    
    private var weekdayTitle: String {
        day.formatted(.dateTime.weekday(.wide))
    }
    
    private var totalHeight: CGFloat {
        viewModel.slotHeight * 96
    }
    
    private func height(for item: DayPlanItem) -> CGFloat {
        let durationMinutes = max(item.duration / 60, Double(viewModel.slotIntervalMinutes))
        let slots = ceil(durationMinutes / Double(viewModel.slotIntervalMinutes))
        return CGFloat(slots) * viewModel.slotHeight
    }
    
    private func offset(for item: DayPlanItem) -> CGFloat {
        let dayStart = day.startOfDay()
        let minutes = Calendar.current.dateComponents([.minute], from: dayStart, to: item.startDate).minute ?? 0
        let slots = Double(minutes) / Double(viewModel.slotIntervalMinutes)
        return CGFloat(slots) * viewModel.slotHeight
    }
    
    private func offset(for preview: DropPreview) -> CGFloat {
        guard let previewDay = Date(isoDayIdentifier: preview.dayIdentifier) else { return 0 }
        let minutes = Calendar.current.dateComponents([.minute], from: previewDay, to: preview.startDate).minute ?? 0
        let slots = Double(minutes) / Double(viewModel.slotIntervalMinutes)
        return CGFloat(slots) * viewModel.slotHeight
    }
    
    private var preview: some View {
        Group {
            if let dropPreview = viewModel.dropPreview, dropPreview.dayIdentifier == day.isoDayIdentifier {
                Rectangle()
                    .fill(theme.secondaryColor.opacity(0.6))
                    .frame(height: 3)
                    .offset(y: offset(for: dropPreview))
                    .animation(.easeInOut(duration: 0.15), value: dropPreview)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dayTitle)
                    .font(.headline)
                Text(weekdayTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            ScrollView(.vertical, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    TimelineBackground(totalHeight: totalHeight, slotHeight: viewModel.slotHeight)
                    ForEach(items) { item in
                        DayPlanItemCard(
                            item: item,
                            height: height(for: item),
                            theme: theme,
                            onRemove: {
                                viewModel.removeItem(item.id, from: day)
                            }
                        )
                        .offset(y: offset(for: item))
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 8)
                                .onChanged { value in
                                    let locationY = max(0, offset(for: item) + value.location.y)
                                    viewModel.updateDropPreview(day: day, locationY: locationY)
                                }
                                .onEnded { _ in
                                    viewModel.clearDropPreview()
                                }
                        )
                        .onDrag {
                            if let payload = viewModel.dragPayload(for: item.id, on: day) {
                                return NSItemProvider(object: NSString(string: payload))
                            }
                            return NSItemProvider()
                        }
                    }
                    preview
                }
                .frame(height: totalHeight)
                .padding(.trailing, 4)
                .contentShape(Rectangle())
                .onDrop(of: [UTType.plainText.identifier], delegate: DayPlanDropDelegate(day: day, viewModel: viewModel, slotHeight: viewModel.slotHeight))
            }
            .frame(height: 420)
        }
        .padding()
        .cardStyle(theme: theme)
    }
}

private struct TimelineBackground: View {
    let totalHeight: CGFloat
    let slotHeight: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let hourHeight = slotHeight * 4
            Path { path in
                let hours = Int(totalHeight / hourHeight)
                for hour in 0...hours {
                    let y = CGFloat(hour) * hourHeight
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        }
    }
}

private struct DayPlanItemCard: View {
    let item: DayPlanItem
    let height: CGFloat
    let theme: Theme
    let onRemove: () -> Void
    
    private var timeRange: String {
        "\(item.startDate.formatted(date: .omitted, time: .shortened)) - \(item.endDate.formatted(date: .omitted, time: .shortened))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimaryColor)
                Spacer()
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            
            Text(timeRange)
                .font(.caption)
                .foregroundStyle(theme.textSecondaryColor)
            
            if let location = item.location, !location.isEmpty {
                Label(location, systemImage: "mappin.circle")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondaryColor)
            }
            
            if !item.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(item.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.secondaryColor.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }
            
            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondaryColor)
                    .lineLimit(4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height, alignment: .top)
        .background(theme.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .shadow(radius: theme.shadowRadius / 2)
    }
}

private struct QuickAddSuggestionsView: View {
    let suggestions: [QuickAddSuggestion]
    let primaryColor: Color
    let action: (QuickAddSuggestion) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Add")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            action(suggestion)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(suggestion.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(durationDescription(suggestion.duration))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(primaryColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private func durationDescription(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

private struct ActivityLogSection: View {
    let entries: [ActivityLogEntry]
    let theme: Theme
    
    private let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .numeric
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activity Log")
                    .font(.headline)
                Spacer()
            }
            
            if entries.isEmpty {
                Text("No recent changes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries.prefix(10)) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.description)
                            .font(.subheadline)
                        Text(dateFormatter.localizedString(for: entry.timestamp, relativeTo: Date()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if entry.id != entries.prefix(10).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .cardStyle(theme: theme)
    }
}

private struct ConflictBanner: View {
    let conflict: DayPlanConflict
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(conflict.message)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding()
        .background(Color.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct DayPlanDropDelegate: DropDelegate {
    let day: Date
    let viewModel: DayPlannerViewModel
    let slotHeight: CGFloat
    
    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.plainText])
    }
    
    func dropEntered(info: DropInfo) {
        viewModel.updateDropPreview(day: day, locationY: info.location.y)
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        viewModel.updateDropPreview(day: day, locationY: info.location.y)
        return DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        viewModel.clearDropPreview()
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.plainText]).first else {
            viewModel.clearDropPreview()
            return false
        }
        let location = info.location
        viewModel.updateDropPreview(day: day, locationY: location.y)
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
            var payload: DayPlanDragPayload?
            if let data = data as? Data {
                payload = viewModel.decodeDragPayload(from: data)
            } else if let string = data as? String {
                payload = viewModel.decodeDragPayload(from: string)
            }
            guard let payload else {
                DispatchQueue.main.async {
                    viewModel.clearDropPreview()
                }
                return
            }
            let startDate = viewModel.dropStartDate(for: location.y, on: day, slotHeight: slotHeight)
            DispatchQueue.main.async {
                _ = viewModel.moveItem(
                    with: payload.itemID,
                    from: payload.sourceDayIdentifier,
                    to: day,
                    proposedStartDate: startDate
                )
                viewModel.clearDropPreview()
            }
        }
        return true
    }
}

#Preview {
    PlannerView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}
