import SwiftUI

struct AddEntrySheet: View {
    @Binding var isPresented: Bool
    var initialEntry: GlucoseEntry? = nil

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 44, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                AddEntryView(initialEntry: initialEntry, onClose: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        isPresented = false
                    }
                }, onDone: { entry in
                    if let old = initialEntry {
                        GlucoseEntryStorage.remove(id: old.id)
                    }
                    GlucoseEntryStorage.append(entry)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        isPresented = false
                    }
                })
            }
            .frame(maxWidth: .infinity)
            .frame(height: min(proxy.size.height * 0.86, 600))
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(hex: "F3F3F3"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 26, x: 0, y: 16)
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

struct AddEntryView: View {
    @EnvironmentObject private var profileStore: UserProfileStore

    var initialEntry: GlucoseEntry? = nil
    var onClose: () -> Void
    var onDone: (GlucoseEntry) -> Void

    private var unit: String { profileStore.profile.unit ?? "mg/dL" }

    private enum ActiveWheel {
        case date
        case time
        case value
        case meal
    }

    @State private var activeWheel: ActiveWheel? = nil
    @State private var selectedDateTime: Date = Date()
    @State private var glucoseValueMgDl: Int = 100
    @State private var mealTime: String = "Before breakfast"


    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "HH:mm"
        return f
    }()

    private var dateText: String {
        Self.dateFormatter.string(from: selectedDateTime)
    }

    private var timeText: String {
        Self.timeFormatter.string(from: selectedDateTime)
    }

    private static let mealOptions: [String] = [
        "Before breakfast",
        "After breakfast",
        "Before lunch",
        "After lunch",
        "Before dinner",
        "After dinner",
        "Not specified"
    ]

    private static func defaultMealOption(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<9:   return "Before breakfast"
        case 9..<12:  return "After breakfast"
        case 12..<14: return "Before lunch"
        case 14..<17: return "After lunch"
        case 17..<19: return "Before dinner"
        case 19..<22: return "After dinner"
        default:     return "Not specified"
        }
    }

    private var glucoseText: String {
        GlucoseDisplay.formatted(mgDl: Double(glucoseValueMgDl), unit: unit)
    }

    private let mgDlRange = 40...400
    private let mmolRange = 20...220

    private var glucosePickerValueMgDl: Binding<Int> {
        Binding(
            get: { glucoseValueMgDl },
            set: { glucoseValueMgDl = $0 }
        )
    }

    private var glucosePickerValueMmol: Binding<Int> {
        Binding(
            get: { min(max(Int(round(Double(glucoseValueMgDl) / 18.0 * 10)), mmolRange.lowerBound), mmolRange.upperBound) },
            set: { glucoseValueMgDl = Int(round(Double($0) / 10.0 * 18.0)) }
        )
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button(action: onClose) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.08))
                            .frame(width: 44, height: 44)
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.black.opacity(0.45))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Blood glucose")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "171717"))

                Spacer()

                Button(action: {
                    let entry = GlucoseEntry(
                        id: initialEntry?.id ?? UUID(),
                        date: selectedDateTime,
                        value: glucoseValueMgDl,
                        mealTime: mealTime
                    )
                    onDone(entry)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "FB2651"))
                            .frame(width: 44, height: 44)
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            VStack(spacing: 18) {
                demoRow(title: "Date", value: dateText, isAccent: activeWheel == .date) {
                    withAnimation(.easeInOut(duration: 0.18)) { activeWheel = .date }
                }
                if activeWheel == .date {
                    DatePicker("", selection: $selectedDateTime, displayedComponents: [.date])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                }

                demoRow(title: "Time", value: timeText, isAccent: activeWheel == .time) {
                    withAnimation(.easeInOut(duration: 0.18)) { activeWheel = .time }
                }
                if activeWheel == .time {
                    DatePicker("", selection: $selectedDateTime, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                }

                demoRow(title: "Add", value: glucoseText, isAccent: activeWheel == .value) {
                    withAnimation(.easeInOut(duration: 0.18)) { activeWheel = .value }
                }
                if activeWheel == .value {
                    if unit == "mmol/L" {
                        Picker("", selection: glucosePickerValueMmol) {
                            ForEach(Array(mmolRange), id: \.self) { i in
                                Text(String(format: "%.1f", Double(i) / 10.0)).tag(i)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                    } else {
                        Picker("", selection: glucosePickerValueMgDl) {
                            ForEach(Array(mgDlRange), id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                    }
                }

                demoRow(title: "Meal times", value: mealTime, isAccent: activeWheel == .meal) {
                    withAnimation(.easeInOut(duration: 0.18)) { activeWheel = .meal }
                }
                if activeWheel == .meal {
                    Picker("", selection: $mealTime) {
                        ForEach(Self.mealOptions, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 18)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.18)) { activeWheel = nil }
            }

            Spacer(minLength: 12)
        }
        .padding(.bottom, 18)
        .onAppear {
            if let e = initialEntry {
                selectedDateTime = e.date
                glucoseValueMgDl = e.value
                mealTime = e.mealTime
            } else {
                mealTime = Self.defaultMealOption(for: selectedDateTime)
            }
        }
    }

    @ViewBuilder
    private func demoRow(
        title: String,
        value: String,
        isAccent: Bool,
        onTapValue: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.callout)
                .fontWeight(.regular)
                .foregroundColor(Color(hex: "171717"))
            Spacer()
            Button(action: onTapValue) {
                Text(value)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(isAccent ? Color(hex: "FB2651") : Color(hex: "171717"))
                    .frame(width: 140, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.55))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        }
        .padding(.top, 6)
    }
}

#Preview("AddEntrySheet") {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        var body: some View {
            ZStack(alignment: .bottom) {
                Color.gray.opacity(0.3).ignoresSafeArea()
                AddEntrySheet(isPresented: $isPresented)
            }
        }
    }
    return PreviewWrapper()
}
