# StackTracker Development Log

## Project Overview
**StackTracker** is a native iOS app (SwiftUI + SwiftData) for tracking Bitcoin DCA purchases, cold storage balances, and portfolio performance. All data stays on-device. No accounts, no servers.

**Repo:** https://github.com/tarsbot9-create/StackTracker
**Stack:** Swift 5, SwiftUI, SwiftData, iOS 17+, Xcode 26.3
**Bundle ID:** com.stacktracker.app

---

## Architecture

### Models (`StackTracker/Models/`)
- **Purchase.swift** - Core model. Tracks date, BTC amount, price, USD spent, wallet name, notes, and `transactionTypeRaw` (buy/sell/withdrawal/payment). Schema versioned (V1 -> V2 migration in place).
- **PriceCache.swift** - Caches BTC price data
- **WatchedAddress.swift** - Stores watched Bitcoin addresses (label, address, cached balance, last sync). Also contains `AddressTransaction` model for on-chain tx history with cost basis tracking (`costBasisSource`: matched/manual/historical/unset).

### Services (`StackTracker/Services/`)
- **PriceService.swift** - CoinGecko API for live BTC price, 24h change, 30-day chart data, and historical price lookups. Rate-limited to 1 call/60s.
- **PortfolioCalculator.swift** - Computes total stack (buys - sells, withdrawals NOT subtracted), exchange vs cold storage split, avg cost basis, realized P&L, DCA streak.
- **CSVImportService.swift** - Auto-detects platform from CSV headers and parses transactions. Supports: Coinbase, Cash App, Strike, Swan, River, StackTracker re-import, and generic CSV fallback. Handles Cash App quirks (parenthesized amounts, timezone dates, older exports with BTC amount only in Notes field). Uses `unicodeScalars` iteration to handle `\r\n` line endings (Swift's Character type merges `\r\n` into a single grapheme cluster).
- **BlockchainService.swift** - Mempool.space API for address balance lookup, transaction history, and auto-matching incoming txs to exchange purchases (by amount within 5% and time within 48h).

### Views (`StackTracker/Views/`)
- **Dashboard/** - Live BTC price ticker, 30-day chart, total stack (BTC/sats/USD), P&L, exchange vs cold storage breakdown, stats grid (cost basis, invested, purchases, DCA streak)
- **Portfolio/** - All purchases with individual P&L, sortable, filterable, swipe to delete
- **AddPurchase/** - Manual entry with USD/BTC toggle, current price auto-fill, wallet selector
- **Import/** - CSV import with platform auto-detect, preview screen, duplicate detection, select/deselect, transaction type badges (buy/sell/transfer/spent)
- **Addresses/** - Add Bitcoin address (validates format, queries mempool.space), address list with total cold storage balance, detail view with full tx history, cost basis coverage progress bar, auto-match + manual entry + historical price fallback
- **Settings/** - Denomination, currency, CSV import/export, delete data, about section
- **Components/** - BitcoinChartView, PriceTickerView, StatCard

### Key Design Decisions
- **File picker**: Uses `UIDocumentPickerViewController` with `asCopy: true` instead of SwiftUI's `fileImporter` (sandbox permission issues on simulator)
- **CSV parsing**: Iterates `unicodeScalars` not `Character` to handle Windows `\r\n` line endings
- **Stack calculation**: Withdrawals are transfers, not reductions. Total stack = buys - sells. Exchange + cold storage shown separately.
- **Transaction types**: buy, sell, withdrawal (transfer to cold storage), payment (BTC spent)
- **Cost basis waterfall**: Auto-match exchange withdrawals to on-chain deposits -> manual entry -> historical price from CoinGecko
- **Schema migration**: V1 (original) -> V2 (added transactionTypeRaw). Lightweight migration with fallback to fresh DB.

---

## Session Log: March 3, 2026

### Setup
- Installed Xcode 26.3 on Joey's Mac mini
- Authenticated GitHub CLI (`gh auth login`) as `tarsbot9-create`
- Downloaded iOS 26.2 simulator runtime
- Created GitHub repo and pushed existing codebase
- Generated Xcode project file (`.pbxproj`) from scratch
- First successful build and simulator launch

### Features Built
1. **CSV Import System**
   - Auto-detects Coinbase, Cash App, Strike, Swan, River from headers
   - Preview screen with per-row selection and duplicate detection
   - Fixed Cash App parsing: parenthesized amounts `($15.00)`, quoted prices with commas `"$67,213.26"`, timezone dates `2026-03-03 08:31:12 CST`
   - Fixed critical Swift bug: `Character` type merges `\r\n`, switched to `unicodeScalars`
   - Handles older Cash App exports (pre-2025) where BTC amount is only in Notes field
   - Replaced SwiftUI `fileImporter` with `UIDocumentPickerViewController(asCopy: true)` for reliable sandbox file access

2. **Sell/Withdrawal/Payment Tracking**
   - Full transaction type support in CSV import
   - Sells reduce stack and track realized P&L
   - Withdrawals are transfers (don't reduce stack, feed address auto-match)
   - Payments (spending BTC) reduce stack
   - Canceled/failed transactions automatically skipped
   - Color-coded badges in import preview

3. **Cold Storage Address Tracking**
   - Add any Bitcoin address (legacy, P2SH, SegWit, Taproot)
   - Validates format, queries mempool.space for balance and tx count
   - Full transaction history with cost basis tracking
   - Auto-match: compares incoming on-chain txs to exchange purchases (amount within 5%, time within 48h)
   - Manual cost basis entry and historical price fallback
   - Cost basis coverage progress bar
   - Read-only -- no private keys needed

4. **Dashboard Enhancements**
   - Exchange vs cold storage breakdown below stack total
   - Withdrawals no longer subtracted from total stack

5. **Schema Migration**
   - V1 -> V2 lightweight migration for new `transactionTypeRaw` field
   - Fallback to fresh DB if migration fails

### Bugs Fixed
- CSV parser treating entire file as one row (`\r\n` grapheme clustering)
- File picker sandbox permissions (switched to UIDocumentPickerViewController)
- Older Cash App exports missing Asset Amount/Price columns
- SwiftData schema mismatch after adding transaction type field
- `#Predicate` macro failing when capturing object properties (extracted to local `let`)

### Tested With
- Fake Coinbase CSV (12 buys, 1 send, 1 ETH buy -- correctly parsed)
- Real Cash App CSV (87 buys, 1 sell, 17 withdrawals, 148 non-BTC rows skipped)
- Satoshi's genesis address (57.12 BTC balance confirmed against mempool.space)
- Fake invalid address (error handling works)

---

## Session Log: March 4, 2026

### UI Overhaul
1. **Inline navigation titles** - Removed large headers from all pages, switched to compact inline titles
2. **30-day chart improvements** - Shrunk height (180->130), Y-axis scales to actual price range with 25% padding (no more starting from $0), clipped area fill so gradient doesn't bleed over x-axis
3. **Portfolio cleanup** - Filtered out withdrawals/payments (fixed +infinity P&L bug), only shows buys and sells
4. **Tab reorganization** - Removed "Add" tab, replaced with Analytics tab. New layout: Dashboard | Portfolio | Analytics | Addresses | Settings. Add Purchase accessible via (+) button in Portfolio toolbar. Add Address via existing button on Addresses page.

### Analytics Page Rebuild
- Removed "Cost Basis vs BTC Price" chart and "Per-Purchase Performance" chart
- Added "BTC Stacked by Year" bar chart (previous years green, current YTD orange, amounts annotated)
- Top cards: Total Stack | Total Return | Stacking Since | Purchases
- Fixed `costBasisOverTime` to filter buys only (was including withdrawals with $0 cost, inflating value)
- Fixed "Invested vs Value" chart - value line was incorrectly above invested due to withdrawal data

### Dashboard Streamlining
- Stat cards reduced to: Avg Cost Basis + Total Invested (side by side)
- Added full-width thin DCA Streak bar below cards
- DCA Streak calculation now only counts buy transactions (was counting withdrawals as purchase weeks)

### Adaptive Theme System
- Added Light/Dark/Auto segmented picker in Settings
- Theme colors use `UIColor { traitCollection in }` for dynamic switching
- Dark mode preserves original navy palette (#0D1117 background, #161B22 cards)
- Light mode uses iOS system colors (white background, gray cards)
- Auto mode follows device system appearance setting
- Removed all hardcoded `.toolbarColorScheme(.dark)` overrides

### Bug Fixes
- **PriceService singleton** - All tabs now share `PriceService.shared` instead of creating separate instances. Previously, CoinGecko rate limiter (1 call/60s) meant only Dashboard got the price; Analytics showed -100% return and $0 value.
- **Duplicate Theme.swift** - Had two Theme files (root + Theme/), edits went to wrong one. Removed duplicate.
- **Add Purchase sheet** - Added Cancel button and dismiss environment for sheet presentation

### Simulator Note
- Updated from iPhone 16 Pro to iPhone 17 Pro simulator (Xcode 26.3 / iOS 26.2)

---

## Session Log: March 5, 2026

### App Store Prep
1. **App Icon**
   - Researched best practices and competitor icons (Strike, Swan, River, Cash App)
   - Created 3 concepts: Stacking Bars, Stacked S, Stacked Chevrons
   - Selected Concept B: Stacked S — stylized "S" from horizontal bars with vertical strikes
   - Colors: Bitcoin orange gradient (#FFAB40 → #F7931A → #E07B10) on dark navy (#0D1117)
   - Polished with subtle glow, drop shadow, radial background
   - Exported 1024x1024 PNG: `AppIcon-1024.png`

2. **Privacy Policy**
   - Hosted on GitHub Pages: https://tarsbot9-create.github.io/stacktracker-site/privacy.html
   - Landing page: https://tarsbot9-create.github.io/stacktracker-site/
   - Support email: stacktrackersupport@gmail.com
   - Repo: https://github.com/tarsbot9-create/stacktracker-site

3. **Monetization Strategy**
   - Model: Freemium with RevenueCat
   - Monthly: $4.99 (stacktracker_pro_monthly)
   - Annual: $34.99 (stacktracker_pro_annual) — saves 42%, highlighted as default
   - Free tier: Manual add purchase, basic dashboard, up to 25 transactions, Settings
   - Pro tier: CSV import, unlimited transactions, cold storage addresses, Analytics tab, CSV export

### RevenueCat Integration
- Added RevenueCat/purchases-ios Swift Package dependency
- Created `SubscriptionService.swift` — @MainActor singleton, isPro state, purchase/restore methods, 25-tx limit check, RevenueCat delegate for reactive updates
- Created `PaywallView.swift` — Reusable paywall with annual (pre-selected, "BEST VALUE" badge) and monthly plans, subscribe/restore buttons, error alerts, legal links
- Created `OnboardingView.swift` — 3-page TabView(.page): "Track Your Stack", "Your Data, Your Device", "Stack Smarter" with "Start Free Trial" + "Continue with Free Plan"
- Modified `StackTrackerApp.swift` — RevenueCat configure() in init, onboarding gate via @AppStorage("hasCompletedOnboarding")
- Modified `SettingsView.swift` — Subscription section (Pro: "Active" + manage link; Free: "Upgrade to Pro"), import/export gated with lock icons
- Modified `DCAAnalyticsView.swift` — Blur overlay + lock icon + "Unlock Pro" button for free users
- Modified `AddressListView.swift` — Locked state with lock icon and "Unlock Pro" button
- Modified `AddPurchaseView.swift` — 25-tx limit check in savePurchase(), "X free transactions remaining" counter
- Modified `Package.swift` and `project.pbxproj` for SPM dependency and new file references
- **Build: SUCCEEDED** (only pre-existing warnings in BlockchainService and CSVImportService)
- **TODO:** Replace placeholder API key `"your_revenuecat_api_key_here"` in SubscriptionService.swift:17

### API Decision
- CoinGecko free tier stays for now (30 calls/min, ~10K/month)
- Upgrade to Analyst plan ($129/mo) only if substantial user growth
- No code changes needed for upgrade — just swap API key
- Proxy server consideration deferred to post-launch

---

## Session Log: March 9, 2026

### Tax Center (Phase 1)
1. **TaxLotEngine** (`Services/TaxLotEngine.swift`)
   - Full lot matching engine with FIFO, LIFO, HIFO accounting methods
   - Processes sells and payments against purchase lots chronologically
   - Holding period tracking (short-term < 365 days, long-term > 365 days)
   - Tax year summaries with ST/LT gain/loss breakdown
   - Sell simulator: replays existing disposals then simulates hypothetical sale

2. **Taxes Tab** (replaced Addresses tab)
   - FIFO/LIFO/HIFO segmented picker
   - Year filter chips (All + per-year based on actual disposal dates)
   - Capital gains summary card (net gain/loss, ST/LT breakdown)
   - Pro-gated with paywall for free users
   - Fixed "All" view bug: was showing "No taxable events in 0" instead of aggregating all years

3. **Disposal Detail View**
   - Full per-disposal breakdown: proceeds, cost basis, ST/LT split, method, lots consumed
   - Each lot match shows purchase date, price, BTC consumed, holding days, gain/loss

4. **Sell Calculator**
   - "Available to sell" card with live price
   - BTC input with 25%/50%/All quick-fill buttons
   - Toggle current market price vs custom price
   - FIFO/LIFO/HIFO picker
   - Results: proceeds, cost basis, ST gain, LT gain, expandable lot breakdown

### Tax Center (Phase 2)
5. **Realized vs Unrealized Gain Dashboard** (Analytics tab)
   - New "Gain Breakdown" card: realized gains (sells) vs unrealized gains (open positions)
   - Total P&L combining both

6. **Open Lots View** (Analytics tab)
   - Sheet showing every remaining purchase lot after disposals
   - Per-lot: purchase date, remaining BTC, cost basis, current gain/loss, holding days
   - Short-term lots: progress bar showing days until long-term (X/365)
   - Sort by: Oldest, Newest, Largest, Most Gain

7. **Tax Year CSV Export** (Taxes tab toolbar menu)
   - Form 8949 CSV: TurboTax/CPA-compatible (Description, Date Acquired, Date Sold, Proceeds, Cost Basis, Gain/Loss, Term)
   - Summary CSV: per-disposal overview with ST/LT breakdown
   - Respects year filter selection
   - `TaxExportService.swift` for generation + temp file writing

### Portfolio Upgrades
8. **Search bar** - searches wallet name, notes, date, BTC amount, USD amount, price
9. **Type filter chips** - All | Buys | Sells | Flagged (with count badges)
10. **Sort menu** (toolbar) - Newest, Oldest, Largest, Smallest, Top Performers, Worst Performers
11. **Flag system** - swipe right to flag/unflag, context menu, orange flag icon + border on flagged cards
12. **Schema V3** - Added `isFlagged` field to Purchase model (lightweight migration with fresh DB fallback)

### Settings & UI Polish
13. **App logo** at top of Settings - transparent background, centered, no border
14. **AppIcon** properly sized to 1024x1024 in asset catalog (was 1200x1028)
15. **AppLogo image set** - separate from AppIcon for use in UI

### Simulator Stability
16. **RevenueCat full bypass** - all methods (configure, refreshStatus, fetchPackages, purchase, restore) wrapped in `#if targetEnvironment(simulator)` guards that auto-grant Pro
17. **Onboarding bypass** - "Start Free Trial" skips paywall on simulator
18. **DB migration fallback** - if migration fails, deletes old store + journal files and starts fresh

### Bugs Fixed
- "No taxable events in 0" when All year filter selected (was looking for current year instead of aggregating)
- RevenueCat crashes on simulator (placeholder API key + unconfigured Purchases.shared)
- Onboarding "Start Free Trial" crash (triggered RevenueCat purchase flow)
- Schema migration "Duplicate version checksums" crash (V2 and V3 referenced same models)
- App icon 1200x1028 instead of 1024x1024 (resized with sips)

---

## Session Log: March 10, 2026

### App Icon Polish
- Recentered S logo from original 1200x1028 source (was off-center by ~89px)
- Removed dark line artifact on right side caused by non-square crop
- Boosted color saturation (+45%), contrast (+20%), brightness (+10%)
- Added subtle blue-indigo gradient to dark background
- Updated transparent in-app logo (AppLogo.imageset) to match
- Note: Professional vector icon recommended before App Store launch ($30-50 Fiverr)

### Widget Extension
- Built small (price + stack) and medium (price + portfolio P&L) widgets
- CoinGecko price fetch every 15 min with cached fallback
- Embedded in main app via PlugIns with proper Info.plist
- WidgetDataService for shared UserDefaults (needs App Groups from developer account)
- Price data confirmed flowing on simulator
- Portfolio data requires App Groups configuration (post-developer account activation)

### Bugs Fixed
- App icon dark line on right side (non-square source crop)
- App icon S logo off-center (cropped around content center, not image center)
- Widget "not found" in widget picker (missing embed build phase + Info.plist)
- Widget install crash "Invalid placeholder attributes" (needed NSExtension plist)

---

## Session Log: March 12, 2026 (Overnight)

### Haptic Feedback System
1. **Centralized Haptics.swift** - New utility in Extensions/ with static methods: `tap()`, `confirm()`, `select()`, `success()`, `warning()`, `error()`, `heavy()`
2. **Replaced all manual haptic calls** - Every `UIImpactFeedbackGenerator`/`UISelectionFeedbackGenerator`/`UINotificationFeedbackGenerator` call now uses the centralized helper
3. **Added haptics to:** filter chip selection, FIFO/LIFO/HIFO method picker, tax year picker, theme picker, save/edit transactions, CSV import/export, tax CSV export, delete all data, pull-to-refresh on all tabs

### Pull-to-Refresh
4. **Analytics tab** - Added `.refreshable` with price + chart data refresh
5. **Taxes tab** - Added `.refreshable` with price refresh
6. Both Dashboard and Portfolio already had pull-to-refresh (now with haptic feedback added)

### Error Handling
7. **Analytics network error** - Added `NetworkErrorBanner` to Analytics view with retry button when price fetch fails
8. **CSV import hardening** - Better error messages ("File may have been moved or deleted", "unsupported encoding", "Make sure it's a CSV exported from a supported exchange")
9. **Auto-deselect duplicates** - When CSV is parsed and duplicates are detected, they're automatically deselected (user can re-select if needed)
10. **Export error feedback** - Tax CSV export and Settings CSV export now show haptic error feedback on failure

### Light Mode Polish
11. **Theme additions** - Added `bitcoinOrangeText` (slightly darker orange for light mode readability) and `surfaceTint` (warm white for light mode surfaces)
12. All views already use adaptive Theme colors, so light mode support is solid

### Settings Enhancements
13. **Legal section** - Added Privacy Policy and Terms of Use (EULA) links
14. **CSV export upgrade** - Now includes transaction type (buy/sell/withdrawal/payment) and flagged status columns

### App Store Prep
15. **APP-STORE-METADATA.md** - Complete metadata document with:
    - App name, subtitle, keywords (100 chars)
    - Full description with feature highlights
    - Promotional text (170 chars)
    - Screenshot specs and recommended sequence
    - Privacy labels (data not collected)
    - In-app purchase descriptions
    - Age rating, copyright, URLs

### Build Status
- **BUILD SUCCEEDED** - All changes compile cleanly on iPhone 17 Pro simulator
- Committed and pushed to main

---

## Launch Checklist (Priority Order)

### Build Before Launch (TARS overnight work)
- [x] 1. Light mode polish — adaptive Theme colors, all screens use Theme constants ✅ (Mar 10+12)
- [x] 2. Empty states — Dashboard, Portfolio, Analytics, Taxes, Import all have empty states ✅ (Mar 9)
- [x] 3. Onboarding update — Tax Center slide added ✅ (Mar 9)
- [x] 4. Error handling — CSV import hardened, network errors on Dashboard + Analytics, haptic error feedback ✅ (Mar 12)
- [x] 5. Haptic feedback — centralized Haptics.swift, all interactions covered ✅ (Mar 12)
- [x] 6. Pull-to-refresh — all 4 data tabs (Dashboard, Portfolio, Analytics, Taxes) ✅ (Mar 10+12)
- [x] 7. Transaction detail view — full detail + edit + delete + flag ✅ (Mar 9)
- [ ] 8. App Store screenshots — 5-6 shots for 6.7" and 6.1" displays (needs developer account + real device/SimRecorder)
- [x] 9. App icon — "Stacked S" 1024x1024 PNG in asset catalog ✅ (Mar 5, confirmed Mar 12)
- [x] 10. Form 8949 CSV export — working with FIFO/LIFO/HIFO, per-lot breakdown ✅ (Mar 9)

### Developer Account — UNBLOCKED ✅ (Mar 12)
- [x] Apple Developer Program activated (Team ID: V6GW78L4D3) ✅
- [x] Bundle IDs registered: com.joeystanley.stacktracker + .widget ✅
- [x] Device registered (Joey's iPhone 17) ✅
- [x] Xcode signing configured (automatic, team V6GW78L4D3) ✅
- [x] App Store Connect listing created ✅
- [x] TestFlight live — build 4 (1.0) latest ✅
- [x] Export compliance automated (ITSAppUsesNonExemptEncryption=NO) ✅
- [x] TestFlight Pro bypass for testing ✅

### Remaining Before Launch
- [ ] RevenueCat real API key + create subscription products in App Store Connect
- [ ] Pricing strategy review (consider lower price for launch)
- [ ] App Store screenshots (6.7" + 6.1" sets)
- [ ] Remove TestFlight Pro bypass before public release
- [ ] App Privacy labels in App Store Connect

### Post-Launch (v1.1+)
- [ ] iCloud sync/backup (SwiftData + CloudKit)
- [x] Price alerts / milestone notifications (retention feature) ✅ (Mar 13)
- [x] Rate prompt after 2 weeks ✅ (Mar 13)
- [x] Milestones view integrated into Dashboard ✅ (Mar 13)
- [x] DCA Calculator (Dashboard toolbar) ✅ (Mar 13)
- [x] Sats-per-dollar in price ticker ✅ (Mar 13)
- [ ] Tax-loss harvesting scanner
- [ ] xPub/multi-address wallet tracking
- [x] Export: include transaction types + flagged status in CSV ✅ (Mar 12)

---

## Session Log: March 13, 2026 (Overnight)

### New Features Built
1. **NotificationService** (`Services/NotificationService.swift`)
   - Price alerts with local notifications (set target price + direction above/below)
   - Milestone achievement notifications (100K sats through 1 BTC)
   - Persists alerts to UserDefaults, tracks triggered state
   - Notification permission request flow

2. **ReviewPromptService** (`Services/ReviewPromptService.swift`)
   - StoreKit SKStoreReviewController integration
   - Conditions: 14+ days since install, 5+ transactions
   - 90-day cooldown between prompts, max 3/year
   - Records first launch date in UserDefaults

3. **PriceAlertsView** (`Views/Settings/PriceAlertsView.swift`)
   - Full UI for managing price alerts
   - Add alerts with pre-filled round number near current price
   - Shows active vs triggered alerts
   - Swipe to delete, notification permission prompt
   - Accessible from Settings > Notifications section

4. **Dashboard Milestones Card**
   - "Next Milestone" progress card shows on Dashboard below DCA streak
   - Progress bar, sats remaining, percentage complete
   - Taps through to full MilestonesView
   - Special "WHOLE COINER" state when all milestones complete

5. **DCA Calculator** (`Views/Dashboard/DCACalculatorView.swift`)
   - Weekly DCA planning tool accessible from Dashboard toolbar
   - Quick presets ($25-$500) or custom amount input
   - Time horizon slider (1-60 months)
   - Projects BTC/sats at current price
   - Shows sats per dollar, monthly cost, total invested

6. **Sats-per-Dollar Display**
   - Added "X sats/$1" below BTC price on Dashboard ticker
   - Quick reference for sats-denominated thinking

### Integration Points
- Dashboard `.task` now checks: review prompt, milestone notifications, price alerts
- StackTrackerApp `init()` records first launch for ReviewPromptService
- Settings shows Notifications section with Price Alerts link + active alert count
- All files added to Xcode project (.pbxproj) and build verified

### Infrastructure
- Updated overnight cron job from Kalshi (deprecated) to StackTracker focus
- BTC & macro research saved to workspace/research/2026-03-13-btc-macro.md

### Build Status
- **BUILD SUCCEEDED** — 3 commits pushed to main
- Commits: price alerts + milestones + review prompt, DCA calculator, sats-per-dollar

---

## Session Log: March 13, 2026 (Evening - with Joey)

Joey tested the app and provided UI/UX feedback. 10 commits, 2 TestFlight builds shipped.

### Website
1. **Landing page redesign** - stacktracker-site updated with feature grid (6 features), privacy banner, Free vs Pro pricing cards, proper footer. Was just a tagline + 2 links.

### UI/UX Fixes
2. **CSV import success screen** - Replaced cramped card with full-screen animated view: spring-animated checkmark with expanding orange rings, stats pills (buys/sells/transfers), full-width Done button
3. **Keyboard dismiss** - Added `scrollDismissesKeyboard(.interactively)` + orange "Done" toolbar button on Sell Calculator and Add Purchase. Removed broken root-level `onTapGesture` (was conflicting with buttons/toggles).
4. **30-day chart fix** - CoinGecko free tier sometimes returns 10+ months of data. Now filters response to only keep data points within the requested window.
5. **CoinGecko caching** - Chart data cached 60s, historical prices cached 10min. Reduces rate limit errors significantly.
6. **Avg cost basis fix** - Portfolio summary card was dividing totalInvested by remaining stack (buys-sells). Fixed to divide by total BTC bought (matches Dashboard calculation).
7. **Rounded fonts** - Portfolio card BTC/sats fonts changed from `.monospaced` to `.rounded` to match Dashboard style.

### New Features
8. **App icon** - Joey iterated with ChatGPT/Gemini. Final: white background, orange stacked bars + ₿ symbol. Source was 800x800, upscaled to 1024x1024. Created transparent orange-only version for Settings logo that works on dark/light mode.
9. **Portfolio layout swap** - Sort options (Newest, Oldest, Largest, Smallest, Top Performers, Worst Performers, Flagged) now primary scrollable chips. Type filter (All/Buys/Sells) moved to toolbar menu with filter icon.
10. **Portfolio summary card** - Three-column card at top of Portfolio: Invested | Total P/L ($ and %) | Avg Cost per BTC
11. **Dashboard cost basis change** - 7d percent change shown inside Avg Cost Basis stat card (derived from chart data)
12. **Paywall update** - "Cost Basis Tracking" added as first Pro feature: "Know your exact cost basis across every purchase"
13. **Dynamic milestones** - Named milestones under 1 BTC (100K sats through 1 BTC). Dynamic milestones above: 0.5 BTC steps from 1-10 BTC, 1 BTC steps from 10-21 BTC. 21 BTC = "One in a Million" (1/1,000,000 of total supply). MilestoneEngine shared between Dashboard and MilestonesView. Remaining shows BTC instead of sats when large.

### TestFlight Builds
- **Build 5 (1.0)** - website, import success, keyboard v1, chart fix, caching, icon, sort chips, summary card, cost basis change, paywall
- **Build 6 (1.0)** - dynamic milestones, cost basis fix, rounded fonts, keyboard dismiss v2

### Key Decisions
- Apple subscription management screen is native iOS - we don't control it
- $2.99 showing in Apple subscriptions is not from StackTracker (products not created yet)
- CoinGecko rate limit is per IP address, not per app
- **Joey feedback: don't build features autonomously** - run ideas by him first, let him approve before implementation

### Remaining Before Launch
1. RevenueCat real API key + subscription products in App Store Connect
2. App Store screenshots (6.7" + 6.1" sets)
3. Remove TestFlight Pro bypass
4. App Privacy labels
5. Add Joey's friend as External Tester (waiting on Apple ID email)

---

## Session Log: March 15, 2026 (Overnight)

### Code Quality
1. **MilestoneEngine refactor** - Eliminated ~65 lines of duplicate code in DashboardView. Dashboard now uses shared `MilestoneEngine.nextMilestone()` static method and `ultimateMilestoneSats` constant.
2. **Accessibility labels** - Added to Dashboard total stack, current value, and PriceTickerView (combined element with price + 24h change).
3. **Unused variable warning** - Fixed in `MilestoneEngine.dynamicMilestones()`.
4. **TASKS.md update** - Was stale since March 5, still referenced Kalshi. Updated to reflect current StackTracker status.
5. Clean build, zero warnings. 1 commit pushed.

---

## Session Log: March 16, 2026 (Evening - with Joey)

### UI Adjustments
1. **Stat card sizing** - Added "X purchases" subtitle to Total Invested card, then reverted both cards to clean matching design after removing 7d change.
2. **Removed 7d cost basis change** - Joey felt it was noisy/not informative. Deleted custom avgCostBasisCard, reverted to standard StatCard.

### Bug Fixes
3. **Notification denied state** - When user denies notification permission, "Enable Notifications" button now detects the denied state and opens iOS Settings directly. Auto-refreshes status when app returns to foreground.

### New: CSV Column Mapper
4. **Column mapping fallback UI** - When CSV auto-detect fails, shows "Map Your Columns" sheet with CSV preview + dropdown pickers for Date, BTC Amount, Price, USD Spent, and Transaction Type. Supports any exchange format now.
5. **CSV import list updated** - Shows "Auto-detected" next to Coinbase/Cash App/Strike/Swan/River, plus "Any Other CSV" with "Manual column mapping" option.

### CSV Format Verification Research
- Only Coinbase and Cash App CSV formats are verified against real exports
- Strike, Swan, River parsers are educated guesses based on public documentation
- Column mapper serves as universal safety net for any exchange

### Build
- **Build 7 (1.0)** shipped to TestFlight

---

## Session Log: March 17, 2026 (Overnight)

### Performance Optimization: DateFormatter Caching
1. **CSVImportService date parsing** - Previously created 12 DateFormatters + 2 ISO8601DateFormatters on every `parseDate()` call. These are expensive objects in Foundation. Refactored to use static cached formatters that are created once and reused across all CSV parsing. For a 500-row CSV, this eliminates ~7,000 unnecessary object allocations.
2. **Duplicate key generation** - `ParsedPurchase.duplicateKey` and `DuplicateInfo.init` each created a new ISO8601DateFormatter per call. Replaced with shared static formatters. For a 100-row CSV with 100 existing purchases, this eliminates ~200 unnecessary allocations.
3. **Compiler warning fix** - Removed unused `headers` variable in `parseWithMapping()` method (column indices are used directly, headers not needed).

### Build Status
- **BUILD SUCCEEDED** - zero warnings, clean build
- 1 commit pushed to main
