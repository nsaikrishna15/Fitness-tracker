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

    // MARK: - Upper A (Monday) — Chest · Back · Shoulders · Triceps
    // Equipment: Adjustable bench + dumbbells (DB bench press),
    //            Hoist Dual Cable (lat pulldown + cable row + tricep pushdown),
    //            Dumbbells (shoulder press). Bodyweight: plank.
    // Goal: compound push + pull strength, upper body mass, posture.

    private static func upperA(phase: ProgramPhase) -> WorkoutSession {
        let s = phase.gymSets
        let r = phase.gymReps
        let iso = phase.isolationReps
        return WorkoutSession(
            id: "upper_a_p\(phase.rawValue)",
            slot: "Morning", label: "Upper A", icon: "dumbbell.fill",
            exercises: [
                ExerciseDefinition(id: "ua_bench",      name: "DB Bench Press",          targetSets: s, targetReps: r,
                    targetKg: nil, note: "Flat bench + dumbbells. 2 sec down, brief pause at chest, drive up. Elbows at 45–60° — not flared wide.\(phase == .phase4 ? " Drop set on final set — reduce 20% weight, max reps." : "")"),
                ExerciseDefinition(id: "ua_latpd",      name: "Cable Lat Pulldown",      targetSets: s, targetReps: r,
                    targetKg: nil, note: "Hoist cable — high pulley, wide overhand grip. Chest tall, pull bar to collarbone. Full stretch at top on every rep. Primary back width builder."),
                ExerciseDefinition(id: "ua_dbshoulder", name: "Seated DB Shoulder Press",targetSets: s, targetReps: r,
                    targetKg: nil, note: "Sit on bench (upright). Core braced. Press to just short of lockout — keep tension. Lower controlled 2 sec. Drives testosterone + shoulder strength."),
                ExerciseDefinition(id: "ua_row",        name: "Cable Row",               targetSets: s, targetReps: r,
                    targetKg: nil, note: "Hoist cable — low pulley, handle or V-bar. Sit upright. Pull to lower chest — squeeze shoulder blades together for 1 sec. Don't lean back or use momentum."),
                ExerciseDefinition(id: "ua_tricep",     name: "Cable Tricep Pushdown",   targetSets: 3, targetReps: iso,
                    targetKg: nil, note: "Hoist cable — high pulley. Keep elbows pinned tight to sides throughout. Push to full extension, slow 2-sec return. Adds arm size and fills out shirt sleeves."),
                ExerciseDefinition(id: "ua_plank",      name: "Plank",                   targetSets: 3, targetReps: phasePhank(phase),
                    targetKg: nil, note: "Forearms + toes. Hips level — not sagging, not raised. Breathe steadily. \(phase == .phase1 ? "30 sec build — add 5 sec each week." : phase == .phase2 ? "45 sec target." : "60 sec target — brace abs like you're about to be punched.")", isBodyweight: true),
            ],
            isRest: false
        )
    }

    // MARK: - Upper B (Thursday) — Incline Chest · Lats · Arms · Rear Delt
    // Equipment: Adjustable bench (30°) + dumbbells, Hoist Dual Cable (pulldown + face pull + optional curl).
    // Goal: upper chest detail, bicep/tricep size, rotator cuff health (face pull), arm aesthetics.

    private static func upperB(phase: ProgramPhase) -> WorkoutSession {
        let s = phase.gymSets
        let r = phase.gymReps
        let iso = phase.isolationReps
        return WorkoutSession(
            id: "upper_b_p\(phase.rawValue)",
            slot: "Morning", label: "Upper B", icon: "dumbbell.fill",
            exercises: [
                ExerciseDefinition(id: "ub_incline",  name: "Incline DB Press",     targetSets: s, targetReps: r,
                    targetKg: nil, note: "Bench at 30°. Elbows at 60°, not flared. Targets upper chest + front delt. Full range — touch chest at bottom, stop before lockout at top."),
                ExerciseDefinition(id: "ub_latpd",    name: "Cable Lat Pulldown",   targetSets: s, targetReps: r,
                    targetKg: nil, note: "Hoist cable — narrow or neutral grip today. Different stimulus to Monday's wide grip. Pull to upper chest, hold the squeeze 1 sec."),
                ExerciseDefinition(id: "ub_lateral",  name: "DB Lateral Raise",     targetSets: 3, targetReps: iso,
                    targetKg: nil, note: "Slight elbow bend. Lead with elbows, stop at shoulder height. Pause 1 sec at top. No momentum — pure lateral delt. Builds shoulder width."),
                ExerciseDefinition(id: "ub_facepull", name: "Cable Face Pull",      targetSets: 3, targetReps: iso,
                    targetKg: nil, note: "Hoist cable at eye level — use rope or handles. Pull to forehead, elbows flared high. Externally rotate at end. Critical for posture, shoulder health, and rotator cuff longevity."),
                ExerciseDefinition(id: "ub_curl",     name: "DB Bicep Curl",        targetSets: 3, targetReps: iso,
                    targetKg: nil, note: "Full range — supinate (twist) at top, full stretch at bottom. Alternate arms or simultaneous. No swinging. Consistency here adds visible arm size in 8 weeks."),
            ],
            isRest: false
        )
    }

    // MARK: - Lower A (Tuesday) — Quad Dominant · Unilateral · Core
    // Equipment: Hoist Leg Press, Hoist Hamstring Curl machine, dumbbells/kettlebells (goblet + lunge),
    //            pull-up bar on Hoist cable (hanging knee raise). Bodyweight: lunge phase 1, knee raise.
    // Goal: quad strength + size, single-leg stability, core, knee health.

    private static func lowerA(phase: ProgramPhase) -> WorkoutSession {
        let s = phase.gymSets
        let r = phase.gymReps
        let iso = phase.isolationReps
        return WorkoutSession(
            id: "lower_a_p\(phase.rawValue)",
            slot: "Morning", label: "Lower A", icon: "figure.strengthtraining.traditional",
            exercises: [
                ExerciseDefinition(id: "la_legpress",  name: "Hoist Leg Press",       targetSets: s, targetReps: r,
                    targetKg: nil, note: "Feet shoulder-width, mid-platform. Full depth — knees track over toes. Don't lock out at top. Primary quad + glute compound. Add weight every session."),
                ExerciseDefinition(id: "la_goblet",    name: "Goblet Squat",          targetSets: s, targetReps: r,
                    targetKg: nil, note: phase == .phase1 ? "Hold KB/DB at chest. Phase 1 weeks 1–2: bodyweight to build depth pattern. Heels flat on floor, break parallel, knees tracking out." : "Hold heavy KB/DB at chest. Heels flat. Break parallel every rep. This trains squat depth and hip mobility together.",
                    isBodyweight: phase == .phase1),
                ExerciseDefinition(id: "la_hamcurl",   name: "Hoist Hamstring Curl",  targetSets: s, targetReps: r,
                    targetKg: nil, note: "Seated on the Hoist machine. 3-second negative (lower slow) every rep. Full range of motion. Hamstring strength protects knees and improves posture."),
                ExerciseDefinition(id: "la_lunge",     name: "DB Reverse Lunge",      targetSets: 3, targetReps: iso,
                    targetKg: nil, note: phase == .phase1 ? "Bodyweight phase 1. Step back until back knee hovers 2 cm above floor. Front shin stays vertical. Alternate legs. Builds single-leg stability." : "Hold DBs at sides. Step back — front shin vertical, back knee just above floor. Alternate legs each rep. Single-leg strength = athletic performance + injury resilience.",
                    isBodyweight: phase == .phase1),
                ExerciseDefinition(id: "la_abs",       name: "Hanging Knee Raise",    targetSets: 3, targetReps: "12",
                    targetKg: nil, note: "Hang from the pull-up bar on the Hoist cable machine. Bring knees to chest — slow and controlled, no swinging. Or: lying leg raise on the mat if bar is occupied.", isBodyweight: true),
            ],
            isRest: false
        )
    }

    // MARK: - Lower B (Saturday) — Posterior Chain · Glutes · Metabolic Finisher
    // Equipment: Hoist Leg Press (glute stance), dumbbells (RDL + hip thrust), Hoist Leg Extension,
    //            kettlebells (KB swing). Bodyweight: hip thrust BW option phase 1.
    // Goal: glutes + hamstrings for aesthetics + strength, hormonal stimulus (KB swing + hip thrust),
    //       metabolic conditioning as session finisher.

    private static func lowerB(phase: ProgramPhase) -> WorkoutSession {
        let s = phase.gymSets
        let r = phase.gymReps
        let iso = phase.isolationReps
        return WorkoutSession(
            id: "lower_b_p\(phase.rawValue)",
            slot: "Morning", label: "Lower B", icon: "figure.strengthtraining.traditional",
            exercises: [
                ExerciseDefinition(id: "lb_legpress",  name: "Hoist Leg Press",      targetSets: s, targetReps: r,
                    targetKg: nil, note: "Today: feet HIP-WIDTH apart, placed HIGH on the platform. This shifts load from quads (Tuesday) to glutes and hamstrings. Full depth, drive through heels."),
                ExerciseDefinition(id: "lb_rdl",       name: "DB Romanian Deadlift", targetSets: s, targetReps: r,
                    targetKg: nil, note: "DBs close to shins. Hinge at hips — soft knees, flat back. Feel hamstring stretch at bottom before you drive. Best posterior chain exercise in this program. Heavy and slow."),
                ExerciseDefinition(id: "lb_legext",    name: "Hoist Leg Extension",  targetSets: 3, targetReps: iso,
                    targetKg: nil, note: "Hoist machine. Squeeze quad at the top for 1 full sec. 3-sec lowering. Light-moderate weight, perfect contraction every rep. Knee extension strength and quad detail."),
                ExerciseDefinition(id: "lb_hipthrust", name: "DB Hip Thrust",        targetSets: 3, targetReps: iso,
                    targetKg: nil, note: "Upper back resting on bench edge, DB/plate across hips. Drive through heels, squeeze glutes hard at the top — chin tucked. Extend your hips, not your lower back. Top exercise for glute development and testosterone response."),
                ExerciseDefinition(id: "lb_kbswing",   name: "Kettlebell Swing",     targetSets: 4, targetReps: "15",
                    targetKg: nil, note: "Hip hinge — NOT a squat. Hike KB back between legs, snap hips forward explosively to drive it to chest height. Power from glutes and hips, not arms or shoulders. Best hormonal + metabolic stimulus in this program.\(phase.rawValue >= 3 ? " Phase 3+: go heavy — 24–32 kg target. Each set should feel like a sprint." : " Start 12–16 kg — form before weight.")"),
            ],
            isRest: false
        )
    }

    // MARK: - Cardio (Wednesday / Friday)
    // Wednesday = higher intensity metabolic work (KB circuit → intervals → HIIT)
    // Friday = steady state active recovery (walk → incline walk → interval build)
    // Both build cardiovascular health, fat oxidation, skin circulation, and mental reset.

    private static func cardio(phase: ProgramPhase, isWed: Bool) -> WorkoutSession {
        let (label, detail, duration, note): (String, String, String, String) = {
            switch phase {
            case .phase1:
                return isWed
                    ? ("Walk 30 min", "Brisk Walk", "30 min",
                       "Outdoor or treadmill. Brisk but conversational pace. This is your aerobic base — consistency here is what drives fat oxidation and cardiovascular health. Don't skip.")
                    : ("Walk 30 min", "Active Recovery Walk", "30 min",
                       "Easy pace — legs will be sore from Tuesday. 30 min movement to flush lactic acid and improve recovery. Outside if possible — sunlight = cortisol regulation.")
            case .phase2:
                return isWed
                    ? ("KB Circuit 35 min", "KB + Walk Circuit", "35 min",
                       "5 min warm-up walk → 4 rounds: 15 KB swings (pick a weight you can do with crisp form) + 5 min brisk walk → 5 min cool-down. Builds metabolic fitness and burns fat without joint stress.")
                    : ("Incline Walk 35 min", "Incline Walk", "35 min",
                       "Treadmill: 5–8% incline, 5.5 km/h. Or hilly outdoor route. Higher calorie burn without running impact. This is one of the most underrated fat-loss tools available.")
            case .phase3:
                return isWed
                    ? ("Intervals 25 min", "Walk/Jog Intervals", "25 min",
                       "5 min warm-up walk → 10 rounds: 1 min jog + 1 min walk → 5 min cool-down. Alternative: 5 rounds of 30 sec heavy KB swings + 90 sec rest. Both build VO2max.")
                    : ("Incline Walk 40 min", "Incline Walk", "40 min",
                       "Treadmill: 8–10% incline, 6 km/h. Or 40-min brisk walk with hills. Steady state in fat-burning zone — keeps cortisol low while burning calories.")
            case .phase4:
                return isWed
                    ? ("HIIT 30 min", "HIIT Intervals", "30 min",
                       "5 min walk → 8 rounds: 90 sec run + 60 sec walk → 5 min cool-down. Or battle rope: 30 sec all-out + 60 sec rest × 10. Both drive VO2max gains and accelerate fat loss.")
                    : ("Walk + Intervals 30 min", "Walk + Intervals", "30 min",
                       "5 min walk → 8 rounds: 1 min jog + 90 sec walk → 5 min cool-down. Active aerobic base session — complements Saturday's heavy lower day.")
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

    // MARK: - Evening (all gym days) — Foam Roll · Stretch · Core · Pelvic Floor
    // Goal: accelerate recovery, improve flexibility, rebuild deep core, support sexual health,
    //       reduce cortisol for better sleep, improve skin via circulation + parasympathetic activation.
    // Equipment: foam roller (in gym), mat. All bodyweight — can do at home or in gym.

    private static func eveningGymDay() -> WorkoutSession {
        WorkoutSession(
            id: "eve_gym",
            slot: "Evening", label: "Recovery + Core", icon: "figure.flexibility",
            exercises: [
                ExerciseDefinition(id: "eve_foam",    name: "Foam Rolling",       targetSets: 1, targetReps: "3 min",
                    targetKg: nil, note: "Foam roller (in gym). Roll: quads 60s, IT band / outer hip 60s, upper back 60s. Slow — pause on tight spots for 5–10 sec. Flushes metabolic waste and reduces DOMS (delayed soreness).", isBodyweight: true),
                ExerciseDefinition(id: "eve_stretch", name: "Full Body Stretch",  targetSets: 1, targetReps: "10 min",
                    targetKg: nil, note: "Hip flexors 60s each side · Hamstrings 60s · Doorway chest stretch 45s · Lat overhead stretch 45s · Shoulder cross-body 30s each. Hold every stretch — no bouncing. Consistent nightly stretching rebuilds flexibility in 4–6 weeks and directly improves sleep quality.", isBodyweight: true),
                ExerciseDefinition(id: "eve_core",    name: "Dead Bug Hold",      targetSets: 3, targetReps: "10",
                    targetKg: nil, note: "Lie on back, arms straight up, knees 90°. Extend opposite arm + leg toward floor (2 sec lowering, 1 sec hold). Lower back STAYS FLAT on floor the entire time — this is the point. Rebuilds deep core stability (transverse abdominis) that protects the spine.", isBodyweight: true),
                ExerciseDefinition(id: "eve_kegels",  name: "Kegel Holds",        targetSets: 3, targetReps: "20",
                    targetKg: nil, note: "Contract pelvic floor 5 sec, release 5 sec. Builds pelvic floor strength — directly improves sexual function, sensation, and control in both men and women. Takes 6–8 weeks of daily consistency to feel the full effect. Do this every evening without exception.", isBodyweight: true),
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
