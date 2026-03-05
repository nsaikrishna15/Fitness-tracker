import SwiftUI
import Charts

// MARK: - Progress Tab (weight logging + chart + history)

struct BodyweightChartView: View {
    @EnvironmentObject private var store: HabitStore

    @State private var weekStart: Date = Date().startOfWeek()
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showingLogSheet = false

    private var weekDays: [Date] { weekStart.weekDays() }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                weighInDayPicker
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 14)

                weekStrip
                    .padding(.bottom, 10)

                logButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                bmiCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)

                chartSection
                    .padding(.bottom, 28)

                Divider()
                    .background(Color.cellBorder)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)

                historySection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
            }
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showingLogSheet) {
            WeightLogSheet(date: selectedDate)
                .environmentObject(store)
        }
    }

    // MARK: - Weigh-in day picker

    private var weighInDayPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weigh-in Day")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondaryText)

            let options = ["Every Day", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<options.count, id: \.self) { i in
                        Button(action: { store.weighInDay = i }) {
                            Text(options[i])
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(store.weighInDay == i ? .black : .primaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(store.weighInDay == i ? Color.accentGreen : Color.cellBackground)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cellBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Week strip

    private var weekStrip: some View {
        VStack(spacing: 0) {
            // Week nav header
            HStack {
                Button(action: {
                    weekStart = Calendar(identifier: .iso8601).date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? weekStart
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primaryText)
                        .frame(width: 28, height: 28)
                        .background(Color.cellBackground)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(weekRangeLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primaryText)

                Spacer()

                Button(action: {
                    weekStart = Calendar(identifier: .iso8601).date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primaryText)
                        .frame(width: 28, height: 28)
                        .background(Color.cellBackground)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Day buttons
            HStack(spacing: 6) {
                ForEach(weekDays, id: \.self) { day in
                    let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
                    let isToday    = day.isToday
                    let isFuture   = day.isFutureDay
                    let kg         = store.weight(on: day)
                    let isWeighIn  = isWeighInDay(day)

                    Button(action: {
                        if !isFuture { selectedDate = day }
                    }) {
                        VStack(spacing: 3) {
                            Text(day.shortWeekdayLabel)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(isSelected ? .black : (isToday ? .accentGreen : .secondaryText))

                            Text(day.dayOfMonthLabel)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(isSelected ? .black : (isToday ? .accentGreen : (isFuture ? .secondaryText.opacity(0.4) : .primaryText)))

                            if let kg {
                                Text(String(format: "%.1f", kg))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(isSelected ? .black : .accentGreen)
                            } else {
                                // dot indicator if this is the designated weigh-in day
                                Circle()
                                    .fill(isWeighIn && !isFuture ? Color.accentGreen.opacity(0.5) : Color.clear)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            isSelected ? Color.accentGreen :
                            (isToday ? Color.accentGreen.opacity(0.1) : Color.cardBackground)
                        )
                        .cornerRadius(8)
                        .opacity(isFuture ? 0.4 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(isFuture)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    // MARK: - Log button

    private var logButton: some View {
        let existing = store.weight(on: selectedDate)
        let label    = existing != nil
            ? String(format: "Edit  %.1f kg  — %@", existing!, selectedDate.mediumLabel)
            : "Log weight for \(selectedDate.mediumLabel)"
        let icon     = existing != nil ? "pencil" : "plus"

        return Button(action: { showingLogSheet = true }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if existing != nil {
                    Text("Tap to edit")
                        .font(.system(size: 11))
                        .foregroundColor(.secondaryText)
                }
            }
            .foregroundColor(existing != nil ? .accentGreen : .primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.cardBackground)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                existing != nil ? Color.accentGreen.opacity(0.4) : Color.cellBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - BMI Card

    private var bmiCard: some View {
        let bmi     = store.bmiValue
        let category = bmi.map { bmiCategory($0) }
        let catColor = bmi.map { bmiColor($0) } ?? Color.secondaryText

        return HStack(spacing: 0) {
            // BMI value
            VStack(spacing: 4) {
                Text("BMI")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondaryText)
                if let b = bmi {
                    Text(String(format: "%.1f", b))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(catColor)
                    Text(category ?? "")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(catColor)
                } else {
                    Text("–")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.secondaryText)
                    Text("Log weight first")
                        .font(.system(size: 10))
                        .foregroundColor(.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 44).background(Color.cellBorder)

            // Body fat target
            VStack(spacing: 4) {
                Text("Fat Target")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondaryText)
                Text(String(format: "%.0f%%", store.targetBodyFatPct))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.accentGreen)
                Text(store.isMale ? "Male · Athletic" : "Female · Athletic")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondaryText)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 44).background(Color.cellBorder)

            // Daily protein target — sourced from DietPlan via store
            VStack(spacing: 4) {
                Text("Protein/day")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondaryText)
                Text("\(store.dailyProteinG)g")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.accentGreen)
                Text("\(store.dailyCalories) kcal plan")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cellBorder, lineWidth: 1))
    }

    private func bmiCategory(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }

    private func bmiColor(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: return .accentBlue
        case 18.5..<25: return .accentGreen
        case 25..<30: return .orange
        default: return .red
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        let data = store.chartWeightData
        let weights = data.compactMap { $0.weightKg }
        let firstKg = weights.first
        let lastKg  = weights.last
        let delta   = (firstKg != nil && lastKg != nil) ? lastKg! - firstKg! : nil

        return VStack(alignment: .leading, spacing: 0) {

            // Header row: title + delta badge + filter label
            HStack(alignment: .center, spacing: 8) {
                Text("Weight Trend")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primaryText)

                if let d = delta, data.count >= 2 {
                    let isDown = d < 0
                    HStack(spacing: 3) {
                        Image(systemName: isDown ? "arrow.down" : "arrow.up")
                            .font(.system(size: 9, weight: .bold))
                        Text(String(format: "%.1f kg", abs(d)))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(isDown ? .accentGreen : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isDown ? Color.accentGreen : Color.orange).opacity(0.12))
                    .cornerRadius(6)
                }

                Spacer()

                if store.weighInDay != 0 {
                    Text(weighInDayLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.cellBackground)
                        .cornerRadius(5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Chart card
            VStack(spacing: 0) {
                if data.count < 2 {
                    emptyChartState
                } else {
                    let minY = (weights.min() ?? 60) - 2
                    let maxY = (weights.max() ?? 100) + 2

                    Chart(data) { entry in
                        // Subtle area fill — very low opacity so it doesn't dominate
                        AreaMark(
                            x: .value("Date", entry.date),
                            y: .value("kg", entry.weightKg ?? 0)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accentGreen.opacity(0.08), Color.clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )

                        // Main line
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("kg", entry.weightKg ?? 0)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.accentGreen)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        // Data points
                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("kg", entry.weightKg ?? 0)
                        )
                        .foregroundStyle(Color.accentGreen)
                        .symbolSize(28)
                        .annotation(position: .top, spacing: 4) {
                            if let kg = entry.weightKg {
                                Text(String(format: "%.1f", kg))
                                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.secondaryText)
                            }
                        }
                    }
                    .chartYScale(domain: minY...maxY)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                                .foregroundStyle(Color.cellBorder)
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                .foregroundStyle(Color.secondaryText)
                                .font(.system(size: 9))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                                .foregroundStyle(Color.cellBorder)
                            AxisValueLabel {
                                if let kg = value.as(Double.self) {
                                    Text(String(format: "%.0f", kg))
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondaryText)
                                }
                            }
                        }
                    }
                    .frame(height: 210)
                    .padding(.top, 8)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
            .background(Color.cardBackground)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cellBorder, lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    private var emptyChartState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 34))
                .foregroundColor(Color.secondaryText.opacity(0.4))
            Text("No data yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondaryText)
            Text("Log weight on any past day\nto see your trend appear here.")
                .font(.system(size: 12))
                .foregroundColor(Color.secondaryText.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }

    // MARK: - History list

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("History")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primaryText)
                Spacer()
                Text("\(store.allWeightHistory.count) entries")
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
            }

            if store.allWeightHistory.isEmpty {
                Text("No entries yet — log your first weight above.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.allWeightHistory.enumerated()), id: \.element.id) { idx, entry in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.date.mediumLabel)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primaryText)
                                if let prev = entry.previousKg, let edited = entry.lastEditedAt {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 8))
                                        Text("was \(String(format: "%.1f", prev)) kg · \(edited.relativeLabel)")
                                            .font(.system(size: 10))
                                    }
                                    .foregroundColor(Color.orange.opacity(0.8))
                                }
                            }
                            Spacer()
                            Text(String(format: "%.1f kg", entry.weightKg ?? 0))
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(.accentGreen)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)

                        if idx < store.allWeightHistory.count - 1 {
                            Divider()
                                .background(Color.cellBorder)
                                .padding(.leading, 14)
                        }
                    }
                }
                .background(Color.cardBackground)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cellBorder, lineWidth: 1))
            }
        }
    }

    // MARK: - Helpers

    private var weekRangeLabel: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        return "\(SharedDateFormatter.monthDay.string(from: first)) – \(SharedDateFormatter.monthDay.string(from: last))"
    }

    private var weighInDayLabel: String {
        ["Every Day", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][safe: store.weighInDay] ?? ""
    }

    private func isWeighInDay(_ date: Date) -> Bool {
        guard store.weighInDay != 0 else { return true }
        let iso = Calendar(identifier: .iso8601).component(.weekday, from: date)
        let isoMon = (iso - 2 + 7) % 7 + 1
        return isoMon == store.weighInDay
    }
}

