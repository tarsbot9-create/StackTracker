import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var currentPage = 0
    @State private var showPaywall = false

    private let pages: [(icon: String, title: String, description: String)] = [
        ("bitcoinsign.circle.fill", "Track Your Stack", "Log every Bitcoin purchase and watch your stack grow over time. Import from Coinbase, Cash App, Strike, Swan, and more."),
        ("chart.line.uptrend.xyaxis", "Visualize Progress", "See your DCA performance with interactive charts, cost basis tracking, and portfolio analytics."),
        ("doc.text.magnifyingglass", "Tax Center", "Track capital gains with FIFO, LIFO, or HIFO accounting. Simulate sells and export Form 8949 for your CPA.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    onboardingPage(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            bottomButtons
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
        }
        .background(Theme.darkBackground)
        .sheet(isPresented: $showPaywall) {
            PaywallView {
                hasCompletedOnboarding = true
            }
        }
    }

    private func onboardingPage(_ page: (icon: String, title: String, description: String)) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(Theme.bitcoinOrange)

            Text(page.title)
                .font(.title.bold())
                .foregroundColor(Theme.textPrimary)

            Text(page.description)
                .font(.body)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    private var bottomButtons: some View {
        Group {
            if currentPage < pages.count - 1 {
                // Pages 1 & 2: Next + Skip
                VStack(spacing: 12) {
                    Button {
                        withAnimation {
                            currentPage += 1
                        }
                    } label: {
                        Text("Next")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Theme.bitcoinOrange)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                    }

                    Button {
                        hasCompletedOnboarding = true
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            } else {
                // Page 3: Start Free Trial + Continue Free
                VStack(spacing: 12) {
                    Button {
                        #if targetEnvironment(simulator)
                        hasCompletedOnboarding = true
                        #else
                        showPaywall = true
                        #endif
                    } label: {
                        Text("Start Free Trial")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Theme.bitcoinOrange)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                    }

                    Button {
                        hasCompletedOnboarding = true
                    } label: {
                        Text("Continue with Free Plan")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
    }
}
