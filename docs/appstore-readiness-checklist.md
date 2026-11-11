# TapLog submission checklist

Updated 12 October 2026 IST by the readiness pass recorded at the end of this file, and
corrected on 11 November 2026 for the signing team. The
previous pass's code fixes are in [release-fix-results.md](release-fix-results.md). External
submission/device checks remain pending.

Reviewed 11 October 2026 IST, re-audited 12 October 2026 IST. Scope: this working tree, not
just HEAD. Assumption: launch the existing local-first iPhone app with a free tier and one
non-consumable Pro purchase. No backend or sync is required for this launch.

Status: **not ready to submit**. Missing = confirmed repository gap. Verify = evidence
unavailable, not proof something is absent. Ready = repository evidence only unless
explicitly runtime-tested. `[x]` means the item's full requirement is proven and the
evidence is named. An item with partial coverage stays unchecked and says what is proven
and what is not. This checklist supersedes dated readiness assertions in README/build-plan
and does not repeat the older checklist's legal/tax conclusions as verified facts.

## Status at a glance (12 October 2026)

- **20 proven, 61 open.** Every open item names its missing input, its external check, or
  both; the audit below was refreshed against source on 12 October 2026.
- **Order of work**, once the owner inputs below arrive:
  1. Support email + two HTTPS URLs, then publish and check the pages on a phone
     (runbook step 0, checklist "Release blockers first").
  2. The paid team is already in `project.yml`; raise `CURRENT_PROJECT_VERSION`, then run
     [signed-build-testflight-runbook.md](signed-build-testflight-runbook.md) steps 1–6 and 8
     (step 7 is the paywall screenshot, tracked with the listing items below).
  3. Install the processed build and work through
     [physical-device-qa-sheet.md](physical-device-qa-sheet.md).
  4. Finish App Store Connect (product, agreements, tax/banking, age rating, screenshots,
     review contact) and submit with explicit authorization.
- **Only the owner can supply:** support email, hosting URLs, review contact, provisioning
  and signing under the paid team already in `project.yml`, the keyword decision (`siri`
  under guideline 2.3.7), the Pro price and launch
  countries, and the paid-account/tax conclusions.
- **Only Apple's servers can prove:** App Store Connect records, agreements, product load
  from the real store, archive validation, TestFlight processing and sandbox purchase.
- **Only a physical device can prove:** Siri, Action Button, widgets, share sheet,
  locked-device behavior, persistence across processes, real export files and accessibility
  with VoiceOver/Reduce Motion/high contrast.
- Local evidence for everything proven here: `docs/review-evidence/readiness-12oct/`
  (test and Release logs) and `docs/review-evidence/` (previous pass).

## Release blockers first

- [x] **Fixed in code:** Settings opens an offline Privacy Policy screen. Native simulator
  navigation/rendering verified in the previous pass; the source is
  `Sources/TapLog/Settings/PrivacyPolicyView.swift` and the Settings row is present in the
  12 October Settings capture (`docs/review-evidence/readiness-12oct/max-settings-light.png`). The public metadata policy URL remains pending.
- [ ] **Missing from listing:** final hosted support and privacy URLs. Local HTML exists but
  metadata marks both URLs *Needed* and both pages still contain `SUPPORT_EMAIL`.
  - **Proven 12 Oct:** policy wording checked against the app's actual behavior
    (`docs/review-evidence/readiness-12oct/`); restore and export instructions and the
    Action Button steps are accurate against the registered shortcuts; the support page now
    states that CSV import does not exist. Nothing is published and no page was uploaded.
  - **Missing:** the real support email and two HTTPS hosting URLs. Add them, then check
    mobile rendering, that no login is required, and that the contact route works. Hosting
    outside the repo is unknown.
- [ ] **Current configuration:** the paid team `FKM4DL483M` is in the tree, re-checked
  11 November 2026 against `project.yml` and the generated project. Provision the app and
  both extensions, then inspect a signed archive.
  - **Proven 12 Oct:** `project.yml` then set `DEVELOPMENT_TEAM: 87VL9T9A8H` (personal)
    while the committed project was generated with `FKM4DL483M`; the archive commands are
    in [signed-build-testflight-runbook.md](signed-build-testflight-runbook.md).
  - **Missing:** provisioning of the app and both extensions with the same
    registered App Group in the paid team, and inspection of the signed archive's
    entitlements. The archive inspection needs the owner's signed build; no account change
    is left to make.
