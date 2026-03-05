import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject private var store: HabitStore
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var currentMinute: Int = WorkoutView.minuteOfDay()
    @State private var showSkipConfirmation: Bool = false

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    /// All 120 calendar days of the program, from program start date.
    private var allProgramDays: [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: store.programStartDate)
        return (0..<120).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    /// Future days in the program — shown in read-only preview mode so the user
    /// can plan equipment and mentally prepare. No set logging allowed.
    private func isPreview(_ date: Date) -> Bool { date.isFutureDay }

    /// Today before 6:59 AM — show locked card; sets cannot be logged yet.
    private func isLocked(_ date: Date) -> Bool {
        guard !date.isPastDay, !date.isFutureDay else { return false }
        return currentMinute < (6 * 60 + 59)
    }

    private var daySession: DaySession {
        WorkoutSchedule.session(for: selectedDate, programStart: store.programStartDate)
    }

    private var currentPhase: ProgramPhase {
        ProgramPhase.current(startDate: store.programStartDate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                dayStrip
                    .padding(.bottom, 12)

                phaseBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                if isLocked(selectedDate) {
                    lockedCard
                        .padding(.horizontal, 16)
                } else if isPreview(selectedDate) {
                    upcomingBanner
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                    sessionBlock(session: daySession.morning, isPreview: true)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                    sessionBlock(session: daySession.evening, isPreview: true)
                        .padding(.horizontal, 16)
                } else {
                    if store.isWorkoutMissed(for: selectedDate) {
                        missedSessionBanner
                            .padding(.horizontal, 16)
                            .padding(.bottom, 14)
                    }
                    sessionBlock(session: daySession.morning)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                    sessionBlock(session: daySession.evening)
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 32)
            }
            .padding(.top, 12)
        }
        .background(Color.appBackground)
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.cardBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { clearStaleIfLocked(selectedDate) }
        .onChange(of: selectedDate) { date in clearStaleIfLocked(date) }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            let m = WorkoutView.minuteOfDay()
            if m != currentMinute { currentMinute = m }
        }
        .confirmationDialog(
            "Skip this session?",
            isPresented: $showSkipConfirmation,
            titleVisibility: .visible
        ) {
            Button("Skip Session", role: .destructive) {
                store.skipWorkoutSession(for: selectedDate)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This session will be marked skipped. No progression penalty. The program day counter does not advance.")
        }
    }

    private func clearStaleIfLocked(_ date: Date) {
        if isLocked(date) { store.clearWorkoutSets(for: date) }
    }

    // MARK: - Day strip — full 120-day program, scrollable

    private var dayStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(allProgramDays, id: \.self) { day in
                        dayPill(for: day)
                            .id(day)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                // Delay slightly to ensure layout is complete before scrolling
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    proxy.scrollTo(today, anchor: .center)
                }
            }
            .onChange(of: selectedDate) { date in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(date, anchor: .center)
                }
            }
        }
    }

    private func dayPill(for day: Date) -> some View {
        let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
        let isToday    = day.isToday
        let preview    = isPreview(day)
        let locked     = isLocked(day)
        let missed     = store.isWorkoutMissed(for: day)
        let skipped    = store.isWorkoutSkipped(for: day)
        let session    = WorkoutSchedule.session(for: day, programStart: store.programStartDate)
        let icon: String = locked ? "lock.fill" : (skipped ? "slash.circle" : session.morning.icon)

        let iconColor: Color = {
            if isSelected { return .black }
            if missed  { return .orange }
            if skipped { return .secondaryText.opacity(0.4) }
            if preview { return .secondaryText.opacity(0.45) }
            return .secondaryText
        }()

        let dotColor: Color = missed ? .orange : (skipped ? Color.secondaryText.opacity(0.35) : .clear)

        return Button(action: { selectedDate = day }) {
            VStack(spacing: 2) {
                Text(day.shortWeekdayLabel)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isSelected ? .black : (isToday ? .accentGreen : .secondaryText))

                Text(day.dayOfMonthLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? .black : (isToday ? .accentGreen : .primaryText))

                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(iconColor)

                // Status dot: orange = missed, dim = skipped, clear = normal
                Circle()
                    .fill(dotColor)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 42, height: 62)
            .background(
                isSelected ? Color.accentGreen :
                (isToday ? Color.accentGreen.opacity(0.1) : Color.cardBackground)
            )
            .cornerRadius(8)
            .opacity(preview && !isSelected ? 0.65 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Upcoming session preview banner

    private var upcomingBanner: some View {
        let dayNum = store.calendarDayNumber(for: selectedDate)
        return HStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 14))
                .foregroundColor(.accentBlue)
            VStack(alignment: .leading, spacing: 1) {
                Text("UPCOMING — DAY \(dayNum) OF 120")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.accentBlue)
                    .tracking(0.5)
                Text("Plan your equipment. Logging opens on the day.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.accentBlue.opacity(0.08))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentBlue.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Missed session banner

    private var missedSessionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("SESSION NOT LOGGED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
                    .tracking(0.5)
                Text("Log it now, or skip to remove this flag.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
            }
            Spacer()
            Button("Skip") { showSkipConfirmation = true }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
        }
        .padding(12)
        .background(Color.orange.opacity(0.06))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Phase banner

    private var phaseBanner: some View {
        let programDay = store.activeProgramDay
        let clamped    = max(1, min(programDay, 120))
        let isDeload   = store.isDeloadWeek
        let mode       = store.intensityMode
        let modeColor  = Color(hex: mode.colorHex)

        return VStack(spacing: 6) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(currentPhase.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isDeload ? .orange : .accentGreen)
                        Text("· Workout Day \(clamped) of 120")
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                    }
                    Text(isDeload ? "Deload week — 2 sets, –20% weight" : currentPhase.description)
                        .font(.system(size: 11))
                        .foregroundColor(isDeload ? .orange : .secondaryText)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(mode.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(modeColor)
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundColor(.secondaryText)
                        Text(mode.deficitLabel)
                            .font(.system(size: 10))
                            .foregroundColor(.secondaryText)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.cellBorder, lineWidth: 2)
                        .frame(width: 36, height: 36)
                    Circle()
                        .trim(from: 0, to: CGFloat(clamped) / 120.0)
                        .stroke(isDeload ? Color.orange : Color.accentGreen,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 36, height: 36)
                    Text("\(Int(CGFloat(clamped) / 120.0 * 100))%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(isDeload ? .orange : .accentGreen)
                }
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cellBorder, lineWidth: 1))
    }

    // MARK: - Session block (morning or evening)

    @ViewBuilder
    private func sessionBlock(session: WorkoutSession, isPreview: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Session header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentGreen.opacity(isPreview ? 0.08 : 0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: session.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isPreview ? .accentGreen.opacity(0.5) : .accentGreen)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(session.slot.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondaryText)
                            .tracking(0.6)
                        Text(session.label)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(isPreview ? .primaryText.opacity(0.65) : .primaryText)
                        if isPreview {
                            Text("PREVIEW")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.accentBlue)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.accentBlue.opacity(0.12))
                                .cornerRadius(3)
                        }
                    }
                    if !session.isRest && !isPreview {
                        let done  = session.exercises.reduce(0) { $0 + store.workoutSetsForExercise(date: selectedDate, exerciseID: $1.id).filter { $0.completed }.count }
                        let total = session.exercises.reduce(0) { $0 + $1.targetSets }
                        if total > 0 {
                            Text("\(done) / \(total) sets")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(done >= total ? .accentGreen : .secondaryText)
                        }
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(Color.cardBackground)
            .cornerRadius(session.isRest ? 10 : 0)
            .overlay(
                Group {
                    if session.isRest {
                        RoundedRectangle(cornerRadius: 10).stroke(Color.cellBorder, lineWidth: 1)
                    }
                }
            )

            if !session.isRest {
                Divider().background(Color.cellBorder)

                // Cardio guidance — interactive days only
                if session.icon == "figure.run" && !isPreview {
                    let mode  = store.intensityMode
                    let color = Color(hex: mode.colorHex)
                    HStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 11))
                            .foregroundColor(color)
                        Text(mode.cardioGuidance)
                            .font(.system(size: 11))
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(color.opacity(0.07))
                    Divider().background(Color.cellBorder)
                }

                if isPreview {
                    ForEach(session.exercises) { exercise in
                        PreviewExerciseRow(exercise: exercise)
                        if exercise.id != session.exercises.last?.id {
                            Divider().background(Color.cellBorder).padding(.leading, 12)
                        }
                    }
                } else {
                    ForEach(session.exercises) { exercise in
                        ExerciseCard(exercise: exercise, date: selectedDate)
                        if exercise.id != session.exercises.last?.id {
                            Divider().background(Color.cellBorder).padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .background(session.isRest ? Color.clear : Color.cardBackground)
        .cornerRadius(10)
        .overlay(
            Group {
                if !session.isRest {
                    RoundedRectangle(cornerRadius: 10).stroke(Color.cellBorder, lineWidth: 1)
                }
            }
        )
    }

    // MARK: - Locked card

    private var lockedCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundColor(.secondaryText)
            Text("Locked until 6:59 AM")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondaryText)
            Text("Workout tab opens with your morning session.")
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cellBorder, lineWidth: 1))
    }

    private static func minuteOfDay() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

