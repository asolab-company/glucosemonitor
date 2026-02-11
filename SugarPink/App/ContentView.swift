import SwiftUI

enum AppStage {
    case splash
    case onboarding
    case paywall
    case main
}

private let hasReachedMainKey = "sugarpink.hasReachedMain"

struct ContentView: View {
    @State private var stage: AppStage = Self.initialStage

    private static var initialStage: AppStage {
        UserDefaults.standard.bool(forKey: hasReachedMainKey) ? .main : .splash
    }

    var body: some View {
        Group {
            switch stage {
            case .splash:
                SplashView {
                    withAnimation {
                        stage = .onboarding
                    }
                }
            case .onboarding:
                OnboardingView {
                    withAnimation {
                        stage = .paywall
                    }
                }
            case .paywall:
                PaywallView(
                    onSubscribe: { productId in
                        Task {
                            await SubscriptionManager.shared.purchase(productId: productId)
                            await MainActor.run {
                                UserDefaults.standard.set(true, forKey: hasReachedMainKey)
                                withAnimation {
                                    stage = .main
                                }
                            }
                        }
                    },
                    onSkip: {
                        UserDefaults.standard.set(true, forKey: hasReachedMainKey)
                        withAnimation {
                            stage = .main
                        }
                    },
                    onRestore: {
                        Task {
                            await SubscriptionManager.shared.restorePurchases()
                        }
                    }
                )
            case .main:
                MainView()
            }
        }
    }
}

#Preview {
    ContentView()
}

