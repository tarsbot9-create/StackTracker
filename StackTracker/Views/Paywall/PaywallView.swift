import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    @State private var selectedPlan: PlanType = .annual
    @State private var isPurchasing = false
    @State private var showError = false

    var onProActivated: (() -> Void)?

    enum PlanType {
        case monthly, annual
    }

    private let features: [(icon: String, title: String, description: String)] = [
        ("target", "Cost Basis Tracking", "Know your exact cost basis across every purchase"),
        ("square.and.arrow.down", "CSV Import & Export", "Import from Coinbase, Strike, Swan & more"),
        ("infinity", "Unlimited Transactions", "Track your full stacking history"),
        ("chart.bar.xaxis", "Advanced Analytics", "DCA charts, performance, and 24h/7d changes"),
        ("doc.text.magnifyingglass", "Tax Center & Sell Simulator", "FIFO/LIFO/HIFO lot matching and Form 8949 export")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    featureList
                    planCards
                    subscribeButton
                    restoreLink
                    legalLinks
                }
                .padding(20)
            }
            .background(Theme.darkBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.textSecondary)
                            .font(.title3)
                    }
                }
            }
            .alert("Purchase Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(subscriptionService.purchaseError ?? "Something went wrong. Please try again.")
            }
        }
        .task {
            await subscriptionService.fetchPackages()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(Theme.bitcoinOrange)

            Text("StackTracker Pro")
                .font(.title.bold())
                .foregroundColor(Theme.textPrimary)

            Text("Unlock the full Bitcoin tracking experience")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Feature List

    private var featureList: some View {
        VStack(spacing: 16) {
            ForEach(features, id: \.title) { feature in
                HStack(spacing: 14) {
                    Image(systemName: feature.icon)
                        .font(.title3)
                        .foregroundColor(Theme.bitcoinOrange)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.textPrimary)

                        Text(feature.description)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        VStack(spacing: 12) {
            // Annual plan
            planCard(
                type: .annual,
                title: "Annual",
                price: "$34.99/year",
                detail: "$2.92/month",
                badge: "BEST VALUE"
            )

            // Monthly plan
            planCard(
                type: .monthly,
                title: "Monthly",
                price: "$4.99/month",
                detail: "$59.88/year",
                badge: nil
            )
        }
    }

    private func planCard(type: PlanType, title: String, price: String, detail: String, badge: String?) -> some View {
        Button {
            selectedPlan = type
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)

                        if let badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Theme.bitcoinOrange)
                                .cornerRadius(4)
                        }
                    }

                    Text(detail)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                Text(price)
                    .font(.subheadline.bold())
                    .foregroundColor(selectedPlan == type ? Theme.bitcoinOrange : Theme.textPrimary)
            }
            .padding(16)
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedPlan == type ? Theme.bitcoinOrange : Theme.cardBorder, lineWidth: selectedPlan == type ? 2 : 1)
            )
        }
    }

    // MARK: - Subscribe Button

    private var subscribeButton: some View {
        Button {
            Task {
                await performPurchase()
            }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text("Subscribe")
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Theme.bitcoinOrange)
            .foregroundColor(.black)
            .cornerRadius(12)
        }
        .disabled(isPurchasing)
    }

    // MARK: - Restore

    private var restoreLink: some View {
        Button {
            Task {
                isPurchasing = true
                let restored = await subscriptionService.restorePurchases()
                isPurchasing = false
                if restored {
                    onProActivated?()
                    dismiss()
                } else if subscriptionService.purchaseError != nil {
                    showError = true
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Legal

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)

            Text("|")
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)

            Link("Privacy Policy", destination: URL(string: "https://tarsbot9-create.github.io/stacktracker-site/privacy.html")!)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.top, 4)
    }

    // MARK: - Purchase Logic

    private func performPurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        // Find the matching package
        let targetID = selectedPlan == .annual ? "stacktracker_pro_annual" : "stacktracker_pro_monthly"
        guard let package = subscriptionService.packages.first(where: { $0.storeProduct.productIdentifier == targetID })
                ?? subscriptionService.packages.first else {
            subscriptionService.purchaseError = "No products available. Please try again later."
            showError = true
            return
        }

        let success = await subscriptionService.purchase(package)
        if success {
            onProActivated?()
            dismiss()
        } else if subscriptionService.purchaseError != nil {
            showError = true
        }
    }
}
