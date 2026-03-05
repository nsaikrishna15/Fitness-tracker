import Foundation

// MARK: - Exercise Definition

struct ExerciseDefinition: Identifiable {
    let id: String
    let name: String
    let targetSets: Int
    let targetReps: String
    let targetKg: Double?       // nil = bodyweight / use progression engine
    let note: String
    let isBodyweight: Bool      // true = no weight input shown

    init(id: String, name: String, targetSets: Int, targetReps: String,
         targetKg: Double?, note: String, isBodyweight: Bool = false) {
        self.id = id
        self.name = name
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetKg = targetKg
        self.note = note
        self.isBodyweight = isBodyweight
    }
}

// MARK: - Program Phase
// 120-day program. All 4 phases maintain Mon/Tue/Thu/Sat gym, Wed/Fri cardio, Sun rest.
// What changes: sets (3→4), reps (12→8), exercise complexity, cardio intensity.

enum ProgramPhase: Int, CaseIterable {
    case phase1 = 1  // Days  1–30  — Foundation (3×12, light weights, learn movement)
    case phase2 = 2  // Days 31–60  — Volume     (4×10, heavier, add compound variety)
    case phase3 = 3  // Days 61–90  — Strength   (4×8, heavier, intensity techniques)
    case phase4 = 4  // Days 91–120 — Peak       (4×6-8, max loads, drop sets)

    var title: String {
        switch self {
        case .phase1: return "Phase 1 — Foundation"
        case .phase2: return "Phase 2 — Volume"
        case .phase3: return "Phase 3 — Strength"
        case .phase4: return "Phase 4 — Peak"
        }
    }

    var range: String {
        switch self {
        case .phase1: return "Days 1–30"
        case .phase2: return "Days 31–60"
        case .phase3: return "Days 61–90"
        case .phase4: return "Days 91–120"
        }
    }

    var description: String {
        switch self {
        case .phase1: return "3×12 on all lifts. Focus is form, not weight. Every rep controlled."
        case .phase2: return "4×10. Add weight weekly. Cardio builds to incline walk."
        case .phase3: return "4×8. Heavy compound work. Deload on week 8 of program."
        case .phase4: return "4×6–8. Max intensity. Drop sets on final set of each compound."
        }
    }

    // Sets and reps per phase for main compound lifts
    var gymSets: Int {
        switch self { case .phase1: return 3; case .phase2: return 4; case .phase3: return 4; case .phase4: return 4 }
    }
    var gymReps: String {
        switch self { case .phase1: return "12"; case .phase2: return "10"; case .phase3: return "8"; case .phase4: return "6–8" }
    }
    var isolationReps: String {
        switch self { case .phase1: return "15"; case .phase2: return "12"; case .phase3: return "10"; case .phase4: return "10–12" }
    }

    static func current(startDate: Date) -> ProgramPhase {
        let cal = Calendar(identifier: .iso8601)
        let day = cal.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        switch day {
        case 0..<30:  return .phase1
        case 30..<60: return .phase2
        case 60..<90: return .phase3
        default:      return .phase4
        }
    }
}

// MARK: - Day Session

struct DaySession {
    let morning: WorkoutSession
    let evening: WorkoutSession
}

struct WorkoutSession: Identifiable {
    let id: String
    let slot: String
    let label: String
    let icon: String
    let exercises: [ExerciseDefinition]
    let isRest: Bool

    static func rest(slot: String) -> WorkoutSession {
        WorkoutSession(id: "rest_\(slot.lowercased())", slot: slot,
                       label: "Rest", icon: "moon.zzz.fill", exercises: [], isRest: true)
    }
}

// MARK: - Workout Schedule
// Schedule is FIXED across all 120 days:
//   Mon → Upper A   Tue → Lower A   Wed → Cardio
//   Thu → Upper B   Fri → Cardio    Sat → Lower B   Sun → Rest
// Phase only affects sets/reps/notes — not which day you train.

struct WorkoutSchedule {

