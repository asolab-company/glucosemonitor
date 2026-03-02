import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.openURL) private var openURL
    @State private var products: [Product] = []
    @State private var selectedProductID: String?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    
    var onSubscribe: (String) -> Void = { _ in }
    var onSkip: () -> Void = {}
    var onRestore: () -> Void = {}
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#F3F3F3")
                .ignoresSafeArea()
            
            Image("app_bg_paywall")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: DeviceSize.isSmall ? 120 : 260, alignment: .bottom)
                .clipped()
                .ignoresSafeArea(edges: .top)
            
            VStack {
          
                    VStack(spacing: 16) {
                        Color.clear
                            .frame(height: DeviceSize.isSmall ? 100 : 200)
                        
                   
                        VStack(spacing: 4) {
                            Text("Unlock Full")
                                .font(.largeTitle)
                                .fontWeight(.heavy)
                                .foregroundColor(Color.init(hex: "FB2651"))
                            Text("Glucose Control")
                                .font(.largeTitle)
                                .fontWeight(.heavy)
                                .foregroundColor(Color.init(hex: "73787D"))
                            Text("Get access to powerful tools designed to help you understand and manage your blood sugar with confidence.")
                                .font(.callout)
                                .multilineTextAlignment(.center)
                                .foregroundColor(Color.init(hex: "171717"))
                                .lineLimit(3)
                                .minimumScaleFactor(0.85)
                                .allowsTightening(true)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 8)
                        
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .padding(.horizontal, 24)
                        }
                        
                        if isLoading {
                            ProgressView()
                                .padding()
                        } else {
                            VStack(spacing: 12) {
                                ForEach(products, id: \.id) { product in
                                    PaywallOptionRow(
                                        product: product,
                                        isSelected: product.id == selectedProductID,
                                        isBestOffer: product.id == AppConstants.Subscription.yearlyID
                                    ) {
                                        selectedProductID = product.id
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        if (!DeviceSize.isSmall){
                            Spacer()
                        }
                      
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal")
                                .foregroundColor(.pink)
                            Text("Cancel Anytime")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.init(hex: "FB2651"))
                        }
                        .padding(.top, 8)
                    }
          
                
                Button {
                    if let id = selectedProductID {
                        onSubscribe(id)
                    }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(hex: "FB2651"))
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                }
                .disabled(selectedProductID == nil || isLoading)

                HStack {
                    Button("Privacy Policy") {
                        if let url = URL(string: AppConstants.Links.privacyPolicy) {
                            openURL(url)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Skip") { onSkip() }
                    
                    Spacer()
                    
                    Button("Restore") {
                        onRestore()
                        Task { try? await AppStore.sync() }
                    }
                    
                    Spacer()
                    
                    Button("Terms of Use") {
                        if let url = URL(string: AppConstants.Links.termsOfUse) {
                            openURL(url)
                        }
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.init(hex: "AEB5BC"))
                .padding(.horizontal, 30)
                .padding(.bottom)
                .buttonStyle(.plain)
            }
        }
        .task {
            await loadProducts()
        }
    }
    
    private func loadProducts() async {
        do {
            isLoading = true
            errorMessage = nil
            let storeProducts = try await Product.products(for: AppConstants.Subscription.allIDs)
            let preferredOrder: [String] = [
                AppConstants.Subscription.weeklyID,
                AppConstants.Subscription.monthlyID,
                AppConstants.Subscription.yearlyID
            ]
            let orderIndex = Dictionary(uniqueKeysWithValues: preferredOrder.enumerated().map { ($0.element, $0.offset) })
            let sortedProducts = storeProducts.sorted {
                (orderIndex[$0.id] ?? Int.max) < (orderIndex[$1.id] ?? Int.max)
            }
            await MainActor.run {
                self.products = sortedProducts
                self.selectedProductID = AppConstants.Subscription.yearlyID
                if !sortedProducts.contains(where: { $0.id == self.selectedProductID }) {
                    self.selectedProductID = sortedProducts.first?.id
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Could not load prices from the Store."
                self.isLoading = false
            }
        }
    }

}

struct PaywallOptionRow: View {
    let product: Product
    let isSelected: Bool
    let isBestOffer: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle(for: product))
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "171717"))

                    Text(priceLine(for: product))
                        .font(.caption)
                        .foregroundColor(Color.black.opacity(0.35))
                }

                Spacer(minLength: 12)

        if isBestOffer {
            Text("BEST OFFER")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FF6282"), Color(hex: "FB2651")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .frame(height: 60)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "FF6282"), Color(hex: "FB2651")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    }
                }
            )
            .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    private func displayTitle(for product: Product) -> String {
        switch product.id {
        case AppConstants.Subscription.weeklyID:
            return "Weekly Access"
        case AppConstants.Subscription.monthlyID:
            return "Monthly Access"
        case AppConstants.Subscription.yearlyID:
            return "Yearly Access"
        default:
            return product.displayName
        }
    }

    private func periodLabel(for product: Product) -> String {
        switch product.id {
        case AppConstants.Subscription.weeklyID:
            return "week"
        case AppConstants.Subscription.monthlyID:
            return "month"
        case AppConstants.Subscription.yearlyID:
            return "year"
        default:
            guard let subscription = product.subscription else { return "" }
            switch subscription.subscriptionPeriod.unit {
            case .day:
                return "day"
            case .week:
                return "week"
            case .month:
                return "month"
            case .year:
                return "year"
            @unknown default:
                return ""
            }
        }
    }

    private func priceLine(for product: Product) -> String {
        let period = periodLabel(for: product)
        guard !period.isEmpty else { return product.displayPrice }
        return "\(product.displayPrice) / \(period)"
    }
}

#Preview("Paywall") {
    PaywallView()
}
