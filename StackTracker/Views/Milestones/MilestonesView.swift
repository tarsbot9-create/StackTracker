import SwiftUI
import SwiftData

struct Milestone: Identifiable {
    let id = UUID()
    let name: String
    let targetSats: Int
    let icon: String
    let celebration: String
}

let milestones: [Milestone] = [
    Milestone(name: "100K Sats", targetSats: 100_000, icon: "star", celebration: "First milestone!"),
    Milestone(name: "500K Sats", targetSats: 500_000, icon: "star.fill", celebration: "Half a million sats!"),
    Milestone(name: "1M Sats", targetSats: 1_000_000, icon: "crown", celebration: "Whole coiner in sats!"),
    Milestone(name: "5M Sats", targetSats: 5_000_000, icon: "crown.fill", celebration: "Serious stacker!"),
    Milestone(name: "0.1 BTC", targetSats: 10_000_000, icon: "bitcoinsign.circle", celebration: "0.1 Bitcoin club!"),
    Milestone(name: "0.25 BTC", targetSats: 25_000_000, icon: "bitcoinsign.circle.fill", celebration: "Quarter coiner!"),
    Milestone(name: "0.5 BTC", targetSats: 50_000_000, icon: "bolt.fill", celebration: "Halfway to whole!"),
    Milestone(name: "1 BTC", targetSats: 100_000_000, icon: "trophy.fill", celebration: "WHOLE COINER!"),
]

struct MilestonesView: View {
    @Query(sort: \Purchase.date) private var purchases: [Purchase]

    private var totalSats: Int {
        Int(purchases.reduce(0) { $0 + $1.btcAmount } * 100_000_000)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Current stack
                    VStack(spacing: 4) {
                        Text("Your Stack")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text(Formatters.satsFormatter.string(from: NSNumber(value: totalSats)) ?? "0")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundColor(Theme.bitcoinOrange)
                        Text("sats")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
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
                    ForEach(milestones) { milestone in
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
                        Text("\(Formatters.satsFormatter.string(from: NSNumber(value: remaining)) ?? "0") sats to go")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
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
