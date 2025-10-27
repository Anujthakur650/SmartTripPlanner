# Merge Audit

## Summary of Changes

- Refactored `MapView` by extracting helper views into dedicated files and moving section logic into
  private extensions, reducing the type body to conform with SwiftLint limits.
- Added missing `CoreLocation` import and corrected the `SavedRouteRow` initializer usage to resolve
  compile-time errors introduced in previous refactors.
- Introduced dedicated view files: `RouteSummaryView`, `SavedRouteRow`, `SavedRouteSummaryCard`, and
  `AssociationEditorView`, and registered them in the Xcode project.
- Established repository health tooling:
  - Enabled weekly Dependabot updates for Swift packages and GitHub Actions.
  - Added a CodeQL code scanning workflow.
  - Added community and security documentation (Code of Conduct, Security Policy, issue and PR
    templates).
- Updated the README with current project health information and links to the new governance docs.

## Testing

- Not run (covered by CI via `swiftlint`, `swiftformat`, `xcodebuild`, and unit tests on merge).

## Security & Operations

- Branch protection for `main` must require CI (lint, format, build, tests) and CodeQL checks before
  merge. Configure these rules in GitHub settings if not already enforced.
- GitHub Advanced Security features (code scanning, secret scanning, Dependabot alerts, coordinated
  vulnerability disclosure) should be verified in the repository settings to ensure alerts are
  delivered.
- Vulnerability reports should be directed to `security@smarttripplanner.example` per `SECURITY.md`.
