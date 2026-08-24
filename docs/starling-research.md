# Starling — Comprehensive Research

## 1. Company Overview

| Fact | Detail |
|---|---|
| **Full name** | Starling (formerly Starling Bank) |
| **Founded** | January 2014, London, UK |
| **Founder** | Anne Boden MBE (30+ years in banking; ex-AIB, Standard Chartered, UBS, ABN AMRO) |
| **Current CEO** | Raman Bhatia (Boden stepped down 2024) |
| **Type** | Private (planned London IPO) |
| **Valuation** | £2.5 billion ($3.1B) |
| **Employees** | ~1,000+ |
| **HQ** | London, UK |
| **Licence** | Full UK banking licence (FSCS protected up to £85,000) |

### Origin story
Anne Boden left her COO role at Allied Irish Banks in 2014 after seeing firsthand how the financial crisis destroyed lives. She wanted to build a bank for people who lost trust in the system. She secured a £48M investment from Harald McPike after a 3-day pitch session, got a banking licence in June 2016, and launched in beta March 2017. Tom Blomfield (later Monzo founder) was her CTO but left after disagreements in 2015, taking several engineers with him.

---

## 2. Key Metrics (2023-2025)

| Metric | 2022 | 2023 | 2024-25 |
|---|---|---|---|
| **Revenue** | £453M | £682M (+50%) | £714M (+5%) |
| **Net income** | £142M | £301M (+111%) | £223M (PBT) |
| **Active users** | 3.6M | 4.2M | 4.2M+ core |
| **SME accounts** | ~400K | 500K+ | Growing |
| **Total deposits** | £10.5B | £11B | Growing |
| **Card spend** | £16.5B | £19.9B (+20.6%) | Growing |
| **Transactions** | £143B | £174B (+21%) | Growing |
| **Avg retail deposit** | £2,900/mo | £2,500/mo | — |
| **Avg SME deposit** | £14,400/mo | £12,800/mo | — |
| **Gross margin** | — | — | 72.7% |

### Revenue model
- **Interest income** (86% of revenue) — lending, overdrafts, FSCS-protected deposits
- **Interchange fees** (~1% per card transaction, shared with Mastercard)
- **Subscriptions** — second current account (£2/mo), Kite kids (£2/mo), USD business (£5/mo), Business Toolkit
- **Transfer fees** — FX conversion (0.4-2%), SWIFT transfers (£5.50)
- **Marketplace referral fees** — partners pay for customer referrals
- **Engine SaaS** — BaaS platform licensing (£2.3M → £8.7M YoY)

### UK neobank ranking (by users)
1. **Revolut** — ~8M+ UK users
2. **Monzo** — ~6M+ UK users
3. **Starling** — ~4.2M UK users

But Starling has the **highest revenue per customer** — 3x more per user than competitors.

---

## 3. Complete Feature Map

### 3A. Personal Banking

| Feature | Description |
|---|---|
| **Current Account** | Full UK bank account, free Mastercard debit card |
| **Instant Notifications** | Real-time push on every transaction with merchant name + category icon |
| **Spending Insights** | Auto-categorised spending by category (50+) and by merchant, with bar charts and date range picker |
| **Spending Intelligence** | AI-powered natural language queries on spending data (Google Gemini) |
| **Spaces** | Virtual sub-accounts to ring-fence money for specific purposes |
| **Round Ups** | Round transactions to nearest pound, send spare change to a Space (x1/x2/x5/x10 multiplier) |
| **Bills Manager** | Set aside money for regular bills, auto-deduct when due |
| **Connected Cards** | Additional debit cards linked to specific Spaces |
| **Virtual Cards** | Up to 5 virtual debit cards for Spaces |
| **Fixed Saver** | Fixed-term savings with interest |
| **Joint Accounts** | Shared accounts with partners |
| **Kite** | Children's accounts (ages 6-16) with parental controls |
| **Under 16s Payment Link** | Unique link anyone can use to send money to a child's Space |
| **Card Controls** | Freeze/unfreeze, limit ATM withdrawals, block online payments |
| **Cheque Deposits** | Mobile cheque capture |
| **Overdraft** | Arranged (0%) and unarranged (15-35% daily) |
| **Loans** | Personal and business loans |
| **Marketplace** | Third-party integrations (insurance, pensions, mortgages) |
| **Apple Watch** | Full app on wrist |

### 3B. Business Banking

