# SmartTripPlanner iOS App

[![CI](https://github.com/smarttripplanner/SmartTripPlanner/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/smarttripplanner/SmartTripPlanner/actions/workflows/ci.yml)
[![CodeQL](https://github.com/smarttripplanner/SmartTripPlanner/actions/workflows/codeql.yml/badge.svg?branch=main)](https://github.com/smarttripplanner/SmartTripPlanner/actions/workflows/codeql.yml)

A comprehensive trip planning application built with SwiftUI for iOS 17+. SmartTripPlanner helps users organize trips, plan itineraries, manage packing lists, store travel documents, and integrate with calendar, weather, and location services.

## Features

- **Trip Management**: Create, organize, and manage multiple trips
- **Itinerary Planner**: Plan daily activities with calendar integration
- **Interactive Maps**: View destinations and navigate with Apple Maps
- **Packing Lists**: Create and manage packing checklists
- **Document Storage**: Store travel documents, tickets, and reservations
- **Weather Integration**: Get weather forecasts using WeatherKit
- **iCloud Sync**: Sync data across devices with CloudKit
- **Gmail Integration**: Import trip confirmations from email
- **Calendar Integration**: Sync trip events with Calendar app
- **Photo Library**: Save trip photos and documents

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Apple Developer Account (for WeatherKit, CloudKit, and provisioning)
- macOS 14+ (for development)

## Architecture

The app follows a modular architecture with clear separation of concerns:

### Folder Structure

```
SmartTripPlanner/
├── Core/                          # Core app functionality
│   ├── DependencyContainer.swift  # Service injection
│   ├── AppEnvironment.swift       # Global app state
│   └── NavigationCoordinator.swift # Navigation management
├── Features/                      # Feature modules
│   ├── Trips/                    # Trip management
│   ├── Planner/                  # Itinerary planning
│   ├── Map/                      # Map integration
│   ├── Packing/                  # Packing lists
│   ├── Docs/                     # Document storage
│   └── Settings/                 # App settings
├── Services/                      # Business logic services
│   ├── WeatherService.swift      # WeatherKit integration
│   ├── MapsService.swift         # MapKit integration
│   ├── CalendarService.swift     # EventKit integration
│   ├── EmailService.swift        # Gmail integration
│   ├── ExportService.swift       # PDF/JSON export
│   └── SyncService.swift         # CloudKit sync
├── UIComponents/                  # Reusable UI components
├── DesignSystem/                  # Theme and styling
│   └── Theme.swift
└── Assets.xcassets/              # Images and colors
```

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/SmartTripPlanner.git
cd SmartTripPlanner
```

### 2. Apple Developer Configuration

#### a. WeatherKit Setup

1. Log in to [Apple Developer Portal](https://developer.apple.com)
2. Go to Certificates, Identifiers & Profiles
3. Select your App ID (com.smarttripplanner.SmartTripPlanner)
4. Enable **WeatherKit** capability
5. Save and regenerate provisioning profiles

#### b. iCloud/CloudKit Setup

1. In Apple Developer Portal, configure App ID with:
   - **iCloud** capability
   - **CloudKit** containers
2. Create iCloud container: `iCloud.com.smarttripplanner.SmartTripPlanner`
3. Enable **Private Database** and **Shared Database** in CloudKit Dashboard
4. Configure CloudKit Schema (optional, can be done automatically)

#### c. Background Tasks Setup

1. Enable **Background Modes** in App ID
2. Check:
   - Background fetch
   - Remote notifications
   - Background processing

#### d. Provisioning Profiles

1. Create development provisioning profile with all capabilities enabled
2. Download and install profile in Xcode
3. Update `DEVELOPMENT_TEAM` in project settings

### 3. Configure Environment Variables

1. Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

2. Update `.env` with your credentials:

```bash
APPLE_ID=your.email@example.com
TEAM_ID=YOUR_TEAM_ID
ITC_TEAM_ID=YOUR_ITC_TEAM_ID
GOOGLE_CLIENT_ID=YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com
```

### 4. Google Sign-In Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing
3. Enable **Gmail API**
4. Create OAuth 2.0 credentials:
   - Application type: iOS
   - Bundle ID: `com.smarttripplanner.SmartTripPlanner`
5. Download OAuth client configuration
6. Update `Info.plist` with your client ID:
   - Replace `YOUR-CLIENT-ID` in `CFBundleURLSchemes`

### 5. Update Info.plist Privacy Strings

The following privacy descriptions are already included in `Info.plist`:

- **NSCalendarsUsageDescription**: Calendar access for trip planning
- **NSLocationWhenInUseUsageDescription**: Location access for maps and navigation
- **NSPhotoLibraryAddUsageDescription**: Photo library access for saving documents

You can customize these strings as needed.

### 6. Install Dependencies

#### Install Homebrew (if not already installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### Install SwiftLint

```bash
brew install swiftlint
```

#### Install SwiftFormat

```bash
brew install swiftformat
```

#### Install fastlane

```bash
brew install fastlane
```

### 7. Open Project in Xcode

```bash
cd SmartTripPlanner
open SmartTripPlanner.xcodeproj
```

### 8. Configure Signing

1. In Xcode, select the `SmartTripPlanner` target
2. Go to **Signing & Capabilities**
3. Select your **Team**
4. Verify all capabilities are enabled:
   - iCloud (with CloudKit and iCloud Documents)
   - Background Modes
   - WeatherKit
   - Push Notifications (optional)

### 9. Build and Run

1. Select an iOS 17+ simulator or device
2. Press `Cmd+B` to build
3. Press `Cmd+R` to run

## Swift Package Dependencies

The project uses the following Swift Package dependencies (managed automatically by Xcode):

- **GoogleSignIn** (7.0.0+): Google OAuth authentication
  - Repository: https://github.com/google/GoogleSignIn-iOS.git

SwiftLint and SwiftFormat are integrated as build phases and run automatically during builds.

## Development Workflow

### Running Tests

```bash
# Using Xcode
Cmd+U

# Using fastlane
fastlane test

# Using xcodebuild
cd SmartTripPlanner
xcodebuild test -project SmartTripPlanner.xcodeproj -scheme SmartTripPlanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Linting and Formatting

```bash
# Run SwiftLint
cd SmartTripPlanner
swiftlint

# Run SwiftFormat (check only)
swiftformat --lint .

# Run SwiftFormat (apply fixes)
swiftformat .

# Using fastlane
fastlane lint
fastlane format
```

### Building

```bash
# Using fastlane
fastlane build

# Using xcodebuild
cd SmartTripPlanner
xcodebuild build -project SmartTripPlanner.xcodeproj -scheme SmartTripPlanner -destination 'generic/platform=iOS'
```

### Beta Distribution

```bash
# Build and upload to TestFlight
fastlane beta
```

## CI/CD

### GitHub Actions

The repository includes two GitHub Actions workflows:

- **CI** (`.github/workflows/ci.yml`): Builds the app for iOS Simulator, runs unit tests, and enforces SwiftLint & SwiftFormat without allowing failures.
- **CodeQL** (`.github/workflows/codeql.yml`): Performs static analysis for Swift code and surfaces security vulnerabilities.

Both workflows run on pull requests to `main` and `develop`, and on pushes to `main`. Results are available in the **Actions** tab.

### Continuous Integration

The CI pipeline includes:

- **Build validation**: Ensures code compiles successfully.
- **Unit tests**: Runs all test suites.
- **Code quality**: SwiftLint and SwiftFormat checks fail the build if violations are found.
- **Security**: CodeQL static analysis runs on macOS to catch Swift issues early.
- **Platform**: Runs on macOS 14 with Xcode 15.2.

### Branch Protection & Governance

The `main` branch is protected and requires:

- ✅ At least one maintainer approval (code owner review enforced via `.github/CODEOWNERS`).
- ✅ Passing **CI / Build and Test** and **CodeQL Analysis** status checks.
- ✅ Up-to-date merges with `main` prior to completion.

See [GOVERNANCE.md](./GOVERNANCE.md) and [SECURITY.md](./SECURITY.md) for details on the governance model and security response process.

## Entitlements

The app requires the following entitlements (configured in `SmartTripPlanner.entitlements`):

- **iCloud**:
  - CloudKit (private and shared database)
  - iCloud Documents (iCloud Drive access)
- **Background Tasks**:
  - Background fetch
  - Background processing
  - Remote notifications
- **WeatherKit**: Weather data access
- **Push Notifications**: Optional for future features
- **Location**: When-in-use authorization
- **EventKit**: Calendar access
- **Photo Library**: Add-only access

## Troubleshooting

### WeatherKit Not Working

- Verify WeatherKit is enabled in Apple Developer Portal
- Ensure app is signed with valid provisioning profile
- WeatherKit requires a paid Apple Developer Account
- Check entitlements file includes `com.apple.developer.weatherkit`

### iCloud Sync Issues

- Verify iCloud container ID matches: `iCloud.com.smarttripplanner.SmartTripPlanner`
- Sign in with Apple ID in iOS Settings > iCloud
- Enable iCloud Drive on device
- Check CloudKit Dashboard for container configuration

### Google Sign-In Not Working

- Verify Google Client ID is correctly configured in Info.plist
- Check URL scheme matches reversed client ID
- Enable Gmail API in Google Cloud Console
- Verify OAuth consent screen is configured

### Build Failures

- Clean build folder: `Cmd+Shift+K`
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Update Swift Package dependencies
- Verify Xcode version is 15.0+

### Code Signing Issues

- Ensure Development Team is selected in project settings
- Verify provisioning profile includes all required capabilities
- Check certificate is valid and not expired
- Try automatic signing management

## Project Configuration

### Bundle Identifier

```
com.smarttripplanner.SmartTripPlanner
```

### Deployment Target

- iOS 17.0+

### Swift Version

- Swift 5.9

### Supported Devices

- iPhone (iOS 17+)
- iPad (iOS 17+)
- Not supported: macOS, watchOS, tvOS

### Supported Orientations

- iPhone: Portrait, Landscape Left, Landscape Right
- iPad: All orientations

## Contributing

Please review the [Code of Conduct](./CODE_OF_CONDUCT.md) and [Governance](./GOVERNANCE.md) guidelines before contributing.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes and commit: `git commit -am 'Add new feature'`
4. Run tests and linting: `fastlane test && fastlane lint`
5. Push to branch: `git push origin feature/my-feature`
6. Create a Pull Request

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint and SwiftFormat configurations
- Write unit tests for new features
- Document public APIs

## License

Copyright © 2024 SmartTripPlanner. All rights reserved.

## Support

For issues and questions:

- Create an issue in GitHub repository
- Contact: support@smarttripplanner.com
- Documentation: https://docs.smarttripplanner.com

## Roadmap

- [ ] AI-powered trip suggestions
- [ ] Collaboration features (shared trips)
- [ ] Offline mode with local caching
- [ ] Apple Watch companion app
- [ ] Widget support
- [ ] Siri shortcuts integration
- [ ] Trip sharing to social media
- [ ] Budget tracking
- [ ] Multi-language support

---

Built with ❤️ using SwiftUI and modern iOS technologies.