    static func session(for date: Date, programStart: Date) -> DaySession {
        let phase = ProgramPhase.current(startDate: programStart)
        let cal = Calendar(identifier: .iso8601)
        let iso = cal.component(.weekday, from: date)
        let dayIdx = (iso - 2 + 7) % 7   // 0=Mon … 6=Sun

        let morning: WorkoutSession
        let evening: WorkoutSession

        switch dayIdx {
        case 0: morning = upperA(phase: phase)
        case 1: morning = lowerA(phase: phase)
        case 2: morning = cardio(phase: phase, isWed: true)
        case 3: morning = upperB(phase: phase)
        case 4: morning = cardio(phase: phase, isWed: false)
        case 5: morning = lowerB(phase: phase)
        default: morning = .rest(slot: "Morning")
        }

        switch dayIdx {
        case 0, 1, 3, 5:   // Gym days — evening stretch + kegels
            evening = eveningGymDay()
        case 2, 4:          // Cardio days — rest evening
            evening = .rest(slot: "Evening")
        default:            // Sunday
            evening = .rest(slot: "Evening")
        }

        return DaySession(morning: morning, evening: evening)
    }

    // MARK: - Upper A (Monday)
    // Phase 1: 3×12 light — learn the movement pattern
    // Phase 2: 4×10 — add weight, cable row added
    // Phase 3: 4×8 — heavier, close-grip bench variant on last set
    // Phase 4: 4×6-8 — max weight, drop set on bench

    private static func upperA(phase: ProgramPhase) -> WorkoutSession {
        let s = phase.gymSets
        let r = phase.gymReps
        let _ = phase.isolationReps
        return WorkoutSession(
            id: "upper_a_p\(phase.rawValue)",
            slot: "Morning", label: "Upper A", icon: "dumbbell.fill",
            exercises: [
                ExerciseDefinition(id: "ua_bench",      name: "Bench Press",       targetSets: s, targetReps: r,
                    targetKg: nil, note: "Controlled descent, 2 sec down. Drive through chest, not shoulders.\(phase == .phase4 ? " Drop set on final set." : "")"),
                ExerciseDefinition(id: "ua_latpd",      name: "Lat Pulldown",      targetSets: s, targetReps: r,
                    targetKg: nil, note: "Wide grip. Chest up. Pull to collarbone level. Full stretch at top."),
                ExerciseDefinition(id: "ua_dbshoulder", name: "DB Shoulder Press", targetSets: s, targetReps: r,
                    targetKg: nil, note: "Seated. Core braced. Stop just short of lockout at top."),
                ExerciseDefinition(id: "ua_row",        name: "Cable Row",         targetSets: s, targetReps: r,
                    targetKg: nil, note: "Sit tall. Pull to lower chest. Squeeze shoulder blades 1 sec."),
                ExerciseDefinition(id: "ua_plank",      name: "Plank",             targetSets: 3, targetReps: phasePhank(phase),
                    targetKg: nil, note: "Forearms + toes. Hips level. Breathe. \(phase == .phase1 ? "30 sec target." : phase == .phase2 ? "45 sec target." : "60 sec target.")", isBodyweight: true),
            ],
            isRest: false
        )
    }

    // MARK: - Upper B (Thursday)

    private static func upperB(phase: ProgramPhase) -> WorkoutSession {
        let s = phase.gymSets
        let r = phase.gymReps
        let iso = phase.isolationReps
        return WorkoutSession(
            id: "upper_b_p\(phase.rawValue)",
            slot: "Morning", label: "Upper B", icon: "dumbbell.fill",
            exercises: [
                ExerciseDefinition(id: "ub_incline",  name: "Incline DB Press",  targetSets: s, targetReps: r,
                    targetKg: nil, note: "30–45° incline. Elbows at 60°, not flared wide. Full range."),
                ExerciseDefinition(id: "ub_latpd",    name: "Lat Pulldown",      targetSets: s, targetReps: r,
                    targetKg: nil, note: "Neutral or close grip on Thursday. Different stimulus to Monday."),
                ExerciseDefinition(id: "ub_lateral",  name: "Lateral Raise",     targetSets: 3, targetReps: iso,
                    targetKg: nil, note: "Slight bend in elbow. Lead with elbows. Stop at shoulder height."),
                ExerciseDefinition(id: "ub_facepull", name: "Face Pull",         targetSets: 3, targetReps: iso,
                    targetKg: nil, note: "Cable at eye level. Pull to forehead, elbows flared. Externally rotate."),
                ExerciseDefinition(id: "ub_curl",     name: "DB Bicep Curl",     targetSets: 3, targetReps: iso,
                    targetKg: nil, note: "Full range. Supinate at top. No swinging — brace your back."),
            ],
            isRest: false
        )
    }