- [x] **Fixed and tested:** original P1 code findings addressed with production regressions.
  Final combined simulator suite and unsigned Release passed. Physical-device integration
  remains pending. See `docs/release-fix-results.md` and the re-run below.
- [ ] **Verify:** App Store Connect app record, product, agreements, tax/banking and regional
  availability. A local StoreKit file does not prove any of these exist.
  - **Proven 12 Oct:** the local `.storekit` file is used only by the Debug run scheme
    (`TapLog.xcscheme` LaunchAction) and is not referenced by the project or included in the
    Release bundle.
  - **Missing:** all Apple-server state, including whether the product exists.
- [ ] **Verify:** Release archive validation/upload and TestFlight installation. Runbook
  prepared; nothing was archived, validated or uploaded.
- [ ] **Verify:** hands-on physical-device capture and sandbox purchase/restore. Simulator
  unit tests are insufficient evidence for these integrations. QA sheet:
  [physical-device-qa-sheet.md](physical-device-qa-sheet.md).
- [x] **Local release baseline:** source snapshot and reviewed fixes are committed on
  `release/readiness-fixes` (commit `92fcd99`, worktree `/private/tmp/taplog-release-fixes`).
  Verified changes are applied to this checkout while existing user edits remain intact.
  This pass adds uncommitted changes in this checkout (branch `budget-trees-redesign`) and a
  regenerated project; signed distribution from the final revision remains pending.

## Account, identifiers and commercial setup

- [ ] Verify active paid membership and correct Account Holder/team. Confirm renewal and
  ability to distribute. **Missing:** Apple account access; not inspected.
- [ ] Register/confirm explicit identifiers `dev.amteshwar.taplog`, `.widget`, `.share` and
  `group.dev.amteshwar.taplog`. Check App Group capability on all targets. Avoid renaming
  identifiers after customers acquire purchases.
  - **Proven 12 Oct:** all three identifiers and the App Group ID appear consistently in
    `project.yml`, the three entitlement files, `StoreLocator.appGroupID` and the unsigned
    Release bundle's Info.plists (`dev.amteshwar.taplog`, `.widget`, `.share`; group
    `group.dev.amteshwar.taplog` on all three targets). A test pins the group ID against the
    entitlements files.
  - **Missing:** registration and capability state in the developer portal.
- [ ] Verify app record uses the intended bundle ID, available name, primary language, SKU
  and ownership. **Missing:** App Store Connect access.
- [ ] Verify current required agreements. For paid Pro, complete Apple's required paid-app,
  tax and banking setup. Account Holder completes legal signatures. **Missing:** account
  access; `project.yml` comments are not evidence.
- [ ] Choose launch countries and app price Free. Configure lifetime Pro price per storefront.
  Confirm taxes/currency in App Store Connect. **Missing:** App Store Connect access. The
  local test file's $4.99 is a placeholder, not storefront pricing.
- [ ] Declare accurate DSA trader status and complete required verification for EU
  availability. Review public contact information deliberately. **Missing:** account access
  and the owner's distribution decision.
- [ ] Verify content rights, copyright and support-contact ownership. **Missing:** owner
  decisions (the draft says "2026 Amteshwar Singh Khokhar").

## Build, signing and package

- [x] Local simulator build and unit suite passed on the current worktree.
  - **Proven 12 Oct:** full TapLog scheme, 430 test executions, zero failures, started
    14:47:48 IST (final run after the fixes below; see
    `docs/review-evidence/readiness-12oct/final-tests.log`). Exact command in
    "Verification".
- [x] Deployment target is iOS 17 and device family is iPhone. Installed Xcode is 27.
  - **Proven 12 Oct:** unsigned Release bundle reports `MinimumOSVersion 17.0`,
    `DTSDKName iphoneos27.0`, `UIDeviceFamily [1]` on the app and both extensions.
- [x] Regenerated a disposable current-worktree copy with XcodeGen 2.46.0. Regeneration is
  deterministic: a diff against the working project showed only the new file this pass added.
