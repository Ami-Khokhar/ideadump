# iOS launch legal and privacy review

## Status

This is a launch checklist, not legal advice. Complete the owner and counsel items before App Store submission.

## 1. Product name and intellectual property

- [ ] Choose the final product name before release.
- [ ] Search Apple App Store results, trademark registers in every launch market, domains, and relevant social handles.
- [ ] Have qualified counsel assess confusingly similar marks before adopting the name.
- [ ] Replace `TapLog` and `taplog` in the bundle identifier, App Group, extensions, App Intents, deep links, metadata, screenshots, support materials, tests, and documentation after clearance.
- [ ] Keep written records of clearance searches and ownership of code, design, copy, and purchased assets.
- [ ] Review third-party and open-source licenses and preserve required notices.

## 2. Privacy and data-flow verification

- [ ] Make a production data inventory before completing App Store Connect App Privacy answers.
- [ ] Confirm whether expenses, notes, categories, device identifiers, diagnostics, analytics, crash reports, account data, backups, or purchase data leave the device.
- [ ] Confirm whether iCloud, CloudKit, App Groups, Siri, Shortcuts, widgets, share extensions, StoreKit, analytics, or crash-reporting SDKs are enabled in the production build.
- [ ] Verify that every public statement such as “local”, “offline”, “private”, or “your data stays on your device” matches the shipped build.
- [ ] Explain export, deletion, reset, backup, restore, and retention behavior in plain language.
- [ ] Publish a privacy policy at a stable public URL before submission.
- [ ] Keep the privacy policy, App Store privacy answers, onboarding, support page, and in-app copy consistent.

## 3. App Store legal materials

- [ ] Provide a monitored support email and public support URL.
- [ ] Add a public privacy-policy URL in App Store Connect.
- [ ] Decide whether to use Apple’s standard EULA or a custom EULA.
- [ ] If using custom terms, publish terms of use with governing-law and contact details reviewed for the launch markets.
- [ ] Complete age rating, content declarations, encryption/export-compliance, and App Review notes accurately.
- [ ] Ensure review notes explain offline use, widgets, Siri/Shortcuts, Action Button behavior, share extension behavior, and any paywall or restore-purchase path.

## 4. Payments, tax, and consumer disclosures

- [ ] Decide whether the app is free, paid once, or uses an in-app purchase/subscription.
- [ ] Configure matching App Store Connect products and test purchase, restore, cancellation, and entitlement behavior in Sandbox/TestFlight.
- [ ] State price, what is included, recurring billing terms, and restore-purchase behavior clearly in the app and store listing where applicable.
- [ ] Complete Apple tax, banking, and paid-app agreements using the legal entity that will receive proceeds.
- [ ] Obtain local tax and consumer-law advice for every launch market.

## 5. Pre-submission acceptance checks

- [ ] Counsel has reviewed the final name, privacy policy, terms, consumer disclosures, and launch markets.
- [ ] The production build has been checked on a real device with network disabled.
- [ ] Export, deletion/reset, backup/restore, widgets, Siri/Shortcuts, share extension, deep links, purchases, and restore purchases have documented test results.
- [ ] App Store metadata and screenshots contain no unverified privacy, security, financial, or feature claims.
- [ ] Support and privacy URLs load without authentication and contain current contact details.

## Owner inputs required

1. Launch countries and legal entity country.
2. Final product name after clearance.
3. Monetisation model and App Store Connect product IDs.
4. Production SDK and data-flow inventory.
5. Support email, support URL, and privacy-policy URL.
6. Apple Developer team and App Store Connect account owner.
7. Qualified counsel and tax adviser confirmation.

## Proposed follow-up branches

- `launch/name-clearance` for approved rename implementation.
- `launch/appstore-metadata` for final, verified App Store copy and review notes.
- `launch/support-pages` for hosted privacy, terms, and support materials.
- `launch/storekit` for purchase and restore-purchase coverage.
- `launch/testflight` for release validation evidence.