    // MARK: - Lower A (Tuesday)

    private static func lowerA(phase: ProgramPhase) -> WorkoutSession {
        let s = phase.gymSets
        let r = phase.gymReps
        let iso = phase.isolationReps
        return WorkoutSession(
            id: "lower_a_p\(phase.rawValue)",
            slot: "Morning", label: "Lower A", icon: "figure.strengthtraining.traditional",
            exercises: [
                ExerciseDefinition(id: "la_legpress",  name: "Leg Press",           targetSets: s, targetReps: r,
                    targetKg: nil, note: "Feet shoulder-width, mid-platform. Full depth. Don't lock out at top."),
                ExerciseDefinition(id: "la_goblet",    name: "Goblet Squat",        targetSets: s, targetReps: r,
                    targetKg: nil, note: phase == .phase1 ? "Hold DB at chest. Week 1–2: BW only to learn depth." : "Hold DB at chest. Heels on floor. Break parallel.",
                    isBodyweight: phase == .phase1),
                ExerciseDefinition(id: "la_hamcurl",   name: "Hamstring Curl",      targetSets: s, targetReps: r,
                    targetKg: nil, note: "Lying or seated. Slow negative — 3 seconds lowering. Full range."),
                ExerciseDefinition(id: "la_calf",      name: "Calf Raise",          targetSets: 3, targetReps: iso,
                    targetKg: nil, note: "Full stretch at bottom every rep. Pause 1 sec at top. Can use leg press platform.", isBodyweight: true),
                ExerciseDefinition(id: "la_abs",       name: "Hanging Knee Raise",  targetSets: 3, targetReps: "12",
                    targetKg: nil, note: "Controlled. No swinging. Or lying leg raise if no bar.", isBodyweight: true),
            ],
            isRest: false
        )
    }

    // MARK: - Lower B (Saturday)

    private static func lowerB(phase: ProgramPhase) -> WorkoutSession {
        let s = phase.gymSets
        let r = phase.gymReps
        let iso = phase.isolationReps
        return WorkoutSession(
            id: "lower_b_p\(phase.rawValue)",
            slot: "Morning", label: "Lower B", icon: "figure.strengthtraining.traditional",
            exercises: [
                ExerciseDefinition(id: "lb_legpress",  name: "Leg Press",           targetSets: s, targetReps: r,
                    targetKg: nil, note: "Narrow stance (inner quads) on Saturdays vs shoulder-width Tuesday."),
                ExerciseDefinition(id: "lb_rdl",       name: "Romanian Deadlift",   targetSets: s, targetReps: r,
                    targetKg: nil, note: "DBs close to legs. Hinge at hips, soft knee. Feel hamstrings stretch. Keep back flat."),
                ExerciseDefinition(id: "lb_legext",    name: "Leg Extension",       targetSets: 3, targetReps: iso,
                    targetKg: nil, note: "Squeeze quad at top, 1 sec hold. Slow down. Don't use momentum."),
                ExerciseDefinition(id: "lb_hipthrust", name: "Hip Thrust",          targetSets: 3, targetReps: iso,
                    targetKg: nil, note: "Back on bench, DB on hips. Drive through heels. Squeeze glutes hard at top."),
                ExerciseDefinition(id: "lb_abs",       name: "Abs (Crunch / Plank)",targetSets: 3, targetReps: "12",
                    targetKg: nil, note: "Choice: crunches, ab wheel, or plank. Rotate weekly.", isBodyweight: true),
            ],
            isRest: false
        )
    }

    // MARK: - Cardio (Wednesday / Friday)
    // Builds progressively: Phase 1 = walk, Phase 2 = incline walk, Phase 3/4 = intervals