- [x] Unsigned Release build for generic iOS passed.
  - **Proven 12 Oct:** `xcodebuild ... -configuration Release -sdk iphoneos ...
    CODE_SIGNING_ALLOWED=NO build` succeeded at 14:38 IST with zero `warning:` lines. A
    no-sign build is compilation evidence, not distribution validation.
- [ ] Create a properly signed archive with paid-team profiles. Confirm extension embedding,
  version/build alignment, app/extension identifiers, App Group entitlements and distribution
  signing. **Missing:** paid-team provisioning. Exact commands:
  [signed-build-testflight-runbook.md](signed-build-testflight-runbook.md).
- [ ] Increase build number for every upload. Keep marketing version/build synchronized
  across app and extensions. **Missing:** the edit itself; one setting
  (`CURRENT_PROJECT_VERSION` in `project.yml`) versions all three, currently `1`.
- [x] Inspected unsigned Release app/widget/share package.
  - **Proven 12 Oct:** all three bundles carry a `PrivacyInfo.xcprivacy`; identifiers and
    versions align (`1.0` / `1`); iOS 17 minimum; iPhoneOS 27 SDK; iPhone-only device family
    (fixed this pass — the extensions previously declared iPad family `1,2`);
    `ITSAppUsesNonExemptEncryption=false`; app icon has no alpha at 1024 px; no third-party
    frameworks or Swift packages. Archive validation and visual asset review remain unchecked.
- [x] Confirm debug-only seed/navigation hooks stay out of Release, and no test configuration
  supplies a fake product to the uploaded app.
  - **Proven 12 Oct:** the Release binaries contain none of `-seedSampleData`, `-autolog`,
    `-onboarding`, `-route`, `-editCategory`, `-appearance`, "Seed sample data" or
    "DebugSeeder"; the Debug build contains all of them (negative control on the same scan).
    No `.storekit` file exists anywhere in the Release products, and `TapLog.storekit` is
    referenced only by the scheme's LaunchAction, not by the project or bundle.
- [ ] Validate archive in Organizer. Upload, wait for processing, and resolve
  warnings/errors. Preserve dSYMs and archive with the release revision. **Missing:** signed
  archive and Apple-server step.
- [ ] Test minimum supported OS, current stable OS, and smaller/larger supported iPhone sizes.
  - **Proven 12 Oct:** iPhone SE (3rd generation, 4.7-inch, iOS 26.5 simulator) and iPhone 17
    Pro Max (6.9-inch, iOS 26.5 simulator) at base and accessibility-XXXL text sizes. No iOS
    17–18 runtime is installed on this Mac, so minimum-OS runtime verification is still
    missing, as is any physical device.

## Privacy, security and data policy

- [x] Privacy manifests exist for app and both extensions and the project references them.
  UserDefaults reasons are declared. Verified again 12 Oct in the unsigned Release bundle.
- [x] Inventory required-reason API use across all targets and dependencies.
  - **Proven 12 Oct:** source scan of all `Sources/` Swift for UserDefaults, file-timestamp,
    disk-space, system-boot-time and active-keyboard APIs found UserDefaults only (declared
    with `1C8F.1` and `CA92.1` in all three manifests). No third-party SDKs or Swift packages
    are linked. The archive/Connect privacy report cannot be compared until an archive is
    uploaded.
- [ ] Confirm App Privacy answers from actual behavior, including all SDKs.
  - **Proven 12 Oct:** the only network traffic in source is StoreKit (`Product.products`,
    purchase, `AppStore.sync`, transaction updates); there is no analytics, crash-reporting
    or third-party SDK. Description should name Apple's StoreKit and Siri processing rather
    than claim an absolute "no network".
  - **Missing:** the Connect questionnaire itself, and the archive privacy report.
