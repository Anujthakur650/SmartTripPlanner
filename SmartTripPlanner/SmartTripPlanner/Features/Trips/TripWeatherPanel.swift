import SwiftUI

struct TripWeatherPanel: View {
    let state: TripWeatherViewModel.State
    var onRetry: () -> Void
    
    var body: some View {
        Group {
            switch state {
            case .idle:
                EmptyView()
            case .noTrips:
                placeholderCard(
                    title: "Plan a trip",
                    message: "Add a destination to see the weather forecast here."
                )
            case let .loading(tripName):
                loadingCard(tripName: tripName)
            case let .content(summary, trip):
                contentCard(summary: summary, trip: trip)
            case let .error(message, suggestion):
                errorCard(message: message, suggestion: suggestion)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: stateIndicator)
    }
    
    private var stateIndicator: String {
        switch state {
        case .idle: return "idle"
        case .noTrips: return "noTrips"
        case .loading: return "loading"
        case .content: return "content"
        case .error: return "error"
        }
    }
    
    @ViewBuilder
    private func loadingCard(tripName: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView()
            Text(tripName ?? "Fetching weather…")
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Material.ultraThick)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    @ViewBuilder
    private func placeholderCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "sun.max")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Material.thick)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    @ViewBuilder
    private func errorCard(message: String, suggestion: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Weather unavailable", systemImage: "cloud.slash")
                .font(.headline)
            Text(message)
                .font(.subheadline)
            if let suggestion, !suggestion.isEmpty {
                Text(suggestion)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Button(action: onRetry) {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    @ViewBuilder
    private func contentCard(summary: WeatherSummary, trip: Trip) -> some View {
        let formatter = WeatherPresentationFormatter(timeZone: summary.timezone)
        VStack(alignment: .leading, spacing: 16) {
            header(summary: summary, trip: trip, formatter: formatter)
            Divider().opacity(0.2)
            forecastList(summary: summary, formatter: formatter)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.9), Color.blue.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.accentColor.opacity(0.3), radius: 12, y: 8)
    }
    
    @ViewBuilder
    private func header(summary: WeatherSummary, trip: Trip, formatter: WeatherPresentationFormatter) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.locationName)
                        .font(.headline.weight(.bold))
                        .accessibilityIdentifier("weather_location_label")
                    Text(trip.name)
                        .font(.subheadline)
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: summary.current.symbolName)
                    .font(.system(size: 42, weight: .light))
                    .shadow(radius: 4)
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(formatter.temperature(summary.current.temperature))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("weather_temperature_label")
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.current.conditionDescription.capitalized)
                        .font(.subheadline.weight(.semibold))
                    Text("Feels like \(formatter.temperature(summary.current.apparentTemperature))")
                        .font(.caption)
                        .opacity(0.85)
                }
            }
            HStack(spacing: 16) {
                Label("H: \(formatter.temperature(summary.current.highTemperature))", systemImage: "arrow.up")
                    .font(.caption)
                Label("L: \(formatter.temperature(summary.current.lowTemperature))", systemImage: "arrow.down")
                    .font(.caption)
                if let precipitation = summary.current.precipitationChance {
                    Label("\(formatter.precipitation(chance: precipitation))", systemImage: "cloud.rain")
                        .font(.caption)
                }
            }
            .opacity(0.9)
        }
    }
    
    @ViewBuilder
    private func forecastList(summary: WeatherSummary, formatter: WeatherPresentationFormatter) -> some View {
        let daily = summary.forecast.prefix(5)
        VStack(spacing: 12) {
            ForEach(Array(daily.enumerated()), id: \.offset) { index, day in
                HStack {
                    Text(index == 0 ? "Today" : formatter.dayLabel(for: day.date))
                        .font(.headline)
                        .frame(width: 70, alignment: .leading)
                    Image(systemName: day.symbolName)
                        .frame(width: 30)
                    Spacer()
                    Text("\(formatter.temperature(day.highTemperature)) / \(formatter.temperature(day.lowTemperature))")
                        .font(.subheadline.weight(.semibold))
                    if day.precipitationChance > 0 {
                        Text(formatter.precipitation(chance: day.precipitationChance))
                            .font(.caption)
                            .opacity(0.8)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

struct WeatherPresentationFormatter {
    private let temperatureFormatter: MeasurementFormatter
    private let percentFormatter: NumberFormatter
    private let dayFormatter: DateFormatter
    
    init(timeZone: TimeZone, locale: Locale = .current) {
        let measurementFormatter = MeasurementFormatter()
        measurementFormatter.unitOptions = .temperatureWithoutUnit
        measurementFormatter.numberFormatter.maximumFractionDigits = 0
        measurementFormatter.locale = locale
        self.temperatureFormatter = measurementFormatter
        
        let percentFormatter = NumberFormatter()
        percentFormatter.numberStyle = .percent
        percentFormatter.maximumFractionDigits = 0
        percentFormatter.locale = locale
        self.percentFormatter = percentFormatter
        
        let dayFormatter = DateFormatter()
        dayFormatter.locale = locale
        dayFormatter.timeZone = timeZone
        dayFormatter.dateFormat = "EEE"
        self.dayFormatter = dayFormatter
    }
    
    func temperature(_ measurement: Measurement<UnitTemperature>) -> String {
        temperatureFormatter.string(from: measurement)
    }
    
    func precipitation(chance: Double) -> String {
        percentFormatter.string(from: NSNumber(value: chance)) ?? ""
    }
    
    func dayLabel(for date: Date) -> String {
        dayFormatter.string(from: date)
    }
}
