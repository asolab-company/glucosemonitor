import SwiftUI
import UIKit

struct HistoryView: View {
    @EnvironmentObject private var profileStore: UserProfileStore

    @State private var selectedDate: Date = Date()
    @State private var monthDate: Date = Date()

    @State private var entries: [GlucoseEntry] = GlucoseEntryStorage.load()

    private var unit: String { profileStore.profile.unit ?? "mg/dL" }
    @State private var entryToEdit: GlucoseEntry? = nil
    private let loadFromStorage: Bool

    private let bg = Color(hex: "F3F3F3")
    
    private var editSheetDismiss: Binding<Bool> {
        Binding(get: { entryToEdit != nil }, set: { if !$0 { entryToEdit = nil } })
    }
    
    init(previewEntries: [GlucoseEntry]? = nil) {
        if let previewEntries {
            _entries = State(initialValue: previewEntries)
            loadFromStorage = false
        } else {
            _entries = State(initialValue: GlucoseEntryStorage.load())
            loadFromStorage = true
        }
    }
    
    private var dayEntries: [GlucoseEntry] {
        entriesForSelectedDay()
    }

    var body: some View {
        ZStack {
            mainContent
                .onAppear {
                    if loadFromStorage {
                        entries = GlucoseEntryStorage.load()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .glucoseEntriesDidUpdate)) { _ in
                    if loadFromStorage {
                        entries = GlucoseEntryStorage.load()
                    }
                }

            if let entry = entryToEdit {
                ZStack {
                    MainVisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                        .ignoresSafeArea()

                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                }
                .transition(.opacity)
                .onTapGesture {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        entryToEdit = nil
                    }
                }
                .zIndex(10)

                AddEntrySheet(isPresented: editSheetDismiss, initialEntry: entry)
                    .environmentObject(profileStore)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(11)
                    .onDisappear {
                        if loadFromStorage {
                            entries = GlucoseEntryStorage.load()
                        }
                    }
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: entryToEdit != nil)
    }

    private var mainContent: some View {
        ZStack (alignment: .top){
            bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Color.clear.frame(height: 50)
                historyContentBody
            }
            ZStack(alignment: .bottom) {
                Text("History")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "171717"))
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .trailing) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedDate = Date()
                                monthDate = Date()
                            }
                        } label: {
                            Text("Show today")
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: "FB2651"))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, DeviceSize.isSmall ? 20 : 50)
            }
            .frame(maxWidth: .infinity)
            .frame(height: DeviceSize.isSmall ? 80 : 110)
            .background {
                BottomRoundedShape(radius: 0)
                    .fill(Color(hex: "ECECEC"))
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private var historyContentBody: some View {
        HistoryContent(
            monthDate: monthDate,
            selectedDate: $selectedDate,
            dayEntries: dayEntries,
            unit: unit,
            onPrevMonth: prevMonthAction,
            onNextMonth: nextMonthAction,
            onDelete: delete,
            onEdit: { entryToEdit = $0 }
        )
    }

    private func prevMonthAction() {
        withAnimation(.easeInOut(duration: 0.18)) {
            monthDate = Calendar.current.date(byAdding: .month, value: -1, to: monthDate) ?? monthDate
        }
    }

    private func nextMonthAction() {
        withAnimation(.easeInOut(duration: 0.18)) {
            monthDate = Calendar.current.date(byAdding: .month, value: 1, to: monthDate) ?? monthDate
        }
    }

    private var header: some View {
        Text("History")
            .font(.title3)
            .fontWeight(.medium)
            .foregroundColor(Color(hex: "171717"))
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedDate = Date()
                        monthDate = Date()
                    }
                } label: {
                    Text("Show today")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "FB2651"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
    }

    private func monthTitle(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    private func entriesForSelectedDay() -> [GlucoseEntry] {
        let cal = Calendar.current
        return entries
            .filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date > $1.date }
    }

    private func delete(_ entry: GlucoseEntry) {
        entries.removeAll { $0.id == entry.id }
        GlucoseEntryStorage.remove(id: entry.id)
    }
}

