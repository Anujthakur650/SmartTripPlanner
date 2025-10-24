# App Store Assets & Submission Checklist

Use this checklist before archiving the production build and submitting to App Store Connect.

## Marketing Assets
- [ ] App icon (1024×1024 PNG, no transparency)
- [ ] iPhone 6.7" screenshots (min 3, max 10)
- [ ] iPhone 6.1" screenshots (min 3, max 10)
- [ ] Optional iPad screenshots if iPad is supported
- [ ] App preview video (optional) adhering to App Store specs
- [ ] Promotional text and subtitle (less than 30 characters)
- [ ] Keywords list and support URL updated

## Privacy & Compliance
- [ ] Info.plist usage descriptions reviewed (Location, Calendar, Photo Library)
- [ ] Privacy manifest published (PrivacyInfo.xcprivacy)
- [ ] In-app privacy controls verified (analytics, personalization, diagnostics, background refresh)
- [ ] Data deletion workflow tested end-to-end
- [ ] App privacy responses aligned with in-app settings

## Build Validation
- [ ] Background fetch tasks registered and scheduled successfully
- [ ] Manual sync triggered from Settings without error
- [ ] Diagnostics opt-in toggles analytics logging as expected
- [ ] Settings legal links open to the latest policy pages
- [ ] In-app review prompt tested on device (use TestFlight build)

## App Store Connect Submission
- [ ] Incremented build number and version in Xcode
- [ ] Archived release build signed with production certificate
- [ ] Uploaded via Xcode Organizer (App Store Connect > TestFlight)
- [ ] Completed App Privacy questionnaire matches manifest declarations
- [ ] Internal testers assigned and release notes updated

Document completion of each item when preparing the TestFlight submission for Task 16.
