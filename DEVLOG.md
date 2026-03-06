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

## Next Steps (Backlog)
- [ ] Replace RevenueCat placeholder API key (needs RevenueCat account setup)
- [ ] Update privacy policy to disclose RevenueCat anonymous purchase data
- [ ] App Privacy labels in App Store Connect
- [ ] Light mode polish (ensure all screens look good in both modes)
- [ ] App Store screenshots + metadata (description, keywords, subtitle)
- [ ] TestFlight distribution (requires active developer account)
- [ ] Milestones view (100K sats to 1 BTC progress bars)
- [ ] Portfolio view: show transaction type badges, filter by type
- [ ] Export: include transaction types in CSV export
- [ ] Address auto-match: surface matches in UI ("This withdrawal matched your Cold Storage address")
- [ ] Tax reporting: FIFO/LIFO cost basis methods, annual summary
