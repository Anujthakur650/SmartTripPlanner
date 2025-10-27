# Security Policy

## Supported Versions

The `main` branch of SmartTripPlanner is actively supported. All security fixes are released through pull requests targeting `main`.

| Version | Supported |
| ------- | --------- |
| main    | ✅        |
| develop | ✅        |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. Email the security team at [security@smarttripplanner.com](mailto:security@smarttripplanner.com).
2. Provide a detailed description of the issue, including reproduction steps and any potential impact.
3. Allow up to 72 hours for an initial response. Critical issues are triaged immediately.
4. Avoid publicly disclosing the vulnerability until a fix has been released.

## Security Checks & Automation

To prevent regressions, every pull request must pass:

- **CI** (`.github/workflows/ci.yml`): Builds the app, runs unit tests, and enforces SwiftLint/SwiftFormat.
- **CodeQL** (`.github/workflows/codeql.yml`): Performs static analysis for Swift vulnerabilities.

Branch protection rules require these checks to be green before merging to `main`.

## Responsible Disclosure

The SmartTripPlanner team follows Coordinated Vulnerability Disclosure best practices. We appreciate the community's help in keeping the project secure and will credit researchers who report issues responsibly once a fix is available.