| Feature | Description |
|---|---|
| **Business Current Account** | Free, with invoicing and accounting tools |
| **Sole Trader Account** | Simplified for self-employed |
| **Business Toolkit** | Accounting, bookkeeping, tax categorisation (subscription) |
| **Business Spending Insights** | Categories like Marketing, Self-Assessment Tax |
| **Invoicing** | Create and send invoices from the app |
| **Multi-user Access** | Team accounts with different permission levels |
| **Integration** | Xero, QuickBooks, FreeAgent, Zettle |

### 3C. Engine by Starling (BaaS / SaaS)

| Fact | Detail |
|---|---|
| **What** | Cloud-native banking platform sold as SaaS to other banks |
| **Revenue** | £2.3M (2024) → £8.7M (2025) — 3.8x growth |
| **Clients** | Other banks and financial institutions globally |
| **Capabilities** | Account opening, payments, card issuance, savings, budgeting tools |
| **API** | Modular, API-based architecture |
| **Expansion** | Launched first US subsidiary (April 2025) |
| **Differentiator** | Banks can run their own digital banking on Starling's proven tech |

---

## 4. Spending Intelligence (AI Feature — June 2025)

This is Starling's most innovative recent feature. Key details:

- **Natural language queries** — ask questions like "How much did I spend on groceries last week?" or "How much did I donate to charity last year?"
- **Voice input** — speak your question instead of typing
- **Personalised prompts** — AI suggests questions based on YOUR spending patterns (e.g. "You travel a lot — ask about your holiday spending")
- **Graph + analytics response** — visual charts and breakdowns
- **Privacy-first** — opt-in only, data stays in Google Cloud, not used for training
- **Built on Google Gemini** — understands intent and context of natural language
- **UK first** — first UK bank to let customers interact with spending data via AI

### How it works technically
1. Customer asks a question (text or voice)
2. Google Gemini understands intent and context
3. Starling's proprietary systems query the customer's transactional data
4. Analysis is returned with graphs and insights
5. All data remains within Starling's secure Google Cloud environment

---

## 5. Design Language & UX

### Brand (Sep 2025 rebrand)
- **New name**: "Starling" (dropped "Bank")
- **New brand platform**: "Get busy living"
- **Design inspiration**: Murmurations (starling flock flight patterns)
- **Philosophy**: Money management as enabling life, not restricting it
- **Logo**: Abstract starling in flight (replaced the old bird icon)
- **Card redesigns**: New colours and patterns

### App UX Patterns
- **Tab-based navigation**: Home, Spaces, Spending, Payments, Card
- **Spending tab**: Categories or Merchants toggle, bar chart, date range picker, source toggle (include/exclude Spaces)
- **Pie chart on home**: Shows spending breakdown at a glance (recently changed to bar charts)
- **Transaction feed**: Chronological list with merchant icons, category badges, amounts
- **Transaction detail**: Tap any transaction to see notes, receipts, category, merchant
- **Category customisation**: 50+ built-in categories, can rename any, add custom tags
- **Date range presets**: This month, Last month, Custom, Payday-aligned
- **Spaces UI**: Cards with photos, targets, progress bars, virtual cards

### What users love most (Reddit/App Store)
1. **Spaces** — "virtual envelope budgeting" — #1 praised feature
2. **Instant notifications** — real-time, detailed
3. **Spending Insights** — category breakdown, merchant tracking
4. **Clean UI** — "beautifully designed", "easy to navigate"
5. **Round Ups** — passive saving that adds up
6. **No fees** — free current account, free ATM, free card

---

## 6. Technology Stack

| Layer | Technology |
|---|---|
| **Backend** | ~20+ Java microservices |
| **Cloud** | AWS (primary), Google Cloud (secondary) |
| **Containers** | Docker |
| **Orchestration** | Custom (evaluating Kubernetes/EKS/GKE) |
| **APIs** | RESTful, async (each service has inbound command bus + database) |
| **Deployment** | 4-5 deploys/day to production |
| **Monitoring** | Prometheus + Grafana |
| **Logging** | ELK stack (Elasticsearch, Logstash, Kibana) |
| **Load balancing** | Nginx + AWS ELBs |
| **IaC** | CloudFormation + custom scripts |
| **iOS** | Swift, MVVM-C architecture, highly modular |
| **Android** | Java/Kotlin |
| **Security** | Microsegmentation, private keys per device, jailbreak detection, data encrypted at rest + in transit |
| **Testing** | Chaos engineering (Netflix-style, in production) |

### Architecture philosophy
- **Async APIs** between services (prioritise resilience and auditability over raw speed)
- **Service isolation** via separate VPCs and subnets
- **Backwards API compatibility** enforced via Swagger + Pact
- **Convention over Conway** — services divided by function, not team (flexible at small scale)

