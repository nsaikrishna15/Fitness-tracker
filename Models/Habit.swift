import Foundation

// Days of week (ISO: 0=Mon … 6=Sun)
typealias DayMask = Set<Int>

enum HabitID: String, Codable, CaseIterable {
    case wakeWater       = "wakeWater"
    case brushToilet     = "brushToilet"
    case sunlight        = "sunlight"
    case preWorkout      = "preWorkout"
    case gymUpperA       = "gymUpperA"
    case gymLowerA       = "gymLowerA"
    case gymUpperB       = "gymUpperB"
    case gymLowerB       = "gymLowerB"
    case walk            = "walk"
    case rest            = "rest"
    case breakfast       = "breakfast"
    case officeHydrate   = "officeHydrate"
    case lunch           = "lunch"
    case waterCheck      = "waterCheck"
    case snack           = "snack"
    case dinner          = "dinner"
    case eveningWorkout  = "eveningWorkout"
    case lightActivity   = "lightActivity"
    case progressPhoto   = "progressPhoto"
    case windDown        = "windDown"
    case sleep           = "sleep"
}

struct HabitDefinition {
    let id: HabitID
    let time: String
    let displayName: String
    let detail: String
    let icon: String
    /// nil = active all days; non-nil = active only on listed ISO weekday indices (0=Mon…6=Sun)
    let activeDays: DayMask?
    /// Hour + minute when the habit unlocks on TODAY (1 min before scheduled time).
    /// Past days are always unlocked. Future days always locked.
    let unlockHour: Int
    let unlockMinute: Int

    /// Returns true if this habit is currently tappable for `date`.
    /// Rules:
    ///   - Past days  → always unlocked
    ///   - Future days → always locked
    ///   - Today      → unlocked once current time >= (unlockHour:unlockMinute)
    func isUnlocked(for date: Date) -> Bool {
        if date.isPastDay { return true }
        if date.isFutureDay { return false }
        // Today: check clock
        let cal = Calendar.current
        let now = Date()
        let h = cal.component(.hour,   from: now)
        let m = cal.component(.minute, from: now)
        let nowMins    = h * 60 + m
        let unlockMins = unlockHour * 60 + unlockMinute
        return nowMins >= unlockMins
    }

