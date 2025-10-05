# App Store Submission Checklist

## Build & Assets
- [ ] Archive with Xcode 15 or newer using the `Release` configuration.
- [ ] Verify signing certificates and App Store provisioning profiles from your Apple Developer team.
- [ ] Update `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` prior to upload.
- [ ] Re-run the unit test suite (`Cmd+U`) and smoke test on a physical device.
- [ ] Capture new 6.7", 6.5", 5.5", and iPad screenshots plus an App Preview video if desired.

## Privacy & Compliance
- [ ] Complete the privacy questionnaire in App Store Connect (photos stored locally, link previews fetched via HTTPS, optional notifications, keychain passcode uses encryption).
- [ ] Provide an accessible privacy policy URL explaining on-device storage and encryption usage.
- [ ] Answer export-compliance questions (app uses standard encryption for authentication only).

## Reviewer Notes
- [ ] Include instructions for testing the passcode flow (e.g., demo account or test steps).
- [ ] Mention optional notification prompts and that the app functions without them.
- [ ] Describe any mock data or login requirements.

## Post-Upload
- [ ] Validate the `.ipa` via Xcode Organizer/Transporter before submitting.
- [ ] Ship a TestFlight build to internal/external testers for final sign-off.
- [ ] Prepare marketing copy, keywords, support URL, and contact information in App Store Connect.