---

## 7. Competitive Positioning

### Starling vs Monzo vs Revolut

| Dimension | Starling | Monzo | Revolut |
|---|---|---|---|
| **Focus** | "Proper bank" | "Money management" | "Global finance" |
| **Profitability** | 4th year profitable | Recently profitable | Complex (crypto, trading) |
| **Revenue/user** | Highest (3x Monzo) | Medium | Lower (volume play) |
| **Spending tools** | 50+ categories, AI queries | Similar categories | Basic |
| **Budgeting** | Spaces + Round Ups | Pots + Round Ups | Vaults + Vaults |
| **International** | UK only | UK + limited | 200+ countries |
| **Crypto** | No | No | Yes |
| **Stocks** | No | No | Yes |
| **Design** | Clean, minimal | Colourful, friendly | Dense, feature-heavy |
| **Business** | Full suite (Engine) | Full suite | Basic |

### What Starling does better than anyone
1. **Revenue efficiency** — highest profit per customer
2. **Spending Intelligence** — AI natural language on spending data
3. **Engine SaaS** — licensing their banking platform to other banks
4. **Spaces UX** — the most intuitive envelope budgeting implementation
5. **Stability** — survived COVID without layoffs while Monzo/Revolut cut staff

---

## 8. Lessons for TapLog

### Direct feature inspirations

| Starling Feature | TapLog Adaptation | Effort |
|---|---|---|
| **50+ spending categories** | Expand default seeds, add more niche categories | Low |
| **Monthly bar chart** | Add monthly view to Weekly Recap | Medium |
| **Date range picker** | Custom periods, payday-aligned | Medium |
| **Spaces / envelope budgets** | Budget targets per category | High |
| **Round Ups** | N/A (requires banking integration) | N/A |
| **AI Spending Intelligence** | On-device AI queries via Apple Intelligence | High |
| **Transaction notes + receipts** | Already have notes; add photo attach | Low |
| **Payday-aligned periods** | Let user set their "month start day" | Low |
| **Merchant tracking** | Auto-detect merchant from note/description | Medium |
| **Category search** | Search/filter categories in the picker | Low |

### UX patterns to adopt
1. **Transaction detail view** — tap any log to see full details, edit, add receipt
2. **Category icons** — every category has a visual identifier (emoji is already there)
3. **Source toggle** — show/hide different data sources (e.g. manual vs widget vs Siri logs)
4. **Progress bars on categories** — "You've spent $400 of your $500 Food budget"
5. **Personalised suggestions** — "You usually log coffee in the morning"

### Business model lessons
1. **Free core, premium insights** — Starling's core is free; advanced features (Business Toolkit, second accounts) are paid
2. **BaaS as revenue** — Engine SaaS generates £8.7M/year by licensing their tech
3. **High revenue per user** — focus on depth, not just breadth
4. **Marketplace ecosystem** — third-party integrations add value without building everything

### What NOT to copy
1. **Requires bank account** — TapLog's zero-account philosophy is a differentiator
2. **UK-only** — TapLog is global
3. **Bank connection required** — TapLog's on-device-first approach is unique
4. **Dense feature set** — TapLog's 5-second capture simplicity is sacred
5. **Complex BaaS** — Engine is a whole separate business; not relevant for TapLog

---

## 9. Key Quotes

> "We built a bank in a year." — Greg Hawkins, CTO

> "We believe that anyone and everyone can be 'Good with money.'" — Harriet Rees, CIO

> "Knowledge is power, and it's the first step to taking active control of your money." — Harriet Rees, CIO

> "I often describe the Starling stack as the layers of a cake, with the icing being the mobile app that sits the top." — Anne Boden

---

## 10. Summary

Starling is what happens when you take banking seriously as a product. They:
- Built their own tech stack from scratch (no legacy)
- Focused on one thing (current account) and made it excellent
- Let the product speak (no marketing spend until 2019)
- Built for resilience (survived COVID without layoffs)
- Now licensing their platform to other banks (Engine SaaS)

For TapLog, the biggest takeaways are:
1. **Spending Insights UX** — the category/merchant/date-range breakdown is the gold standard
2. **AI queries** — asking natural language questions about your spending is the future
3. **Spaces** — envelope budgeting is the #1 feature users love
4. **Revenue efficiency** — you don't need millions of users if each one is valuable
5. **Simplicity first** — Starling started with ONE product and made it perfect

