# TapLog first iOS submission (Sept 2026): App Review, Apple trademark, and consumer-law risk fact sheet

Research date: 2026-09-18. All Apple pages were fetched on this date unless noted. The App Review Guidelines page showed no "last updated" date in the fetched copy. Apple Media Services Terms showed "last updated September 14, 2026". Likelihood ratings are the researcher's inferences, not Apple statements.

## Q1. Metadata and trademarks: Guidelines 2.3.1 / 2.3.7, "Siri" and "Action Button" in keywords, and what Apple's trademark and marketing rules allow

### Takeaway
"Siri" is a registered Apple trademark, and 2.3.7 bars packing metadata "with trademarked terms", so "siri" in the keywords field is a real (moderate, not certain) rejection or keyword-edit risk. Remove it. "Action Button", "Control Center", "Lock Screen" and "Home Screen" are not on Apple's trademark list, but "action button" is still a feature name, not a search term that describes the app. Referential use in the description ("works with Siri") is allowed if it is accurate and spelled correctly. No Apple mark may appear in the app name.

### Cited Findings
- 2.3.7 text: "assign keywords that accurately describe your app, and don't try to pack any of your metadata with trademarked terms, popular app names, pricing information, or other irrelevant phrases just to game the system. App names must be limited to 30 characters. Metadata such as app names, subtitles, screenshots, and previews should not include prices, terms, or descriptions that are not specific to the metadata type… Apple may modify inappropriate keywords at any time." — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- 2.3.7 also: subtitles "should not include inappropriate content, reference other apps, or make unverifiable product claims." — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- 2.3.1 (current text): no hidden or undocumented features; "All new features, functionality, and product changes must be described with specificity in the Notes for Review section of App Store Connect (generic descriptions will be rejected)"; misleading marketing or "promoting a false price" is grounds for removal and account termination. — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- 2.3.10: keep metadata focused on the app; "Don't include irrelevant information." — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- Apple Trademark List: "Siri®" is listed. "Siri Shortcuts®", "Live Activities®", "Dynamic Island®", "App Store®", "iPhone®", "Apple Pay®" are listed. "Action Button", "Control Center", "Lock Screen", "Home Screen" were not found on the list. — [Apple Trademark List](https://www.apple.com/legal/intellectual-property/trademark/appletmlist.html)
- Apple third-party trademark guidelines: you may not use any Apple trademark "as or as part of a company name, trade name, product name, or service name"; referential phrases ("runs on", "for use with", "for", "compatible with") are allowed if the mark is not part of the product name, is less prominent than the product name, the product actually works with it, and no endorsement is implied; "Always spell and capitalize Apple's trademarks exactly as they are shown in the Apple Trademark List. Do not shorten or abbreviate"; no plural or possessive forms; outside the US, "Do not use trademark symbols"; suggested credit line: "___ is a trademark of Apple Inc., registered in the U.S. and other countries and regions." The page gives no guidance on keywords or metatags. — [Guidelines for Using Apple Trademarks](https://www.apple.com/legal/intellectual-property/guidelinesfor3rdparties.html)
- App Store marketing guidelines: use product names in referential phrases ("app name for iPhone", "works with", "compatible with"), "Don't say iPhone app name"; Siri is on the "Do Not Translate" list and must be capitalized "Siri"; "If your app supports widgets, you may show your app's widget on the Home Screen as long as no third-party content is depicted"; show the app "as it appears when your app is running" and use "fictional account information instead of data from a real person." — [App Store Marketing Guidelines](https://developer.apple.com/app-store/marketing/guidelines/)
- Marketing guidelines on device images: "Use Apple-provided product bezels in all your marketing materials to display your app on the Apple devices it supports", and use them unmodified. — [App Store Marketing Guidelines](https://developer.apple.com/app-store/marketing/guidelines/)
- Anecdotal (July 2025): an app was rejected under 2.3.7 because its subtitle contained a third-party trademark (example given: GoPro), even though the description disclaimed affiliation. It was approved after the mark was removed from the subtitle and the name took the form "App Name for [Brand]". — [Apple Developer Forums thread 791158](https://developer.apple.com/forums/thread/791158)
- Secondary: Apple rejects apps whose name or subtitle includes trademarked terms or popular app names. — [Shopapper, 5.2.1 & 2.3.7 fix](https://shopapper.com/fix-app-store-metadata-rejection-guideline-5-2-1-2-3-7/)

### Inferences
- **Keyword "siri" — likelihood: moderate.** Fix: remove it. The 2.3.7 text names trademarked terms explicitly, and Siri® is a registered mark. The worst case is a 2.3.7 rejection. A milder case is that Apple silently edits the keyword.
- **Keyword "action button" — likelihood: low to moderate.** It is not a listed trademark, but it names an iPhone hardware feature, not what the app does. Fix: drop it. Use the 100 characters for terms that describe the app (for example "expense", "spending", "tracker", "log").
- **Keywords "chai", "grove", "streak", "diary" — likelihood: low.** A reviewer can read these as irrelevant under 2.3.7 or 2.3.10 unless the app clearly shows them (chai as a sample expense, grove or trees as the budget metaphor, streaks as a feature). Keep a term only if a reviewer can see it in the app. "no account" and "offline" are accurate.
- **Name "TapLog: Expense Tracker" and subtitle "Fast, private spending log" — likelihood: low.** No Apple marks. The name is 23 characters, under the 30-character limit. "Private" is a claim, so it must be true (offline, no data collection) and must match the App Privacy label.
- **Description — likelihood: low if accurate.** Mentioning Siri, the Action Button, Control Center and widgets is referential use. Write "works with Siri" or "log by voice with Siri". Do not write "TapLog Siri" or "Siri's". Capitalize exactly (Siri, iPhone, App Store). Omit ™/® symbols, because the listing is distributed outside the US. An optional credit line at the end of the description is allowed but not required. Every listed integration must work in the reviewed build (2.3.1).
- **"ONE PAYMENT, NO SUBSCRIPTION" in the description — likelihood: low.** 2.3.7 bars prices in names, subtitles, screenshots and previews, not in the description. Keep it out of screenshot captions, the subtitle and the keywords. The statement must stay true (2.3.1 "false price").
- **Screenshots without device frames — likelihood: very low.** The bezel rule in the marketing guidelines is about marketing materials that show Apple devices. The researcher found no rule that requires frames in App Store screenshots. Keep captions free of prices. Show only fictional data. If a widget is shown on a Home Screen, show no third-party app content.

### Gaps
- No primary Apple source or first-hand report was found that names "Siri" in the keywords field as a rejection cause. The risk is inferred from the 2.3.7 text and the trademark list.
- The App Store Connect screenshot-specification page was not fetched in this pass. The exact wording on framed or unframed screenshots is unverified.

## Q2. Guidelines 3.1.1 / 3.1.2: non-consumable requirements, paywall contents, and Terms/Privacy links

### Takeaway
For a non-consumable, the hard requirements are: use Apple IAP (3.1.1), give a restore mechanism (3.1.1), make the IAP visible and working for the reviewer (2.1(b)), and link a privacy policy in App Store Connect and inside the app (5.1.1(i)). The detailed paywall disclosures (title, length, price, Terms and Privacy links) come from 3.1.2 and Schedule 2, which cover auto-renewable subscriptions. TapLog's "Restore purchase" button in Settings and on the paywall meets the restore rule.

### Cited Findings
- 3.1.1: unlocking features or "a full version" must use in-app purchase. Apps may not use license keys, QR codes or similar. "you should make sure you have a restore mechanism for any restorable in-app purchases." — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- 3.1.2 is headed "Subscriptions" and covers auto-renewable subscriptions. 3.1.2(c): "Before asking a customer to subscribe, you should clearly describe what the user will get for the price… Ensure you clearly communicate the requirements described in Schedule 2." — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- 2.1(b): "If you offer in-app purchases in your app, make sure they are complete, up-to-date, visible to the reviewer and functional. If any configured in-app purchase items cannot be found or reviewed in your app, explain the reason in your review notes." — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- 5.1.1(i): "All apps must include a link to their privacy policy in the App Store Connect metadata field and within the app in an easily accessible manner." The policy must state what data is collected, third-party sharing, and retention and deletion. — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

### Inferences
- **Restore — likelihood of rejection: low.** TapLog already has a Restore button in Settings and on the paywall. Test that restore works in sandbox on a clean install and that a failed or empty restore shows a clear message.
- **Paywall contents for a non-consumable.** Show the localized price from StoreKit (never a hard-coded "$4.99"; Indian users see INR), what Pro unlocks (more than three trees, monthly recap), that it is a one-time purchase, and a Restore button. A Terms (EULA) link and a Privacy link on the paywall are not required by the text found for non-subscription IAP. Adding them costs nothing and removes reviewer doubt. **Recommendation: add both small links.**
- **Privacy policy link inside the app is mandatory (5.1.1(i)).** Put it in Settings at minimum. This is a common, easy-to-miss 5.1.1 rejection for offline apps that "collect nothing".
- 3.1.2 subscription disclosures do not apply, because TapLog has no subscription. Do not use subscription-style wording ("plan", "per month") near the Pro offer. It can confuse a reviewer into applying 3.1.2.

### Gaps
- Schedule 2 of the Apple Developer Program License Agreement could not be read verbatim (the fetch returned only a table of contents). The exact section numbers and wording of the subscription disclosure rules are unverified in this pass.
- The Human Interface Guidelines in-app purchase page did not render in the fetch, so HIG wording on restore buttons is not quoted.

## Q3. IAP review for a first submission: attach to version, review screenshot, and common failures

### Takeaway
The first non-consumable must be attached to and submitted with the app version. It needs a review screenshot. The most common first-submission failure is products that do not load on the reviewer's device, which leads to a 2.1 rejection. Developer reports link this to an inactive Paid Apps Agreement or to an IAP left unattached.

### Cited Findings
- "The first consumable, non-consumable, auto-renewable subscription, and non-renewing subscription In-App Purchase of each type must be submitted with a new app version." Process: IAP page, "Add for Review", select the app version, "Submit for Review". — [App Store Connect Help: Submit an In-App Purchase](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)
- Review screenshot: required. "A screenshot of the In-App Purchase that clearly shows the item or service being offered. This screenshot is used for review only and isn't displayed on the App Store." It must meet the app's screenshot specifications. "Once you've uploaded a screenshot, you can update it but not remove it." IAP review notes are limited to 4,000 characters. Display name is 2–30 characters. Description is at most 45 characters. Changes to localized information require review. — [App Store Connect Help: In-App Purchase information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information)
- Anecdotal: 2.1 rejections where IAP products failed to load or the purchase failed on the review device; advice to confirm the Paid Applications agreement is signed; App Review uses the sandbox, which is sometimes unstable. — [RevenueCat Community: IAP not loading](https://community.revenuecat.com/sdks-51/ios-rejection-as-iap-are-not-loading-7719); [RevenueCat Community: 2.1 App Completeness](https://community.revenuecat.com/general-questions-7/apple-store-rejection-guideline-2-1-performance-app-completeness-6493); [Apple Developer Forums 815029](https://developer.apple.com/forums/thread/815029)
- Anecdotal/secondary: creating an IAP in App Store Connect does not submit it. The "In-App Purchases and Subscriptions" section on the version page can be hidden until a product reaches "Ready to Submit". — [SaaSCity 2026 fix guide](https://saascity.io/blog/app-store-connect-in-app-purchases-subscriptions-section-missing-fix-2026); [Despia blog](https://blog.despia.com/in-app-purchases-not-submitted-for-review-the-fix)

### Inferences
- **"IAP not found or not loading" 2.1 rejection — likelihood: moderate to high on a first submission if the steps below are missed; low if done.** Fix checklist:
  1. Paid Apps Agreement "Active" (banking and tax forms complete) before submission.
  2. The TapLog Pro product is at "Ready to Submit" with price, availability, localized name and description, and a review screenshot of the paywall.
  3. Tick TapLog Pro in the version's In-App Purchases section before "Submit for Review".
  4. The product ID in code matches App Store Connect exactly.
  5. The paywall shows a readable error and retry, not a blank or spinning screen, when products fail to load.
- **Review notes (2.1 and 2.3.1): write specific steps.** For example: no account needed; to reach the paywall, create a fourth budget tree or open Monthly Recap; Restore is in Settings > Restore purchase; how to test the Siri or App Intent phrase, the Action Button, the Control Center control and the widgets; the app is fully offline, so no demo login.

### Gaps
- No Apple primary page was fetched that states the Paid Apps Agreement must be active for IAP products to load in review. This is supported only by developer reports.

## Q4. Updated age-rating questionnaire (2025–2026) for a simple finance utility

### Takeaway
Apple added 13+, 16+ and 18+ ratings and new questions in July 2025, with answers due January 31, 2026. A new app in September 2026 simply answers the new questionnaire at creation. An offline expense tracker with no user-generated content, web access, ads, chat, gambling or medical content should calculate to 4+.

### Cited Findings
- July 24, 2025: new 13+, 16+ and 18+ tiers alongside 4+ and 9+. New required questions cover "in-app controls, capabilities, medical or wellness topics, and violent themes". Deadline: "by January 31, 2026, to avoid an interruption when submitting your app updates in App Store Connect." Developers may pick a higher rating than calculated. — [Apple Developer News: Updated age ratings](https://developer.apple.com/news/?id=ks775ehf)
- The old 12+ and 17+ ratings were replaced. — [TechCrunch, July 25, 2025](https://techcrunch.com/2025/07/25/apple-broadens-app-stores-age-rating-system)
- 2.3.6: "Answer the age rating questions in App Store Connect honestly." 2.3.8: metadata, including IAP icons and screenshots, must suit a 4+ audience. — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- Secondary: apps distributed in Texas may face added consent requirements if updated after January 1, 2026 (Texas SB 2420). — [SoCast Digital](https://www.socastdigital.com/2025/12/15/important-ios-app-age-rating-updates-required-by-january-31-2026/)

### Inferences
- **Risk: low.** Answer "None" or "No" for violence, medical or wellness, gambling, user-generated content, messaging, and unrestricted web access. Expect 4+. The "capabilities" question may ask about features such as in-app purchases. Answer it truthfully.
- The January 31, 2026 deadline has passed. It mattered for existing apps. A new app must complete the new questionnaire before it can submit.

### Gaps
- The exact wording of each new question in App Store Connect was not retrieved.
- The Texas SB 2420 effect on a 4+ finance utility was not verified from a primary source. It is reported only by a secondary blog.

## Q5. Guidelines 4.2 (minimum functionality), 4.3 (spam), 2.1 (completeness), and review notes

### Takeaway
Expense trackers are a crowded category, so a 4.3(b) "indistinguishable from what's already widely available" rejection is possible. It is less likely for a native app with Siri, Action Button, Control Center and widget capture and a distinct budget-tree UI. Make these differentiators obvious to the reviewer in the first minute and in the review notes.

### Cited Findings
- 4.2: "If your app is not particularly useful, unique, or 'app-like,' it doesn't belong on the App Store. If your App doesn't provide some sort of lasting entertainment value or adequate utility, it may not be accepted." — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- 4.3(b): "Don't submit apps that are indistinguishable from what's already widely available… Certain kinds of apps, such as dating, flashlight, sound effects, wallpaper, simple timers, and fortune telling, are well established on the App Store and we will not accept new submissions unless they offer a meaningfully different or improved experience." Expense trackers are not on the named list. — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- 2.1(a): submissions must be final, with no placeholder content, tested on-device, and with "fully functional URLs". Apps that crash are rejected. — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- Anecdotal: many developers report 4.3 rejections with little explanation, including after an earlier approval. — [Forums 788684](https://developer.apple.com/forums/thread/788684); [Forums 788165](https://developer.apple.com/forums/thread/788165); [Forums 774834](https://developer.apple.com/forums/thread/774834)
- Secondary (opinion): an expense tracker is fine if it "does something specific" that others do not. It is a 4.3 case if the only honest description is "an expense tracker". — [ReleaseMyApp: 4.3 guide](https://www.releasemyapp.com/blog/fix-app-store-rejection-guideline-4-3)

### Inferences
- **4.3(b) — likelihood: low to moderate.** **4.2 — likelihood: low.** The app has native system integrations and real utility. Fixes: open on a useful first screen, not an empty state. Seed optional sample data or a short onboarding. State the differentiators in the review notes (fast capture through Siri, Action Button, Control Center and widgets; offline with no account; budget trees). The support URL, privacy policy URL and marketing URL must all load (2.1(a)).
- **2.1 crash or completeness — likelihood: low if tested.** Test the release build on a physical device with a sandbox account, on the newest iOS that App Review uses.
- If a 4.3 rejection arrives, reply in Resolution Center with specifics, or appeal to the App Review Board. Anecdotal reports show appeals sometimes succeed (see the forum threads above).

### Gaps
- No first-hand report was found of a 4.3 rejection for a native expense tracker specifically. The risk estimate comes from the guideline text and general reports.

## Q6. Terms of Use / EULA: is Apple's Standard EULA enough, and how to reference it

### Takeaway
Yes. With no custom EULA uploaded, Apple's Standard EULA governs the license automatically. This is enough for a free app with one non-consumable. Link it from the description and the app (Settings, and optionally the paywall). A custom EULA is worth it only if you need terms the standard one lacks. For example, you might want wording on what "lifetime" means, on discontinuation, or on local-law specifics.

### Cited Findings
- The Standard EULA says a license to each app "is subject to your prior acceptance of either this Licensed Application End User License Agreement ('Standard EULA'), or a custom end user license agreement between you and the Application Provider ('Custom EULA'), if one is provided." — [Apple Standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/)
- The license is "nontransferable" for Apple-branded products you own or control. The app is provided "AS IS" and "AS AVAILABLE". Liability is capped at $50.00, where local law allows. — [Apple Standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/)

### Inferences
- **Risk: low.** Add to the description: "Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/", and add the same link in Settings next to the privacy policy.
- The Standard EULA says nothing about "lifetime" or what happens if TapLog is discontinued. If the "lifetime" wording is kept, a short custom EULA or a support-page FAQ can define it (see Q7). A plain-language FAQ is simpler than a custom EULA and does not need App Store Connect changes.

### Gaps
- The DPLA exhibit that sets the minimum terms for a custom EULA was not read verbatim.

## Q7. Consumer law: "lifetime", "yours for good", "own forever"; discontinuation; refunds

### Takeaway
The main legal risk is an ownership or permanence claim ("yours for good", "own forever", "lifetime") that the developer cannot fully guarantee. Apple's own terms say purchased content may become unavailable. Regulators in the US (California), the UK and India now target misleading digital claims. Refunds and withdrawal rights are handled by Apple as merchant, not by the developer. Safer wording: "One-time purchase. No subscription." or "Pay once, unlock Pro."

### Cited Findings
- Apple Media Services Terms (EU/Ireland version, updated Sept 14, 2026): "you may [cancel]… within fourteen (14) days from when you received your receipt without giving any reason". Exception: "You cannot cancel your order for the supply of Content if the delivery has started upon your request and acknowledgement." "UNLESS REQUIRED BY APPLICABLE LAW, APPLE HAS NO RESPONSIBILITY TO CONTINUE MAKING CONTENT AVAILABLE." Content may be removed and then cannot be redownloaded. "the Content provider is solely responsible for such Content, any warranties… and any claims." — [Apple Media Services Terms (IE)](https://www.apple.com/legal/internet-services/itunes/ie/terms.html)
- US version (updated Sept 14, 2026): "All Transactions are final", subject to Apple's remedy of replacement or refund; problems are reported at reportaproblem.apple.com. "Content may be removed from the Services and become unavailable… APPLE WILL NOT BE LIABLE TO YOU IF CONTENT, INCLUDING PURCHASED CONTENT, BECOMES UNAVAILABLE." — [Apple Media Services Terms (US)](https://www.apple.com/legal/internet-services/itunes/us/terms.html)
- Older (2014): Apple introduced the 14-day EU cancellation right to implement the Consumer Rights Directive. — [Osborne Clarke](https://www.osborneclarke.com/insights/apple-introduces-14-day-refunds-what-does-that-mean-for-virtual-content-providers)
- EU Digital Content Directive (2019/770): for a single act of supply, the trader must provide updates needed to keep the content in conformity for the period the consumer "may reasonably expect". The liability period is at least two years from supply. — [EUR-Lex Directive 2019/770](https://eur-lex.europa.eu/eli/dir/2019/770/oj/eng); summary: [Cooley Productwise](https://products.cooley.com/2022/06/23/productwise-bitesize-digital-content-and-digital-services-directive-2019-770/)
- California AB 2426 (effective Jan 1, 2025): "digital good" includes a "digital application or game". Sellers may not use "buy" or "purchase", or terms suggesting "unrestricted ownership interest", without a clear pre-transaction disclosure that the purchase is a license. Exemptions include subscriptions, free goods, and goods available for "permanent offline download… without a connection to the internet". — [Cooley on AB 2426](https://www.cooley.com/news/insight/2024/2024-10-01-new-california-law-requires-disclosures-for-selling-online-digital-goods)
- US litigation example: a class action alleged that Rosetta Stone's "lifetime" download expired after 24 months, under California unfair competition and false advertising law. In false advertising, "the overall impression" matters, so what "lifetime" means must be clear before purchase. — [Top Class Actions](https://topclassactions.com/lawsuit-settlements/consumer-products/subscriptions/rosetta-stone-misled-customers-through-advertising-class-action-lawsuit-says/); [Holmes Weinberg](https://holmesweinberg.com/whats-in-a-lifetime-more-than-you-might-think/)
- UK: the DMCC Act 2024 unfair-commercial-practices provisions took effect April 6, 2025. The CMA can fine up to 10% of global turnover. The Act adds bans on drip pricing and fake reviews. — [Cooley](https://www.cooley.com/news/insight/2025/2025-04-14-new-uk-consumer-law-regime-comes-into-force); [CMS](https://cms.law/en/gbr/legal-updates/the-dmcc-act-consumer-elements-come-into-force-from-6-april-2025)
- India: the CCPA Guidelines for Prevention and Regulation of Dark Patterns, 2023 (notified Nov 30, 2023) apply to e-commerce entities, advertisers, product sellers and service providers that systematically offer goods or services in India. They list 13 patterns, including false urgency, confirm shaming, forced action, subscription trap, bait and switch, drip pricing and nagging. On June 5, 2025 the CCPA advised platforms to self-audit within 3 months. — [AZB & Partners](https://www.azbpartners.com/bank/regulatory-crackdown-on-dark-patterns-ccpas-enforcement-actions-and-emerging-compliance-landscape-in-indian-e-commerce/); [IAPP](https://iapp.org/news/a/india-s-ccpa-guidelines-on-dark-patterns-welcome-signal-but-law-is-still-soft); [MediaNama](https://www.medianama.com/2025/11/223-ccpa-dark-pattern-self-audit-declarations-18-e-commerce-quick-commerce-platforms/)

### Inferences
- **"Yours for good" / "own forever" / "lifetime" — likelihood of enforcement against a small indie app: low; reputational and complaint risk: moderate.** Apple's terms say content can become unavailable, the Standard EULA grants a license (not ownership), and the developer cannot promise the app will run on future iOS versions. Recommended fixes:
  - Paywall: replace "One payment, yours for good" with "One-time purchase. No subscription. Restore anytime on your Apple ID." In the App Store Connect product name, use "TapLog Pro (one-time)" instead of "lifetime".
  - Description: "ONE PAYMENT, NO SUBSCRIPTION" is accurate and low-risk. Keep it.
  - If "lifetime" stays anywhere, define it on the support page. For example: "Pro stays unlocked for as long as TapLog is available and runs on your device, and it can be restored on devices using the same Apple ID."
- **AB 2426:** TapLog Pro unlocks features in an app that works fully offline and keeps working without the internet. The exemption for "permanent offline download" may apply. That is not certain, because the unlock is a license tied to the Apple ID. Avoiding "own", "buy it forever" and similar ownership words removes the question.
- **Discontinuation:** Apple's terms put continued availability outside Apple's responsibility, and the provider is responsible for warranties and claims. Because TapLog is offline, an installed copy keeps working after removal from sale. Whether it can be redownloaded or restored after removal is not guaranteed under Apple's terms. EU/EEA users may expect conformity and updates for a reasonable period, with a two-year liability floor under the DCD. Practical fix: do not promise updates forever. Keep CSV export free (already done), so users keep their data.
- **Refunds:** Apple is the merchant. EU users get the 14-day withdrawal right unless delivery started with their request and acknowledgement. In the US, sales are final, subject to Apple's report-a-problem process. The developer does not issue refunds. The support page can say: "Refunds are handled by Apple at reportaproblem.apple.com."
- **Dark patterns (India and UK):** a one-time $4.99 offer with Restore and no timer carries low risk. Avoid fake countdowns ("offer ends tonight"), confirm-shaming dismiss text ("No, I like overspending"), and repeated paywall pop-ups (nagging).

### Gaps
- The EU Consumer Rights Directive text (Art. 16(m) digital content exception) was not fetched directly. The rule is cited through Apple's implementation.
- No FTC guidance page that addresses "lifetime" claims specifically was retrieved. The US point rests on California law and one class action.
- UK Consumer Rights Act 2015 digital-content remedies were not fetched.
- India Consumer Protection (E-Commerce) Rules, 2020: whether they apply to a solo developer selling only through Apple's store was not confirmed. The CCPA dark-patterns PDF on consumeraffairs.gov.in could not be fetched (TLS error), so the applicability wording is taken from a law-firm summary.

## Q8. India-specific App Store points (pricing, tax display)

### Takeaway
Apple is the merchant of record and collects GST in India. Store prices are shown tax-inclusive in INR. The developer does not need separate tax display. The main India-specific tasks are to check the auto-generated INR price for the $4.99 tier and to follow the dark-patterns guidelines (Q7).

### Cited Findings
- Secondary: Apple acts as merchant of record in most countries and collects and remits VAT or GST. Tier prices are tax-inclusive local prices. India's GST on digital services is 18%. Developer proceeds are calculated on the tax-exclusive amount. — [AppsOps tax guide](https://appsops.store/blog/app-store-tax-vat-gst-territories)
- Apple's tax exhibits to Schedules 2 and 3 of the DPLA (dated 2025-08-21) list per-territory tax handling. — [Apple Exhibits to Schedule 2 and 3 (PDF)](https://developer.apple.com/support/downloads/terms/exhibits/Exhibits-to-Schedule-2-and-3-20250821-English.pdf)

### Inferences
- **Risk: low.** Set the base price in USD and check the generated INR price in App Store Connect. Adjust it manually if a rounder rupee price suits Indian buyers better. The paywall must show StoreKit's localized price (`displayPrice`), so Indian users see rupees, including tax.
- The keyword "chai" suggests an India focus. Keywords can be localized per storefront. Consider putting India-specific terms in an English (India) localization if one is offered, not in the US keywords.

### Gaps
- The India line in Apple's tax exhibit PDF was not read directly. The GST rate and Apple's collection role come from a secondary source.
- No Apple rule was found that requires India-only metadata, grievance-officer details or other India-specific disclosures for a developer selling through the App Store.
