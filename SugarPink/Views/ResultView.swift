import SwiftUI
import UIKit
import StoreKit

struct ResultView: View {
    @EnvironmentObject private var profileStore: UserProfileStore
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    var forPreview: Bool

    private var unit: String { profileStore.profile.unit ?? "mg/dL" }

    enum Scope: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year"
        var id: String { rawValue }
    }

    @State private var scope: Scope = .day
    @State private var selectedDate: Date = Date()
    @State private var tempSelectedDate: Date = Date()
    @State private var isDatePickerPresented: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showGlucoseView: Bool = false
    @State private var entries: [GlucoseEntry]

    private let cal = Calendar.current
    private let loadFromStorage: Bool

    init(forPreview: Bool = false, previewEntries: [GlucoseEntry]? = nil) {
        self.forPreview = forPreview
        if let previewEntries {
            _entries = State(initialValue: previewEntries)
            loadFromStorage = false
        } else {
            _entries = State(initialValue: GlucoseEntryStorage.load())
            loadFromStorage = true
        }
    }

    private var filteredEntries: [GlucoseEntry] {
        entries.filter { entry in
            switch scope {
            case .day:
                return cal.isDate(entry.date, inSameDayAs: selectedDate)
            case .week:
                guard
                    let interval = cal.dateInterval(
                        of: .weekOfYear,
                        for: selectedDate
                    )
                else { return false }
                return entry.date >= interval.start && entry.date < interval.end
            case .month:
                return cal.isDate(
                    entry.date,
                    equalTo: selectedDate,
                    toGranularity: .month
                )
            case .year:
                return cal.isDate(
                    entry.date,
                    equalTo: selectedDate,
                    toGranularity: .year
                )
            }
        }
    }

    private var bodyRange: (min: Double, max: Double) {
        let values = filteredEntries.map { Double($0.value) }
        guard let mn = values.min(), let mx = values.max() else {
            return (0, 0)
        }
        return (mn, mx)
    }

    private var averageValue: Double {
        let values = filteredEntries.map { Double($0.value) }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private var lastReading: (time: String, value: Double)? {
        guard let last = filteredEntries.max(by: { $0.date < $1.date }) else {
            return nil
        }
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "HH:mm"
        return (f.string(from: last.date), Double(last.value))
    }

    private var minValueReading: (time: String, value: Double)? {
        guard let minE = filteredEntries.min(by: { $0.value < $1.value }) else { return nil }
        return (timeString(minE.date), Double(minE.value))
    }

    private var maxValueReading: (time: String, value: Double)? {
        guard let maxE = filteredEntries.max(by: { $0.value < $1.value }) else { return nil }
        return (timeString(maxE.date), Double(maxE.value))
    }

    private var targetRange: (min: Double, max: Double) {
        let profile = profileStore.profile
        let age = profile.age ?? 30
        let profileUnit = profile.unit ?? "mg/dL"

        let rangeMg: (Double, Double)
        switch age {
        case ..<6:
            rangeMg = (100, 180)
        case 6..<13:
            rangeMg = (90, 180)
        case 13..<18:
            rangeMg = (90, 130)
        case 18..<60:
            rangeMg = (80, 130)
        default:
            rangeMg = (90, 150)
        }

        if profileUnit == "mmol/L" {
            return (rangeMg.0 / 18.0, rangeMg.1 / 18.0)
        } else {
            return rangeMg
        }
    }

    fileprivate struct MealBucket: Identifiable {
        let id: String
        let title: String
        let key: String
        let count: Int
        let average: Double?
    }

    private var mealBuckets: [MealBucket] {
        let categories: [(key: String, title: String)] = [
            ("before breakfast", "Before Breakfast"),
            ("after breakfast", "After Breakfast"),
            ("before lunch", "Before Lunch"),
            ("after lunch", "After Lunch"),
            ("before dinner", "Before Dinner"),
            ("after dinner", "After Dinner"),
            ("not specified", "Not specified")
        ]

        let lowercasedEntries = filteredEntries.map { ($0, $0.mealTime.lowercased()) }

        return categories.map { cat in
            let group = lowercasedEntries
                .filter { $0.1.contains(cat.key) }
                .map { $0.0 }
            let count = group.count
            let avg: Double? = count > 0
                ? Double(group.map(\.value).reduce(0, +)) / Double(count)
                : nil
            return MealBucket(
                id: cat.key,
                title: cat.title,
                key: cat.key,
                count: count,
                average: avg
            )
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#F3F3F3").ignoresSafeArea()

      
                VStack(spacing: 0) {
                    Color.clear.frame(height: DeviceSize.isSmall ? 40 : 30)
                    ZStack{
                        scopePicker.padding(.horizontal, 18)
                            .padding(.vertical)
                    } .background {
                        BottomRoundedShape(radius: 0)
                            .fill(Color(hex: "ECECEC"))
                    }
                   
        
                    ScrollView(.vertical, showsIndicators: false) {
                     
                            ZStack {
                                VStack (spacing:14) {
                                   

                                    GaugeAverageCard(
                                        average: filteredEntries.isEmpty ? nil : averageValue,
                                        minReading: minValueReading,
                                        maxReading: maxValueReading,
                                        targetRange: targetRange,
                                        unit: unit,
                                        minGauge: 0,
                                        maxGauge: 160,
                                        onQuestionTap: { showGlucoseView = true }
                                    )
                                    .padding(.horizontal, 18)
                                }
                                    .padding(.bottom)

                            }.background {
                                BottomRoundedShape(radius: 40)
                                    .fill(Color(hex: "ECECEC"))
                                    .shadow(
                                        color: Color.black.opacity(0.20),
                                        radius: 2,
                                        x: 0,
                                        y: 2
                                    )
                                    .shadow(
                                        color: Color.black.opacity(0.06),
                                        radius: 2,
                                        x: 0,
                                        y: 1
                                    )
                            }

                 

                            mealBasedSection
                                .padding(.horizontal, 18)
                                .padding(.top, 4)
                                .padding(.bottom,100)
                        
                      
                    }
              

                 
                }

                .padding(.top, 8)
            
            

            ZStack(alignment: .bottom) {
                Text("Results")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "171717"))
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .trailing) {
                        datePill
                    }
                    .overlay(alignment: .leading) {
                        if !subscriptionManager.isPremiumUnlocked {
                            Button {
                                showPaywall = true
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)

                                    Text("PRO")
                                        .font(.system(size: 16, weight: .heavy))
                                        .foregroundColor(.white)

                                    Spacer(minLength: 0)
                                }
                                .padding(.leading,10)
                                .frame(width: 90, height: 32)
                                .background {
                                    RightRoundedRect(radius: 35)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "FB2651"), Color(hex: "FF6282")],
                                                startPoint: .bottom,
                                                endPoint: .top
                                            )
                                        )
                                        .shadow(
                                            color: Color.black.opacity(0.06),
                                            radius: 10,
                                            x: 0,
                                            y: 6
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top,DeviceSize.isSmall ? 20 : 50)
            }
            .frame(maxWidth: .infinity)
            .frame(height: DeviceSize.isSmall ? 80 : 110)
            .background {
                BottomRoundedShape(radius: 0)
                    .fill(Color(hex: "ECECEC"))
            }
            .ignoresSafeArea(edges: .top)

            if isDatePickerPresented {
                datePickerOverlay
            }
        }
        .onAppear {
            if loadFromStorage {
                entries = GlucoseEntryStorage.load()
            }
            ensureSelectedDateHasData()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.willEnterForegroundNotification
            )
        ) { _ in
            if loadFromStorage {
                entries = GlucoseEntryStorage.load()
            }
            ensureSelectedDateHasData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .glucoseEntriesDidUpdate)) { _ in
            if loadFromStorage {
                entries = GlucoseEntryStorage.load()
            }
            ensureSelectedDateHasData()
        }
        .fullScreenCover(isPresented: $showGlucoseView) {
            GlucoseView()
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(
                onClose: { showPaywall = false },
                onUnlocked: { showPaywall = false }
            )
        }
    }

    private var header: some View {
        Text("Trends")
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {

            }
            .padding(.top, 6)
    }

    private var datePill: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                tempSelectedDate = selectedDate
                isDatePickerPresented = true
            }
        } label: {
            Text(selectedDate.trendsShortText)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "FB2651"))
                .frame(width: 140, height: 36)
                .background {
                    LeftRoundedRect(radius: 18)
                        .fill(Color(hex: "F3F3F3"))
                        .shadow(
                            color: Color.black.opacity(0.06),
                            radius: 10,
                            x: 0,
                            y: 6
                        )
                        .overlay {
                            LeftRoundedRect(radius: 18)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
    }

    private let scopeCellHeight: CGFloat = 28

    private var scopePicker: some View {
        HStack(spacing: 0) {
            ForEach(Scope.allCases) { item in
                Button {
                    if item != .day, !SubscriptionManager.shared.isPremiumUnlocked {
                        showPaywall = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            scope = item
                        }
                    }
                } label: {
                    Text(item.rawValue)
                        .font(.callout)
                        .fontWeight(.regular)
                        .frame(maxWidth: .infinity)
                        .frame(height: scopeCellHeight)
                        .foregroundColor(
                            scope == item ? Color(hex: "FB2651") : Color.black
                        )
                        .background(
                            Group {
                                if scope == item {
                                    RoundedRectangle(
                                        cornerRadius: 7,
                                        style: .continuous
                                    )
                                    .fill(Color.white)
                                } else {
                                    Color.clear
                                }
                            }
                        )
                }
                .buttonStyle(.plain)

                if item != .year {
                    Rectangle()
                        .fill(Color.black.opacity(0.10))
                        .frame(width: 1, height: 16)
                        .padding(.vertical, 8)
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.black.opacity(0.06))
        )
        .frame(height: 32)
    }

    private var mealBasedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meal-Based Readings")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "171717"))

            let firstSix = Array(mealBuckets.prefix(6))
            let lastBucket = mealBuckets.count > 6 ? mealBuckets.last : nil

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                spacing: 12
            ) {
                ForEach(firstSix) { bucket in
                    MealBucketCard(bucket: bucket, unit: unit, minGauge: 0, maxGauge: 160)
                }
            }

            if let lastBucket {
                MealBucketWideCard(bucket: lastBucket, unit: unit, minGauge: 0, maxGauge: 160)
            }
        }
    }

    private func ensureSelectedDateHasData() {
        guard !entries.isEmpty else { return }
        if filteredEntries.isEmpty, let last = entries.max(by: { $0.date < $1.date }) {
            selectedDate = last.date
            tempSelectedDate = last.date
        }
    }

    private var datePickerOverlay: some View {
        ZStack {
            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                .ignoresSafeArea()

            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isDatePickerPresented = false
                    }
                }

            VStack(spacing: 5) {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isDatePickerPresented = false
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "F3F3F3"))

                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.black.opacity(0.35))
                        }
                        .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 22)

                InlineDatePicker(
                    selection: $tempSelectedDate,
                    tintHex: "FB2651"
                )
                .frame(maxWidth: .infinity)
                .frame(height: 340, alignment: .top)
                .clipped()

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedDate = tempSelectedDate
                        isDatePickerPresented = false
                    }
                } label: {
                    Text("Apply")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)
                        .background(Capsule().fill(Color(hex: "FB2651")))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(18)
            .frame(width: 340, height: 500, alignment: .top)
            .transaction { tx in
                tx.animation = nil
                tx.disablesAnimations = true
            }
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white)
                    .shadow(
                        color: Color.black.opacity(0.18),
                        radius: 30,
                        x: 0,
                        y: 18
                    )
            )
            .padding(.horizontal, 18)
        }
        .transition(.opacity)
    }
}