private struct HistoryContent: View {
    let monthDate: Date
    @Binding var selectedDate: Date
    let dayEntries: [GlucoseEntry]
    let unit: String

    let onPrevMonth: () -> Void
    let onNextMonth: () -> Void
    let onDelete: (GlucoseEntry) -> Void
    let onEdit: (GlucoseEntry) -> Void

    var body: some View {
        List {
            Section {
                calendarBlock
                    .listRowInsets(EdgeInsets(top: 10, leading: 18, bottom: 30, trailing: 18))
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        BottomRoundedShape(radius: 40)
                            .fill(Color(hex: "ECECEC"))
                            .shadow(color: Color.black.opacity(0.20), radius: 2, x: 0, y: 2)
                            .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
                    )
            }
            if !dayEntries.isEmpty {
                Section {
                    HistoryHintRow()
                        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            Section {
                if dayEntries.isEmpty {
                    HistoryEmptyState()
                        .listRowInsets(EdgeInsets(top: 22, leading: 18, bottom: 26, trailing: 18))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(dayEntries) { entry in
                        HistoryEntryRow(entry: entry, unit: unit)
                            .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { onDelete(entry) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button { onEdit(entry) } label: { Label("Edit", systemImage: "pencil") }
                                    .tint(Color(hex: "FB2651"))
                            }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .padding(.top, 10)
        .padding(.bottom, 50)
    }

    private var calendarBlock: some View {
        CalendarCard(
            monthDate: monthDate,
            selectedDate: $selectedDate,
            onPrevMonth: onPrevMonth,
            onNextMonth: onNextMonth
        )
    }
}
private struct HistoryEmptyState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image("app_ic_data")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
            

            Text("Add entries\nof the day")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "171717"))
                .multilineTextAlignment(.center)

            Text("Entered records will be\ndisplayed by day for easy")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "AEB5BC"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }
}

private struct CalendarCard: View {
    let monthDate: Date
    @Binding var selectedDate: Date
    let onPrevMonth: () -> Void
    let onNextMonth: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            monthHeader
            weekdaysRow
            CalendarGrid(monthDate: monthDate, selectedDate: $selectedDate)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    private var monthHeader: some View {
        HStack {
            Text(monthTitle(from: monthDate))
                .font(.body)
                .fontWeight(.regular)
                .foregroundColor(Color(hex: "171717"))
            Spacer()
            HStack(spacing: 18) {
                Button(action: onPrevMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "FB2651"))
                }
                .buttonStyle(.plain)
                Button(action: onNextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "FB2651"))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weekdaysRow: some View {
        HStack {
            ForEach(["SUN","MON","TUE","WED","THU","FRI","SAT"], id: \.self) { d in
                Text(d)
                    .font(.footnote)
                    .fontWeight(.regular)
                    .foregroundColor(Color(hex: "AEB5BC"))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 2)
    }

    private func monthTitle(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}

private struct HistoryHintRow: View {
    var body: some View {
        HStack(spacing: 14) {
            Image("app_ic_idea")
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text("Swipe right to edit a post")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "AEB5BC"))

                Text("Swipe left to delete a post")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "AEB5BC"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct CalendarGrid: View {
    let monthDate: Date
    @Binding var selectedDate: Date

    private let cal = Calendar.current
    private let selectedColor = Color(hex: "FB2651")
    private let todayColor = Color(hex: "FF6282").opacity(0.55)

    private struct DayCell {
        let date: Date?
        let dayNumber: Int
    }
    
    private var days: [DayCell] { makeDays() }

    private let cellHeight: CGFloat = 36

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 10) {
            ForEach(days.indices, id: \.self) { idx in
                let day = days[idx]
                Group {
                    if let date = day.date {
                        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
                        let isToday = cal.isDateInToday(date)
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) { selectedDate = date }
                        } label: {
                            ZStack {
                                if isSelected {
                                    Circle().fill(selectedColor).frame(width: 38, height: 38)
                                } else if isToday {
                                    Circle().fill(todayColor).frame(width: 38, height: 38)
                                }
                                Text("\(day.dayNumber)")
                                    .font(.title3)
                                    .fontWeight(.regular)
                                    .foregroundColor(isSelected ? .white : Color(hex: "171717"))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: cellHeight)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: cellHeight)
                    }
                }
            }
        }
        .padding(.top, 5)
    }