// MARK: - PreviewExerciseRow
// Read-only row shown on upcoming (future) days. Displays exercise name, sets, reps,
// and estimated weight from the progression engine. No interactive set logging.

struct PreviewExerciseRow: View {
    let exercise: ExerciseDefinition
    @EnvironmentObject private var store: HabitStore

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryText.opacity(0.65))

                HStack(spacing: 4) {
                    Text("\(exercise.targetSets) sets · \(exercise.targetReps)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondaryText.opacity(0.7))

                    if exercise.isBodyweight {
                        Text("· bodyweight")
                            .font(.system(size: 11))
                            .foregroundColor(.secondaryText.opacity(0.5))
                    } else if let kg = store.suggestedWeight(for: exercise.id) {
                        Text("· \(formattedKg(kg)) kg est.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondaryText.opacity(0.7))
                    }
                }

                if !exercise.note.isEmpty {
                    Text(exercise.note)
                        .font(.system(size: 10))
                        .foregroundColor(.secondaryText.opacity(0.45))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Spacer()

            Image(systemName: "lock.circle")
                .font(.system(size: 18))
                .foregroundColor(.secondaryText.opacity(0.25))
                .padding(.trailing, 14)
        }
    }

    private func formattedKg(_ kg: Double) -> String {
        kg == kg.rounded() ? String(Int(kg)) : String(format: "%.1f", kg)
    }
}

