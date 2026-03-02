import SwiftUI
import SwiftData

@main
struct StackTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Purchase.self, PriceCache.self])
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }

            PortfolioView()
                .tabItem {
                    Label("Portfolio", systemImage: "list.bullet.rectangle")
                }

            AddPurchaseView()
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }

            DCAAnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(Theme.bitcoinOrange)
        .preferredColorScheme(.dark)
    }
}