// MARK: - Weight log / edit sheet

struct WeightLogSheet: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    let date: Date

    @State private var kgText: String = ""
    @FocusState private var focused: Bool

    private var existingEntry: WeightEntry? { store.weightEntry(on: date) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(date.mediumLabel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondaryText)
                    .padding(.top, 8)

                // Previous correction info
                if let prev = existingEntry?.previousKg, let edited = existingEntry?.lastEditedAt {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11))
                        Text("Previously \(String(format: "%.1f", prev)) kg · edited \(edited.relativeLabel)")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondaryText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.cellBackground)
                    .cornerRadius(8)
                    .padding(.horizontal, 32)
                }

                // Input field
                VStack(spacing: 6) {
                    Text("Body weight (kg)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondaryText)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        TextField("e.g. 82.5", text: $kgText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 44, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentGreen)
                            .multilineTextAlignment(.center)
                            .focused($focused)

                        Text("kg")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.secondaryText)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 32)
                .background(Color.cardBackground)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.accentGreen.opacity(focused ? 0.6 : 0.2), lineWidth: 1.5))
                .padding(.horizontal, 24)

                // Remove button — only shown if an entry already exists
                if existingEntry != nil {
                    Button(action: {
                        store.setWeight(nil, on: date)
                        dismiss()
                    }) {
                        Label("Remove entry", systemImage: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(existingEntry != nil ? "Edit Weight" : "Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.accentGreen)
                        .disabled(Double(kgText.replacingOccurrences(of: ",", with: ".")) == nil)
                }
            }
        }
        .onAppear {
            if let kg = store.weight(on: date) {
                kgText = String(format: "%.1f", kg)
            }
            focused = true
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private func save() {
        let normalised = kgText.replacingOccurrences(of: ",", with: ".")
        guard let kg = Double(normalised) else { return }
        store.setWeight(kg, on: date)
        dismiss()
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Date {
    /// "Fri, 20 Feb 2026"
    var mediumLabel: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: self)
    }

    /// "2 hours ago" / "yesterday" etc.
    var relativeLabel: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: self, relativeTo: Date())
    }
}