// MARK: - ExerciseCard

struct ExerciseCard: View {
    let exercise: ExerciseDefinition
    let date: Date
    @EnvironmentObject private var store: HabitStore

    private var suggested: Double? { store.suggestedWeight(for: exercise.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primaryText)
                    let weightLabel: String = {
                        if exercise.isBodyweight { return "bodyweight" }
                        if let kg = suggested { return "\(formattedKg(kg)) kg suggested" }
                        return "bodyweight"
                    }()
                    Text("\(exercise.targetSets) sets · \(exercise.targetReps) · \(weightLabel)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondaryText)
                }
                Spacer()
                let done = store.workoutSetsForExercise(date: date, exerciseID: exercise.id).filter { $0.completed }.count
                Text("\(done)/\(exercise.targetSets)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(done >= exercise.targetSets ? .accentGreen : .secondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if !exercise.note.isEmpty {
                Text(exercise.note)
                    .font(.system(size: 10))
                    .foregroundColor(.secondaryText)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }

            Divider().background(Color.cellBorder)

            ForEach(1...exercise.targetSets, id: \.self) { setNum in
                SetRow(exercise: exercise, date: date, setNumber: setNum, suggestedKg: suggested)
                    .onChange(of: store.workoutSets) { _ in checkAndRecordCompletion() }
                if setNum < exercise.targetSets {
                    Divider().background(Color.cellBorder).padding(.leading, 14)
                }
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cellBorder, lineWidth: 1))
        .padding(.bottom, 8)
    }

    private func checkAndRecordCompletion() {
        guard !exercise.isBodyweight else { return }
        let sets = store.workoutSetsForExercise(date: date, exerciseID: exercise.id)
        let done = sets.filter { $0.completed }.count
        if done >= exercise.targetSets {
            store.recordExerciseCompletion(exerciseID: exercise.id,
                                           allSetsCompleted: true,
                                           dateKey: date.dateKey)
        }
    }

    private func formattedKg(_ kg: Double) -> String {
        kg == kg.rounded() ? String(Int(kg)) : String(format: "%.1f", kg)
    }
}

