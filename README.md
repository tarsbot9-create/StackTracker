# StackTracker

**Track your Bitcoin savings journey.** A privacy-first, Bitcoin-only savings tracker for iOS.

## Features

- **Manual BTC Entry** - Log purchases by date, amount, and price
- **Dashboard** - Total stack in BTC/sats/USD with real-time price
- **Portfolio** - All purchases with individual P&L, sortable and filterable
- **DCA Analytics** - Cost basis vs price charts, investment vs value, per-purchase performance
- **Milestones** - Progress toward 100K sats, 1M sats, 0.1 BTC, 1 BTC
- **CSV Export** - Export your data for tax prep
- **Privacy First** - All data stored locally. No accounts. No servers. No tracking.

## Tech Stack

- SwiftUI (iOS 17+)
- SwiftData (local persistence)
- Swift Charts
- CoinGecko API (free tier, BTC price data)

## Setup

1. Open Xcode
2. File > New > Project > iOS App
3. Name: StackTracker, Interface: SwiftUI, Storage: SwiftData
4. Replace the generated files with the contents of `StackTracker/`
5. Build & Run

## Project Structure

```
StackTracker/
├── StackTrackerApp.swift       # App entry + tab navigation
├── Models/                     # SwiftData models (Purchase, PriceCache)
├── Services/                   # Price API + portfolio calculations
├── Views/
│   ├── Dashboard/              # Main screen with price, stack summary, stats
│   ├── AddPurchase/            # Purchase entry form
│   ├── Portfolio/              # Purchase list with P&L
│   ├── Analytics/              # DCA charts and performance
│   ├── Milestones/             # Progress toward sats goals
│   ├── Settings/               # Preferences, export, about
│   └── Components/             # Reusable UI components
├── Theme/                      # Colors and styling
└── Extensions/                 # Number/date formatters
```

## Roadmap

- [ ] RevenueCat subscription paywall
- [ ] Home screen widgets (WidgetKit)
- [ ] "What if" DCA simulator
- [ ] xpub/address watch-only tracking
- [ ] iCloud sync
- [ ] Share milestone cards
- [ ] Apple Watch complication

## License

Proprietary. All rights reserved.
