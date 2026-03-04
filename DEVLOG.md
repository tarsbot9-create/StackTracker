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

## Next Steps (Backlog)
- [ ] Analytics tab (was replaced by Addresses -- add back as section in Dashboard or Settings)
- [ ] Milestones view (100K sats to 1 BTC progress bars)
- [ ] Portfolio view: show transaction type badges, filter by type
- [ ] Export: include transaction types in CSV export
- [ ] Address auto-match: surface matches in UI ("This withdrawal matched your Cold Storage address")
- [ ] Tax reporting: FIFO/LIFO cost basis methods, annual summary
- [ ] App Store prep: app icon, screenshots, privacy policy
- [ ] TestFlight distribution
- [ ] Real device testing (iPhone via USB)
