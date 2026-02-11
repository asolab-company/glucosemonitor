import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var currentPage: Int = 0

    @State private var gender: String? = nil
    @State private var age: Int? = nil
    @State private var unit: String? = nil

    private var isFormComplete: Bool {
        gender != nil && age != nil && unit != nil
    }

    private var isContinueDisabled: Bool {
        currentPage == 2 && !isFormComplete
    }

    enum PickerKind {
        case gender
        case age
        case unit
    }

    @State private var activePicker: PickerKind? = nil
    @State private var tempGender: String = "Male"
    @State private var tempUnit: String = "mg/dL"
    @State private var tempAge: Int = 29

    private var isPickerPresented: Bool {
        activePicker != nil
    }

    var body: some View {
        ZStack {
            Color(hex: "#F3F3F3")
                .ignoresSafeArea()

            VStack {
                TabView(selection: $currentPage) {
                    OnboardingPage(
                        imageName: "app_bg_onbording",
                        titleTop: "Start Taking",
                        titleBottom: "Control",
                        description:
                            "Your smart companion for monitoring glucose, spotting patterns, and managing your health with confidence."
                    )
                    .tag(0)

                    OnboardingPage(
                        imageName: "app_bg_onbording2",
                        titleTop: "Understand",
                        titleBottom: "Your Patterns",
                        description:
                            "Beautiful graphs and summaries help you understand how your glucose changes over time."
                    )
                    .tag(1)

                    OnboardingPageWithForm(
                        gender: $gender,
                        age: $age,
                        unit: $unit,
                        onOpenPicker: { picker in
                            switch picker {
                            case .gender:
                                tempGender = gender ?? tempGender
                                activePicker = .gender
                            case .age:
                                tempAge = age ?? tempAge
                                activePicker = .age
                            case .unit:
                                tempUnit = unit ?? tempUnit
                                activePicker = .unit
                            }
                        }
                    )
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea(.container, edges: .top)

                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(
                                index == currentPage
                                    ? Color.pink : Color.gray.opacity(0.4)
                            )
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 8)

                Button {
                    if currentPage < 2 {
                        withAnimation { currentPage += 1 }
                    } else {
                        UserProfileStorage.save(
                            UserProfile(gender: gender, age: age, unit: unit)
                        )
                        onFinish()
                    }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(
                                cornerRadius: 20,
                                style: .continuous
                            )
                            .fill(Color(hex: "FB2651"))
                        )
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: 20,
                                style: .continuous
                            )
                            .stroke(Color(hex: "FB2651"), lineWidth: 2)
                        )
                        .opacity(isContinueDisabled ? 0.45 : 1.0)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }
                .disabled(isContinueDisabled)

                if currentPage == 0 {
                    LegalTextView()
                        .padding(.bottom, 16)
                } else {
                    LegalTextView()
                        .padding(.bottom, 16)
                        .opacity(0)
                }
            }

            if isPickerPresented {
                ZStack {
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                        .ignoresSafeArea()

                    Color.black.opacity(0.10)
                        .ignoresSafeArea()
                }
                .transition(.opacity)
                .onTapGesture { activePicker = nil }
                .zIndex(10)
            }

            if let activePicker {
                VStack {
                    switch activePicker {
                    case .gender:
                        WheelPopoverContainer(title: "Gender") {
                            Picker("Gender", selection: $tempGender) {
                                Text("Male").tag("Male")
                                Text("Female").tag("Female")
                                Text("Other").tag("Other")
                            }
                            .pickerStyle(.wheel)
                        } onCancel: {
                            self.activePicker = nil
                        } onDone: {
                            UIImpactFeedbackGenerator(style: .light)
                                .impactOccurred()
                            gender = tempGender
                            self.activePicker = nil
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
                            self.activePicker = nil
                        } onDone: {
                            UIImpactFeedbackGenerator(style: .light)
                                .impactOccurred()
                            age = tempAge
                            self.activePicker = nil
                        }

                    case .unit:
                        WheelPopoverContainer(title: "Glucose unit") {
                            Picker("Unit", selection: $tempUnit) {
                                Text("mg/dL").tag("mg/dL")
                                Text("mmol/L").tag("mmol/L")
                            }
                            .pickerStyle(.wheel)
                        } onCancel: {
                            self.activePicker = nil
                        } onDone: {
                            UIImpactFeedbackGenerator(style: .light)
                                .impactOccurred()
                            unit = tempUnit
                            self.activePicker = nil
                        }
                    }
                }
                .transition(.scale.combined(with: .opacity))
                .zIndex(11)
            }
        }
        .animation(
            .spring(response: 0.28, dampingFraction: 0.86),
            value: isPickerPresented
        )
        .onAppear {
            let p = UserProfileStorage.load()
            if gender == nil { gender = p.gender }
            if age == nil { age = p.age }
            if unit == nil { unit = p.unit }
        }
    }
}

