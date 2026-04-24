import SwiftUI

enum AppStage {
    case splash
    case onboarding
    case paywall
    case main
}

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var stage: AppStage = .splash
    @State private var didFinishSplash = false

    var body: some View {
        Group {
            switch stage {
            case .splash:
                SplashView {
                    Task { await finishSplash() }
                }
            case .onboarding:
                OnboardingView {
                    hasCompletedOnboarding = true
                    withAnimation {
                        stage = .paywall
                    }
                }
            case .paywall:
                PaywallView(
                    onClose: {
                        withAnimation {
                            stage = .main
                        }
                    },
                    onUnlocked: {
                        withAnimation {
                            stage = .main
                        }
                    }
                )
            case .main:
                MainView()
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            AppsFlyerService.shared.startRespectingTrackingAuthorization()
        }
        .onChange(of: subscriptionManager.isPremiumUnlocked) { _, isUnlocked in
            guard isUnlocked, didFinishSplash else { return }
            withAnimation {
                stage = .main
            }
        }
    }

    @MainActor
    private func finishSplash() async {
        guard !didFinishSplash else { return }
        didFinishSplash = true

        await subscriptionManager.refreshSubscriptionStatus()

        withAnimation {
            if subscriptionManager.isPremiumUnlocked {
                stage = .main
            } else if hasCompletedOnboarding {
                stage = .paywall
            } else {
                stage = .onboarding
            }
        }
    }
}

#Preview {
    ContentView()
}
