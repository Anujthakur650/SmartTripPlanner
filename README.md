# SmartTripPlanner iOS Workspace

SmartTripPlanner is a modular SwiftUI application targeting iOS 17 and later. The codebase is organised as an Xcode workspace that embeds a set of Swift Package Manager (SPM) modules to keep core domain logic, services, reusable UI, feature flows, and app shell composition cleanly separated. The primary goals of the project bootstrap are:

- Consistent environment-aware configuration for Debug and Release builds
- First-class support for privacy-sensitive system capabilities (CloudKit, background activity, notifications, location, documents, media capture)
- SPM-managed SwiftLint and SwiftFormat toolchains wired into local hooks, Fastlane lanes, and CI
- Automated build, lint, format, and test validation on the latest public Xcode
- Ready-to-ship Fastlane pipelines for TestFlight distribution and marketing automations

---

## Table of Contents

1. [Workspace & Modules](#workspace--modules)
2. [System Requirements](#system-requirements)
3. [Project Setup](#project-setup)
   - [Clone & Open](#clone--open)
   - [Configure Signing](#configure-signing)
   - [Secrets & Environment](#secrets--environment)
   - [Install Git Hooks](#install-git-hooks)
4. [Apple Developer Configuration](#apple-developer-configuration)
   - [Bundle Identifiers](#bundle-identifiers)
   - [CloudKit & iCloud Drive](#cloudkit--icloud-drive)
   - [Background Activity](#background-activity)
   - [Push & Remote Notifications](#push--remote-notifications)
   - [Location Services](#location-services)
   - [Calendars & Documents](#calendars--documents)
   - [WeatherKit Provisioning](#weatherkit-provisioning)
5. [Running the App](#running-the-app)
6. [Tooling & Automation](#tooling--automation)
   - [SPM Style Tooling](#spm-style-tooling)
   - [Fastlane Lanes](#fastlane-lanes)
   - [GitHub Actions CI](#github-actions-ci)
7. [Development Workflows](#development-workflows)
   - [Formatting & Linting](#formatting--linting)
   - [Unit Tests](#unit-tests)
   - [Environment Switching](#environment-switching)
8. [Troubleshooting](#troubleshooting)
9. [Support](#support)

---

## Workspace & Modules

The repository root defines `SmartTripPlanner.xcworkspace`, which links the iOS application target (`SmartTripPlanner`) and a co-located Swift package in `Modules/`.

SwiftPM products exported by `Modules/Package.swift`:

| Module        | Description                                                                                  |
|---------------|----------------------------------------------------------------------------------------------|
| `Core`        | Fundamental app state containers, navigation primitives, theming tokens, and configuration   |
| `Services`    | Service layer protocols and concrete WeatherKit, CloudKit, Calendar, and Sync facades        |
| `UIComponents`| Design-system level reusable SwiftUI components and styling helpers                          |
| `Features`    | UI flows and view models that coordinate services, state, and UI components                   |
| `AppShell`    | High-level scene composition (tab scaffolding, dependency injection, and entry points)       |

Each target has the SwiftLint and SwiftFormat plugins applied, ensuring consistent style enforcement across modules whenever they are built or when plugins are executed manually.

---

## System Requirements

- macOS 14.5 or later
- Xcode 15.4 (or the latest publicly available Xcode with iOS 17 SDK)
- Ruby 3.x (for Fastlane)
- Bundler (optional, if you prefer to isolate Fastlane dependencies)
- An Apple Developer Program membership with access to App Store Connect

---

## Project Setup

### Clone & Open

```bash
git clone git@github.com:your-org/SmartTripPlanner.git
cd SmartTripPlanner
open SmartTripPlanner.xcworkspace
```

Always work via the workspace to ensure Xcode resolves embedded package targets correctly.

### Configure Signing

Signing defaults are defined in `SmartTripPlanner/Configurations/*.xcconfig`:

- `Base.xcconfig` – shared values (`APP_BUNDLE_IDENTIFIER`, `DEVELOPMENT_TEAM`, deployment target, signing style)
- `Debug.xcconfig` – debug-specific compiler flags and `ENVIRONMENT_NAME=Debug`
- `Release.xcconfig` – release optimisation and `ENVIRONMENT_NAME=Release`

Update `DEVELOPMENT_TEAM` and, if required, `APP_BUNDLE_IDENTIFIER` to match your developer account. Xcode will pick up these settings for both the app and test targets.

### Secrets & Environment

1. Duplicate the secrets template and keep the real file outside of source control:
   ```bash
   cp SmartTripPlanner/Configurations/Secrets.plist.template SmartTripPlanner/Configurations/Secrets.plist
   ```
2. Populate the following keys with production or sandbox credentials:
   - `WEATHERKIT_KEY_ID`, `WEATHERKIT_TEAM_ID`, `WEATHERKIT_SERVICE_ID`
   - `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_REVERSED_CLIENT_ID`
   - `ICLOUD_PRIMARY_CONTAINER`, `ICLOUD_SHARED_CONTAINER`, `ICLOUD_SERVICES_CONTAINER`
3. `AppConfiguration` (in `Core`) gracefully handles missing values, but features such as WeatherKit or Google Sign-In require valid credentials at runtime.

### Install Git Hooks

Local formatting and linting are enforced via SPM plugins. Install the provided hook once per clone:

```bash
chmod +x scripts/*.sh
ln -sf ../../scripts/pre-commit.sh .git/hooks/pre-commit
```

You can also run the hook manually at any time:

```bash
scripts/pre-commit.sh
```

---

## Apple Developer Configuration

### Bundle Identifiers

- `com.smarttripplanner.app` – primary application identifier (configurable via xcconfig)
- `com.smarttripplanner.app.tests` – generated automatically for the UI/unit-test bundle

### CloudKit & iCloud Drive

1. Enable iCloud with CloudKit and iCloud Documents for the main App ID.
2. Create the following containers:
   - `iCloud.com.smarttripplanner.core`
   - `iCloud.com.smarttripplanner.services`
   - `iCloud.com.smarttripplanner.shared`
3. Regenerate development and distribution provisioning profiles after toggling capabilities.

The entitlement file (`SmartTripPlanner.entitlements`) already references the above containers and sets the environment to *Development*.

### Background Activity

Enable the **Background Modes** capability with the following options:

- Background fetch
- Remote notifications
- Background processing
- Location updates

`Info.plist` includes the necessary `UIBackgroundModes` entries.

### Push & Remote Notifications

- Enable the Push Notifications capability for your App ID.
- The entitlement file contains `aps-environment` set to `development` by default; update to `production` when preparing release builds.

### Location Services

- Grant *When In Use* and *Always* permissions.
- Ensure “Location updates” is ticked inside Background Modes.
- `Info.plist` contains human-readable `NSLocation*` usage descriptions and a temporary usage reason for itinerary planning.

### Calendars & Documents

- Enable Calendar, Reminders (if required), and iCloud Documents access in the Apple Developer Portal.
- `NSCalendarsUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`, and `NSCameraUsageDescription` are included to satisfy App Store review requirements.

### WeatherKit Provisioning

WeatherKit requires App Store Connect configuration:

1. Create a WeatherKit key in the Apple Developer portal.
2. Associate the key with the SmartTripPlanner service identifier.
3. Record the Key ID, Team ID, and Service ID in `Secrets.plist`.
4. Enable WeatherKit for the bundle identifier in Certificates, Identifiers & Profiles.

---

## Running the App

1. Open `SmartTripPlanner.xcworkspace` in Xcode.
2. Select the **SmartTripPlanner** scheme.
3. Pick an iOS 17+ simulator (or a physical device with appropriate provisioning).
4. Build (`⌘B`) and run (`⌘R`).

The app loads the tab-based shell defined in the `AppShell` module and automatically injects dependencies from `DependencyContainer`.

---

## Tooling & Automation

### SPM Style Tooling

SwiftLint and SwiftFormat are brought in via the Swift Package Manager, avoiding Homebrew dependence. Useful scripts:

- `scripts/format.sh` – runs the SwiftFormat plugin across all package targets (mutating)
- `scripts/lint.sh` – runs the SwiftLint plugin across all package targets
- `scripts/pre-commit.sh` – convenience wrapper that formats then lints

### Fastlane Lanes

Fastlane is configured under `fastlane/Fastfile` with the following lanes:

| Lane        | Description                                                                                             |
|-------------|---------------------------------------------------------------------------------------------------------|
| `build`     | Build the Debug configuration for the simulator via the workspace                                       |
| `test`      | Execute unit tests on the latest iPhone simulator                                                       |
| `lint`      | Run `scripts/lint.sh` via Fastlane for CI parity                                                        |
| `format`    | Apply workspace-wide formatting using `scripts/format.sh`                                               |
| `beta`      | Increment build number, archive the Release configuration, and upload to TestFlight (requires signing)  |
| `screenshots` | Capture UI screenshots with `capture_screenshots` (configure Snapfile as needed)                     |

All Fastlane commands assume execution from the repository root: `fastlane <lane>`.

### GitHub Actions CI

`.github/workflows/ci.yml` runs on pushes to `main` and pull requests:

1. Checks out the repository and selects the latest Xcode 15.2+ toolchain on macOS 14
2. Restores SPM caches (including the workspace modules)
3. Executes the SwiftFormat plugin and fails if unformatted changes are produced
4. Executes the SwiftLint plugin to surface style violations
5. Builds the SmartTripPlanner scheme for the latest iPhone simulator
6. Runs unit tests for the same destination

CI never modifies workflow files—fix failing steps in code or configuration files instead.

---

## Development Workflows

### Formatting & Linting

Run locally before raising a pull request:

```bash
scripts/format.sh    # Applies formatting
scripts/lint.sh      # Static analysis (fails on warnings/errors)
```

For pre-push confidence:

```bash
fastlane lint
fastlane test
```

### Unit Tests

Run tests from Xcode (`⌘U`) or via the command line:

```bash
fastlane test
```

### Environment Switching

`ENVIRONMENT_NAME` is injected into the Info.plist from the active xcconfig. Access it at runtime through `AppConfiguration.shared.environmentName`. Use this to toggle between sandbox APIs, feature flags, or analytics destinations.

---

## Troubleshooting

| Issue | Resolution |
|-------|------------|
| **WeatherKit responses are empty** | Verify WeatherKit entitlements and credentials in `Secrets.plist`. Ensure the device/simulator has a valid network connection. |
| **CloudKit operations fail** | Confirm the container identifiers in `Secrets.plist` match those configured in the Apple Developer portal. Regenerate provisioning profiles after changes. |
| **Location permissions denied** | Ensure the simulator/device has location services enabled and background location granted. Review `NSLocation*` usage descriptions for clarity. |
| **CI fails during format check** | Run `scripts/format.sh` locally and re-stage any modified files before pushing. |
| **Signing errors** | Make sure your developer team identifier is set in `Base.xcconfig` and that the correct provisioning profiles are installed. |

---

## Support

For questions or improvements:

- Open a GitHub issue describing the requested change or bug report
- Contact the iOS platform team at `ios@smarttripplanner.com`
- Review additional documentation in `PROJECT_SUMMARY.md` and `CONTRIBUTING.md`

---

Happy travels and happy shipping! ✈️🌤️