struct OnboardingPage: View {
    let imageName: String
    let titleTop: String
    let titleBottom: String
    let description: String

    var body: some View {
        VStack(spacing: 0) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: DeviceSize.isSmall ? 320 : 450, alignment: .bottom)
                .clipped()
                .ignoresSafeArea(edges: .top)

            Text(titleTop)
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundColor(Color(hex: "FB2651"))
            Text(titleBottom)
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundColor(Color(hex: "73787D"))
                .padding(.bottom)
            Text(description)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(hex: "171717"))
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .allowsTightening(true)
                .padding(.horizontal, 32)

            Spacer()
        }
    }
}

struct OnboardingPageWithForm: View {
    @Binding var gender: String?
    @Binding var age: Int?
    @Binding var unit: String?

    enum PickerKind {
        case gender
        case age
        case unit
    }

    let onOpenPicker: (PickerKind) -> Void

    private var ageText: String {
        if let age { return "\(age) years" }
        return "Select"
    }

    var body: some View {
        VStack {
            Spacer()
            Image("app_ic_info")
                .resizable()
                .scaledToFit()
                .frame(width: DeviceSize.isSmall ? 80 : 110, height: DeviceSize.isSmall ? 80 :  110)
            Spacer()

            Text("Let's Begin")
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundColor(Color(hex: "FB2651"))
            Text("Your Journey")
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundColor(Color(hex: "73787D"))

            Text(
                "The data will help you customize the application individually for you."
            )
            .font(.callout)
            .multilineTextAlignment(.center)
            .foregroundColor(.black)
            .padding(.horizontal, 32)

            VStack(spacing: 0) {
                SettingRow(
                    title: "Gender",
                    value: gender ?? "Select",
                    isPlaceholder: gender == nil,
                    showsDivider: true,
                    onTap: { onOpenPicker(.gender) }
                )

                SettingRow(
                    title: "Age",
                    value: ageText,
                    isPlaceholder: age == nil,
                    showsDivider: true,
                    onTap: { onOpenPicker(.age) }
                )

                SettingRow(
                    title: "Glucose unit",
                    value: unit ?? "Select",
                    isPlaceholder: unit == nil,
                    showsDivider: false,
                    onTap: { onOpenPicker(.unit) }
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
            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 6)
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer()
        }
    }
}

struct WheelPopoverContainer<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color(hex: "171717"))
                Spacer()
            }

            content()
                .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                Button("Cancel") { onCancel() }
                    .font(.headline)
                    .foregroundColor(Color.black.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )

                Button("Done") { onDone() }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: "FB2651"))
                    )
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 22, x: 0, y: 14)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        .presentationCompactAdaptation(.popover)
    }
}

struct SettingRow: View {
    let title: String
    let value: String
    var isPlaceholder: Bool = false
    var showsDivider: Bool = true
    var onTap: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.callout)
                        .foregroundColor(Color(hex: "171717"))

                    Spacer(minLength: 12)

                    HStack(spacing: 8) {
                        Text(value)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(
                                isPlaceholder
                                    ? Color.black.opacity(0.25)
                                    : Color(hex: "171717")
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(width: 140, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(0.06),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsDivider {
                Divider()
                    .overlay(Color.black.opacity(0.08))
                    .padding(.leading, 18)
            }
        }
    }
}

struct LegalTextView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack {
            Text("By Proceeding You Accept")
                .foregroundColor(.gray)
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            HStack(spacing: 4) {
                Text("Our")
                    .foregroundColor(.gray)
                Button("Terms Of Use") {
                    if let url = URL(string: AppConstants.Links.termsOfUse) {
                        openURL(url)
                    }
                }
                .foregroundColor(.pink)
                Text("And")
                    .foregroundColor(.gray)
                Button("Privacy Policy") {
                    if let url = URL(string: AppConstants.Links.privacyPolicy) {
                        openURL(url)
                    }
                }
                .foregroundColor(.pink)
            }
            .font(.caption)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        }
    }
}

#Preview("Onboarding") {
    OnboardingView(onFinish: {})
}
