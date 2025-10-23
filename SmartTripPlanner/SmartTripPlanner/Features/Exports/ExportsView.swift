import SwiftUI

struct ExportsView: View {
    @EnvironmentObject private var exportService: ExportService
    @EnvironmentObject private var appEnvironment: AppEnvironment
    
    @State private var selectedDelivery: ExportService.DeliveryOption = .share
    @State private var isExportingItinerary = false
    @State private var isExportingGPX = false
    @State private var presentedError: ExportService.ExportError?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !appEnvironment.isOnline {
                        offlineBanner
                    }
                    deliverySection
                    exportCards
                    historySection
                }
                .padding()
            }
            .navigationTitle(String(localized: "Exports"))
            .alert(item: $presentedError) { error in
                Alert(
                    title: Text(String(localized: "Export Error")),
                    message: Text(error.errorDescription ?? "") + Text("\n") + Text(error.recoverySuggestion ?? ""),
                    dismissButton: .default(Text(String(localized: "OK")))
                )
            }
        }
    }
    
    private var offlineBanner: some View {
        Label {
            Text(String(localized: "Offline mode – exports will use cached data only."))
        } icon: {
            Image(systemName: "wifi.exclamationmark")
        }
        .font(.footnote)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.15))
        .foregroundColor(.orange)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var deliverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Delivery"))
                .font(.headline)
            Picker(String(localized: "Delivery option"), selection: $selectedDelivery) {
                ForEach(ExportService.DeliveryOption.allCases) { option in
                    Label(option.localizedTitle, systemImage: option.systemImage)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)
            Text(String(localized: "Choose how you'd like to receive your export."))
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
    
    private var exportCards: some View {
        VStack(spacing: 16) {
            exportCard(
                title: String(localized: "Itinerary PDF"),
                subtitle: String(localized: "A branded itinerary including overview, segments, day plans, packing checklist, and key documents."),
                icon: "doc.richtext",
                isLoading: isExportingItinerary,
                isEnabled: exportService.canGenerateItinerary,
                action: exportItinerary
            )
            exportCard(
                title: String(localized: "Routes GPX"),
                subtitle: String(localized: "Export saved routes and waypoints for Apple Maps and third-party apps."),
                icon: "map",
                isLoading: isExportingGPX,
                isEnabled: exportService.canGenerateGPX,
                action: exportGPX
            )
        }
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "History"))
                .font(.headline)
            if exportService.history.isEmpty {
                ContentUnavailableView(
                    String(localized: "No exports yet"),
                    systemImage: "square.and.arrow.up",
                    description: Text(String(localized: "Your exported files will appear here for quick access."))
                )
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 12) {
                    ForEach(exportService.history) { record in
                        historyRow(for: record)
                    }
                }
            }
        }
    }
    
    private func exportCard(title: String, subtitle: String, icon: String, isLoading: Bool, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Button(action: action) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity)
                } else {
                    Label(String(localized: "Export"), systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isEnabled || isLoading)
            .opacity(isEnabled ? 1 : 0.6)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
    
    private func historyRow(for record: ExportService.HistoryRecord) -> some View {
        let url = exportService.fileURL(for: record)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: record.kind.systemImage)
                    .foregroundColor(.accentColor)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.filename)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(historyDetail(for: record))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Menu {
                    Button {
                        tryDeliver(record: record, option: selectedDelivery)
                    } label: {
                        Label {
                            Text(String(localized: "Deliver via")) + Text(" ") + Text(selectedDelivery.localizedTitle)
                        } icon: {
                            Image(systemName: selectedDelivery.systemImage)
                        }
                    }
                    Button {
                        tryDeliver(record: record, option: .share)
                    } label: {
                        Label(String(localized: "Share"), systemImage: ExportService.DeliveryOption.share.systemImage)
                    }
                    Button {
                        tryDeliver(record: record, option: .files)
                    } label: {
                        Label(String(localized: "Save to Files"), systemImage: ExportService.DeliveryOption.files.systemImage)
                    }
                    Button {
                        tryDeliver(record: record, option: .print)
                    } label: {
                        Label(String(localized: "Print"), systemImage: ExportService.DeliveryOption.print.systemImage)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .padding(4)
                }
            }
            Text(url.path)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(.separator), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }
    
    private func historyDetail(for record: ExportService.HistoryRecord) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let sizeFormatter = ByteCountFormatter()
        sizeFormatter.countStyle = .file
        let dateText = formatter.string(from: record.createdAt)
        let sizeText = sizeFormatter.string(fromByteCount: Int64(record.sizeInBytes))
        return "\(dateText) • \(sizeText)"
    }
    
    private func exportItinerary() {
        guard !isExportingItinerary else { return }
        isExportingItinerary = true
        Task {
            do {
                _ = try await exportService.exportCurrentItinerary(delivery: selectedDelivery)
            } catch let error as ExportService.ExportError {
                presentedError = error
            } catch {
                presentedError = ExportService.ExportError.pdfGenerationFailed
            }
            isExportingItinerary = false
        }
    }
    
    private func exportGPX() {
        guard !isExportingGPX else { return }
        isExportingGPX = true
        Task {
            do {
                _ = try await exportService.exportGPX(delivery: selectedDelivery)
            } catch let error as ExportService.ExportError {
                presentedError = error
            } catch {
                presentedError = ExportService.ExportError.gpxGenerationFailed
            }
            isExportingGPX = false
        }
    }
    
    private func tryDeliver(record: ExportService.HistoryRecord, option: ExportService.DeliveryOption) {
        do {
            try exportService.deliver(record: record, option: option)
        } catch let error as ExportService.ExportError {
            presentedError = error
        } catch {
            presentedError = ExportService.ExportError.presentationUnavailable
        }
    }
}

#Preview {
    let container = DependencyContainer()
    return ExportsView()
        .environmentObject(container.exportService)
        .environmentObject(container.travelDataStore)
        .environmentObject(container.appEnvironment)
}