// MARK: - SetRow

struct SetRow: View {
    let exercise: ExerciseDefinition
    let date: Date
    let setNumber: Int
    let suggestedKg: Double?
    @EnvironmentObject private var store: HabitStore

    @State private var repsText: String = ""
    @State private var kgText: String   = ""
    @FocusState private var repsFocused: Bool
    @FocusState private var kgFocused: Bool

    private var existingSet: WorkoutSet? {
        store.workoutSetsForExercise(date: date, exerciseID: exercise.id).first { $0.setNumber == setNumber }
    }

    private var kgPlaceholder: String {
        if let kg = suggestedKg {
            return kg == kg.rounded() ? String(Int(kg)) : String(format: "%.1f", kg)
        }
        return "kg"
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("S\(setNumber)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondaryText)
                .frame(width: 24)
                .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text("REPS")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondaryText)
                TextField(exercise.targetReps, text: $repsText)
                    .keyboardType(.default)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.primaryText)
                    .focused($repsFocused)
                    .onChange(of: repsFocused) { focused in if !focused { save() } }
            }
            .frame(width: 52)
            .padding(7)
            .background(Color.cellBackground)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(repsFocused ? Color.accentBlue : Color.cellBorder, lineWidth: 1))

            if !exercise.isBodyweight {
                VStack(alignment: .leading, spacing: 2) {
                    Text("KG")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondaryText)
                    TextField(kgPlaceholder, text: $kgText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.primaryText)
                        .focused($kgFocused)
                        .onChange(of: kgFocused) { focused in if !focused { save() } }
                }
                .frame(width: 52)
                .padding(7)
                .background(Color.cellBackground)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(kgFocused ? Color.accentBlue : Color.cellBorder, lineWidth: 1))
            } else {
                Text("BW")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .frame(width: 66)
            }

            Spacer()

            Button(action: { toggleDone() }) {
                Image(systemName: existingSet?.completed == true ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(existingSet?.completed == true ? .accentGreen : .secondaryText)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
        }
        .padding(.vertical, 8)
        .onAppear { syncFromStore() }
        .onChange(of: date) { _ in syncFromStore() }
    }

    private func syncFromStore() {
        if let s = existingSet {
            repsText = s.actualReps
            kgText   = s.actualKg.map { String(format: "%.1f", $0) } ?? ""
        } else {
            repsText = ""
            kgText   = ""
        }
    }

    private func effectiveKg() -> Double? {
        if !kgText.isEmpty, let v = Double(kgText) { return v }
        return suggestedKg
    }

    private func save() {
        let reps = repsText.isEmpty ? exercise.targetReps : repsText
        let kg   = effectiveKg()
        let s = WorkoutSet(
            dateKey:    date.dateKey,
            exerciseID: exercise.id,
            setNumber:  setNumber,
            actualReps: reps,
            actualKg:   exercise.isBodyweight ? nil : kg,
            completed:  existingSet?.completed ?? false
        )
        store.upsertWorkoutSet(s)
    }

    private func toggleDone() {
        let reps = repsText.isEmpty ? exercise.targetReps : repsText
        let kg   = effectiveKg()
        let nowDone = !(existingSet?.completed ?? false)
        let s = WorkoutSet(
            dateKey:    date.dateKey,
            exerciseID: exercise.id,
            setNumber:  setNumber,
            actualReps: reps,
            actualKg:   exercise.isBodyweight ? nil : kg,
            completed:  nowDone
        )
        store.upsertWorkoutSet(s)
        if !nowDone {
            store.recordExerciseCompletion(exerciseID: exercise.id,
                                           allSetsCompleted: false,
                                           dateKey: date.dateKey)
        }
        syncFromStore()
    }
}
