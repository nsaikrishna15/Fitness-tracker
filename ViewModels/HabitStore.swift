import Foundation
import Combine

@MainActor
final class HabitStore: ObservableObject {

    // MARK: - Published State

    @Published var currentWeekStart: Date
    @Published private(set) var entries: [HabitEntry] = [] {
        didSet { rebuildCache() }
    }
    @Published private(set) var weightEntries: [WeightEntry] = []
    @Published private(set) var workoutSets: [WorkoutSet] = []

    private let persistence = PersistenceManager.shared

    // O(1) lookup: [dateKey: Set<HabitID>] — rebuilt whenever entries change.
    // Avoids scanning the full array on every isCompleted() call.
    private var completedCache: [String: Set<HabitID>] = [:]

    // Injected calendar — defaults to ISO 8601 for week calculations.
    // Can be overridden in unit tests without touching global state.
    let calendar: Calendar

    // MARK: - Init

    init(calendar: Calendar = Calendar(identifier: .iso8601)) {
        self.calendar           = calendar
        self.weighInDay         = UserDefaults.standard.object(forKey: "weighInDay") as? Int ?? 0
        self.heightCm           = UserDefaults.standard.double(forKey: "heightCm")   // 0 if not set
        let savedAge            = UserDefaults.standard.integer(forKey: "age")
        self.age                = savedAge > 0 ? savedAge : 25
        self.isMale             = UserDefaults.standard.object(forKey: "isMale") as? Bool ?? true
        self.targetBodyFatPct   = UserDefaults.standard.double(forKey: "targetBodyFatPct") == 0
                                    ? 12.0
                                    : UserDefaults.standard.double(forKey: "targetBodyFatPct")
        self.preferredProtein   = UserDefaults.standard.string(forKey: "preferredProtein") ?? "chicken"
        self.onboardingDone     = UserDefaults.standard.bool(forKey: "onboardingDone")
        let savedStart = UserDefaults.standard.double(forKey: "programStartDate")
        self.programStartDate   = savedStart > 0
            ? Date(timeIntervalSince1970: savedStart)
            : Calendar(identifier: .iso8601).startOfDay(for: Date())
        currentWeekStart = Date().startOfWeek()
        entries       = persistence.loadHabitEntries()
        weightEntries = persistence.loadWeightEntries()
        workoutSets   = persistence.loadWorkoutSets()

        // Reload when iCloud pushes changes from another device
        NotificationCenter.default.addObserver(
            forName: PersistenceManager.remoteChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.entries       = self.persistence.loadHabitEntries()
                self.weightEntries = self.persistence.loadWeightEntries()
                self.workoutSets   = self.persistence.loadWorkoutSets()
            }
        }
    }

    // MARK: - Cache

    private func rebuildCache() {
        var cache: [String: Set<HabitID>] = [:]
        for entry in entries where entry.isCompleted {
            cache[entry.dateKey, default: []].insert(entry.habitID)
        }
        completedCache = cache
    }

    // MARK: - Week Navigation

    func goToPreviousWeek() {
        currentWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) ?? currentWeekStart
    }

    func goToNextWeek() {
        currentWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? currentWeekStart
    }

    func goToCurrentWeek() {
        currentWeekStart = Date().startOfWeek()
    }

    // MARK: - Habit CRUD

    /// O(1) lookup via cache dictionary.
    func isCompleted(habit: HabitID, on date: Date) -> Bool {
        completedCache[date.dateKey]?.contains(habit) ?? false
    }

    func toggle(habit: HabitID, on date: Date) {
        let key = date.dateKey
        var newCompleted: Bool
        if let idx = entries.firstIndex(where: { $0.habitID == habit && $0.dateKey == key }) {
            entries[idx].isCompleted.toggle()
            newCompleted = entries[idx].isCompleted
        } else {
            entries.append(HabitEntry(habitID: habit, dateKey: key, isCompleted: true))
            newCompleted = true
        }
        persistence.saveHabitEntries(entries)
        // Keep workout sets in sync when a workout habit is ticked/unticked
        syncWorkoutSets(habitID: habit, dateKey: key, completed: newCompleted)
    }

    // MARK: - User Profile (persisted in UserDefaults)

    @Published var heightCm: Double {
        didSet { UserDefaults.standard.set(heightCm, forKey: "heightCm") }
    }
    @Published var age: Int {
        didSet { UserDefaults.standard.set(age, forKey: "age") }
    }
    @Published var isMale: Bool {
        didSet { UserDefaults.standard.set(isMale, forKey: "isMale") }
    }
    @Published var targetBodyFatPct: Double {
        didSet { UserDefaults.standard.set(targetBodyFatPct, forKey: "targetBodyFatPct") }
    }
    @Published var preferredProtein: String {
        didSet { UserDefaults.standard.set(preferredProtein, forKey: "preferredProtein") }
    }
    @Published var onboardingDone: Bool {
        didSet { UserDefaults.standard.set(onboardingDone, forKey: "onboardingDone") }
    }

    /// Day the user first launched / completed onboarding — determines program phase.
    /// Defaults to today if not yet set (set during onboarding save).
    @Published var programStartDate: Date {
        didSet {
            UserDefaults.standard.set(programStartDate.timeIntervalSince1970, forKey: "programStartDate")
        }
    }

    /// Most recent logged weight (kg), or nil if none.
    var latestWeight: Double? {
        weightEntries.filter { $0.weightKg != nil }.sorted { $0.dateKey > $1.dateKey }.first?.weightKg ?? nil
    }

    /// BMR using Mifflin-St Jeor formula. Nil if height or age not yet set.
    var bmrValue: Double? {
        guard let kg = latestWeight, heightCm > 0, age > 0 else { return nil }
        return DietPlan.bmr(weightKg: kg, heightCm: heightCm, age: age, isMale: isMale)
    }

    /// TDEE = BMR × phase activity multiplier.
    var tdeeValue: Double? {
        guard let b = bmrValue else { return nil }
        return DietPlan.tdee(bmr: b, programStartDate: programStartDate)
    }

    /// Target daily calories = TDEE − intensityMode.calorieDeficit, floored at 1500 (male) / 1200 (female).
    var targetKcal: Int {
        let deficit = intensityMode.calorieDeficit
        guard let t = tdeeValue else { return DietPlan.targetKcal(tdee: 2500, isMale: isMale, deficit: deficit) }
        return DietPlan.targetKcal(tdee: t, isMale: isMale, deficit: deficit)
    }

    /// Daily protein target — 2.2 g/kg LEAN BODY MASS.
    /// LBM is used instead of total bodyweight to prevent inflated protein for overweight users.
    /// Falls back to total weight when body composition cannot be estimated (no height/age).
    var dailyProteinG: Int { DietPlan.proteinGrams(weightKg: latestWeight ?? 80, leanMassKg: leanBodyMassKg) }

    /// Daily fat target — max(25% kcal, 0.5 g/kg total weight) — ACSM minimum for hormonal health.
    var dailyFatG: Int { DietPlan.fatGrams(targetKcal: targetKcal, weightKg: latestWeight ?? 80) }

    /// Daily carbs target — fills remaining calories.
    var dailyCarbsG: Int { DietPlan.carbGrams(targetKcal: targetKcal, proteinG: dailyProteinG, fatG: dailyFatG) }

    /// Daily calories — same as targetKcal, exposed for external use.
    var dailyCalories: Int { targetKcal }

    /// BMI using latest weight and stored height.
    var bmiValue: Double? {
        guard let kg = latestWeight, heightCm > 0 else { return nil }
        let m = heightCm / 100
        return kg / (m * m)
    }

    /// Estimated current body fat % via Deurenberg BMI-based formula.
    var estimatedBodyFatPct: Double? {
        guard let kg = latestWeight, heightCm > 0, age > 0 else { return nil }
        return DietPlan.estimatedBodyFatPct(weightKg: kg, heightCm: heightCm, age: age, isMale: isMale)
    }

    /// Lean Body Mass = total weight × (1 − BF%). Used for protein calculation.
    var leanBodyMassKg: Double? {
        guard let kg = latestWeight, let bf = estimatedBodyFatPct else { return nil }
        return kg * (1.0 - bf / 100.0)
    }

    /// Target body weight at user's goal body fat percentage.
    /// target_weight = LBM ÷ (1 − targetBF%). Accounts for individual muscle mass —
    /// far more accurate than any BMI-based target for physique goals.
    var bodyFatTargetWeightKg: Double? {
        guard let lbm = leanBodyMassKg else { return nil }
        return DietPlan.targetWeightFromBF(leanMassKg: lbm, targetBFpct: targetBodyFatPct)
    }

    /// BMI the user will have at their goal weight (informational — shown alongside target weight).
    var bmiAtTargetWeight: Double? {
        guard let target = bodyFatTargetWeightKg, heightCm > 0 else { return nil }
        return DietPlan.bmi(weightKg: target, heightCm: heightCm)
    }

    /// Estimated weeks to reach goal weight at the current calorie deficit.
    var weeksToTargetWeight: Int? {
        guard let kg = latestWeight, let target = bodyFatTargetWeightKg else { return nil }
        return DietPlan.weeksToTarget(currentKg: kg, targetKg: target, dailyDeficitKcal: intensityMode.calorieDeficit)
    }

    /// Difference between estimated current BF% and the user's target.
    var fatGapPct: Double? {
        guard let current = estimatedBodyFatPct else { return nil }
        return current - targetBodyFatPct
    }

    /// Current training intensity mode — drives calorie deficit and cardio guidance.
    var intensityMode: IntensityMode {
        guard let current = estimatedBodyFatPct else { return .standardCut }
        return DietPlan.intensityMode(currentBF: current, targetBF: targetBodyFatPct)
    }


    @Published var weighInDay: Int {
        didSet { UserDefaults.standard.set(weighInDay, forKey: "weighInDay") }
    }

    func weight(on date: Date) -> Double? {
        weightEntries.first { $0.dateKey == date.dateKey }?.weightKg ?? nil
    }

    func setWeight(_ kg: Double?, on date: Date) {
        let key = date.dateKey
        if let idx = weightEntries.firstIndex(where: { $0.dateKey == key }) {
            let old = weightEntries[idx].weightKg
            // Only record a correction if the value actually changed and wasn't nil→value
            if let old, old != kg {
                weightEntries[idx].previousKg   = old
                weightEntries[idx].lastEditedAt = Date()
            }
            weightEntries[idx].weightKg = kg
        } else {
            weightEntries.append(WeightEntry(dateKey: key, weightKg: kg))
        }
        persistence.saveWeightEntries(weightEntries)
    }

    func weightEntry(on date: Date) -> WeightEntry? {
        weightEntries.first { $0.dateKey == date.dateKey }
    }

    // MARK: - Workout Sets

    func workoutSetsForExercise(date: Date, exerciseID: String) -> [WorkoutSet] {
        let key = date.dateKey
        return workoutSets
            .filter { $0.dateKey == key && $0.exerciseID == exerciseID }
            .sorted { $0.setNumber < $1.setNumber }
    }

    func upsertWorkoutSet(_ set: WorkoutSet) {
        if let idx = workoutSets.firstIndex(where: {
            $0.dateKey    == set.dateKey &&
            $0.exerciseID == set.exerciseID &&
            $0.setNumber  == set.setNumber
        }) {
            workoutSets[idx] = set
        } else {
            workoutSets.append(set)
        }
        persistence.saveWorkoutSets(workoutSets)
        syncWorkoutHabit(dateKey: set.dateKey)
    }

    // MARK: - Workout ↔ Habit sync

    /// Maps a workout HabitID to the exercises that represent it.
    /// IDs match WorkoutModels.swift exercise IDs exactly.
    private static let workoutHabitExercises: [HabitID: [String]] = [
        .gymUpperA:      ["ua_bench", "ua_latpd", "ua_dbshoulder", "ua_row", "ua_tricep", "ua_plank"],
        .gymLowerA:      ["la_legpress", "la_goblet", "la_hamcurl", "la_lunge", "la_abs"],
        .gymUpperB:      ["ub_incline", "ub_latpd", "ub_lateral", "ub_facepull", "ub_curl"],
        .gymLowerB:      ["lb_legpress", "lb_rdl", "lb_legext", "lb_hipthrust", "lb_kbswing"],
        .walk:           ["walk_main"],
        .eveningWorkout: ["eve_foam", "eve_stretch", "eve_core", "eve_kegels"],
    ]

    /// After any set change, check if all sets for the day's workout are done
    /// and update the matching habit entry to match.
    private func syncWorkoutHabit(dateKey: String) {
        for (habitID, exerciseIDs) in Self.workoutHabitExercises {
            // Only sync if this habit is active on the day represented by dateKey
            guard let date = SharedDateFormatter.dateKey.date(from: dateKey) else { continue }
            let cal = Calendar(identifier: .iso8601)
            let iso = cal.component(.weekday, from: date)
            let dayIdx = (iso - 2 + 7) % 7
            if let mask = HabitDefinition.all.first(where: { $0.id == habitID })?.activeDays,
               !mask.contains(dayIdx) { continue }

            // Find all expected sets across all exercises for this habit
            let allSets = workoutSets.filter { $0.dateKey == dateKey && exerciseIDs.contains($0.exerciseID) }
            let totalExpected = exerciseIDs.compactMap { exID in
                WorkoutType.allExercises.first { $0.id == exID }?.targetSets
            }.reduce(0, +)
            let allDone = totalExpected > 0 && allSets.filter { $0.completed }.count >= totalExpected

            // Update the habit entry to match
            if let idx = entries.firstIndex(where: { $0.habitID == habitID && $0.dateKey == dateKey }) {
                if entries[idx].isCompleted != allDone {
                    entries[idx].isCompleted = allDone
                    persistence.saveHabitEntries(entries)
                }
            } else if allDone {
                entries.append(HabitEntry(habitID: habitID, dateKey: dateKey, isCompleted: true))
                persistence.saveHabitEntries(entries)
            }
        }
    }

    /// When a workout habit is toggled manually on the Habits tab,
    /// mark all its workout sets as done (or uncompleted) to match.
    private func syncWorkoutSets(habitID: HabitID, dateKey: String, completed: Bool) {
        guard let exerciseIDs = Self.workoutHabitExercises[habitID] else { return }
        for exID in exerciseIDs {
            guard let def = WorkoutType.allExercises.first(where: { $0.id == exID }) else { continue }
            for setNum in 1...def.targetSets {
                let existing = workoutSets.first {
                    $0.dateKey == dateKey && $0.exerciseID == exID && $0.setNumber == setNum
                }
                let updated = WorkoutSet(
                    dateKey:    dateKey,
                    exerciseID: exID,
                    setNumber:  setNum,
                    actualReps: existing?.actualReps ?? def.targetReps,
                    actualKg:   existing?.actualKg ?? def.targetKg,
                    completed:  completed
                )
                if let idx = workoutSets.firstIndex(where: {
                    $0.dateKey == dateKey && $0.exerciseID == exID && $0.setNumber == setNum
                }) {
                    workoutSets[idx] = updated
                } else {
                    workoutSets.append(updated)
                }
            }
        }
        persistence.saveWorkoutSets(workoutSets)
    }

    func allWorkoutSets(for date: Date) -> [WorkoutSet] {
        workoutSets.filter { $0.dateKey == date.dateKey }
    }

    /// Removes all workout sets for a date (used to clear stale data on locked days).
    func clearWorkoutSets(for date: Date) {
        let key = date.dateKey
        let before = workoutSets.count
        workoutSets.removeAll { $0.dateKey == key }
        if workoutSets.count != before {
            persistence.saveWorkoutSets(workoutSets)
            syncWorkoutHabit(dateKey: key)
        }
    }

    // MARK: - Progression Engine

    /// Persisted exercise progression records. Key = exerciseID.
    private(set) var exerciseProgressions: [String: ExerciseProgress] = {
        guard let data = UserDefaults.standard.data(forKey: "exerciseProgressions_v1"),
              let decoded = try? JSONDecoder().decode([String: ExerciseProgress].self, from: data)
        else { return [:] }
        return decoded
    }()

    private func saveProgressions() {
        if let data = try? JSONEncoder().encode(exerciseProgressions) {
            UserDefaults.standard.set(data, forKey: "exerciseProgressions_v1")
        }
    }

    /// Returns the suggested weight for an exercise today.
    /// - Uses stored progression if available.
    /// - Falls back to bodyweight-scaled starting weight from ProgressionEngine.
    /// - Returns nil for bodyweight exercises.
    func suggestedWeight(for exerciseID: String) -> Double? {
        if let record = exerciseProgressions[exerciseID] {
            return record.currentKg
        }
        // First time seeing this exercise — use starting weight scaled to user's body weight
        let bw = latestWeight ?? 90.0
        return ProgressionEngine.startingWeight(exerciseID: exerciseID, bodyweightKg: bw)
    }

    /// Call after completing all sets for an exercise on a given date.
    /// allSetsCompleted: true if every set was logged and marked done.
    func recordExerciseCompletion(exerciseID: String, allSetsCompleted: Bool, dateKey: String) {
        let bw = latestWeight ?? 90.0
        var record = exerciseProgressions[exerciseID] ?? ExerciseProgress(
            exerciseID:   exerciseID,
            currentKg:    ProgressionEngine.startingWeight(exerciseID: exerciseID, bodyweightKg: bw),
            failCount:    0,
            sessionsDone: 0,
            isDeloaded:   false
        )
        ProgressionEngine.update(
            record:            &record,
            allSetsCompleted:  allSetsCompleted,
            isDeloadWeek:      programDayStore.isDeloadWeek
        )
        exerciseProgressions[exerciseID] = record
        saveProgressions()

        // Mark this calendar day as an active workout day
        programDayStore.markDone(dateKey: dateKey)
        saveProgramDayStore()
    }

    // MARK: - Program Day Store (tracks which calendar days had real workout activity)

    private(set) var programDayStore: ProgramDayStore = {
        guard let data = UserDefaults.standard.data(forKey: "programDayStore_v1"),
              let decoded = try? JSONDecoder().decode(ProgramDayStore.self, from: data)
        else { return ProgramDayStore() }
        return decoded
    }()

    private func saveProgramDayStore() {
        if let data = try? JSONEncoder().encode(programDayStore) {
            UserDefaults.standard.set(data, forKey: "programDayStore_v1")
        }
    }

    /// Program day number (1–120) based on actual workout days logged, not calendar days.
    /// This means skipping a day does NOT advance the counter.
    var activeProgramDay: Int { programDayStore.programDay }

    /// True during deload week (program days 50–56).
    var isDeloadWeek: Bool { programDayStore.isDeloadWeek }

    // MARK: - Computed

    /// % of applicable habit-day cells completed in currentWeek.
    var currentWeekCompletionPct: Double {
        let days = currentWeekStart.weekDays()
        var total = 0.0
        var done  = 0.0
        for habit in HabitDefinition.all {
            for (idx, day) in days.enumerated() {
                if let mask = habit.activeDays { guard mask.contains(idx) else { continue } }
                total += 1
                if isCompleted(habit: habit.id, on: day) { done += 1 }
            }
        }
        guard total > 0 else { return 0 }
        return (done / total) * 100
    }

    /// Last 12 weeks of non-nil weight data, sorted ascending.
    /// If weighInDay != 0, only returns entries on that ISO weekday.
    var chartWeightData: [WeightEntry] {
        let cutoff = calendar.date(byAdding: .weekOfYear, value: -12, to: Date()) ?? Date()
        return weightEntries
            .filter { $0.weightKg != nil }
            .filter { $0.date >= cutoff }
            .filter {
                guard weighInDay != 0 else { return true }
                let iso = calendar.component(.weekday, from: $0.date)
                // Calendar.iso8601 weekday: 2=Mon…8=Sun → convert to 1-based Mon=1
                let isoMon = (iso - 2 + 7) % 7 + 1
                return isoMon == weighInDay
            }
            .sorted { $0.dateKey < $1.dateKey }
    }

    /// All non-nil weight entries sorted descending (for history list).
    var allWeightHistory: [WeightEntry] {
        weightEntries
            .filter { $0.weightKg != nil }
            .sorted { $0.dateKey > $1.dateKey }
    }
}
