# Apple account and storefront obligations for an India-resident individual developer (TapLog, target release 25 Sep 2026)

Research date: 18 September 2026. Scope: Apple Developer Program enrollment (individual, India), seller name, EU DSA trader status, App Store Small Business Program, Paid Apps Agreement / tax / banking. Apple help pages were fetched live on 18 Sep 2026 and reflect their current text. Older rules are marked as older. Forum and blog reports are marked ANECDOTAL.

## 1. Apple Developer Program enrollment for an individual in India

### Takeaway
In India, enrollment is available only through the Apple Developer app (not the web). You need an Apple Account with two-factor authentication, your exact legal name in the Apple Account, a photo of a government-issued photo ID, and the same device for the whole flow. The fee is 99 USD a year, charged in local currency as an auto-renewing App Store subscription. Apple publishes no approval time, and forum reports range from days to many weeks. For a 25 September release, this is the critical-path risk.

### Cited Findings
**Channel (India-specific)**
- "Enrollment in India is only available through the Apple Developer app." — [Apple: Program enrollment help](https://developer.apple.com/help/account/membership/program-enrollment/)
- Supported devices: an iPhone or iPad with Touch ID, Face ID or a passcode, or a Mac with Apple silicon or a T2 chip. "You must use the same device for the entire enrollment process." The device must be signed in to iCloud and run the latest Apple Developer app. — [Apple: Enrolling with the Apple Developer app](https://developer.apple.com/help/account/membership/enrolling-in-the-app/)

**Account requirements**
- You need "an Apple Account with two-factor authentication turned on," and you must be "the legal age of majority in your region." — [Apple: Program enrollment help](https://developer.apple.com/help/account/membership/program-enrollment/)
- The Apple Account information must be valid and current: first name, last name, address, phone number, trusted phone number and trusted devices. — [Apple: Enrolling with the Apple Developer app](https://developer.apple.com/help/account/membership/enrolling-in-the-app/)
- "Make sure to use your legal name in the first and last name fields of your Apple Account. Using an alias, nickname, or company name ... will cause a delay in the approval of your enrollment." — [Apple: Enroll](https://developer.apple.com/programs/enroll/)
- Individuals must give contact details ("Email, phone, and address"), and "P.O. boxes are not accepted" for enrollment. — [Apple: Enroll](https://developer.apple.com/programs/enroll/); the same rule is on [Apple: Identity verification](https://developer.apple.com/help/account/membership/identity-verification)

**Identity verification / government ID**
- "You'll be asked to verify your identity using your driver's license or government-issued photo ID. Take a picture of your photo ID." Passports are accepted in most regions, and the accepted IDs vary by region. — [Apple: Enrolling with the Apple Developer app](https://developer.apple.com/help/account/membership/enrolling-in-the-app/)
- Apple checks the ID's authenticity and "pull[s] your name and address from the photo, but will not keep the image". Apple may share the data with a third-party identity verification provider. — [Apple: Enrolling with the Apple Developer app](https://developer.apple.com/help/account/membership/enrolling-in-the-app/)
- "Verification of your legal identity is currently required in order to enroll ... In some cases, you may be asked for your government identification number or an image of your photo ID. Additional or alternative documentation may be required." — [Apple: Identity verification](https://developer.apple.com/help/account/membership/identity-verification)
- Apple's pages give no list of India-specific ID types. The documentation does not name Aadhaar, PAN or a passport for India. — [Apple: Identity verification](https://developer.apple.com/help/account/membership/identity-verification)

**Fee and payment**
- "The Apple Developer Program annual fee is 99 USD ... in local currency where available." — [Apple: Program enrollment help](https://developer.apple.com/help/account/membership/program-enrollment/); "Prices may vary by region and are listed in local currency during the enrollment process." — [Apple: Enroll](https://developer.apple.com/programs/enroll/)
- In the app, "membership is provided on an annual basis as an auto-renewable subscription that renews until cancelled. You can make your purchase using one of your Apple Account payment methods." — [Apple: Enrolling with the Apple Developer app](https://developer.apple.com/help/account/membership/enrolling-in-the-app/)
- India exception: "Apple Account balances (from redeeming Apple Gift Cards or adding funds) are accepted from developers based in India as payment for Apple Developer Program membership." In most other regions, Apple does not accept them. — [Apple: Enrolling with the Apple Developer app](https://developer.apple.com/help/account/membership/enrolling-in-the-app/)
- You can cancel up to one day before renewal. "Membership fees paid for the year during which you cancel are nonrefundable." — [Apple: Enrolling with the Apple Developer app](https://developer.apple.com/help/account/membership/enrolling-in-the-app/)
- The rule for web enrollment ("you must use your own credit card", otherwise enrollment is delayed and Apple asks for a photo ID) applies to the web flow. Web enrollment is not available in India. — [Apple: Program enrollment help](https://developer.apple.com/help/account/membership/program-enrollment/)
- INR amount (NOT from Apple; the sources conflict): one blog says "about ₹8,300" a year plus a forex fee and GST — [Color Leaves](https://colorleaves.in/blog/apple-developer-account-cost-india/). A 14 Sep 2026 DEV post converts at ₹95.61/USD to "about ₹9,500 a year". That post discloses a commercial relationship. — [DEV Community](https://dev.to/preciousky_45d956626d31c3/what-it-actually-costs-to-publish-an-iphone-app-on-the-app-store-from-india-2026-numbers-1nmi)

**Approval time and delays**
- Apple's only stated timing: "If you haven't received a membership confirmation within 24 hours of your purchase, contact us." — [Apple: Program enrollment help](https://developer.apple.com/help/account/membership/program-enrollment/). After you submit your information, "it will be reviewed by Apple. You'll then receive an email with next steps" (no stated duration). — [Apple: Enrolling with the Apple Developer app](https://developer.apple.com/help/account/membership/enrolling-in-the-app/)
- The documented cause of delay is an incorrect legal name (alias, nickname or company name). — [Apple: Identity verification](https://developer.apple.com/help/account/membership/identity-verification); [Apple: Enroll](https://developer.apple.com/programs/enroll/)
- ANECDOTAL, India, Nov 2025: several Indian developers reported "Unknown Error" / "Invalid Request" failures in the Apple Developer app for 4+ days. Email support did not reply for 4 days, and the thread shows no resolution. — [Apple Developer Forums thread 807524](https://developer.apple.com/forums/thread/807524)
- ANECDOTAL, region not stated: enrollments "pending" for 7 days (Mar 2026), 10+ days, 12+ days, and 40+ days, and one report of 423 days. — [Forum 820213](https://developer.apple.com/forums/thread/820213); [Forum 821208](https://developer.apple.com/forums/thread/821208); [Forum 813941](https://developer.apple.com/forums/thread/813941); [Forum 813862](https://developer.apple.com/forums/thread/813862); [Forum 784941](https://developer.apple.com/forums/thread/784941)

**Converting individual → organization later**
- "If you have enrolled as an individual and need to convert your individual account to an organization account, please contact us." — [Apple: Program enrollment help](https://developer.apple.com/help/account/membership/program-enrollment/)
- To switch, you must "be the founder/cofounder of the organization and provide details such as your organization's D-U-N-S Number". Apple may ask for business documents. You make the request through Apple's migrate-individual-account form. — [Apple: Updating your account information](https://developer.apple.com/help/account/membership/updating-your-account-information/)
- For organizations: "must have a D-U-N-S Number", must be a legal entity ("We do not accept DBAs, fictitious business names, trade names, or branches"), and must have a public website on a domain that the organization owns. — [Apple: Enroll](https://developer.apple.com/programs/enroll/)
- Individuals do not need a D-U-N-S number. — [Apple: Program enrollment help](https://developer.apple.com/help/account/membership/program-enrollment/)
- Third-party guides say that after conversion the Apple ID, Team ID, certificates and apps stay, and only the seller name changes. Apple can phone to verify within about two weeks. — [Shopgate guide](https://support.shopgate.com/en/knowledge/how-to-convert-your-apple-developer-program-from-an-individual-to-an-organization-account) (secondary source)
- Apple's warning: a change of organization name "will update your vendor name across all your apps. This will reset the identifierForVendor (IDFV) for existing users ... This change cannot be undone." — [Apple: Updating your account information](https://developer.apple.com/help/account/membership/updating-your-account-information/)

### Inferences
- Do not spend time on a D-U-N-S number now. A sole proprietorship in India (no legal entity) cannot enroll as an organization anyway ("We do not accept DBAs ... trade names"). Enroll as an individual and convert later only if you form a company (for example, a Pvt Ltd or LLP).
- Before you start: correct the Apple Account first and last name to exactly match your government ID, have a passport or driver's license ready, and use one device from start to finish. These are the only controllable delay factors that Apple documents.
- Apple publishes no SLA, and the forum reports vary widely. Assume a real chance that enrollment alone takes longer than the 7 days to 25 September.

### Gaps
- No official Apple INR price was found. The price shows only inside the Apple Developer app. The GST treatment of the fee was not confirmed from an Apple source.
- No Apple source lists the ID documents it accepts for India (Aadhaar vs passport vs driver's license).
- No Reddit or r/iOSProgramming India-specific enrollment timelines were retrievable in this session. The forum data is mostly from unknown regions.

## 2. Seller name shown on the App Store for an individual; can it change?

### Takeaway
For an individual account, the App Store shows your personal legal name as the seller. You cannot change it by editing your Apple Account name. The only documented path to a different seller name is conversion to an organization account (this needs a legal entity and a D-U-N-S number).

### Cited Findings
- "If you're an individual or sole proprietor/single-person business, your personal legal name will be listed as the seller on the App Store." — [Apple: Program enrollment help](https://developer.apple.com/help/account/membership/program-enrollment/)
- "Your name will be displayed as the seller name of your apps on the App Store." — [Apple: Enroll](https://developer.apple.com/programs/enroll/)
- "To have your organization's name appear as the seller, your organization must be recognized as a legal entity and you must be enrolled as an organization." — [Apple: Program enrollment help](https://developer.apple.com/help/account/membership/program-enrollment/)
- "If you're enrolled in the Apple Developer Program as an individual, updating your name in your Apple Account will not change the name used for your membership or seller name on the App Store." — [Apple: Updating your account information](https://developer.apple.com/help/account/membership/updating-your-account-information/)

### Inferences
- "TapLog" or a brand name cannot be the seller on an individual account. The listing will show the developer's legal name, for example as it appears on his ID.

### Gaps
- Apple documents no process for an individual to correct a misspelled legal name after approval (other than contacting support).

## 3. EU Digital Services Act trader status

### Takeaway
A developer who earns money through an in-app purchase is very likely a "trader" under Apple's guidance. As a trader, he must give and verify an address (an individual can use a P.O. box with proof of association), a phone number and an email. Apple shows these on EU product pages. Every developer must declare a status, even with no EU distribution. Apps without a status were removed from EU storefronts from 17 Feb 2025. Exclusion of the 27 EU storefronts is possible in Pricing and Availability, and then no contact details are shown anywhere. But he must still declare a status, and he loses access to EU customers.

### Cited Findings
**Who is a trader**
- Apple quotes the EU definition: "any natural person ... acting ... for purposes relating to his or her trade, business, craft or profession." "You must assess whether you're a trader for EU law purposes." "Apple can't determine whether you're a trader." — [Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- One factor Apple lists: "Whether you make revenue as a result of your app, for example if your app includes In-App Purchases, or if it's a paid or ad-sponsored app." Other factors are commercial practices/advertising, VAT registration, and development in connection with a trade or profession. — [Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- Hobbyist carve-out: "if you're a hobbyist and you developed your app with no intention of commercializing it, you may not be considered a trader." — [Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- Press summary: developers "who make money from the App Store through either an upfront purchase price or through in-app purchases are considered traders, regardless of size." — [MacRumors, 17 Oct 2024](https://www.macrumors.com/2024/10/17/developers-eu-app-store-trader-requirements/) (secondary; Apple's own wording is "factors", not a rule)

**What is public and how Apple verifies it**
- Individuals must enter an "Address or P.O. Box", a phone number and an email address, and certify "that you only offer products or services that comply with the applicable rules of EU law." — [Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- Verification steps: validate the email with a two-factor code. Validate the phone with a two-factor code, or request manual verification if the number cannot receive codes. Then upload "a current document that verifies your business name and address", then confirm. — [Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- P.O. box / alternate address: "If you're displaying an alternate address, such as a P.O. Box, you'll also need to provide documentation that reflects your association with this alternate address (for example, a receipt or bill)." — [Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- NOTE the two rules differ: a P.O. box is allowed for the DSA display address but is "not accepted" for the enrollment address. — [Apple: Enroll](https://developer.apple.com/programs/enroll/) vs [Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- "Once verified, Apple will publish this information on your App Store product page when your app is distributed in any of the 27 territories of the EU." — [Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- Virtual offices, coworking addresses and virtual phone numbers: the only sources are third-party blogs that say small developers use them. — [save office blog](https://saveoffice.io/blog/app-store-developer-account-address) (commercial vendor, low reliability). Apple's documented rule for alternate addresses is only the proof-of-association requirement above.

**Declaring "not a trader" / not declaring**
- If you are not a trader, "consumers in the EU will be informed that consumer rights stemming from applicable consumer protection laws won't apply to contracts between you and them." — [Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- "Even if you don't distribute apps in the EU, you'll still need to declare a trader status." The prompt appears the "next time you submit a new app in App Store Connect". — [Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- OLDER (17 Oct 2024): from that date, trader status was required to submit updates for EU apps, and "If you're a trader, you'll need to provide your trader information before you can submit your app for review." — [Apple Developer News, 17 Oct 2024](https://developer.apple.com/news/?id=yfacfeal)
- OLDER (announced 16 Jan 2025, effective 17 Feb 2025): "apps without trader status will be removed from the App Store in the European Union until trader status is provided and verified, if necessary." — [Apple Developer News, 16 Jan 2025](https://developer.apple.com/news/?id=einwn76m). Still in force per the current help page.
- Impact: Appfigures counted about 135,000 apps inactive on EU storefronts within about 30 hours, rising to about 137,000. — [TechRepublic](https://www.techrepublic.com/article/eu-app-store-apple-digital-services-act/); [TechCrunch, 18 Feb 2025](https://techcrunch.com/2025/02/18/apple-purges-apps-without-contact-info-from-eu-app-store-as-dsa-deadline-hits)
- Roles: the Account Holder or an Admin does the initial setup. — [Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)

**Excluding EU storefronts**
- In App Store Connect: Pricing and Availability → App Availability → Manage → "select or deselect countries or regions". There is also a checkbox for future new storefronts. If you deselect a storefront later, the app is removed there, but earlier downloaders keep updates. — [Apple: Manage availability](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store)
- Contact details are published only "when your app is distributed in any of the 27 territories of the EU." — [Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)

### Inferences
- With a paid IAP, TapLog meets Apple's first listed trader factor. Declaring "not a trader" while selling a $4.99 unlock in the EU is hard to defend. It also puts a "consumer rights don't apply" notice on the listing.
- Fastest compliant path for 25 Sep: (a) keep the EU storefronts deselected and declare a status, so no EU display applies; or (b) declare trader status and prepare the verification documents now. For India, this means a current document with name and address, for example a utility bill or bank statement (this is an inference; Apple says only "business or legal records"). Also have a phone that can receive codes. Option (a) avoids publishing a home address but gives up the 27 EU storefronts. You can add them later after verification.
- The P.O. box route needs proof of association (a receipt or bill). India Post P.O. boxes exist, but no source confirmed that Apple has accepted one from an Indian developer.

### Gaps
- No source quantified the revenue cost of excluding the EU for a small utility or finance app. The "cost" is qualitative (the 27 EU storefronts are unavailable).
- Apple does not document how long DSA document verification takes, or whether manual phone verification adds days.
- It is not confirmed whether a developer who distributes only outside the EU and declares "trader" must complete full verification before submission, or only when the EU is enabled.

## 4. App Store Small Business Program (SBP)

### Takeaway
A new developer with zero proceeds qualifies. Enrollment is not automatic. You apply as the Account Holder after you accept the Paid Apps Agreement. The 15% rate applies to proceeds 15 days after the end of the fiscal month in which Apple approves the enrollment. So apply as soon as the Paid Apps Agreement is signed, before or at launch, not after the first sale.

### Cited Findings
- Eligibility: "developers who made up to 1 million USD in proceeds in the prior calendar year for all their apps, as well as developers new to the App Store, can qualify." Proceeds are "sales net of Apple's commission and certain taxes and adjustments." — [Apple: Small Business Program](https://developer.apple.com/app-store/small-business-program/)
- Rate: a 15% commission on paid apps and In-App Purchases (10% further reduced for developers on the EU alternative terms). — [Apple: Small Business Program](https://developer.apple.com/app-store/small-business-program/)
- To enroll you must: "Be an Account Holder in the Apple Developer Program"; "Review and accept the latest Paid Apps agreement (Schedule 2 ...) in App Store Connect"; and "If applicable, list all of your Associated Developer Accounts." — [Apple: Small Business Program](https://developer.apple.com/app-store/small-business-program/)
- Start of the rate: "Your proceeds will be adjusted fifteen (15) days after the end of the fiscal calendar month in which your enrollment is approved." — [Apple: Small Business Program](https://developer.apple.com/app-store/small-business-program/)
- Associated Developer Accounts: accounts where you have "Majority (over 50%) ... interest in the ownership" or "Ultimate decision-making authority", or where another account has that relationship with yours. The combined proceeds must stay at or below $1M. — [Apple: Small Business Program](https://developer.apple.com/app-store/small-business-program/)
- If you exceed $1M in the current year, the standard rate applies to future sales. If proceeds later fall below $1M, you can re-qualify the year after. — [Apple: Small Business Program](https://developer.apple.com/app-store/small-business-program/)

### Inferences
- The Paid Apps Agreement must be accepted before the SBP application, so the order is: enrollment approved → accept the Paid Apps Agreement → apply to SBP the same day.
- A September 2026 approval probably makes proceeds from that fiscal month onward eligible for 15%. Sales before approval are probably at 30%. Apple's wording does not say whether earlier sales are adjusted retroactively.
- TapLog is the developer's only account, so he probably has no Associated Developer Accounts. If a relative or employer account shares ownership or control, it counts.

### Gaps
- The Apple help page for SBP enrollment steps returned 404 in this session. Apple states no review duration for SBP applications.
- Apple's fiscal calendar dates for September/October 2026 were not retrieved.

## 5. Paid Apps Agreement, tax and banking before IAP works in sandbox and App Review

### Takeaway
For the $4.99 non-consumable to load in sandbox and App Review, three items in App Store Connect → Business must all show Active: the Paid Apps Agreement (signed by the Account Holder), Tax Forms (a W-8BEN for a non-US individual, through Apple's questionnaire), and Bank Accounts. Apple states that bank changes process "within 24 hours" after Account Holder approval. Developer reports describe days to weeks. No India-specific timing was found.

### Cited Findings
- "To offer In-App Purchases in your app, you must have a Paid Apps Agreement in effect ... The agreement is in effect if App Store Connect shows an Active status." — [Apple TN3186](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox)
- "After you accept the Paid Apps Agreement, your Account Holder needs to submit all required banking and tax information ... complete if App Store Connect shows an Active status in its Bank Accounts and Tax Forms sections." — [Apple TN3186](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox)
- Sandbox testing "doesn't require you submit your In-App Purchases for review." — [Apple TN3186](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox)
- Only the Account Holder can sign. "This agreement must be active in order for you to submit or update paid apps and In-App Purchases." Acceptance "can't [be] undo[ne]". — [Apple: Sign and update agreements](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/)
- Status meanings: New (unsigned), Pending User Info (signed, information missing), Processing (under review), Verifying, Active. — [Apple: View agreements status](https://developer.apple.com/help/app-store-connect/manage-agreements/view-agreements-status/)
- Order: "In order to submit tax forms, you first need to sign the Paid Apps Agreement." Outside the US, "the W-8BEN, W-8BEN-E, or W-8ECI may be required, but you'll be prompted to answer a series of questions." — [Apple: Provide tax information](https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information/)
- For banking, you "first need to sign a Paid Apps Agreement" and "must submit all required tax forms ... in order for us to process banking information." Steps: Business → Agreements → Bank Accounts → Add Bank Account. You then give the country, currency, account type, bank code and account number, and the holder name "exactly as they appear on the bank account". — [Apple: Enter banking information](https://developer.apple.com/help/app-store-connect/manage-banking-information/enter-banking-information)
- Timing: "After the Account Holder approves the change, it will be processed within 24 hours." — [Apple: Enter banking information](https://developer.apple.com/help/app-store-connect/manage-banking-information/enter-banking-information)
- The bank account currency "is also the currency you will be paid in". The holder name must be in English letters and match the bank record exactly, including punctuation. — [Apple: Banking information reference](https://developer.apple.com/help/app-store-connect/reference/banking-information/)
- ANECDOTAL: tax/bank review takes "anywhere from a few days to a couple of weeks". One developer's bank account stayed in "Processing" for several weeks. — [Apple Developer Forums thread 810848](https://developer.apple.com/forums/thread/810848) (as summarized in search results; not India-specific)
- App Review: the first IAP must be submitted together with an app version. Reviewers test purchase and restore in sandbox. Products that fail to load cause Guideline 2.1 rejections. — [Apple Developer Forums 815029](https://developer.apple.com/forums/thread/815029); [Apple Developer Forums 807262](https://developer.apple.com/forums/thread/807262) (ANECDOTAL)
- OLDER (Aug 2021): the bank account holder's address became required in App Store Connect due to local regulations. — [Apple Developer News, 23 Aug 2021](https://developer.apple.com/news/?id=ep8chzr8)

### Inferences
- Critical-path order for 25 Sep: enrollment approved → Account Holder accepts the Paid Apps Agreement → W-8BEN questionnaire → Indian bank account (INR savings account, holder name exactly as in the bank record) → wait for all three Active → sandbox test → submit the app version with the IAP attached → SBP application in parallel.
- For a sole developer, the Account Holder enters the bank details directly, so no separate approval step applies. Apple's "within 24 hours" is the official best case. Plan for several days.

### Gaps
- No Apple source gives India-specific bank fields (IFSC), Indian tax forms (PAN), or GST obligations for app proceeds. No India-specific bank verification timeline was found.
- There is no official statement about App Review behavior when the agreement is still "Processing" at submission time.
