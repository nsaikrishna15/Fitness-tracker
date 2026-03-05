import Foundation

// MARK: - Workout Progression Engine
// Tracks per-exercise weight over time. Completely independent of phase —
// the weight you lifted last session is always the starting point for next session.
// Stored in UserDefaults as JSON.

// MARK: - Exercise Progression Record

struct ExerciseProgress: Codable {
    let exerciseID: String
    var currentKg: Double?      // nil = bodyweight exercise
    var failCount: Int          // consecutive sessions where reps weren't hit
    var sessionsDone: Int       // total sessions completed for this exercise
    var isDeloaded: Bool        // true during deload week (set externally)
}

// MARK: - Progression Rules (static, applies to every user)

enum ProgressionEngine {

    // Upper body: +2.5kg per successful session
    // Lower body (leg press, RDL, goblet): +5kg per successful session
    // Isolation (lateral raise, curl, face pull, calf): +2.5kg
    // Bodyweight / cardio: no weight increment

    static func increment(for exerciseID: String) -> Double {
        switch exerciseID {
        case "la_legpress", "lb_legpress":
            return 5.0
        case "la_goblet", "lb_rdl", "la_hamcurl", "lb_legext", "lb_hipthrust", "la_lunge":
            return 2.5
        case "lb_kbswing":
            return 4.0   // follows kettlebell size increments (8→12→16→20→24→28→32)
        case _ where exerciseID.hasPrefix("ua_") || exerciseID.hasPrefix("ub_"):
            return 2.5
        default:
            return 0   // bodyweight / cardio / time-based
        }
    }

    // Starting weights keyed by exerciseID — scaled from user's bodyweight
    // Base calibrated for 90kg beginner restart. Scale linearly with bodyweight.
    static func startingWeight(exerciseID: String, bodyweightKg: Double) -> Double? {
        let scale = bodyweightKg / 90.0
        let base: Double? = {
            switch exerciseID {
            // Upper A
            case "ua_bench":      return 40.0
            case "ua_latpd":      return 45.0
            case "ua_dbshoulder": return 10.0   // per DB
            case "ua_row":        return 40.0
            case "ua_tricep":     return 15.0   // cable weight
            case "ua_plank":      return nil     // bodyweight
            // Upper B
            case "ub_incline":    return 12.0   // per DB
            case "ub_latpd":      return 45.0
            case "ub_lateral":    return 6.0    // per DB
            case "ub_facepull":   return 15.0
            case "ub_curl":       return 10.0   // per DB
            // Lower A
            case "la_legpress":   return 80.0
            case "la_goblet":     return 12.0
            case "la_hamcurl":    return 25.0
            case "la_lunge":      return 8.0    // per DB; bodyweight in phase 1
            case "la_abs":        return nil    // bodyweight
            // Lower B
            case "lb_legpress":   return 80.0
            case "lb_rdl":        return 20.0   // per DB
            case "lb_legext":     return 30.0
            case "lb_hipthrust":  return 20.0
            case "lb_kbswing":    return 16.0   // KB — 16kg standard starting weight
            default:              return nil
            }
        }()
        guard let b = base else { return nil }
        let scaled = b * scale
        return (scaled / 2.5).rounded() * 2.5
    }

    // Call after a session is logged. Returns updated record.
    // allSetsCompleted: true if user hit target reps on ALL sets of this exercise.
    static func update(
        record: inout ExerciseProgress,
        allSetsCompleted: Bool,
        isDeloadWeek: Bool
    ) {
        if isDeloadWeek {
            // During deload: don't progress, don't penalize
            record.isDeloaded = true
            return
        }

        record.isDeloaded = false

        if allSetsCompleted {
            record.failCount = 0
            record.sessionsDone += 1
            let inc = increment(for: record.exerciseID)
            if inc > 0, let kg = record.currentKg {
                record.currentKg = kg + inc
            }
        } else {
            record.failCount += 1
            if record.failCount >= 2 {
                // Two consecutive failures → deload by 10%
                if let kg = record.currentKg {
                    let reduced = (kg * 0.9 / 2.5).rounded() * 2.5
                    record.currentKg = max(reduced, 2.5)
                }
                record.failCount = 0
            }
            // One failure: stay at same weight (no change to currentKg)
        }
    }
}

// MARK: - Program Day Logic
// The program advances only when the user opens the app and logs at least one set.
// Skipped days do NOT advance the program counter — the workout is held for the next
// day the user shows up. The calendar date still shows on the Workout tab as usual,
// but the "program session" doesn't advance until it's completed.

struct ProgramDayStore: Codable {
    // Set of dateKey strings on which the user completed at least 1 workout set
    var completedWorkoutDays: Set<String> = []

    // Computed: number of days on which a workout was actually logged
    var activeDaysCount: Int { completedWorkoutDays.count }

    // The "program day" for display (1-based, max 120)
    var programDay: Int { max(1, min(activeDaysCount + 1, 120)) }

    mutating func markDone(dateKey: String) {
        completedWorkoutDays.insert(dateKey)
    }
}

// MARK: - Deload Detection
// Week 8 = program days 50–56. We check activeDaysCount, not calendar.
extension ProgramDayStore {
    var isDeloadWeek: Bool {
        let d = activeDaysCount
        return d >= 49 && d <= 55
    }
}
