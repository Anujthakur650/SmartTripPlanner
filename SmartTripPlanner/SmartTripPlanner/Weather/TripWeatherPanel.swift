import SwiftUI
import WeatherKit

struct TripWeatherPanel: View {
    @ObservedObject var viewModel: TripWeatherViewModel
    var accentColor: Color = .blue
    var retryAction: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Weather", systemImage: "cloud.sun.fill")
                    .font(.headline)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            
            if let forecast = viewModel.forecast {
                summaryView(summary: forecast.summary)
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(forecast.days) { day in
                            dayView(day)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else if let error = viewModel.error {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unable to load weather")
                        .font(.subheadline)
                        .bold()
                    Text(error.localizedDescription)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    if let retryAction {
                        Button(action: retryAction) {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                Text("Weather data not available")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func summaryView(summary: TripWeatherSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.condition.description.capitalized)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("High \(summary.high.formatted()) • Low \(summary.low.formatted())")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(summary.temperature.formatted(.measurement(width: .abbreviated)))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
                Text("Precipitation \(NumberFormatter.percent.string(from: NSNumber(value: summary.precipitationChance)) ?? "0%")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func dayView(_ day: TripWeatherDay) -> some View {
        VStack(spacing: 8) {
            Text(day.date, format: Date.FormatStyle().weekday(.abbreviated))
                .font(.caption)
                .foregroundColor(.secondary)
            Image(systemName: day.symbolName)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(accentColor)
            Text("\(day.high.formatted(.measurement(width: .abbreviated))) / \(day.low.formatted(.measurement(width: .abbreviated)))")
                .font(.caption2)
            Text("\(NumberFormatter.percent.string(from: NSNumber(value: day.precipitationChance)) ?? "0%")")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

private extension WeatherCondition {
    var description: String {
        switch self {
        case .clear, .mostlyClear: return "Clear"
        case .partlyCloudy: return "Partly Cloudy"
        case .cloudy, .mostlyCloudy: return "Cloudy"
        case .foggy: return "Foggy"
        case .windy: return "Windy"
        case .drizzle: return "Light Rain"
        case .rain, .heavyRain: return "Rain"
        case .snow, .heavySnow, .flurries: return "Snow"
        case .sleet, .freezingDrizzle, .freezingRain: return "Sleet"
        case .blizzard: return "Blizzard"
        case .hail: return "Hail"
        case .thunderstorms: return "Storms"
        case .smoky: return "Smoky"
        case .tropicalStorm: return "Tropical Storm"
        case .hurricane: return "Hurricane"
        @unknown default: return "Unknown"
        }
    }
}

private extension Measurement where UnitType == UnitTemperature {
    func formatted() -> String {
        MeasurementFormatter.temperatureFormatter.string(from: self)
    }
}

private extension MeasurementFormatter {
    static let temperatureFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .temperatureWithoutUnit
        formatter.unitStyle = .short
        return formatter
    }()
}

private extension NumberFormatter {
    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

#Preview {
    TripWeatherPanel(viewModel: TripWeatherViewModel())
        .padding()
        .background(Color(.systemGroupedBackground))
}
