# StackTracker Widget - Setup Guide

## What's Built

All the code is written and ready. You need to do a few things in Xcode to wire it up.

### Files Created
- `StackTracker/Services/WidgetDataService.swift` - Shared data bridge (main app writes, widget reads)
- `StackTrackerWidget/StackTrackerWidget.swift` - Widget extension (small/medium/large views, timeline provider)
- `DashboardView.swift` - Updated to push data to widget on every price refresh and portfolio change

### Widget Sizes
- **Small:** BTC price, stack amount, value, P&L percentage
- **Medium:** Stack + value + P&L on left, stats grid (price, cost basis, streak, purchases) on right
- **Large:** Full dashboard with all stats in card layout

## Setup Steps in Xcode

### 1. Add Widget Extension Target
1. File > New > Target
2. Choose "Widget Extension"
3. Product Name: `StackTrackerWidget`
4. Uncheck "Include Configuration App Intent" (we use StaticConfiguration)
5. Click Finish
6. When prompted "Activate StackTrackerWidget scheme?", click Activate

### 2. Replace Generated Widget Code
Xcode will generate template files in `StackTrackerWidget/`. Replace all generated Swift files with:
- `StackTrackerWidget/StackTrackerWidget.swift` (already written)

Delete any Xcode-generated `.swift` files in that folder (like `StackTrackerWidgetBundle.swift`, `AppIntent.swift`, etc.)

### 3. Add App Group
Both targets need the same App Group:
1. Select the **StackTracker** (main app) target
2. Signing & Capabilities > + Capability > App Groups
3. Add group: `group.com.stacktracker.shared`
4. Select the **StackTrackerWidget** target
5. Same thing: Signing & Capabilities > App Groups > `group.com.stacktracker.shared`

### 4. Add Shared Files to Widget Target
The widget needs access to `WidgetDataService.swift`. In Xcode:
1. Select `StackTracker/Services/WidgetDataService.swift` in the file navigator
2. In the File Inspector (right panel), under "Target Membership", check **both**:
   - StackTracker
   - StackTrackerWidgetExtension

### 5. Build & Run
1. Select the StackTrackerWidget scheme
2. Build & run on simulator
3. Long-press home screen > tap "+" > search "StackTracker"
4. All three sizes should appear in the gallery with preview data

## How It Works

**Data Flow:**
```
Main App (DashboardView)
  -> WidgetDataService.update() writes to shared UserDefaults
  -> WidgetCenter.shared.reloadTimelines() triggers widget refresh
  -> Widget reads from shared UserDefaults via WidgetDataService.read()
```

**Refresh Schedule:**
- Widget timeline refreshes every 30 minutes automatically
- Also refreshes whenever the main app updates price or portfolio changes
- On pull-to-refresh in Dashboard
- When purchase count changes

**Design:**
- Matches the main app's dark theme (navy #0D1117 background)
- Bitcoin orange (#F7931A) accent
- Green/red P&L colors match main app
- Empty state prompts user to open app

## Notes
- Widget previews use `.preview` data (realistic fake data)
- The `Color(hex:)` extension is duplicated in the widget file since extensions can't be shared across targets without a framework
- No API calls from the widget itself -- all data comes from the main app via UserDefaults
