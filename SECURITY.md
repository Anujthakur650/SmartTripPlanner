# Security Policy

## Supported Versions

Security fixes are applied to the `main` branch. Please ensure you are running the latest commit on
`main` or the most recent tagged release when evaluating security fixes.

## Reporting a Vulnerability

If you discover a vulnerability, please email `security@smarttripplanner.example` with the details.
For the fastest triage:

1. Provide a clear description of the issue and the potential impact.
2. Include step-by-step reproduction instructions, sample data, or proof-of-concept code where
   available.
3. Indicate whether the vulnerability has been disclosed elsewhere.

The maintainers will acknowledge receipt within **two business days** and provide a status update
within **five business days**. Public disclosure will only occur once a fix has been released or a
reasonable mitigation has been documented.

## GitHub Security Features

The repository uses the following GitHub security programs:

- **Code scanning (CodeQL)**: Automated scans run on pull requests and the main branch to detect
  common security vulnerabilities.
- **Dependency updates (Dependabot)**: Automatic security and version updates for GitHub Actions and
  Swift dependencies to ensure timely patching.
- **Secret scanning**: Alerts maintainers when potential credentials are accidentally committed.
- **Vulnerability reporting**: Coordinated disclosure is enabled so external researchers can submit
  reports privately via GitHub.

If you require encrypted communication, mention it in your initial message and we will respond with a
PGP key.
