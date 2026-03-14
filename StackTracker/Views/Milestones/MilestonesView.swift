import SwiftUI
import SwiftData

struct Milestone: Identifiable {
    let id = UUID()
    let name: String
    let targetSats: Int
    let icon: String
    let celebration: String
}

struct MilestoneEngine {
    /// Named milestones for early stackers
    static let namedMilestones: [Milestone] = [
        Milestone(name: "100K Sats", targetSats: 100_000, icon: "star", celebration: "First milestone!"),
        Milestone(name: "500K Sats", targetSats: 500_000, icon: "star.fill", celebration: "Half a million sats!"),
        Milestone(name: "1M Sats", targetSats: 1_000_000, icon: "crown", celebration: "Whole coiner in sats!"),
        Milestone(name: "5M Sats", targetSats: 5_000_000, icon: "crown.fill", celebration: "Serious stacker!"),
        Milestone(name: "0.1 BTC", targetSats: 10_000_000, icon: "bitcoinsign.circle", celebration: "0.1 Bitcoin club!"),
        Milestone(name: "0.25 BTC", targetSats: 25_000_000, icon: "bitcoinsign.circle.fill", celebration: "Quarter coiner!"),
        Milestone(name: "0.5 BTC", targetSats: 50_000_000, icon: "bolt.fill", celebration: "Halfway to whole!"),
        Milestone(name: "1 BTC", targetSats: 100_000_000, icon: "trophy.fill", celebration: "WHOLE COINER!"),
    ]

    /// Generate dynamic milestones beyond 1 BTC up to 21 BTC
    static func dynamicMilestones(currentSats: Int) -> [Milestone] {
        var results: [Milestone] = []
        let currentBTC = Double(currentSats) / 100_000_000.0

        // Generate milestones from 1.5 BTC up to 21 BTC
        var btc = 1.5
        while btc <= 21.0 {
            let sats = Int(btc * 100_000_000)
            let name: String
            let icon: String
            let celebration: String

            if btc == 21.0 {
                name = "21 BTC"
                icon = "sparkles"
                celebration = "One in a Million! 1/1,000,000 of total supply!"
            } else if btc == btc.rounded() {
                name = "\(Int(btc)) BTC"
                icon = btc >= 10 ? "trophy.fill" : "bitcoinsign.circle.fill"
                celebration = "\(Int(btc)) Bitcoin stacked!"
            } else {
                name = String(format: "%.1f BTC", btc)
                icon = "bitcoinsign.circle"
                celebration = String(format: "%.1f Bitcoin stacked!", btc)
            }

            results.append(Milestone(name: name, targetSats: sats, icon: icon, celebration: celebration))

            // Increment: 0.5 steps up to 10 BTC, then 1.0 steps
            btc += btc < 10 ? 0.5 : 1.0
        }

        return results
    }

    /// All milestones relevant to the user (named + dynamic up to a few past current)
    static func allMilestones(currentSats: Int) -> [Milestone] {
        var all = namedMilestones

        // Only show dynamic milestones if user is past 0.5 BTC (show upcoming ones)
        if currentSats >= 50_000_000 {
            let dynamic = dynamicMilestones(currentSats: currentSats)

            // Show all completed dynamic + next 3 upcoming
            let upcoming = dynamic.filter { $0.targetSats > currentSats }
            let completed = dynamic.filter { $0.targetSats <= currentSats }
            let shown = completed + Array(upcoming.prefix(3))
            all.append(contentsOf: shown)
        }

        return all
    }
}

struct MilestonesView: View {
    @Query(sort: \Purchase.date) private var purchases: [Purchase]

    private var totalSats: Int {
        let buys = purchases.filter { $0.transactionType == .buy }.reduce(0.0) { $0 + $1.btcAmount }
        let sells = purchases.filter { $0.transactionType == .sell }.reduce(0.0) { $0 + $1.btcAmount }
        return Int((buys - sells) * 100_000_000)
    }

    private var totalBTC: Double {
        Double(totalSats) / 100_000_000.0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Current stack
                VStack(spacing: 4) {
                    Text("Your Stack")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    if totalBTC >= 1.0 {
                        Text(Formatters.formatBTC(totalBTC) + " BTC")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundColor(Theme.bitcoinOrange)
                    } else {
                        Text(Formatters.satsFormatter.string(from: NSNumber(value: totalSats)) ?? "0")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundColor(Theme.bitcoinOrange)
                        Text("sats")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Theme.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )

                // Milestones
                ForEach(MilestoneEngine.allMilestones(currentSats: totalSats)) { milestone in
                    MilestoneRow(
                        milestone: milestone,
                        currentSats: totalSats
                    )
                }
            }
            .padding(16)
        }
        .background(Theme.darkBackground)
        .navigationTitle("Milestones")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MilestoneRow: View {
    let milestone: Milestone
    let currentSats: Int

    private var progress: Double {
        min(Double(currentSats) / Double(milestone.targetSats), 1.0)
    }

    private var isCompleted: Bool { currentSats >= milestone.targetSats }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: milestone.icon)
                    .font(.title3)
                    .foregroundColor(isCompleted ? Theme.bitcoinOrange : Theme.textSecondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.name)
                        .font(.headline)
                        .foregroundColor(isCompleted ? Theme.bitcoinOrange : Theme.textPrimary)

                    if isCompleted {
                        Text(milestone.celebration)
                            .font(.caption)
                            .foregroundColor(Theme.profitGreen)
                    } else {
                        let remaining = milestone.targetSats - currentSats
                        let remainingBTC = Double(remaining) / 100_000_000.0
                        if remainingBTC >= 0.01 {
                            Text("\(Formatters.formatBTC(remainingBTC)) BTC to go")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        } else {
                            Text("\(Formatters.satsFormatter.string(from: NSNumber(value: remaining)) ?? "0") sats to go")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }

                Spacer()

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.profitGreen)
                        .font(.title3)
                } else {
                    Text("\(Int(progress * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(Theme.textSecondary)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.darkBackground)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(isCompleted ? Theme.profitGreen : Theme.bitcoinOrange)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.easeOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCompleted ? Theme.profitGreen.opacity(0.3) : Theme.cardBorder, lineWidth: 1)
        )
    }
}
