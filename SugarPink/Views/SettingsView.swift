import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var profileStore: UserProfileStore
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    private var profile: UserProfile { profileStore.profile }
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    
    private enum PickerKind {
        case gender
        case age
        case unit
    }
    
    @State private var activePicker: PickerKind? = nil
    @State private var tempGender: String = "Male"
    @State private var tempAge: Int = 29
    @State private var tempUnit: String = "mg/dL"
    
    private var isPickerPresented: Bool { activePicker != nil }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "F3F3F3").ignoresSafeArea()
            


            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    Color.clear.frame(height: 50)

                    if !subscriptionManager.isPremiumUnlocked {
                        ProBannerRow(title: "PRO Version") {
                            showPaywall = true
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                    }

                    SectionTitle("Account")
                        .padding(.horizontal, 24)
                        .padding(.top, 6)

                    VStack(spacing: 0) {
                        SettingRow(
                            title: "Gender",
                            value: profile.gender ?? "Select",
                            isPlaceholder: profile.gender == nil,
                            showsDivider: true,
                            onTap: {
                                tempGender = profileStore.profile.gender ?? tempGender
                                activePicker = .gender
                            }
                        )
                        SettingRow(
                            title: "Age",
                            value: profile.age.map { "\($0) years" } ?? "Select",
                            isPlaceholder: profile.age == nil,
                            showsDivider: true,
                            onTap: {
                                tempAge = profileStore.profile.age ?? tempAge
                                activePicker = .age
                            }
                        )
                        SettingRow(
                            title: "Glucose unit",
                            value: profile.unit ?? "Select",
                            isPlaceholder: profile.unit == nil,
                            showsDivider: false,
                            onTap: {
                                tempUnit = profileStore.profile.unit ?? tempUnit
                                activePicker = .unit
                            }
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color(hex: "ECECEC"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 12)
                    .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 24)

                    SectionTitle("Support & Legal")
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                    
                    VStack(spacing: 6) {
                        SettingsLinkRow(icon: "ic_privacy", fallbackSF: "shield", title: "Privacy") {
                            if let url = URL(string: AppConstants.Links.privacyPolicy) {
                                openURL(url)
                            }
                        }

                        SettingsLinkRow(icon: "ic_terms", fallbackSF: "doc", title: "Terms and Conditions") {
                            if let url = URL(string: AppConstants.Links.termsOfUse) {
                                openURL(url)
                            }
                        }
                        
                        SettingsLinkRow(icon: "ic_medical", fallbackSF: "cross.case.fill", title: "Medical Sources") {
                            if let url = URL(string: AppConstants.Links.medSources) {
                                openURL(url)
                            }
                        }

                    }
                    .padding(.horizontal, 24)

              

              

           

                    SectionTitle("General")
                        .padding(.horizontal, 24)
                        .padding(.top, 6)

                    VStack(spacing: 6) {
                        SettingsLinkRow(icon: "ic_share", fallbackSF: "square.and.arrow.up", title: "Share app") {
                            showShareSheet = true
                        }

                        SettingsLinkRow(icon: "ic_rate", fallbackSF: "star", title: "Rate Us") {
                            requestAppReview()
                        }

                        SettingsLinkRow(icon: "ic_restore", fallbackSF: "arrow.clockwise", title: "Restore") {
                            Task {
                                _ = await SubscriptionManager.shared.restorePurchases()
                            }
                        }
                        SettingsLinkRow(icon: "ic_delete", fallbackSF: "trash", title: "Delete Data", isDestructive: true) {
                            showDeleteConfirm = true
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 50)

                    Spacer(minLength: 28)
                }
            }

            ZStack(alignment: .bottom) {
                Text("Settings")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "171717"))
                    .padding(.top, DeviceSize.isSmall ? 20 : 50)
            }
            .frame(maxWidth: .infinity)
            .frame(height: DeviceSize.isSmall ? 80 : 110)
            .background {
                BottomRoundedShape(radius: 40)
                    .fill(Color(hex: "ECECEC"))
                    .shadow(color: Color.black.opacity(0.20), radius: 2, x: 0, y: 2)
                    .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            profileStore.load()
            tempGender = profileStore.profile.gender ?? "Male"
            tempAge = profileStore.profile.age ?? 29
            tempUnit = profileStore.profile.unit ?? "mg/dL"
        }
        .overlay {
            if isPickerPresented {
                ZStack {
                    VisualEffectBlur(blurStyle: .light)
                        .ignoresSafeArea()
                    Color.black.opacity(0.10)
                        .ignoresSafeArea()
                }
                .onTapGesture { activePicker = nil }
            }
        }
        .overlay {
            if let activePicker {
                settingsPickerContent(activePicker)
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isPickerPresented)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(
                onClose: { showPaywall = false },
                onUnlocked: { showPaywall = false }
            )
        }
        .background {
            if showShareSheet {
                ShareSheetView(
                    activityItems: {
                        var items: [Any] = ["Check out SugarPink – your glucose tracking companion!"]
                        if let url = URL(string: AppConstants.Links.appStoreURL) {
                            items.insert(url, at: 0)
                        }
                        return items
                    }(),
                    onDismiss: { showShareSheet = false }
                )
                .frame(width: 1, height: 1)
            }
        }
        .alert("Delete All Data?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                GlucoseEntryStorage.clearAll()
            }
        } message: {
            Text("All your glucose entries will be permanently deleted. This cannot be undone.")
        }
    }

    private func requestAppReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        AppStore.requestReview(in: scene)
    }
    
    @ViewBuilder
    private func settingsPickerContent(_ picker: PickerKind) -> some View {
        switch picker {
        case .gender:
            WheelPopoverContainer(title: "Gender") {
                Picker("Gender", selection: $tempGender) {
                    Text("Male").tag("Male")
                    Text("Female").tag("Female")
                    Text("Other").tag("Other")
                }
                .pickerStyle(.wheel)
            } onCancel: {
                activePicker = nil
            } onDone: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                profileStore.update(UserProfile(gender: tempGender, age: profileStore.profile.age, unit: profileStore.profile.unit))
                activePicker = nil
            }

        case .age:
            WheelPopoverContainer(title: "Age") {
                Picker("Age", selection: $tempAge) {
                    ForEach(1...120, id: \.self) { v in
                        Text("\(v)").tag(v)
                    }
                }
                .pickerStyle(.wheel)
            } onCancel: {
                activePicker = nil
            } onDone: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                profileStore.update(UserProfile(gender: profileStore.profile.gender, age: tempAge, unit: profileStore.profile.unit))
                activePicker = nil
            }

        case .unit:
            WheelPopoverContainer(title: "Glucose unit") {
                Picker("Unit", selection: $tempUnit) {
                    Text("mg/dL").tag("mg/dL")
                    Text("mmol/L").tag("mmol/L")
                }
                .pickerStyle(.wheel)
            } onCancel: {
                activePicker = nil
            } onDone: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                profileStore.update(UserProfile(gender: profileStore.profile.gender, age: profileStore.profile.age, unit: tempUnit))
                activePicker = nil
            }
        }
    }
}