    private static func cardio(phase: ProgramPhase, isWed: Bool) -> WorkoutSession {
        let (label, detail, duration, note): (String, String, String, String) = {
            switch phase {
            case .phase1:
                return ("Walk 30 min", "Brisk Walk", "30 min",
                        "Outdoor or treadmill. Conversational pace — slightly breathless but can talk. This is your active recovery.")
            case .phase2:
                return ("Incline Walk 35 min", "Incline Walk", "35 min",
                        "Treadmill: 5–8% incline, 5.5–6 km/h. Or hilly outdoor route. Gets harder without feeling like running.")
            case .phase3:
                return isWed ? ("Intervals 25 min", "Walk/Jog Intervals", "25 min",
                                "5 min warm-up walk → 10 rounds: 1 min jog + 1 min walk → 5 min cool-down walk.")
                             : ("Incline Walk 40 min", "Incline Walk", "40 min",
                                "Treadmill: 8–10% incline, 6 km/h. Or 40-min brisk walk with hills.")
            case .phase4:
                return ("Intervals 30 min", "HIIT Walk/Run", "30 min",
                        "5 min walk → 8 rounds: 90 sec run + 60 sec walk → 5 min cool-down. Build to steady 20-min jog by end.")
            }
        }()
        return WorkoutSession(
            id: "cardio_p\(phase.rawValue)_\(isWed ? "wed" : "fri")",
            slot: "Morning", label: label, icon: "figure.run",
            exercises: [
                ExerciseDefinition(id: "walk_main", name: detail, targetSets: 1,
                    targetReps: duration, targetKg: nil, note: note, isBodyweight: true),
            ],
            isRest: false
        )
    }

    // MARK: - Evening (all gym days)

    private static func eveningGymDay() -> WorkoutSession {
        WorkoutSession(
            id: "eve_stretch",
            slot: "Evening", label: "Stretch + Kegels", icon: "figure.flexibility",
            exercises: [
                ExerciseDefinition(id: "eve_stretch", name: "Full Body Stretch", targetSets: 1, targetReps: "10 min",
                    targetKg: nil, note: "Hip flexors, hamstrings, chest, lats, shoulders. Hold each 30–40 sec.", isBodyweight: true),
                ExerciseDefinition(id: "eve_kegels",  name: "Kegel Holds",       targetSets: 3, targetReps: "20",
                    targetKg: nil, note: "Contract 5 sec, release 5 sec. Builds pelvic floor strength and sensitivity.", isBodyweight: true),
            ],
            isRest: false
        )
    }

    // MARK: - Helpers

    private static func phasePhank(_ phase: ProgramPhase) -> String {
        switch phase { case .phase1: return "30s"; case .phase2: return "45s"; case .phase3: return "60s"; case .phase4: return "60s" }
    }
}

// MARK: - Legacy WorkoutType (kept for HabitStore sync compatibility)

enum WorkoutType {
    case upperA, lowerA, upperB, lowerB, walk, rest

    var icon: String {
        switch self {
        case .upperA, .upperB: return "dumbbell.fill"
        case .lowerA, .lowerB: return "figure.strengthtraining.traditional"
        case .walk:            return "figure.run"
        case .rest:            return "moon.zzz.fill"
        }
    }

    static var allExercises: [ExerciseDefinition] {
        // Use the public session() API to enumerate all exercises
        let cal = Calendar(identifier: .iso8601)
        // Pick one Monday, Tuesday, Wednesday, Thursday, Friday, Saturday as representative dates
        let monday    = cal.date(from: DateComponents(weekday: 2, weekOfYear: 1, yearForWeekOfYear: 2024))!
        let tuesday   = cal.date(byAdding: .day, value: 1, to: monday)!
        let wednesday = cal.date(byAdding: .day, value: 2, to: monday)!
        let thursday  = cal.date(byAdding: .day, value: 3, to: monday)!
        let friday    = cal.date(byAdding: .day, value: 4, to: monday)!
        let saturday  = cal.date(byAdding: .day, value: 5, to: monday)!
        let start = monday // phase 1
        return [monday, tuesday, wednesday, thursday, friday, saturday].flatMap { day in
            let s = WorkoutSchedule.session(for: day, programStart: start)
            return s.morning.exercises + s.evening.exercises
        }
    }
}

// MARK: - Logged Set

struct WorkoutSet: Codable, Identifiable, Equatable {
    var id: String { "\(dateKey)_\(exerciseID)_\(setNumber)" }
    let dateKey: String
    let exerciseID: String
    let setNumber: Int
    var actualReps: String
    var actualKg: Double?
    var completed: Bool
}
