import SwiftUI

struct GlucoseView: View {
    @State private var profile: UserProfile = UserProfileStorage.load()
    @Environment(\.dismiss) private var dismiss
    
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

    private var targetRange: (min: Double, max: Double) {
        let age = profile.age ?? 30
        let unit = profile.unit ?? "mg/dL"
        let rangeMg: (Double, Double)
        switch age {
        case ..<6: rangeMg = (100, 180)
        case 6..<13: rangeMg = (90, 180)
        case 13..<18: rangeMg = (90, 130)
        case 18..<60: rangeMg = (80, 130)
        default: rangeMg = (90, 150)
        }
        if unit == "mmol/L" {
            return (rangeMg.0 / 18.0, rangeMg.1 / 18.0)
        }
        return rangeMg
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "F3F3F3").ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    Color.clear.frame(height: 50)

                    GlucoseTargetRangeLegendCard(
                        targetMin: targetRange.min,
                        targetMax: targetRange.max,
                        unit: profile.unit ?? "mg/dL"
                    )
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

                    VStack(spacing: 0) {
                        SettingRow(
                            title: "Gender",
                            value: profile.gender ?? "Select",
                            isPlaceholder: profile.gender == nil,
                            showsDivider: true,
                            onTap: {
                                tempGender = profile.gender ?? tempGender
                                activePicker = .gender
                            }
                        )
                        SettingRow(
                            title: "Age",
                            value: profile.age.map { "\($0) years" } ?? "Select",
                            isPlaceholder: profile.age == nil,
                            showsDivider: true,
                            onTap: {
                                tempAge = profile.age ?? tempAge
                                activePicker = .age
                            }
                        )
                        SettingRow(
                            title: "Glucose unit",
                            value: profile.unit ?? "Select",
                            isPlaceholder: profile.unit == nil,
                            showsDivider: false,
                            onTap: {
                                tempUnit = profile.unit ?? tempUnit
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
                    .padding(.bottom)

           
                }
            }

            ZStack(alignment: .bottom) {
                Text("Glucose Unit")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "171717"))
                    .padding(.top, DeviceSize.isSmall ? 20 : 50)

                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 22, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17, weight: .regular))
                        }
                        .foregroundColor(Color(hex: "FB2651"))
                    }
                    .buttonStyle(.plain)
                    

                    Spacer()
                }
                .padding(.leading, 24)
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
            profile = UserProfileStorage.load()
            tempGender = profile.gender ?? "Male"
            tempAge = profile.age ?? 29
            tempUnit = profile.unit ?? "mg/dL"
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
                profile = UserProfile(gender: tempGender, age: profile.age, unit: profile.unit)
                UserProfileStorage.save(profile)
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
                profile = UserProfile(gender: profile.gender, age: tempAge, unit: profile.unit)
                UserProfileStorage.save(profile)
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
                profile = UserProfile(gender: profile.gender, age: profile.age, unit: tempUnit)
                UserProfileStorage.save(profile)
                activePicker = nil
            }
        }
    }
}

private struct GlucoseTargetRangeLegendCard: View {
    let targetMin: Double
    let targetMax: Double
    let unit: String

    private static let palette: [Color] = [
        Color(hex: "FFD03A"),
        Color(hex: "34D399"),
        Color(hex: "22D3EE"),
        Color(hex: "3B82F6"),
        Color(hex: "FB2651")
    ]

    var body: some View {
        VStack(spacing: 20) {
            ZStack{
                Image("app_bg_progress line")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                
                infoBlock  .padding(.top,50)
            }
      
            rangeRows
        }
        .padding(20)
     
    }

    private var infoBlock: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.08))
                Image(systemName: "info")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "6B7280"))
            }
            .frame(width: 24, height: 24)

            Text("The data is average and is\ndisplayed according to your\nparameters. If necessary,\nyou can edit them.")
                .font(.caption)
                .fontWeight(.regular)
                .foregroundColor(Color(hex: "AEB5BC"))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
             
        }
    }

    private var rangeRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            rangeRow(color: Color(hex: "FFD03A"), title: "Low level", value: "<\(format(targetMin)) \(unit)")
            rangeRow(color: Color(hex: "34D399"), title: "In the range", value: "\(format(targetMin))-\(format(targetMax)) \(unit)")
            rangeRow(color: Color(hex: "FB2651"), title: "High level", value: ">\(format(targetMax)) \(unit)")
        }
    }

    private func rangeRow(color: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .stroke(color, lineWidth: 2.5)
                .frame(width: 12, height: 12)

            Text(title)
                .font(.callout)
                .fontWeight(.regular)
                .foregroundColor(Color(hex: "171717"))

            Spacer(minLength: 8)

            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "171717"))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 140, height: 36, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 100, style: .continuous)
                        .fill(Color(hex: "F3F3F3"))
                )
        }
    }

    private func format(_ v: Double) -> String {
        String(format: "%.1f", v)
    }
}

#Preview("Glucose") {
    GlucoseView()
}
