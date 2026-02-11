import Charts
import SwiftUI
import UIKit

struct TrendsView: View {
    @EnvironmentObject private var profileStore: UserProfileStore

    var forPreview: Bool

    private var unit: String { profileStore.profile.unit ?? "mg/dL" }

    enum Scope: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year"
        var id: String { rawValue }
    }

    struct Point: Identifiable {
        let id = UUID()
        let hour: Double
        let value: Double
    }

    @State private var scope: Scope = .day
    @State private var selectedDate: Date = Date()
    @State private var tempSelectedDate: Date = Date()
    @State private var isDatePickerPresented: Bool = false
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

    private var points: [Point] {
        switch scope {
        case .day:
            return
                filteredEntries.sorted(by: { $0.date < $1.date })
                .map { e in
                    let h = cal.component(.hour, from: e.date)
                    let m = cal.component(.minute, from: e.date)
                    return Point(
                        hour: Double(h) + Double(m) / 60.0,
                        value: Double(e.value)
                    )
                }
                .sorted { $0.hour < $1.hour }
        case .week:
            guard
                let interval = cal.dateInterval(
                    of: .weekOfYear,
                    for: selectedDate
                )
            else { return [] }
            var byDay: [Int: (sum: Int, count: Int)] = [:]
            for e in filteredEntries.sorted(by: { $0.date < $1.date }) {
                let dayOffset =
                    cal.dateComponents([.day], from: interval.start, to: e.date)
                    .day ?? 0
                let d = max(0, min(6, dayOffset))
                let cur = byDay[d] ?? (0, 0)
                byDay[d] = (cur.sum + e.value, cur.count + 1)
            }
            return (0...6).compactMap { d -> Point? in
                guard let t = byDay[d], t.count > 0 else { return nil }
                return Point(
                    hour: Double(d),
                    value: Double(t.sum) / Double(t.count)
                )
            }.sorted { $0.hour < $1.hour }
        case .month:
            var byDay: [Int: (sum: Int, count: Int)] = [:]
            for e in filteredEntries.sorted(by: { $0.date < $1.date }) {
                let d = cal.component(.day, from: e.date)
                let cur = byDay[d] ?? (0, 0)
                byDay[d] = (cur.sum + e.value, cur.count + 1)
            }
            return byDay.map { d, t in
                Point(hour: Double(d), value: Double(t.sum) / Double(t.count))
            }.sorted { $0.hour < $1.hour }
        case .year:
            var byMonth: [Int: (sum: Int, count: Int)] = [:]
            for e in filteredEntries.sorted(by: { $0.date < $1.date }) {
                let m = cal.component(.month, from: e.date)
                let cur = byMonth[m] ?? (0, 0)
                byMonth[m] = (cur.sum + e.value, cur.count + 1)
            }
            return byMonth.map { m, t in
                Point(hour: Double(m), value: Double(t.sum) / Double(t.count))
            }.sorted { $0.hour < $1.hour }
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

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#F3F3F3").ignoresSafeArea()

      
                VStack(spacing: 16) {
                    Color.clear.frame(height:  DeviceSize.isSmall ? 30 : 20)
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        ZStack {
                            VStack (spacing:14) {
                                scopePicker.padding(.horizontal, 18)
                                
                                if filteredEntries.isEmpty {
                                    emptyChartCard.padding(.horizontal, 18)
                                } else {
                                    chartCard.padding(.horizontal, 18)
                                }
                            }.padding(.top,10)
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
                        
                        avgCard.padding(.horizontal, 18)
                        
                        rangeSmallCard.padding(.horizontal, 18)
                        
                        lastCard.padding(.horizontal, 18).padding(.bottom,100)
                    }
               
                }

                .padding(.top, 8)
              
            

            ZStack(alignment: .bottom) {
                Text("Trends")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "171717"))
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .trailing) {
                        datePill
                    }

                    .padding(.top,  DeviceSize.isSmall ? 20 :50)
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
                    withAnimation(.easeInOut(duration: 0.18)) {
                        scope = item
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

    private var rangeCard: some View {
        StatRowCard(
            title: "Range",
            valueText: filteredEntries.isEmpty
                ? GlucoseDisplay.placeholder(unit: unit) : rangeText(bodyRange),
            isProminent: true
        )
    }

    private var chartCard: some View {
        Group {
            if forPreview {
                chartPlaceholder
            } else {
                ChartCard(points: points, scope: scope, selectedDate: selectedDate)
            }
        }
    }

    private var emptyChartCard: some View {
        EmptyTrendsHintCard(
            iconAssetName: "app_ic_trends_empty",
            fallbackSystemName: "drop.fill",
            title: "We need more\nof your data",
            subtitle: "A visual trend will be\ndisplayed for added entries"
        )
    }

    private var chartPlaceholder: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color(hex: "#F6F6F6"))
            .overlay(
                Text("Chart")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(Color.black.opacity(0.3))
            )
            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 12)
            .frame(height: 260)
    }

    private var avgCard: some View {
        StatRowCard(
            title: "Average per hour",
            valueText: filteredEntries.isEmpty
                ? GlucoseDisplay.placeholder(unit: unit) : GlucoseDisplay.formatted(mgDl: averageValue, unit: unit),
            isProminent: false,
            isGradient: true
        )
    }

    private var rangeSmallCard: some View {
        StatRowCard(
            title: "Range",
            valueText: filteredEntries.isEmpty
                ? GlucoseDisplay.placeholder(unit: unit) : rangeText(bodyRange),
            isProminent: false
        )
    }

    private var lastCard: some View {
        let t = lastReading?.time ?? "--:--"
        let v = lastReading?.value ?? 0
        let valueText =
            filteredEntries.isEmpty ? GlucoseDisplay.placeholder(unit: unit) : GlucoseDisplay.formatted(mgDl: v, unit: unit)
        return StatRowCard(
            title: "Last: \(t)",
            valueText: valueText,
            isProminent: false
        )
    }

    private func rangeText(_ r: (min: Double, max: Double)) -> String {
        let minV = GlucoseDisplay.value(mgDl: r.min, unit: unit)
        let maxV = GlucoseDisplay.value(mgDl: r.max, unit: unit)
        let fmt = unit == "mmol/L" ? "%.1f" : "%.0f"
        return String(format: "\(fmt) - \(fmt) \(unit)", minV, maxV)
    }

    private func format(_ v: Double) -> String {
        String(format: "%.1f", v)
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

private struct ChartCard: View {
    let points: [TrendsView.Point]
    let scope: TrendsView.Scope
    let selectedDate: Date

    private let cal = Calendar.current

    private static let minWidthPerDivision: CGFloat = 44
    private var chartMinWidth: CGFloat {
        let count: Int
        switch scope {
        case .day: count = 25
        case .week: count = 7
        case .month:
            let range = cal.range(of: .day, in: .month, for: selectedDate)
            count = range?.count ?? 31
        case .year: count = 12
        }
        return CGFloat(count) * Self.minWidthPerDivision
    }

    private var xAxisConfig: (domain: ClosedRange<Double>, values: [Double]) {
        switch scope {
        case .day:
            return (0...24, (0...24).map(Double.init))
        case .week:
            return (0...6, (0...6).map(Double.init))
        case .month:
            let range = cal.range(of: .day, in: .month, for: selectedDate)
            let count = range?.count ?? 30
            return (1...Double(count), (1...count).map(Double.init))
        case .year:
            return (1...12, (1...12).map(Double.init))
        }
    }

    private var yAxisRange: (min: Double, max: Double) {
        let values = points.map(\.value)
        guard let vMin = values.min(), let vMax = values.max(), vMax > vMin else {
            return (0, 100)
        }
        let pad = (vMax - vMin) * 0.08
        return (vMin - pad, vMax + pad)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: true) {
                    chart
                        .frame(minWidth: chartMinWidth)
                }
                fixedYAxisView
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(hex: "#F6F6F6"))
                .shadow(
                    color: Color.black.opacity(0.08),
                    radius: 16,
                    x: 0,
                    y: 12
                )
        )
    }

    private var fixedYAxisView: some View {
        let range = yAxisRange
        let step = (range.max - range.min) / 4
        let labels: [Double] = (0...4).map { range.max - step * Double($0) }
        return VStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { i, v in
                if i > 0 { Spacer(minLength: 0) }
                Text(String(format: "%.0f", v))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.25))
            }
        }
        .frame(width: 28, height: 260)
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .background(Color(hex: "#F6F6F6"))
    }

    @ViewBuilder
    private var chart: some View {
        if #available(iOS 16.0, *) {
            let config = xAxisConfig
            Chart {
                ForEach(points) { p in
                    LineMark(
                        x: .value("X", p.hour),
                        y: .value("Value", p.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: 2,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .foregroundStyle(Color(hex: "FB2651"))

                    PointMark(
                        x: .value("X", p.hour),
                        y: .value("Value", p.value)
                    )
                    .symbolSize(40)
                    .foregroundStyle(Color.white)
                    .annotation(position: .overlay) {
                        Circle()
                            .stroke(Color(hex: "FB2651"), lineWidth: 3)
                            .frame(width: 12, height: 12)
                    }

                    AreaMark(
                        x: .value("X", p.hour),
                        y: .value("Value", p.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "FB2651").opacity(0.22),
                                Color(hex: "FB2651").opacity(0.00),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartXScale(domain: config.domain)
            .chartXAxis {
                AxisMarks(values: config.values) { value in
                    AxisGridLine().foregroundStyle(Color.black.opacity(0.08))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(xAxisLabel(v))
                                .foregroundColor(Color.black.opacity(0.25))
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 260)
            .frame(minWidth: chartMinWidth)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        } else {
            Text("Charts requires iOS 16+")
                .frame(height: 260)
        }
    }

    private func xAxisLabel(_ v: Double) -> String {
        switch scope {
        case .day:
            return String(format: "%02d", Int(v))
        case .week:
            return "\(Int(v))"
        case .month:
            return "\(Int(v))"
        case .year:
            return "\(Int(v))"
        }
    }
}

private struct EmptyTrendsHintCard: View {
    let iconAssetName: String
    let fallbackSystemName: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 14) {
            Image("app_ic_charts")
    
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
          
            .padding(.top, 10)

            Text(title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Color(hex: "171717"))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text(subtitle)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color.init(hex: "AEB5BC"))
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white)

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "FB2651").opacity(0.10),
                                Color(hex: "FB2651").opacity(0.00),
                                Color(hex: "FB2651").opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 18)
                    .opacity(0.9)
                    .padding(8)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 12)
        )
        .frame(height: 260)
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

#Preview("Trends") {
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

    TrendsView(forPreview: true, previewEntries: samples)
        .environmentObject(UserProfileStore())
}