- [ ] Publish final privacy policy and include accessible in-app link.
  - **Proven 12 Oct:** the in-app link exists and renders offline; the page's coverage of
    device storage, optional notifications, Siri processing, exports, deletion, backup and
    support contact is accurate except the unresolved support email.
  - **Missing:** publication (owner's email + HTTPS URL).
- [ ] Verify support page has a working contact route and tells users how to restore Pro and
  export data.
  - **Proven 12 Oct:** the page documents Action Button and Siri setup, `Settings → Restore
    purchase`, CSV export from `Recap → Export CSV`, and now states that CSV import does not
    exist. Wording matches the app.
  - **Missing:** a working contact route (`SUPPORT_EMAIL` placeholder) and a live URL.
- [ ] Explain uninstall/device-loss risk and whether system device backups can include records.
  - **Proven 12 Oct:** the privacy page says a backup's inclusion depends on the backup's
    configuration, that TapLog runs no backup or sync, and that deleting the app removes
    stored data. There is no CSV import, and the support page now says so.
  - **Missing:** a tested backup/restore claim for any specific configuration; no recovery
    promise has been made, and none should be made without testing.
- [ ] Test Delete All removes active, archived and pending entries, clears intended
  counters/notifications and cannot be undone by a stale session action.
  - **Proven 12 Oct:** `HistoryWipe` fetches every `Entry` (active, archived and pending),
    then commits, invalidates the undo stack and clears the widget receipt; it also resets
    category usage, `logsLogged`, streaks and the weekly notification. Covered by
    `ReleaseSettingsRegressionTests` (refused read, refused save, success ordering).
  - **Missing:** device-level verification, and the migrated-build case. The one-time heal
    copies (does not move) the fallback store into the App Group, so a retained fallback copy
    can still hold the same rows; if the App Group later becomes unavailable the app would
    open that copy again. Source guards do not establish device behavior for that path.
- [x] Check no expense notes, identifiers, receipt data or secrets appear in logs.
  - **Proven 12 Oct:** every `Log` call site carries a fixed label, an error domain/code from
    `Log.describe`, a file path, or counts. No `NSLog`, no `print`, no interpolation of
    amount, note, category name, receipt or credentials. Error descriptions are reduced to
    `domain code` precisely because Core Data userInfo can embed the record. No tracked-file
    secret scan was run; none is required by the release policy.
- [x] Validate all external inputs: deep links, Siri/widget amounts, share text, huge input,
  invalid numbers and spreadsheet formula cells.
  - **Proven 12 Oct:** deep links use a strict machine grammar (digits, one dot, ≤2 decimals,
    app cap; no grouping) and prefill only; Siri/widget amounts are validated twice — raw and
    after cent rounding — and rejected outside `(0, 999999999.99]`; share text is capped at
    4,096 characters and parsed conservatively (OTP/account/balance guards, multi-amount
    decline); the amount field caps length, fractions and the maximum; CSV neutralizes
    formula-leading characters including whitespace/control prefixes. All covered by tests.
- [ ] Test locked-device widget/intent behavior and visibility.
  - **Proven 12 Oct:** the share extension and widget refuse to write to an unshared store
    rather than silently losing a save; the recap notification contains no amount. Data
    protection behavior, Lock Screen visibility and locked-device intent execution are
    physical-device checks — see the QA sheet.
- [x] No account deletion workflow is needed while no account exists.
  - **Proven 12 Oct:** no sign-in, no server, no account model in source. ATT, bank-link
    permissions, remote push provisioning and backend uptime remain not applicable.

## In-app purchase and paid access

- [x] Code uses verified StoreKit transactions and a non-consumable product ID
  `dev.amteshwar.taplog.pro.lifetime`. Restore is exposed in Settings/paywall. Re-verified in
  source and by `ProStoreTests` on 12 Oct.
- [ ] Create/confirm exact product ID/type in App Store Connect, localization, price,
  availability, tax category and review screenshot. **Missing:** App Store Connect; the
  paywall review screenshot also needs a simulator tap (see runbook step 7).
- [ ] Attach the first IAP to the first app-version submission. Include reviewer instructions
  for both paywall entry points. **Missing:** submission step.
- [ ] On TestFlight/sandbox, product loads from Apple's server without local `.storekit`
  configuration and price uses the user's storefront. **Missing:** Apple server. Procedure:
  runbook step 8.
- [ ] Exercise successful purchase, cancel, pending/Ask to Buy, delayed transaction approval,
  interruption, unverified result, refund/revocation and network error.
  - **Proven 12 Oct:** every state has a distinct UI path and message in `ProStore`; unit
    tests pin the notice mapping and the no-false-charge wording.
  - **Missing:** Apple's sandbox and an Ask to Buy configuration; only a real StoreKit
    session can produce these results.
- [ ] Restore an existing purchase after reinstall and on another device. Restore with none
  must explain no purchase found. Verify signed-out and cancelled sign-in flows.
  - **Proven 12 Oct:** `restore()` reports "No previous purchase found on this Apple Account."
    when sync resolves nothing and "Couldn't reach the App Store to restore." on failure.
  - **Missing:** a real account, reinstall and second device.
- [ ] Confirm paid access survives cold launch/offline use and asynchronously resolved
  entitlements do not permanently block or accidentally reveal Pro.
  - **Proven 12 Oct:** `isPro` is derived only from `Transaction.currentEntitlements`, never
    persisted; the listener starts before the first refresh; an unverified transaction never
    unlocks; a verified one retires a stale pending notice.
  - **Missing:** a device with a real purchase and Airplane Mode, to prove cold launch and
    offline use from a receipt rather than from injected state.
- [x] Confirm free tier stays usable: unlimited capture and export, weekly recap, intended
  budget limit. Deleting a budget frees a slot. Editing an existing tree remains possible
  after revocation.
  - **Proven 12 Oct:** `ProGate.canExportCSV` is unconditional and has no gating call site;
    capture has no gate; the weekly recap is free (`canUseMonthlyRecap` gates Month only);
    the limit is 3 configured budgets, derived from the same reports the grove draws
    (deleting one restores the slot); editing a category that already has a target is never
    blocked. `ProGateTests` covers the boundary and revocation cases.
- [x] Check duplicate purchase/restore taps, repeated paywall presentation, Settings upgrade
  after unlocking, and transaction listener ownership.
  - **Proven 12 Oct:** `beginStoreOperation()` drops overlapping purchase/restore attempts and
    is released by `defer`; the paywall dismisses when `isPro` becomes true; the listener is
    owned by the `ProStore` singleton and started once. Family Sharing remains an owner
    decision (the product is marked family-shareable in the local test file only).

## Real-device functional QA

All items below need a physical device. [physical-device-qa-sheet.md](physical-device-qa-sheet.md)
is the shortened sheet for Siri, widgets, share sheet, persistence, export and
purchase/restore; the fuller scenarios remain in this list.

**Missing for every item in this section:** a physical device running the signed TestFlight
build. Simulator results do not count for any line here. The one input is named once instead
of sixteen times.

- [ ] Fresh install: welcome, first confirmed log, optional setup, relaunch midway,
  notification denial. No compulsory setup prevents a capture.
- [ ] Keypad: zero/negative rejection, amount cap, cents, pasted localized input, fast
  repeated taps, note/category edits, cancel and persistent save after force-quit.
- [ ] History: pending confirmation/edit/discard, archived views, delete/undo, filtering/search,
  blank states and large histories. Totals include exactly confirmed active entries unless
  labeled otherwise.
- [ ] Categories: add/rename/reorder/delete, deleting referenced categories, duplicate
  names/keys, budget editing and failure rollback. Historical attribution must remain honest.
- [ ] Siri and Shortcuts: missing parameters, category prompt, optional note/skip, cancelled
  dialog, custom shortcut, all advertised phrases, headless save, repeated invocation and
  locked device.
- [ ] Action Button: configure advertised shortcut on supported hardware and time successful
  capture. Check review notes match the actual action.
- [ ] Home widget: add all supported sizes, daily total, suggestions, one tap one durable save,
  rapid taps, undo receipt, currency changes, category deletion and midnight rollover.
- [ ] Lock Screen: circular/rectangular widgets open the correct route. Verify no blocked
  routing under lock/unlock.
- [ ] Control Center: add/run control on iOS 18+, ensure availability guards on iOS 17.
- [ ] Share sheet: Safari/Notes/Messages text, bank examples, OTP-only text, no amount,
  multiple numbers, localized decimal/currency, long text, failed save and pending-only
  totals. Confirm same shared store as the app.
- [ ] Deep links: cold/warm launch, while Settings/History is open, invalid route/amount,
  missing parameters, duplicate query keys and cancellation. A link prefills only and never
  silently logs.
- [ ] Persistence: app kill/relaunch, multiple processes writing, widget/share writes while app
  is foreground, upgrades from prior schemas, fallback-to-group migration, denied storage, low
  disk and store-open failure.
- [ ] Budgets/recaps: category totals, week/month boundaries, time-zone/DST changes, backdated
  entries, planned/impulse denominators, pending/archived exclusion, empty/over-budget states,
  target changes and Pro gates.
- [ ] Currency: chosen currency persists everywhere. Switching currency must clearly state how
  old entries are interpreted. Test zero-decimal currencies and export retains enough context
  to interpret amounts.
- [ ] CSV: free access, all confirmed historical rows including archived, no pending rows,
  escaping, Unicode, malicious formula prefixes, distinct simultaneous exports, actual opening
  in Numbers/Excel and identifiable currency.
- [ ] Notifications: granted/denied, scheduling after relevant log, Sunday delivery time, tap
  routes to recap, no misleading reminder after wipe. Local notifications require no remote
  push service.

## UX, accessibility and performance

- [ ] VoiceOver reads keypad/category/action buttons and exposes meaningful budget/recap
  summaries. Focus order and sheets work without vision.
  - **Proven 12 Oct:** accessibility labels exist in source for the amount, keypad delete,
    category tiles and their budget state, the intent control, budget rows and toolbar
    actions; decorative art is hidden from the accessibility tree.
  - **Missing:** a real VoiceOver run, which cannot be scripted with `simctl`.
- [ ] Dynamic Type including accessibility sizes, Reduce Motion, light/dark, high contrast,
  long category/note text and right-to-left locales if advertised.
  - **Proven 12 Oct:** base size on 4.7-inch and 6.9-inch screens; accessibility-XXXL on
    6.9-inch for capture, History, Budgets and Recap; light and dark appearance. Five layout
    defects were found and fixed (see "This pass"), and the two arithmetic invariants now
    have regression tests.
  - **Missing:** high-contrast mode, a real Reduce Motion toggle (`simctl` cannot set it;
    motion code paths were reviewed), long custom category/note text, and RTL — the app
    ships English strings only, so RTL is not advertised.
- [ ] Test scrolling, keyboard dismissal, safe areas, sheets and paywall purchase/restore
  buttons on smallest supported screen. No clipped price or hidden destructive confirmation.
  - **Proven 12 Oct:** the capture screen now fits above the pinned keypad at base size on a
    4.7-inch screen (previously the category row started half-visible); destructive Delete
    All confirmation verified in source and tests.
  - **Missing:** the paywall cannot be opened without a tap, so its small-screen layout was
    not re-checked this pass (the previous pass verified its loading/unavailable states on a
    6.9-inch simulator).
- [ ] Measure advertised capture speed on real hardware for each route. Record start/finish
  definition, device/OS and warm/cold launch separately. **Missing:** hardware; do not present
  the welcome screen's "about 5 seconds" as measured. It restates the `≤5 s` goal in
  `build-plan.md` and `investor-pitch.md` and is not a measurement; `README.md` carries no
  speed claim, only the two-or-three-taps premise.
- [ ] Profile realistic long-term data volume, fetch/query cost, animation work, widget memory
  and extension time limits. **Missing:** hardware and long-lived data.
- [ ] Verify offline core usage and notification/purchase failure messages without network.
  - **Proven 12 Oct:** offline paths have explicit copy — paywall "The App Store price isn't
    available right now." with Try again, restore "Couldn't reach the App Store to restore.",
    purchase failure wording that does not promise no charge. The in-app privacy policy is
    offline.
  - **Missing:** an airplane-mode device run.

## Listing and reviewer package

- [x] Draft metadata, privacy/support HTML and screenshot PNGs exist. Presence is not
  approval/readiness evidence. Re-confirmed 12 Oct.
- [ ] Replace the *Needed* URLs and review draft claims against actual Release behavior.
  - **Proven 12 Oct:** every functional claim in `appstore/metadata.md` was checked against
    source (3 free budgets, free weekly recap, free CSV export, widget one-tap save, share
    sheet, Siri phrases, Action Button, no account/server). Lengths re-counted and match the
    stated limits.
  - **Missing:** the URLs, and the owner's decision on the keyword `siri`. Guideline 2.3.7
    says not to pack metadata with trademarked terms; references to Siri in the description
    and review notes describe a real integration and read as functional, but the keyword
    field is search packing. Recommended: drop `siri` from keywords and keep it in the
    description. `action button` is a descriptive feature name, not a trademark.
- [x] Resolve Action Button review-note mismatch.
  - **Proven 12 Oct:** the registered shortcuts are "Log Expense" (headless,
    `openAppWhenRun=false`) and "Open Expense Capture" (opens the keypad), verified in
    `TapLogShortcutsProvider` and in the built app's App Intents metadata. The review notes
    and support page name both, with repeatable steps (Settings → Action Button → Shortcut →
    TapLog).
- [ ] Use current age-rating questionnaire and Apple's resulting regional ratings. Do not rely
  on old static 4+ advice. **Missing:** App Store Connect questionnaire.
- [ ] Review screenshot dimensions against current iPhone slots, visually inspect final
  captures, avoid sample data that misrepresents functionality, and regenerate if screens
  have changed. Current app is iPhone-only, so verify no unintended iPad requirement.
  - **Proven 12 Oct:** the three 1320×2868 PNGs are the current 6.9-inch slot size; visual
    inspection against fresh simulator captures showed the same screens and sample data;
    the app and both extensions are now iPhone-only in the built bundle.
  - **Missing:** regeneration of the composited marketing PNGs. The composition was produced
    outside this repo and no generator exists here; fresh raw 1320×2868 captures of the
    current UI are in `docs/review-evidence/readiness-12oct/` if the owner wants to re-frame
    them.
- [ ] Finalize name/subtitle/keywords/description, category, copyright, content rights, app
  availability, pricing and accessibility declarations if supplied. **Missing:** owner review
  and App Store Connect.
- [ ] Provide review contact details and exact steps to capture, open Month paywall, create
  another budget, restore, and test extensions.
  - **Proven 12 Oct:** `appstore/metadata.md` carries steps to reach both paywall entry
    points, both shortcuts, restore, and the share-sheet and widget extension checks. Every
    step was checked against the registered shortcuts and the app's own navigation.
  - **Missing:** the review contact email and phone (entered in App Store Connect). The
    steps themselves are already written.
- [x] Confirm encryption declaration `ITSAppUsesNonExemptEncryption=false` still reflects the
  final app/dependencies.
  - **Proven 12 Oct:** set in `project.yml`, present in the unsigned Release Info.plist, and
    the app links no third-party frameworks or Swift packages.

## Beta, submission and go-live

All items below require App Store Connect, a signed build or a physical device.

**Missing for every item in this section:** a signed upload plus App Store Connect access
(and, for submission and any real charge, explicit owner authorization).

- [ ] Install processed Release via TestFlight on real devices. Keep a short evidence log of
  flows, device/OS, build and defects. **Procedure:** runbook steps 9–11; recording sheet:
  physical-device-qa-sheet.md.
- [ ] Collect beta feedback on capture reliability and data preservation.
- [ ] Rebuild exact intended revision, rerun tests, archive/validate/upload final build,
  attach it and IAP, confirm all required Connect sections complete.
- [ ] Choose manual release if the owner wants to control launch timing. Submit only with
  explicit authorization. Preserve submission notes and any reviewer response.
- [ ] After approval, verify public support/privacy links, storefront price/product,
  download/install and a real purchase/restore if the owner authorizes a charge.
- [ ] Prepare update plan and retained archive. A previous App Store binary cannot simply be
  rolled back by source control. Critical fixes require a new build and review path.

## This pass — 12 October 2026

Repository work completed, in order.

### Audit and code review

- Audited every unchecked item above against source and the recorded evidence.
- Logging privacy: no user amount, note, category, receipt or secret reaches the log; error
  text is reduced to `domain code`.
- Input validation: deep links, Siri/widget amounts, share text and CSV formula prefixes all
  have explicit guards and tests.
- Deletion: `HistoryWipe` covers all entries and clears counters, notifications and the widget
  receipt; the retained fallback-copy caveat is recorded above.
- Free tier: export, unlimited capture and the weekly recap are ungated; the 3-tree limit
  frees a slot on delete; existing budgets stay editable.
- Entitlement handling: `isPro` derives from StoreKit only, starts listening before the first
  refresh, and never unlocks on an unverified transaction.
- Offline messages: paywall, restore and purchase have honest failure copy.

### Fixes with regression coverage

| Bug found | Fix | Regression evidence |
|---|---|---|
| Log label overflowed its 52 pt pill at accessibility text sizes | Capped the scaled headline in `CaptureBottomBar.logButtonFontSize` | `CaptureBottomBarTests` (cap binds; label still grows) |
| On a 4.7-inch phone the category row started half-visible | Reduced the two flexible spacer floors from 48/36 to 8/8 and added the fit invariant | Fit test failed at 337 > 291 pt with the old values, passes now |
| History rows wrapped letter-by-letter at accessibility sizes | Stacked row layout at accessibility sizes; amounts never wrap | Simulator captures before/after |
| Budget rows truncated the target amount ("₹22.00 / ₹15.…") and interleaved the status sentence | Stacked name/amount/status at accessibility sizes; `fixedSize` so the pair wraps instead of truncating | Simulator captures before/after |
| Recap banner and span control truncated at accessibility sizes | `fixedSize` on the banner text; title moved above the toggle; toggle height grows | Simulator captures before/after |
| Extensions declared iPad device family inside an iPhone-only app | `TARGETED_DEVICE_FAMILY: "1"` on both extension targets | Unsigned Release bundle reports `UIDeviceFamily [1]` for app, widget and share |

### Verification (commands and results)

- Baseline suite before changes: `xcodebuild test -project TapLog.xcodeproj -scheme TapLog
  -destination 'platform=iOS Simulator,id=310F05DC-8DC4-4B38-AFF4-D5970E5DF863'
  -parallel-testing-enabled NO -derivedDataPath <tmp> CODE_SIGNING_ALLOWED=NO` —
  423 test executions, zero failures, 12:27 IST.
- Final suite after all changes: same command, `-derivedDataPath /tmp/taplog-readiness/final-derived`
  — 430 test executions, zero failures, 14:47:48–14:47:49 IST. Source:
  `docs/review-evidence/readiness-12oct/final-tests.log`.
- Focused regression run: `-only-testing:TapLogTests/CaptureBottomBarTests` — 7 tests,
  zero failures. The fit test's failing-before state is kept in
  `docs/review-evidence/readiness-12oct/failing-before-fix-spacer-test.log` (337 pt content
  against a 291 pt viewport with the old spacer values).
- Unsigned Release after all changes: `xcodebuild -project TapLog.xcodeproj -scheme TapLog
  -configuration Release -sdk iphoneos -destination generic/platform=iOS -derivedDataPath
  <tmp> CODE_SIGNING_ALLOWED=NO build` — BUILD SUCCEEDED, zero warnings, 14:38 IST. Source:
  `docs/review-evidence/readiness-12oct/release-build-final.log`.
- Release bundle scan: debug hooks absent, no `.storekit` in products, privacy manifests on
  all three bundles, identifiers/versions aligned.
- Simulator UI: iPhone SE (3rd gen) and iPhone 17 Pro Max, iOS 26.5, Debug build with the
  debug-only `-seedSampleData` and `-route` hooks; light, dark and accessibility-XXXL
  captures in `docs/review-evidence/readiness-12oct/`.
- Not run, by design: any Apple-account change, archive, upload, purchase, signature, page
  publish or merge.

## Primary sources checked

- [Apple upcoming requirements](https://developer.apple.com/news/upcoming-requirements/):
  tooling, updated ratings, required-reason APIs and regional trader requirements.
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/):
  completeness, IAP, metadata accuracy (2.3.7 re-read 12 October 2026) and accessible privacy
  policy.
- [Submit an in-app purchase](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/).
- [Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/).
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/).
- [Export compliance overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/).

Verify the current pages again on submission day. Apple-account statuses and legal/tax
conclusions were not inspected.