    private func makeDays() -> [DayCell] {
        let comps = cal.dateComponents([.year, .month], from: monthDate)
        let firstOfMonth = cal.date(from: comps) ?? monthDate
        let range = cal.range(of: .day, in: .month, for: firstOfMonth) ?? 1..<2
        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let leadingEmpty = max(0, firstWeekday - 1)
        var result: [DayCell] = []
        for _ in 0..<leadingEmpty { result.append(DayCell(date: nil, dayNumber: 0)) }
        for day in range {
            let d = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth)
            result.append(DayCell(date: d, dayNumber: day))
        }
        while result.count % 7 != 0 { result.append(DayCell(date: nil, dayNumber: 0)) }
        return result
    }
}

private struct HistoryEntryRow: View {
    let entry: GlucoseEntry
    var unit: String = "mg/dL"
    private let cardCorner: CGFloat = 20

    var body: some View {
        HStack(spacing: 14) {
            entryIcon
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.mealTime)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "171717"))

                Text(timeString(from: entry.date))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "AEB5BC"))
            }

            Spacer()

            Text(valueString)
                .font(.system(size: DeviceSize.isSmall ? 18 : 22, weight: .heavy))
                .foregroundColor(Color(hex: "171717"))
        }
        .padding(.horizontal, 18)
        .frame(height: 66)
        .background(
            RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private var valueString: String {
        GlucoseDisplay.formatted(mgDl: Double(entry.value), unit: unit)
    }

    private var entryIcon: some View {
        Image(iconAssetName)
         
            .resizable()
            .scaledToFit()
            .frame(width: 42, height: 42)
       
    }

    private var iconAssetName: String {
        let t = entry.mealTime.lowercased()
        if t.contains("breakfast") { return "app_ic_food" }
        if t.contains("lunch") { return "app_ic_food_1" }
        if t.contains("dinner") { return "app_ic_food_2" }
        return "app_ic_food_3"
    }

    private var fallbackSymbol: String {
        let t = entry.mealTime.lowercased()
        if t.contains("breakfast") { return "cup.and.saucer.fill" }
        if t.contains("lunch") { return "takeoutbag.and.cup.and.straw.fill" }
        if t.contains("dinner") { return "fork.knife" }
        return "circle.grid.cross"
    }

    private func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

#Preview("History - Empty") {
    HistoryView(previewEntries: [])
        .environmentObject(UserProfileStore())
}

#Preview("History - With Data") {
    let now = Date()
    let cal = Calendar.current

    let samples: [GlucoseEntry] = [
        GlucoseEntry(id: UUID(), date: now, value: 112, mealTime: "Breakfast"),
        GlucoseEntry(id: UUID(), date: cal.date(byAdding: .hour, value: -3, to: now) ?? now, value: 128, mealTime: "Lunch"),
        GlucoseEntry(id: UUID(), date: cal.date(byAdding: .hour, value: -7, to: now) ?? now, value: 101, mealTime: "Dinner"),
        GlucoseEntry(id: UUID(), date: cal.date(byAdding: .day, value: -1, to: now) ?? now, value: 117, mealTime: "Breakfast"),
        GlucoseEntry(id: UUID(), date: cal.date(byAdding: .day, value: -2, to: now) ?? now, value: 140, mealTime: "Lunch")
    ]

    return HistoryView(previewEntries: samples)
        .environmentObject(UserProfileStore())
}
