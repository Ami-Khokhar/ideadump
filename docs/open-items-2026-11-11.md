# TapLog — open items

Only open work lives here. Finished work is recorded in the commits, the decision
log and the issue history; this file does not keep a log of it.

Live state, 11 November 2026:

| Fact | Value |
|---|---|
| Open issues | #96 (owner inputs and store gates); the issue tracker is authoritative for any follow-up to this document |
| Automated checks | 512 executed, 0 failures, 11 Nov 2026 15:34 IST (local run) |
| Engineering and legal gates | 0 of 20 closed (`docs/release-runbook.md`) |
| Submission checklist | 20 proven, 61 open as of 12 Oct 2026 (`docs/appstore-readiness-checklist.md`) |

## Owner inputs — six, and nothing else unblocks without them

- [ ] Support email, replacing `SUPPORT_EMAIL` in `appstore/support.html` and
      `appstore/privacy-policy.html`.
- [ ] Two hosted HTTPS URLs. `appstore/metadata.md` marks both rows *Needed* — host
      each page and paste its address; the listing cannot ship without them.
- [ ] App Review contact: name, email, phone.
- [ ] Provisioning under the paid team already in `project.yml` (`FKM4DL483M`): the
      app and both extensions registered with the App Group
      `group.dev.amteshwar.taplog`, a signed archive built with it, and that
      archive's entitlements inspected. The in-tree team flip is done; provisioning,
      signing and the archive inspection remain.
- [ ] Pro price, launch countries, and the `siri` keyword decision (guideline 2.3.7).
- [ ] Legal decisions L1–L8 from `docs/release-runbook.md`: enrollment, Paid Apps
      Agreement, W-8BEN, bank, EU DSA trader status, trademark, jurisdiction review,
      IAP attached to version 1.0.

## Signing, TestFlight and App Store Connect — seven

- [ ] S1–S2 of `docs/release-runbook.md`: a signed Release build of the app and both
      extensions with the archive entitlements inspected; Xcode 26 / iOS 26 SDK
      minimum.
- [ ] `docs/signed-build-testflight-runbook.md` steps 1–6 and 8: regenerate and verify
      after any `project.yml` edit (including the build-number bump), provision, confirm
      the App Group, archive, inspect the archive, validate and upload, then install the
      processed build through TestFlight. Step 7 is the paywall screenshot, tracked with
      the listing items below.
- [ ] App Store Connect: app record, product `dev.amteshwar.taplog.pro.lifetime`,
      agreements, tax and banking, regional availability, privacy answers.
- [ ] Current age-rating questionnaire (the post-31 Jan 2026 system; 4+/9+/13+/16+/18+
      or Unrated).
- [ ] First non-consumable submitted with version 1.0, with a review screenshot.
- [ ] Screenshots: 1320×2868, opaque, current UI, no misleading sample data.
- [ ] Listing accuracy: no unmeasured speed claim, no absolute “100% offline”,
      StoreKit's network use described, backup inclusion stated as
      configuration-dependent.

## Hardware pass — two

- [ ] The ten sections of `docs/physical-device-qa-sheet.md`: core capture and
      persistence, Siri, Action Button, widgets, share sheet, storage and upgrade
      paths, export, purchase and restore, notifications, accessibility.
      Four merged fixes still have no hardware evidence: #63 widget totals,
      #65 share parsing, #64 Siri category, #60 splash from the widget.
- [ ] Measure capture speed on hardware for each route, or keep the five-second claim
      out of the listing. No route has a measured number today.

## Repo hygiene — two

- [ ] Decide whether agent tooling belongs in the repo: `.agents/`, `agent/`,
      `.claude/` and `skills-lock.json` are untracked and unignored.
- [ ] One Release build for generic iOS on the reconciled branch, to confirm no
      warnings regressed. The newest recorded Release build is 12 Oct
      (`docs/review-evidence/readiness-12oct/final-release.log`, zero warnings);
      rebuild the reconciled revision.

## Order of work

1. The six owner inputs, because the store work needs them.
2. Signing and TestFlight, because the hardware pass runs against the processed
   build.
3. The phone pass, which produces the only evidence that matters for submission.
4. Repo hygiene, which fits alongside any of the above and blocks nothing.

Apart from the Release build above, nothing in this file can be closed by an agent: the
rest needs the owner, an adviser, an account or a device. `docs/release-runbook.md` states it
plainly: no gate in that list has been closed, and a row with no artifact is not
tested.
