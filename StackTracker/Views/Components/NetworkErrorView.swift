import SwiftUI

/// Reusable error banner for network failures
struct NetworkErrorBanner: View {
    let message: String
    let retryAction: (() async -> Void)?

    @State private var isRetrying = false

    init(_ message: String, retry: (() async -> Void)? = nil) {
        self.message = message
        self.retryAction = retry
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.subheadline)
                .foregroundColor(Theme.lossRed)

            Text(message)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(2)

            Spacer()

            if let retryAction {
                Button {
                    Task {
                        isRetrying = true
                        await retryAction()
                        isRetrying = false
                    }
                } label: {
                    if isRetrying {
                        ProgressView()
                            .tint(Theme.bitcoinOrange)
                            .scaleEffect(0.8)
                    } else {
                        Text("Retry")
                            .font(.caption.bold())
                            .foregroundColor(Theme.bitcoinOrange)
                    }
                }
                .disabled(isRetrying)
            }
        }
        .padding(12)
        .background(Theme.lossRed.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.lossRed.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Toast-style error overlay
struct ErrorToast: View {
    let message: String
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.lossRed)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { isPresented = false }
                }
            }
        }
    }
}
