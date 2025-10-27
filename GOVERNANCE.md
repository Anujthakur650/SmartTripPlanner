# Project Governance

SmartTripPlanner follows a lightweight governance model that emphasizes transparency, security, and code quality.

## Roles

- **Maintainers** — Own long-term roadmap decisions and approve releases.
- **Committers** — Trusted contributors with write access who can merge pull requests that meet the review and CI requirements.
- **Contributors** — Anyone in the community submitting issues, discussions, or pull requests.

Maintainers for this repository:

- @smarttripplanner/maintainers

## Decision Making

1. Product and technical decisions are proposed via GitHub issues or discussions.
2. Pull requests must include context describing the change, testing performed, and any follow-up work.
3. At least one maintainer approval is required for merge.
4. All required status checks (CI and CodeQL) must pass before merge.

## Branch Strategy

- `main`: Stable, production-ready branch. Protected with required reviews and status checks.
- `develop`: Integration branch for upcoming releases. Feature branches merge here first.
- Feature branches are named using the pattern `<type>/<short-description>` (e.g., `feature/interactive-map`).

## Branch Protection Rules

The following rules are enforced on `main` via repository settings:

- ✅ Require pull request reviews (minimum 1, code owner review enforced).
- ✅ Require status checks to pass before merging.
  - CI (`CI / Build and Test`)
  - CodeQL (`CodeQL Analysis`)
- ✅ Require branches to be up to date before merging.
- ✅ Block force pushes and branch deletions.

## Release Process

1. Merge approved changes into `main` with an updated `CHANGELOG.md` entry.
2. Tag releases using semantic versioning (`vX.Y.Z`).
3. Publish release notes summarizing key features, fixes, and security improvements.

## Escalation

- Security issues: [security@smarttripplanner.com](mailto:security@smarttripplanner.com)
- Code of Conduct violations: [conduct@smarttripplanner.com](mailto:conduct@smarttripplanner.com)
- General governance questions: open a discussion in the repository.
