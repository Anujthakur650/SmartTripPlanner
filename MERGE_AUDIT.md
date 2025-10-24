# SmartTripPlanner Merge Audit

_Audit date: 2025-10-24_

## Current Repository State
- **Current branch:** `audit-merge-sync-cto-prs-merge-audit`
- **Main HEAD:** `378015f` – merge of task7 (_map search/POIs/routing_). No other recent task branches are present on `main`.
- **Workspace:** clean checkout; no uncommitted changes.
- **CI:** `.github/workflows/ci.yml` targets macOS 14 runners with Xcode 15.2. CI cannot be validated in this Linux environment; a run needs to be triggered on GitHub Actions after merges.
- **Key gap:** `main` is missing the modular workspace, persistence layer, design system, and feature work completed in later CTO branches. Those branches diverge from `main` and require manual integration.

## Branch & PR Review

| Branch | Last Commit | Scope (from commit) | Status / Notes | Next Action |
| --- | --- | --- | --- | --- |
| `chore/init-swiftui-workspace-modules-ci-fastlane` | e99295b | Initialize modular SwiftUI workspace, scripts, CI wiring | **Blocked.** Adds `.remote.git`, SPM `Modules/` packages, and updates configs that conflict with the existing single-target project. Needs architectural decision before merge. | Decide whether to adopt the modular layout. If yes, drop `.remote.git` artifacts, reconcile Xcode project, re-run CI on GH. |
| `feat/bootstrap-smarttripplanner-ios-setup` | 6c43c41 | Bootstrap app structure with automation | **Obsolete.** Based on pre-task7 history; merging would roll back map feature work now on `main`. | Close/delete branch after confirming no unique assets are needed. |
| `feature/task2-data-model-cloudkit-sync` | 0b57696 | SwiftData + CloudKit sync layer, persistence schema, unit tests | **Pending merge.** Adds new `Persistence/` module, updates `DependencyContainer` and `SyncService`. Will conflict with later branches touching the same types. | Rebase onto latest main, resolve `DependencyContainer.swift`/`SyncService.swift`, update project file with Xcode, run tests. |
| `feat/task4-trips-list-create-import-ics-pkpass-offline` | 4abdcec | Trip list CRUD, ICS/PKPass import, offline persistence | **Pending merge.** Introduces extensive Trips UI, repository, and tests. Heavy edits to `TripsView` and project file; overlaps with tasks 8/12/13/16. | Stage after task2 merge, resolve `TripsView` + dependency wiring, re-run tests. |
| `task7-map-search-pois-routing` | 15be9b1 | Map search, POIs, routing, offline maps groundwork | **Merged.** Diff against `main` is empty; branch can be deleted. | Delete remote branch. |
| `feat/task-6-day-planner-dnd-undo-redo-persistence-sync-quick-add` | d74d94b | Day planner models/view model, DnD, undo/redo | **Pending merge.** Adds planner repository/services and tests. Conflicts expected in `PlannerView`, `DependencyContainer`, and project file. | Merge after trip data layer; coordinate planner state with persistence once task2 is in. |
| `feat/task-8-weatherkit-packing-list-cache-sync-tests` | efa0b40 | WeatherKit integration, packing list automation, caching | **Pending merge.** Touches `TripsView`, `PackingView`, core trip models, and adds Weather services. Overlaps with tasks 4, 6, 13. | Merge after planner; reconcile shared view models/stores, ensure WeatherKit keys and tests updated. |
| `feat/task-10-document-storage-scan-viewer-metadata` | 6edaafe | Document vault, scanning/import workflow, metadata extraction | **Pending merge.** Adds numerous Docs components/services, updates `DocsView`, Info.plist entitlements. Conflicts with tasks 13 & 16 which also touch Docs UI. | Rebase after earlier features, resolve `DocsView`/project.pbxproj, verify entitlements in Info.plist. |
| `feat/task-12-gmail-oauth-import-email-parsing` | c4a1d90 | Gmail OAuth integration, email parsing, import review UI | **Pending merge.** Adds `EmailService`, updates `TripsView`, README. Conflicts with tasks 4/8/13/16 in Trips UI and DependencyContainer. | Merge after documents; ensure OAuth secrets handling, reconcile Trips UI changes. |
| `feat-task-13-exports-pdf-gpx-itinerary-ui` | a656fda | PDF & GPX export services plus Exports UI | **Pending merge.** Adds `ExportsView`, expands `TravelModels`, updates multiple feature views and services. Overlaps with design system + packing/trip views. | Sequence late; resolve shared view styling with design system branch, verify ExportService APIs. |
| `feat/task-14-offline-maps-ios17-regions` | 5fdc9d4 | Offline map regions, map service enhancements | **Pending merge.** Reworks `MapView`, `MapViewModel`, analytics service; overlaps with design system branch (UI) and task16 (service tweaks). | Merge near the end; coordinate map UI changes with design system adjustments. |
| `feat-design-system-tokens-ui-library` | 1663db1 | Design tokens, preview catalog, shared UI components | **Pending merge.** Major refactor of feature views to new design system. Touches the same screens modified in tasks 4/6/8/10/12/13/14/16. | Establish design direction, merge once feature branches are aligned, run through SwiftUI previews/tests. |
| `feat/task-16-app-hardening-privacy-settings-appstore-readiness` | f82738a | Privacy manifest, settings overhaul, localization infra, background refresh | **Pending merge.** Adds `AppDelegate`, localization resources, new services, expands settings UI. Conflicts with Docs/Trips updates and design system. | Final merge after earlier features; resolve Info.plist/localization strings, verify background tasks on device. |

