import SwiftUI

// MARK: - Full-width single-day habit list
// Shows one day at a time. Day strip at top lets you swipe/tap to other days.
// Fits perfectly on any iPhone without horizontal scrolling.

struct WeeklyGridView: View {
    @EnvironmentObject private var store: HabitStore

    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var currentMinute: Int = Self.minuteOfDay()
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // Week header bar
            weekHeader

            // Day strip
            dayStrip
                .padding(.vertical, 10)
                .background(Color.cardBackground)

            Divider().background(Color.cellBorder)

            // Habit list for selected day
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(HabitDefinition.all.enumerated()), id: \.offset) { idx, def in
                        // Skip inactive days with a subtle placeholder
                        let dayIdx = weekdayIndex(of: selectedDay)
                        if let mask = def.activeDays, !mask.contains(dayIdx) {
                            InactiveDayRow(definition: def, isAlternate: idx % 2 == 1)
                        } else {
                            HabitRow(
                                definition: def,
                                day: selectedDay,
                                isAlternate: idx % 2 == 1,
                                currentMinute: currentMinute
                            )
                        }
                        Divider().background(Color.cellBorder)
                    }
                }
            }
            // Swipe left/right to change day
            .gesture(
                DragGesture(minimumDistance: 40, coordinateSpace: .local)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical   = abs(value.translation.height)
                        guard abs(horizontal) > vertical else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if horizontal < 0 { advanceDay(by: 1) }
                            else              { advanceDay(by: -1) }
                        }
                    }
            )
        }
        .background(Color.appBackground)
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            let m = Self.minuteOfDay()
            if m != currentMinute { currentMinute = m }
        }
    }

    // MARK: - Week header

    private var weekHeader: some View {
        HStack(spacing: 12) {
            Button(action: { withAnimation { advanceWeek(by: -1) } }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryText)
                    .frame(width: 32, height: 32)
                    .background(Color.cellBackground)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Button(action: { withAnimation { jumpToToday() } }) {
                    Text(weekRangeLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primaryText)
                }
                .buttonStyle(.plain)

                Text(String(format: "%.0f%% this week", store.currentWeekCompletionPct))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.accentGreen)
            }

            Spacer()

            Button(action: { withAnimation { advanceWeek(by: 1) } }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryText)
                    .frame(width: 32, height: 32)
                    .background(Color.cellBackground)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.cardBackground)
    }

    // MARK: - Day strip

    private var dayStrip: some View {
        HStack(spacing: 6) {
            ForEach(store.currentWeekStart.weekDays(), id: \.self) { day in
                let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDay)
                let isToday    = day.isToday
                let pct        = dayCompletionPct(for: day)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedDay = day }
                }) {
                    VStack(spacing: 3) {
                        Text(day.shortWeekdayLabel)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(isSelected ? .black : (isToday ? .accentGreen : .secondaryText))

                        Text(day.dayOfMonthLabel)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(isSelected ? .black : (isToday ? .accentGreen : .primaryText))

                        // Completion ring
                        ZStack {
                            Circle()
                                .stroke(Color.cellBorder, lineWidth: 1.5)
                                .frame(width: 16, height: 16)
                            if pct > 0 {
                                Circle()
                                    .trim(from: 0, to: pct)
                                    .stroke(isSelected ? Color.black : Color.accentGreen,
                                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        isSelected ? Color.accentGreen :
                        (isToday   ? Color.accentGreen.opacity(0.1) : Color.clear)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Helpers

    private func weekdayIndex(of date: Date) -> Int {
        let cal = Calendar(identifier: .iso8601)
        return (cal.component(.weekday, from: date) - 2 + 7) % 7
    }

    private func advanceDay(by delta: Int) {
        let cal   = Calendar.current
        let weeks = store.currentWeekStart.weekDays()
        guard let newDay = cal.date(byAdding: .day, value: delta, to: selectedDay) else { return }

        // If new day is outside current week, shift week too
        if !weeks.contains(where: { cal.isDate($0, inSameDayAs: newDay) }) {
            if delta > 0 { store.goToNextWeek() }
            else         { store.goToPreviousWeek() }
        }
        selectedDay = newDay
    }

    private func advanceWeek(by delta: Int) {
        if delta > 0 { store.goToNextWeek() }
        else         { store.goToPreviousWeek() }
        // Select Monday of new week (or today if current week)
        let newWeekDays = store.currentWeekStart.weekDays()
        if let first = newWeekDays.first { selectedDay = first }
        // If jumping to current week, land on today
        if delta > 0 && store.currentWeekStart.isToday { jumpToToday() }
    }

    private func jumpToToday() {
        store.goToCurrentWeek()
        selectedDay = Calendar.current.startOfDay(for: Date())
    }

    private var weekRangeLabel: String {
        let days = store.currentWeekStart.weekDays()
        guard let first = days.first, let last = days.last else { return "" }
        return "\(SharedDateFormatter.monthDay.string(from: first)) – \(SharedDateFormatter.monthDay.string(from: last))"
    }

    private func dayCompletionPct(for day: Date) -> Double {
        let dayIdx = weekdayIndex(of: day)
        var total  = 0.0
        var done   = 0.0
        for habit in HabitDefinition.all {
            if let mask = habit.activeDays, !mask.contains(dayIdx) { continue }
            total += 1
            if store.isCompleted(habit: habit.id, on: day) { done += 1 }
        }
        guard total > 0 else { return 0 }
        return done / total
    }

    private static func minuteOfDay() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

// MARK: - HabitRow (full-width, single day)

struct HabitRow: View {
    let definition: HabitDefinition
    let day: Date
    let isAlternate: Bool
    let currentMinute: Int

    @EnvironmentObject private var store: HabitStore

    var body: some View {
        let locked    = !definition.isUnlocked(for: day)
        let completed = store.isCompleted(habit: definition.id, on: day)

        Button(action: {
            if !locked {
                store.toggle(habit: definition.id, on: day)
            }
        }) {
            HStack(spacing: 14) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(completed ? Color.accentGreen.opacity(0.15) : Color.cellBackground)
                        .frame(width: 40, height: 40)
                    Image(systemName: definition.icon)
                        .font(.system(size: 16))
                        .foregroundColor(completed ? .accentGreen : (locked ? .secondaryText.opacity(0.5) : .secondaryText))
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(definition.time)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondaryText)
                        Text(definition.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(locked && !completed ? Color.primaryText.opacity(0.45) : .primaryText)
                    }
                    Text(definition.detail)
                        .font(.system(size: 11))
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                // Checkbox / lock
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(completed ? Color.accentGreen : Color.cellBackground)
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    completed ? Color.accentGreen :
                                    (locked ? Color.cellBorder.opacity(0.35) : Color.cellBorder),
                                    lineWidth: 1.5
                                )
                        )

                    if completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .transition(.scale.combined(with: .opacity))
                    } else if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color.secondaryText.opacity(0.35))
                    }
                }
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: completed)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isAlternate ? Color.rowAltBackground : Color.appBackground)
        .id("\(definition.id.rawValue)_\(day.dateKey)_\(currentMinute)")
    }
}

// MARK: - Inactive day placeholder row

struct InactiveDayRow: View {
    let definition: HabitDefinition
    let isAlternate: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.cellBackground.opacity(0.5))
                    .frame(width: 40, height: 40)
                Image(systemName: definition.icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color.secondaryText.opacity(0.25))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(definition.time)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.secondaryText.opacity(0.3))
                    Text(definition.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.primaryText.opacity(0.2))
                }
                Text("Not scheduled today")
                    .font(.system(size: 11))
                    .foregroundColor(Color.secondaryText.opacity(0.25))
            }
            Spacer()
            Text("–")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(Color.secondaryText.opacity(0.2))
                .frame(width: 32)
                .padding(.trailing, 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isAlternate ? Color.rowAltBackground.opacity(0.5) : Color.appBackground)
    }
}
