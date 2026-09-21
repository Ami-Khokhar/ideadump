# India tax, GST and payouts for an individual Indian developer earning App Store proceeds (TapLog, as of Sept 2026)

Scope: individual resident in India, enrolled in the Apple Developer Program as an individual, one $4.99 non-consumable IAP, sold worldwide; Apple sells to the customer. Research date: 2026-09-18. Source labels: [PRIMARY] = Apple / Government of India; [SECONDARY] = CA firms, fintech blogs, forums. Nothing here is personal tax advice.

## 1. US tax forms in App Store Connect (W-8BEN, treaty claim, TIN, withholding)

### Takeaway
Every developer must submit a US tax form in App Store Connect before paid apps can be distributed; a non-US individual is steered to W-8BEN. Apple Finance Support has said App Store agreements are "sales/commission" and not "royalty" agreements, so there is "generally no tax withholding" on US App Store sales. The India–US treaty Article 12 royalty rates (15% / 10%) that appear in forums and blogs therefore probably do not apply to App Store proceeds. What to write on the W-8BEN treaty line (Part II) is not settled by any Apple source found, so it is a CA decision.

### Cited Findings
- "All developers must complete a US tax form to comply with the Paid Apps Agreement." Developers based outside the US may need W-8BEN, W-8BEN-E or W-8ECI, and App Store Connect asks questions to pick the right form — [PRIMARY: App Store Connect Help, Provide tax information](https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information/)
- After you submit, "you won't be able to make any changes in App Store Connect. For any corrections or additional tax forms, contact us." Get the form right the first time — [PRIMARY: same page](https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information/)
- Apple Finance Support (Apple Media Services), as quoted in a Sept 2022 forum post: "Since the App Store agreements are characterized as a 'sales/commission' agreement, as opposed to a 'royalty' agreement, there is generally no tax withholding for sales in the USA App and Book Stores." — [SECONDARY, quotes an Apple email: Apple Developer Forums thread 708842](https://developer.apple.com/forums/thread/708842)
- In the same thread, a community member suggested the treaty's business-profits article (Article 8 of the 1974 US–Poland treaty) as the relevant article instead of royalties. This is a community opinion, not Apple's answer — [SECONDARY: forum thread 708842](https://developer.apple.com/forums/thread/708842)
- An Indian individual developer (June 2024) asked whether withholding applies and whether the India–US rate is 15% (IRS table) or 10% ("for software products"). The thread has no replies. This confusion is common and Apple has not publicly resolved it for India — [SECONDARY: forum thread 757620](https://developer.apple.com/forums/thread/757620)
- India–US DTAA Article 12: 15% for royalties for literary/artistic/scientific works and for "included services"; 10% for equipment royalties and services ancillary to them — [SECONDARY: Beacon Filing, Article 12 guide](https://beaconfiling.com/dtaa/royalty-tax-rate-india-usa); [SECONDARY: VJM Global DTAA guide](https://www.vjmglobal.com/feeds/blog/dtaa-india-usa)
- Without a valid W-8BEN, Apple "may withhold 30% for US taxes" — [SECONDARY: Karbon Card payout guide](https://www.karboncard.com/blog/apple-google-payouts-india)
- Guides for Indian freelancers on W-8BEN (foreign TIN = PAN, treaty country = India) — [SECONDARY: Skydo W-8BEN guide](https://www.skydo.com/blog/filing-w-8ben-and-w-8ben-e-a-guide-for-indian-freelancers-and-businesses)

### Inferences
- Because Apple treats the App Store as sales/commission (not royalties), the US-source withholding on TapLog proceeds is probably zero once a valid W-8BEN is on file, whichever treaty line is chosen. The 30% rate is the no-form fallback. (Inference from the Apple Finance quote; Apple has not published this for India specifically.)
- A US TIN (SSN/ITIN) is normally not needed for an individual non-US W-8BEN filer who gives a foreign TIN; the Indian PAN is the foreign TIN in practice. Not confirmed on an Apple or IRS page in this session.
- CA FLAG: whether to claim Article 12 (royalties), Article 7 (business profits, no US permanent establishment), or no treaty line at all on W-8BEN Part II. The form cannot be edited after submission.

### Gaps
- Could not fetch the IRS W-8BEN instructions or Apple's downloadable W-8BEN tip sheet (the help page links to it but the fetch did not return its text). The exact questions App Store Connect asks an Indian individual in 2026 are not confirmed.
- No Apple primary page found that states the withholding rate for India-resident individuals.

## 2. Does Apple withhold Indian tax (TDS, equalisation levy) or collect Indian GST?

### Takeaway
Apple added India's 2% equalisation levy (EL) on top of 18% GST in October 2020 and removed it from 29 August 2024. Apple folds India's taxes into its pricing and proceeds, so the developer receives proceeds net of those taxes. No source shows Apple deducting Indian TDS from payouts to Indian developers. Section 194-O e-commerce TDS applies to an e-commerce operator paying a resident participant; whether it reaches Apple (a non-resident paying from abroad) is not settled in any source found.

### Cited Findings
- Oct 26 2020 Apple news: "India: New equalization levy of 2% (in addition to the existing goods and services tax of 18%)" — [PRIMARY: Apple Developer News, 26 Oct 2020](https://developer.apple.com/news/?id=ul8i5to3)
- Aug 29 2024 Apple news: "India: Equalization levy of 2% no longer applicable", effective 29 August 2024; proceeds adjusted — [PRIMARY: Apple Developer News, 29 Aug 2024](https://developer.apple.com/news/?id=rob1vlg0)
- Search-result summary of Apple help text says Apple "collects and remits applicable taxes in India according to Exhibit B of the Paid Applications Agreement". Not verified by a full-page fetch — [PRIMARY but unverified: App Store Connect Help, Understanding taxes](https://developer.apple.com/help/app-store-connect/making-payments-to-apple/understanding-taxes/)
- Proceeds for high-tax territories already have taxes removed, so India proceeds look lower than plain commission maths suggests — [SECONDARY: AppsOps](https://appsops.store/blog/app-store-tax-vat-gst-territories)
- Section 194-O (from 1 Oct 2020): an e-commerce operator deducts TDS on sales by an e-commerce participant; the participant must be resident in India. Rate cut from 1% to 0.1% from 1 Oct 2024. No TDS for a resident individual/HUF with gross sales under ₹5 lakh who gives PAN/Aadhaar — [SECONDARY: ClearTax 194-O](https://cleartax.in/s/section-194o); [SECONDARY: 5paisa 194-O](https://www.5paisa.com/stock-market-guide/tax/section-194o)

### Inferences
- With EL gone since Aug 2024, the only Indian indirect tax inside an Indian-customer price is 18% GST, which Apple (as seller) accounts for; the developer does not charge or remit GST on the Indian customer sale.
- At TapLog's scale (well under ₹5 lakh), even if 194-O applied to Apple, the ₹5 lakh exemption would probably cover it. Check the Form 26AS / AIS for any TDS credit each year.

### Gaps
- Did not read the live Paid Applications Agreement Schedule 2 / Exhibit B text for India (Apple's legal role — agent, commissionaire or reseller — in India).
- No primary confirmation that Apple deducts or does not deduct Indian TDS. The AIS/26AS of an actual Indian App Store developer would settle it.

## 3. GST for the developer (export of services, threshold, LUT, Indian customers)

### Takeaway
The GST registration threshold for services is ₹20 lakh aggregate turnover (₹10 lakh in special category states). Zero-rated exports count in aggregate turnover, but a small developer below the threshold who is not in a compulsory-registration category need not register. LUT (Form GST RFD-11) is needed only by a registered person making zero-rated supplies without paying IGST. Whether App Store proceeds are an "export of services" depends on the five tests in IGST section 2(6), in particular that the recipient (Apple's non-Indian entity) is outside India and payment arrives in convertible foreign exchange. CA FLAG throughout.

### Cited Findings
- CGST Act section 22: a supplier is liable to register if aggregate turnover in a financial year exceeds ₹20 lakh, with lower limits for special category states — [PRIMARY: CBIC tax repository, CGST s.22](https://taxinformation.cbic.gov.in/content/html/tax_repository/gst/acts/2017_CGST_act/active/chapter6/section22_v1.00.html) (page did not load in fetch; text from search result)
- Exports of services are zero-rated. The exporter may export under bond/LUT without paying tax and claim ITC refund, or pay IGST and claim a refund — [PRIMARY: CBIC LUT master circular 8/8/2017](https://cbic-gst.gov.in/pdf/Final_Master_circular_LUT_Bond_04102017.pdf)
- "All registered taxpayers who have zero-rated supply of goods or services have to furnish LUT in Form GST RFD-11 on the GST Portal before affecting such supply" — [PRIMARY: GST portal tutorial, Furnishing of LUT](https://tutorial.gst.gov.in/userguide/refund/Furnishing_of_Letter_of_Undertaking_for_Export_of_Goods_or_Services.htm)
- IGST s.2(6) export of services needs all five: (i) supplier in India; (ii) recipient outside India; (iii) place of supply outside India; (iv) payment in convertible foreign exchange or in INR where RBI permits; (v) supplier and recipient not merely establishments of a distinct person — [SECONDARY summary of statute: TaxGuru on CBIC clarification](https://taxguru.in/goods-and-service-tax/cbic-clarifies-conditions-export-services-igst-act-2017.html); statute at [PRIMARY: CBIC IGST s.2](https://taxinformation.cbic.gov.in/content/html/tax_repository/gst/acts/2017_IGST_Act/active/chapteri/section2_v1.00.html)
- A CA article (May 2021) treats app sales as OIDAR, says export status needs receipt in foreign exchange, and claims domestic OIDAR supplies need registration with no threshold. That last claim is doubtful (see Inferences) — [SECONDARY: TaxGuru, Abhinandan Sethia CA, 2021](https://taxguru.in/goods-and-service-tax/gst-liability-app-developers.html)
- If payment arrives in INR through Razorpay/UPI/Indian bank transfer, the forex condition fails; use platform payout in forex — [SECONDARY: IncorpX](https://www.incorpx.io/blog/gst-export-of-services-freelancers-india)
- An Indian developer on Quora reports that Apple pays in INR through an intermediary bank without a FIRC, and asks how to prove export — [SECONDARY: Quora thread](https://www.quora.com/GST-I-am-an-app-developer-How-do-I-prove-that-the-sales-are-outside-India-since-payment-is-made-in-INR-by-Apple-through-a-intermediary-bank-and-no-FIRC-is-provided)

### Inferences
- If Apple is the seller to customers, the developer's supply is to Apple (a non-Indian Apple entity), not to end users. On that reading, even proceeds from Indian customers are a supply to Apple outside India, and Apple handles GST to the Indian consumer. Whether that supply is an export of services or an "intermediary"-type supply is a CA decision.
- The compulsory OIDAR registration in CGST s.24 targets suppliers located outside India that supply to unregistered Indian persons; it probably does not force a small Indian developer to register. The 2021 TaxGuru claim should not be relied on without CA review. Not verified from s.24 text in this session.
- Year one below ₹20 lakh: probably no GST registration, no LUT, no GST returns. If the developer registers voluntarily (or crosses ₹20 lakh), file the LUT before the first zero-rated supply in each financial year.
- Because Apple may pay in INR (see section 5), the s.2(6)(iv) forex test needs bank proof that the INR credit came from a foreign-currency remittance (FIRC/FIRA/e-BRC). This matters only once registered.

### Gaps
- CBIC pages would not load (certificate error), so s.22 special-category list and s.24 text were not read directly.
- No GST ruling (AAR) found on App Store proceeds specifically.

## 4. Indian income tax (head of income, presumptive scheme, ITR, advance tax, foreign tax credit, Income-tax Act 2025)

### Takeaway
From 1 April 2026 the Income-tax Act, 2025 replaces the 1961 Act, uses "tax year" in place of previous year/assessment year, and merges 44AD, 44ADA and 44AE into a single section 58 with the same rates and limits. App Store proceeds are business or professional income. Whether TapLog income fits the business scheme (old 44AD, 6% deemed profit on digital receipts) or the professional scheme (old 44ADA, 50%) is a CA decision. Foreign tax credit Form 67 becomes Form 44 from tax year 2026-27.

### Cited Findings
- Income-tax Act 2025 takes effect 1 April 2026; 44AD, 44ADA and 44AE merge into section 58 using serial numbers: Sl. 1 business (44AD), Sl. 2 transport (44AE), Sl. 3 profession (44ADA). Deemed profit: 6% of turnover for digital receipts, 8% otherwise; professionals 50% of gross receipts. Books-of-account rule (old 44AA) moves to section 62. "Tax Year" replaces previous year/assessment year — [SECONDARY: TaxGuru](https://taxguru.in/income-tax/presumptive-taxation-simplified-income-tax-act-2025-merges-44ad-44ada-44ae.html)
- Old 44ADA = section 58, Sl. No. 3; thresholds, rates and conditions carry forward unchanged for FY/tax year 2026-27 — [SECONDARY: Karnanica](https://www.karnanica.com/presumptive-taxation-for-professionals/); [SECONDARY: Remote Munshi](https://remotemunshi.com/blog/section-58-replaces-44ad-44ada)
- Business turnover limit ₹2 crore (₹3 crore if cash receipts under 5%) — [SECONDARY: TaxGuru](https://taxguru.in/income-tax/presumptive-taxation-simplified-income-tax-act-2025-merges-44ad-44ada-44ae.html)
- Form 67 (Rule 128) is used for AY 2026-27 and earlier; from tax year 2026-27 it becomes Form 44 under Rule 76 of the Income-tax Rules 2026 and s.533(2)(q) of the 2025 Act. A CA certificate is proposed for individuals whose foreign tax is ₹1 lakh or more — [SECONDARY: Vested blog](https://vested.blog/posts/form-67-form-44-transition-ay-2026-27)
- Form 67 is filed on the e-filing portal — [PRIMARY: Income Tax Dept, Form 67 user manual](https://www.incometax.gov.in/iec/foportal/help/statutory-forms/popular-form/form67-um)

### Inferences
- Selling an app to Apple for resale reads more like a business (old 44AD / s.58 Sl. 1, 6% on digital receipts) than a notified profession (old 44ADA covers professions such as technical consultancy). CA FLAG: pick the scheme.
- If Apple withholds no US tax (section 1), there is no foreign tax to credit and Form 67/44 is not needed. It matters only if Apple withholds (for example, 30% without a valid W-8BEN).
- FY 2025-26 income is filed under the 1961 Act (AY 2026-27); FY 2026-27 income (tax year 2026-27) is the first year under the 2025 Act.

### Gaps
- Not verified from a primary source in this session: ITR form choice (ITR-4 Sugam for presumptive, ITR-3 otherwise); advance-tax trigger (₹10,000 liability) and the presumptive single instalment by 15 March; the 2025-Act section numbers for advance tax. Confirm on incometaxindia.gov.in or with a CA.
- No primary CBDT text for s.58 fetched; all s.58 detail is from CA-firm secondary sources.

## 5. Payouts (currency, SWIFT, threshold, purpose code, FIRC/FIRA/e-BRC, charges)

### Takeaway
Apple lists India with INR bank accounts at a minimum payment threshold of USD 0.02 (the default for unlisted combinations is USD 40). Secondary sources say Apple sends USD over SWIFT, converted to INR by banks, 45–60 days after the revenue month. Inward-remittance proof (FIRA/e-FIRA/FIRC) is the GST export evidence. Expect wire fees and an FX spread.

### Cited Findings
- Minimum payment threshold: India, INR, USD 0.02; all other bank countries/currencies not listed need more than USD 40 — [PRIMARY: App Store Connect Help, Minimum payment threshold](https://developer.apple.com/help/app-store-connect/reference/reporting/minimum-payment-threshold)
- Apple pays USD, converted to INR by intermediaries over SWIFT; payments often start around the 7th; funds arrive 45–60 days after the revenue month — [SECONDARY: Karbon Card](https://www.karboncard.com/blog/apple-google-payouts-india)
- Typical costs: ₹250–₹750 inbound wire fee, FX markup 1.5–2.5% over interbank, and $10–$30 possible intermediary deductions — [SECONDARY: Karbon Card](https://www.karboncard.com/blog/apple-google-payouts-india)
- Purpose code for software revenue: P0802 (or P1001 per the same guide); "Download e-FIRA for every inward remittance, it is your proof of foreign exchange" — [SECONDARY: Karbon Card](https://www.karboncard.com/blog/apple-google-payouts-india)
- One developer reports INR credit through an intermediary bank and no FIRC — [SECONDARY: Quora](https://www.quora.com/GST-I-am-an-app-developer-How-do-I-prove-that-the-sales-are-outside-India-since-payment-is-made-in-INR-by-Apple-through-a-intermediary-bank-and-no-FIRC-is-provided)
- Payment and proceeds views in App Store Connect — [PRIMARY: View payments and proceeds](https://developer.apple.com/help/app-store-connect/getting-paid/view-payments-and-proceeds/)

### Inferences
- Before the first payout: accept the Paid Apps Agreement, submit the W-8BEN, add the bank account (the name must match the enrolled individual), then ask the bank how Apple credits arrive and how to get an e-FIRA / FIRC for each credit, and give the purpose code (P0802 is the commonly cited code for software services; the bank may use another). CA FLAG on purpose code.
- A $4.99 IAP pays roughly $4.24 proceeds before tax under a 15% commission rate (Small Business Program), less in high-VAT/GST countries; the USD 0.02 threshold means even tiny months pay out, and each tiny payout may carry a fixed wire fee.

### Gaps
- No Apple primary page found that states whether Indian accounts receive USD or INR from Apple.
- DGFT e-BRC (now for services on the DGFT portal) not researched; whether a small non-GST-registered developer needs e-BRC is unconfirmed.
- Purpose code from secondary sources only; RBI purpose-code list not fetched.

## 6. Apple invoices and financial reports to keep; flags for a Chartered Accountant

### Takeaway
Keep App Store Connect financial reports, payment statements and Apple tax invoices/documents, plus bank e-FIRA/FIRC for every credit. Apple's help centre has a page for invoices and other tax documents.

### Cited Findings
- App Store Connect has a "Manage invoices and other tax documents" section under tax information — [PRIMARY: App Store Connect Help](https://developer.apple.com/help/app-store-connect/manage-tax-information/manage-invoices-and-other-tax-documents/)
- Payment information reference (what each payment report shows) — [PRIMARY: App Store Connect Help, Payment information](https://developer.apple.com/help/app-store-connect/reference/reporting/payment-information/)

### Inferences — CA decisions (not rules)
1. W-8BEN Part II treaty line (royalties Art. 12 vs business profits Art. 7 vs none). The form is locked after submission.
2. Business (s.58 Sl. 1, ex-44AD) vs profession (s.58 Sl. 3, ex-44ADA) vs regular books.
3. Whether App Store proceeds are an "export of services" under IGST s.2(6), including proceeds from Indian customers routed through Apple, and whether INR credits meet the forex test.
4. Whether to register for GST voluntarily below ₹20 lakh (and then file the LUT each year).
5. Purpose code and FIRC/FIRA/e-BRC documentation with the bank.

### Gaps
- Did not read the invoices page body, so what Apple issues to Indian individuals (for example, self-billed invoices or commission invoices) is not confirmed.
