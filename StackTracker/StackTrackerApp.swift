import SwiftUI
import SwiftData

// MARK: - Schema Migration

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [PurchaseV1.self]
    }

    @Model
    final class PurchaseV1 {
        var id: UUID
        var date: Date
        var btcAmount: Double
        var pricePerBTC: Double
        var usdSpent: Double
        var walletName: String
        var notes: String
        var createdAt: Date

        init() {
            self.id = UUID()
            self.date = .now
            self.btcAmount = 0
            self.pricePerBTC = 0
            self.usdSpent = 0
            self.walletName = ""
            self.notes = ""
            self.createdAt = .now
        }
    }
}

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Purchase.self, PriceCache.self, WatchedAddress.self, AddressTransaction.self]
    }
}

enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}

@main
struct StackTrackerApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Purchase.self, PriceCache.self, WatchedAddress.self, AddressTransaction.self])
        let config = ModelConfiguration(schema: schema)
        do {
            container = try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: [config])
        } catch {
            // Fallback: if migration fails, create fresh container
            container = try! ModelContainer(for: schema, configurations: [config])
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(container)
    }
}

struct AppRootView: View {
    @AppStorage("appearanceMode") private var appearanceMode = "dark"

    private var uiStyle: UIUserInterfaceStyle {
        switch appearanceMode {
        case "dark": return .dark
        case "light": return .light
        default: return .unspecified
        }
    }

    var body: some View {
        ContentView()
            .onChange(of: appearanceMode, initial: true) { _, _ in
                applyAppearance()
            }
    }

    private func applyAppearance() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        for window in windowScene.windows {
            window.overrideUserInterfaceStyle = uiStyle
        }
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

            DCAAnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.xaxis")
                }

            AddressListView()
                .tabItem {
                    Label("Addresses", systemImage: "lock.shield")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(Theme.bitcoinOrange)
    }
}