private struct ProBannerRow: View {
    let title: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 44, height: 44)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(.callout)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 18)
            .frame(height: 66)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(hex: "FB2651"))
                    .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(hex: "ECECEC"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}

private struct SettingsLinkRow: View {
    let icon: String
    let fallbackSF: String
    let title: String
    var isDestructive: Bool = false
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isDestructive ? Color(hex: "FB2651").opacity(0.18) : Color.black.opacity(0.06))
                        .frame(width: 40, height: 40)

                    if UIImage(named: icon) != nil {
                        Image(icon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(isDestructive ? Color(hex: "FB2651") : Color.black.opacity(0.35))
                    } else {
                        Image(systemName: fallbackSF)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isDestructive ? Color(hex: "FB2651") : Color.black.opacity(0.35))
                    }
                }

                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "171717"))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.black.opacity(0.25))
            }
            .padding(.horizontal, 18)
            .frame(height: 66)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.body)
            .fontWeight(.semibold)
            .foregroundColor(Color(hex: "171717"))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard context.coordinator.presented == false else { return }
        let activity = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        activity.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async { onDismiss() }
        }
        uiViewController.present(activity, animated: true)
        context.coordinator.presented = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var presented = false
    }
}

struct BottomRoundedShape: Shape {
    var radius: CGFloat = 40

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview("Settings") {
    SettingsView()
        .environmentObject(UserProfileStore())
}