private struct StatRowCard: View {
    let title: String
    let valueText: String
    let isProminent: Bool
    var isGradient: Bool = false

    var body: some View {
        HStack {
            Text(title)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(isGradient ? .white : Color.black.opacity(0.30))

            Spacer()

            Text(valueText)
                .font(
                    isProminent
                        ? .system(size: 18, weight: .bold)
                        : .system(size: 18, weight: .bold)
                )
                .foregroundColor(.black)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    isGradient
                        ? AnyShapeStyle(gradientFill)
                        : AnyShapeStyle(Color.white)
                )
                .shadow(
                    color: Color.black.opacity(0.08),
                    radius: 14,
                    x: 0,
                    y: 10
                )
        )
        .frame(height: 60)
    }

    private var gradientFill: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "FFB6C4"), Color(hex: "FF8EA3")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct MealBucketCard: View {
    let bucket: ResultView.MealBucket
    var unit: String = "mg/dL"
    var minGauge: Double = 0
    var maxGauge: Double = 160

    private var hasData: Bool { bucket.average != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(bucket.title)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "171717"))

            Text("Entries: \(bucket.count)")
                .font(.caption)
                .foregroundColor(Color(hex: "AEB5BC"))

            Text(valueText)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "171717"))

            MealBucketBar(
                value: bucket.average,
                minGauge: minGauge,
                maxGauge: maxGauge
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private var valueText: String {
        if let avg = bucket.average {
            return GlucoseDisplay.formatted(mgDl: avg, unit: unit)
        } else {
            return GlucoseDisplay.placeholder(unit: unit)
        }
    }
}

