import SwiftUI
import StoreKit

enum MainTab: Int {
    case results = 0
    case trends
    case add
    case history
    case settings
}

struct MainView: View {
    @StateObject private var profileStore = UserProfileStore()
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedTab: MainTab = .results
    @State private var isAddPresented: Bool = false
    @State private var showPaywall: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .results:
                    ResultView()
                case .trends:
                    TrendsView()
                case .add:
                    ResultView()
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#F3F3F3").ignoresSafeArea())
            .environmentObject(profileStore)

            MainTabBar(
                selectedTab: $selectedTab,
                onTabSelect: { tab in
                    if (tab == .trends || tab == .history), !subscriptionManager.isPremiumUnlocked {
                        showPaywall = true
                    } else {
                        selectedTab = tab
                    }
                },
                onAdd: { isAddPresented = true }
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            if isAddPresented {
                ZStack {
                    MainVisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                        .ignoresSafeArea()

                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                }
                .transition(.opacity)
                .onTapGesture {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        isAddPresented = false
                    }
                }
                .zIndex(10)

                AddEntrySheet(isPresented: $isAddPresented)
                    .environmentObject(profileStore)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(11)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isAddPresented)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(
                onSubscribe: { productId in
                    Task {
                        await SubscriptionManager.shared.purchase(productId: productId)
                        await MainActor.run { showPaywall = false }
                    }
                },
                onSkip: { showPaywall = false },
                onRestore: {
                    Task {
                        await SubscriptionManager.shared.restorePurchases()
                        try? await AppStore.sync()
                    }
                }
            )
        }
    }
}

struct MainTabBar: View {
    @Binding var selectedTab: MainTab
    var onTabSelect: (MainTab) -> Void
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            assetTabButton(
                icon: "app_ic_menu",
                title: "Results",
                tab: .results
            )
            
            assetTabButton(
                icon: "app_ic_menu_1",
                title: "Trends",
                tab: .trends
            )
            
            ZStack {
                Button(action: onAdd) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "FF6282"), Color(hex: "FB2651")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.20), Color.white.opacity(0.00)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .blendMode(.screen)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                                    .blur(radius: 0.2)
                            )
                            .shadow(color: Color.black.opacity(0.22), radius: 6, x: 0, y: 4)
                            .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)
                            .frame(width: 50, height: 50)
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            
            assetTabButton(
                icon: "app_ic_menu_2",
                title: "History",
                tab: .history
            )
            
            assetTabButton(
                icon: "app_ic_menu_3",
                title: "Setting",
                tab: .settings
            )
        }
        .padding(.horizontal, 18)
        .frame(height: 70)
        .background {
            Capsule(style: .continuous)
                .fill(Color(hex: "ECECEC").opacity(0.98))
        }
        .overlay {
            if #available(iOS 26.0, *) {
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.40), lineWidth: 1)
            }
        }
        .overlay {
            if #available(iOS 26.0, *) {
                Capsule(style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            } else {
                Capsule(style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
        }
        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 14)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
    
    private func tabButton(icon: String, title: String, tab: MainTab) -> some View {
        let isSelected = selectedTab == tab
        
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(isSelected ? Color(hex: "FB2651") : Color(hex: "AEB5BC"))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "FB2651") : Color(hex: "AEB5BC"))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func assetTabButton(
        icon: String,
        title: String,
        tab: MainTab
    ) -> some View {
        let isSelected = selectedTab == tab
        let tint = isSelected ? Color(hex: "FB2651") : Color(hex: "AEB5BC")

        return Button {
            onTabSelect(tab)
        } label: {
            VStack(spacing: 4) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(tint)

                Text(title)
                    .font(.system(size: DeviceSize.isSmall ? 9 : 10, weight: .medium))
                    .foregroundColor(tint)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct MainVisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style = .systemUltraThinMaterial

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

#Preview("Main View") {
    MainView()
}