    static let all: [HabitDefinition] = [
        HabitDefinition(id: .wakeWater,
                        time: "6:30", displayName: "Wake & Water",
                        detail: "600ml + pinch salt",
                        icon: "drop.fill", activeDays: nil,
                        unlockHour: 6, unlockMinute: 29),

        HabitDefinition(id: .brushToilet,
                        time: "6:35", displayName: "Brush + Toilet",
                        detail: "No phone scrolling",
                        icon: "mouth.fill", activeDays: nil,
                        unlockHour: 6, unlockMinute: 34),

        HabitDefinition(id: .sunlight,
                        time: "6:45", displayName: "Sunlight",
                        detail: "5 min outside",
                        icon: "sun.max.fill", activeDays: nil,
                        unlockHour: 6, unlockMinute: 44),

        HabitDefinition(id: .preWorkout,
                        time: "6:50", displayName: "Pre-Workout",
                        detail: "Banana + 1 scoop whey",
                        icon: "bolt.fill", activeDays: nil,
                        unlockHour: 6, unlockMinute: 49),

        HabitDefinition(id: .gymUpperA,
                        time: "7:00–8:00", displayName: "Upper A",
                        detail: "DB Bench · Cable Lat PD · DB Shoulder · Cable Row · Tricep PD · Plank",
                        icon: "dumbbell.fill", activeDays: [0],
                        unlockHour: 6, unlockMinute: 59),

        HabitDefinition(id: .gymLowerA,
                        time: "7:00–8:00", displayName: "Lower A",
                        detail: "Leg Press · Goblet Squat · Ham Curl · Reverse Lunge · Hanging Knee Raise",
                        icon: "figure.strengthtraining.traditional", activeDays: [1],
                        unlockHour: 6, unlockMinute: 59),

        HabitDefinition(id: .gymUpperB,
                        time: "7:00–8:00", displayName: "Upper B",
                        detail: "Incline DB Press · Lat PD · Lateral Raise · Face Pull · DB Curl",
                        icon: "dumbbell.fill", activeDays: [3],
                        unlockHour: 6, unlockMinute: 59),

        HabitDefinition(id: .gymLowerB,
                        time: "7:00–8:00", displayName: "Lower B",
                        detail: "Leg Press · RDL · Leg Extension · Hip Thrust · KB Swing 4×15",
                        icon: "figure.strengthtraining.traditional", activeDays: [5],
                        unlockHour: 6, unlockMinute: 59),

        HabitDefinition(id: .walk,
                        time: "7:00–7:40", displayName: "Walk 30 min",
                        detail: "Brisk walk / treadmill incline",
                        icon: "figure.walk", activeDays: [2, 4],
                        unlockHour: 6, unlockMinute: 59),

        HabitDefinition(id: .rest,
                        time: "7:00", displayName: "REST",
                        detail: "Full rest / Stretch 10 min",
                        icon: "moon.zzz.fill", activeDays: [6],
                        unlockHour: 6, unlockMinute: 59),

        HabitDefinition(id: .breakfast,
                        time: "8:15", displayName: "Breakfast",
                        detail: "3 whole eggs + 2 whites + ½ cup oats + 1 Thorne",
                        icon: "fork.knife", activeDays: nil,
                        unlockHour: 8, unlockMinute: 14),

        HabitDefinition(id: .officeHydrate,
                        time: "9:00", displayName: "Office Hydrate",
                        detail: "500ml water by 11 AM",
                        icon: "building.2.fill", activeDays: nil,
                        unlockHour: 8, unlockMinute: 59),

        HabitDefinition(id: .lunch,
                        time: "12:30", displayName: "Lunch",
                        detail: "200g chicken + 1 cup rice + veggies",
                        icon: "fork.knife.circle.fill", activeDays: nil,
                        unlockHour: 12, unlockMinute: 29),

        HabitDefinition(id: .waterCheck,
                        time: "3:30", displayName: "Water Check",
                        detail: "Total 2L by now",
                        icon: "drop.circle.fill", activeDays: nil,
                        unlockHour: 15, unlockMinute: 29),

        HabitDefinition(id: .snack,
                        time: "4:30", displayName: "Snack",
                        detail: "Greek yogurt OR 2 boiled eggs + almonds",
                        icon: "leaf.fill", activeDays: nil,
                        unlockHour: 16, unlockMinute: 29),

        HabitDefinition(id: .dinner,
                        time: "7:30", displayName: "Dinner",
                        detail: "150g chicken/fish + salad + small carb + Thorne",
                        icon: "flame.fill", activeDays: nil,
                        unlockHour: 19, unlockMinute: 29),

        HabitDefinition(id: .eveningWorkout,
                        time: "6:00–7:30", displayName: "Evening Session",
                        detail: "Foam Roll 3min · Full Stretch 10min · Dead Bug 3×10 · Kegels 3×20",
                        icon: "moon.stars.fill", activeDays: nil,
                        unlockHour: 18, unlockMinute: 0),

        HabitDefinition(id: .lightActivity,
                        time: "8:30", displayName: "Stretch + Kegels",
                        detail: "10 min stretch + Kegels 3×20",
                        icon: "figure.flexibility", activeDays: nil,
                        unlockHour: 20, unlockMinute: 29),

        HabitDefinition(id: .progressPhoto,
                        time: "9:30", displayName: "Progress Photo",
                        detail: "Same spot / lighting / relaxed pose",
                        icon: "camera.fill", activeDays: nil,
                        unlockHour: 21, unlockMinute: 29),

        HabitDefinition(id: .windDown,
                        time: "10:30", displayName: "Wind Down",
                        detail: "No phone / dim lights",
                        icon: "light.min", activeDays: nil,
                        unlockHour: 22, unlockMinute: 29),

        HabitDefinition(id: .sleep,
                        time: "11:00", displayName: "Sleep",
                        detail: "Min 7.5 hours target",
                        icon: "moon.fill", activeDays: nil,
                        unlockHour: 22, unlockMinute: 59),
    ]
}