private struct MealBucketWideCard: View {
    let bucket: ResultView.MealBucket
    var unit: String = "mg/dL"
    var minGauge: Double = 0
    var maxGauge: Double = 160

    private var hasData: Bool { bucket.average != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(bucket.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "171717"))

                Spacer()

                Text(valueText)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color(hex: "171717"))
            }

            Text("Entries: \(bucket.count)")
                .font(.caption)
                .foregroundColor(Color(hex: "AEB5BC"))

            MealBucketBar(
                value: bucket.average,
                minGauge: minGauge,
                maxGauge: maxGauge
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private var valueText: String {
        if let avg = bucket.average {
            return GlucoseDisplay.formatted(mgDl: avg, unit: unit)
        } else {
            return GlucoseDisplay.placeholder(unit: unit)
        }
    }
}

private struct MealBucketBar: View {
    var value: Double?
    var minGauge: Double = 0
    var maxGauge: Double = 160

    private var barColor: Color {
        guard let v = value else { return Color(hex: "D4D7DB") }
        let palette: [Color] = [
            Color(hex: "FFD03A"),
            Color(hex: "34D399"),
            Color(hex: "22D3EE"),
            Color(hex: "3B82F6"),
            Color(hex: "FB2651")
        ]
        let clamped = max(minGauge, min(maxGauge, v))
        guard maxGauge > minGauge else { return palette.last ?? .white }
        let p = (clamped - minGauge) / (maxGauge - minGauge)
        let idx = Int(round(p * Double(palette.count - 1)))
        return palette[max(0, min(palette.count - 1, idx))]
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color(hex: "D4D7DB"))
                .frame(height: 6)