## Blockers & Observations
- **Shared touchpoints:** `SmartTripPlanner.xcodeproj/project.pbxproj`, `Core/DependencyContainer.swift`, `ContentView.swift`, `Features/Trips/TripsView.swift`, `Features/Docs/DocsView.swift`, and `Features/Planner/PlannerView.swift` are updated across many branches. Manual reconciliation in Xcode is required.
- **Large file additions:** Multiple branches add entirely new directories (`Persistence`, `Services/Trips`, `Services/Exports`, `DesignSystem/Components`, etc.). Ensure they are all referenced in the Xcode project when merging.
- **Environment constraints:** Document scanning, Gmail OAuth, WeatherKit, and background refresh features require entitlements and secrets management. These will need validation once merged.
- **Outdated branches:** `feat/bootstrap-smarttripplanner-ios-setup` predates task7 and should be closed to avoid regressions.

## Recommended Next Actions
1. **Decide on architecture baseline.** Confirm whether to adopt the modular workspace from `chore/init-swiftui-workspace-modules-ci-fastlane` or remain on the current single-target app before merging other branches.
2. **Sequence merges.** Suggested order after architectural alignment: task2 ➝ task4 ➝ task6 ➝ task8 ➝ task10 ➝ task12 ➝ task13 ➝ task14 ➝ design system ➝ task16, with `task7` deleted and bootstrap branch closed.
3. **Use Xcode for conflicts.** Resolve `project.pbxproj` and asset catalog merges in Xcode on macOS, ensuring all new files are part of the build.
4. **Run CI on macOS.** Trigger GitHub Actions after each major merge to validate SwiftLint/SwiftFormat, build, and unit tests. Address any lint/test failures promptly.
5. **Secrets & provisioning.** Prepare `.env`/Secrets.plist updates for WeatherKit, Gmail OAuth, background fetch, etc., before enabling features.
6. **Branch hygiene.** After successful merges, delete remote branches to keep the repo tidy as requested.

## Outstanding Blockers Summary
- Significant manual merge work is required across overlapping SwiftUI views and shared services. Without resolving these conflicts, `main` cannot pick up the pending features.
- CI verification is pending and must be executed on GitHub Actions once merges are staged.

Once the above blockers are addressed, we can proceed with opening PRs for each staged merge, ensure CI is green, and tidy the branch list.
