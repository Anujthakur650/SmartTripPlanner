# Changelog

All notable changes to SmartTripPlanner will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project setup with SwiftUI and iOS 17+ support
- Core architecture with dependency injection
- Tab-based navigation system
- Feature modules:
  - Trips: Trip management and organization
  - Planner: Itinerary planning with calendar integration
  - Map: Interactive map view with location services
  - Packing: Packing list management
  - Docs: Travel document storage
  - Settings: App configuration and preferences
- Service layer:
  - WeatherService: WeatherKit integration
  - MapsService: MapKit and location services
  - CalendarService: EventKit integration
  - EmailService: Google Sign-In for Gmail
  - ExportService: PDF and JSON export
  - SyncService: CloudKit sync (private and shared)
- Design system with theme support
- Entitlements configuration:
  - iCloud/CloudKit (private + shared database)
  - WeatherKit capability
  - Background Tasks
  - Location (When In Use)
  - EventKit (Calendar)
  - Photo Library (Add only)
  - File Access (iCloud Drive)
  - Push Notifications
- Development tools:
  - SwiftLint configuration
  - SwiftFormat configuration
  - GitHub Actions CI workflow
  - fastlane setup (build, test, beta lanes)
- Comprehensive documentation:
  - README with setup instructions
  - CONTRIBUTING guide
  - .env.example for configuration
  - Privacy strings in Info.plist
- Unit test suite with XCTest
- Refactored Map feature with modular SwiftUI components, improved routing UI, and offline messaging.
- Repository health assets: CodeQL security analysis workflow, CODEOWNERS, SECURITY policy, governance guidelines, and README status badges.

### Development Setup
- Xcode 15.0+ support
- Swift 5.9 language version
- iOS 17.0 deployment target
- Swift Package Manager dependencies:
  - GoogleSignIn (7.1.0+)

### Build & CI
- GitHub Actions workflow for PRs
- Automated building and testing
- SwiftLint and SwiftFormat checks
- fastlane automation

## [1.0.0] - TBD

First stable release planned with:
- Complete trip management features
- Full iCloud sync functionality
- Weather integration
- Calendar sync
- Document management
- Export capabilities

---

## Version History

- **Unreleased**: Initial development and project bootstrap
- **1.0.0**: First stable release (planned)