            if value != nil {
                Capsule()
                    .fill(barColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 6)
            }
        }
    }
}



private struct GaugeAverageCard: View {
    let average: Double?
    let minReading: (time: String, value: Double)?
    let maxReading: (time: String, value: Double)?
    let targetRange: (min: Double, max: Double)

    let unit: String
    let minGauge: Double
    let maxGauge: Double
    var onQuestionTap: (() -> Void)? = nil

    private let arcLineWidth: CGFloat = 18
    private let trackOpacity: Double = 0.18

    private var hasData: Bool { average != nil }

    private var avgText: String {
        guard let average else { return "--.-" }
        let v = GlucoseDisplay.value(mgDl: average, unit: unit)
        return unit == "mmol/L" ? String(format: "%.1f", v) : String(format: "%.0f", v)
    }

    private var progress: Double {
        guard let average else { return 0 }
        if maxGauge <= minGauge { return 0 }
        let p = (average - minGauge) / (maxGauge - minGauge)
        return min(1, max(0, p))
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                VStack(spacing: 0) {
                    gauge
                        .frame(height: 210)

                    if hasData {
                        minMaxRow.padding(.horizontal, 18)
                    } else {
                        emptyHint.padding(.horizontal, 18)
                    }

                    targetRangeRow.padding(.horizontal, 18)
                        .padding(.top)
                }
                
            }
        }
    }

    private var gauge: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            let center = CGPoint(x: w / 2, y: h * 0.88)
            let radius = min(w, h) * 0.70

            let topMask = Rectangle()
                .frame(width: w, height: center.y)
                .position(x: w / 2, y: center.y / 2)

            ZStack {
                Circle()
                    .trim(from: 0.0, to: 0.5)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "FFD03A"),
                                Color(hex: "34D399"),
                                Color(hex: "22D3EE"),
                                Color(hex: "3B82F6"),
                                Color(hex: "FB2651"),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: arcLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(180))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                    .mask(topMask)
                    .opacity(0)
                
                Image("app_bg_progress line")
                    .resizable()
                    
                    .frame(height: 170)
                    .padding(.horizontal,18)

                marker(center: center, radius: radius)

                VStack(spacing: 5) {
                    Text(avgText)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color(hex: "171717"))
                

                    Text(unit)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "171717"))

                    Text("Average Figure")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.init(hex: "AEB5BC"))
                }
                .position(x: center.x, y: center.y - radius * 0.42)

                HStack {
                    Text(unit == "mmol/L" ? String(format: "%.0f", GlucoseDisplay.value(mgDl: minGauge, unit: unit)) : "\(Int(minGauge))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.init(hex: "AEB5BC"))

                    Spacer()

                    Text(unit == "mmol/L" ? String(format: "%.1f", GlucoseDisplay.value(mgDl: maxGauge, unit: unit)) : "\(Int(maxGauge))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.init(hex: "AEB5BC"))
                }
                .padding(.horizontal, 30)
                .frame(width: radius * 2)
                .position(x: center.x, y: center.y - 6)
            }
        }
    }

    private func marker(center: CGPoint, radius: CGFloat) -> some View {
        let angle = Double.pi - (Double.pi * progress)
        let x = center.x + radius * CGFloat(cos(angle))
        let y = center.y - radius * CGFloat(sin(angle))

        return ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 38, height: 38)
                .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)

            Circle()
                .stroke(markerColor(for: average), lineWidth: 10)
                .frame(width: 22, height: 22)

            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)
        }
        .position(x: x, y: y)
        .opacity(hasData ? 1.0 : 0.0)
    }

    private func markerColor(for v: Double?) -> Color {
        guard let v else { return .clear }

        let palette: [Color] = [
            Color(hex: "FFD03A"),
            Color(hex: "34D399"),
            Color(hex: "22D3EE"),
            Color(hex: "3B82F6"),
            Color(hex: "FB2651")
        ]

        let clamped = max(minGauge, min(maxGauge, v))
        guard maxGauge > minGauge else { return palette.last ?? .white }

        let p = (clamped - minGauge) / (maxGauge - minGauge)

        let idx = Int(round(p * Double(palette.count - 1)))
        return palette[max(0, min(palette.count - 1, idx))]
    }

    private var minMaxRow: some View {
        HStack(spacing: 0) {
            Spacer()
            VStack(spacing: 5) {
                Text(minReading?.time ?? "--")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.22))

                Text(minReading.map { GlucoseDisplay.formatted(mgDl: $0.value, unit: unit) } ?? GlucoseDisplay.placeholder(unit: unit))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "171717"))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                circleIcon(system: "arrow.down", fill: Color(hex: "FFD03A"))
                circleIcon(system: "arrow.up", fill: Color(hex: "FB2651"))
            }

            VStack(spacing: 5) {
                Text(maxReading?.time ?? "--")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.22))

                Text(maxReading.map { GlucoseDisplay.formatted(mgDl: $0.value, unit: unit) } ?? GlucoseDisplay.placeholder(unit: unit))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "171717"))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            Spacer()
        }
    }

    private func circleIcon(system: String, fill: Color) -> some View {
        ZStack {
            Circle().fill(fill)
            Image(systemName: system)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 28, height: 28)
    }

    private var emptyHint: some View {
        Text("Enter your first values")
            .font(.system(size: 24, weight: .semibold))
            .foregroundColor(Color.init(hex: "AEB5BC"))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .padding(.top, 2)
            .padding(.bottom, 2)
    }

    private var targetRangeRow: some View {
        HStack(spacing: 10) {
            let minText = String(format: targetRange.min >= 10 ? "%.0f" : "%.1f", targetRange.min)
            let maxText = String(format: targetRange.max >= 10 ? "%.0f" : "%.1f", targetRange.max)

            Text("For your age from \(minText) to \(maxText) \(unit)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "AEB5BC"))

            Button {
                onQuestionTap?()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.06))
                    Image(systemName: "questionmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.black.opacity(0.35))
                }
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
        }
        .padding(.top, 4)
    }

    private func format(_ v: Double?) -> String {
        guard let v else { return "--.-" }
        return String(format: "%.1f", v)
    }
}

private struct LeftRoundedRect: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .bottomLeft],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension Date {
    fileprivate var trendsShortText: String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: self)
    }
}

private struct InlineDatePicker: UIViewRepresentable {
    @Binding var selection: Date
    let tintHex: String

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .inline
        picker.timeZone = .current
        picker.locale = .current
        picker.calendar = .current
        picker.date = selection

        picker.tintColor = UIColor(hex: tintHex)

        picker.addTarget(
            context.coordinator,
            action: #selector(Coordinator.changed(_:)),
            for: .valueChanged
        )
        return picker
    }

    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        if uiView.date != selection {
            uiView.setDate(selection, animated: false)
        }
        uiView.tintColor = UIColor(hex: tintHex)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    final class Coordinator: NSObject {
        var selection: Binding<Date>
        init(selection: Binding<Date>) {
            self.selection = selection
        }

        @objc func changed(_ sender: UIDatePicker) {
            selection.wrappedValue = sender.date
        }
    }
}

private extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 {
            s = s.map { "\($0)\($0)" }.joined()
        }
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

private struct RightRoundedRect: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topRight, .bottomRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview("Results – With Data") {
    let now = Date()
    let cal = Calendar.current

    let samples: [GlucoseEntry] = [
        GlucoseEntry(
            date: now,
            value: 112,
            mealTime: "Before breakfast"
        ),
        GlucoseEntry(
            date: cal.date(byAdding: .hour, value: -3, to: now) ?? now,
            value: 128,
            mealTime: "After breakfast"
        ),
        GlucoseEntry(
            date: cal.date(byAdding: .hour, value: -7, to: now) ?? now,
            value: 101,
            mealTime: "Before lunch"
        ),
        GlucoseEntry(
            date: cal.date(byAdding: .day, value: -1, to: now) ?? now,
            value: 117,
            mealTime: "After dinner"
        ),
        GlucoseEntry(
            date: cal.date(byAdding: .day, value: -2, to: now) ?? now,
            value: 140,
            mealTime: "Not specified"
        )
    ]

    ResultView(forPreview: true, previewEntries: samples)
        .environmentObject(UserProfileStore())
}

#Preview("Results – Empty") {
    ResultView(forPreview: true, previewEntries: [])
        .environmentObject(UserProfileStore())
}
