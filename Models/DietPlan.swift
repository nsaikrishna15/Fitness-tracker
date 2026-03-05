import Foundation
import SwiftUI

// MARK: - Single source of truth for all diet numbers in the app.
// DietView, HabitStore, BodyweightChartView all read from here — no hardcoded macros anywhere else.

// MARK: - IntensityMode — derived from (estimatedCurrentBF% - targetBF%)

enum IntensityMode: String, CaseIterable {
    case aggressiveCut = "aggressiveCut"
    case standardCut   = "standardCut"
    case mildCut       = "mildCut"
    case recomp        = "recomp"
    case bulk          = "bulk"

    /// Calorie delta relative to TDEE (negative = deficit, positive = surplus)
    var calorieDeficit: Int {
        switch self {
        case .aggressiveCut: return 750
        case .standardCut:   return 500
        case .mildCut:       return 250
        case .recomp:        return 0
        case .bulk:          return -200   // surplus
        }
    }

    var label: String {
        switch self {
        case .aggressiveCut: return "AGGRESSIVE CUT"
        case .standardCut:   return "STANDARD CUT"
        case .mildCut:       return "MILD CUT"
        case .recomp:        return "RECOMP"
        case .bulk:          return "BULK"
        }
    }

    var colorHex: String {
        switch self {
        case .aggressiveCut: return "FF3B30"   // red
        case .standardCut:   return "FF9F0A"   // orange
        case .mildCut:       return "FFD60A"   // yellow
        case .recomp:        return "0A84FF"   // blue
        case .bulk:          return "30D158"   // green
        }
    }

    var cardioGuidance: String {
        switch self {
        case .aggressiveCut: return "Push the pace — add 5–10 min on top of session target"
        case .standardCut:   return "Moderate effort — complete prescribed duration at steady pace"
        case .mildCut:       return "Active recovery pace — conversational effort only"
        case .recomp:        return "Light movement — focus effort goes to lifting this week"
        case .bulk:          return "Light movement — focus effort goes to lifting this week"
        }
    }

    var deficitLabel: String {
        switch self {
        case .aggressiveCut: return "−750 kcal deficit"
        case .standardCut:   return "−500 kcal deficit"
        case .mildCut:       return "−250 kcal deficit"
        case .recomp:        return "maintenance calories"
        case .bulk:          return "+200 kcal surplus"
        }
    }
}

enum DietPlan {

    // MARK: - BMR — Mifflin-St Jeor 1990

    static func bmr(weightKg: Double, heightCm: Double, age: Int, isMale: Bool) -> Double {
        let base = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age))
        return isMale ? base + 5 : base - 161
    }

    // MARK: - TDEE — BMR × ACSM activity multiplier based on program phase

    static func tdee(bmr: Double, programStartDate: Date) -> Double {
        switch ProgramPhase.current(startDate: programStartDate) {
        case .phase1: return bmr * 1.375
        case .phase2: return bmr * 1.550
        case .phase3, .phase4: return bmr * 1.725
        }
    }

    // MARK: - Estimated Body Fat % — Deurenberg BMI-based formula
    // Men:   BF% = (1.20 × BMI) + (0.23 × age) - 16.2
    // Women: BF% = (1.20 × BMI) + (0.23 × age) - 5.4

    static func estimatedBodyFatPct(weightKg: Double, heightCm: Double, age: Int, isMale: Bool) -> Double {
        let m   = heightCm / 100
        let bmi = weightKg / (m * m)
        let bf  = (1.20 * bmi) + (0.23 * Double(age)) - (isMale ? 16.2 : 5.4)
        return max(3, min(60, bf))  // clamp to physiologically possible range
    }

    // MARK: - IntensityMode from fat gap

    static func intensityMode(currentBF: Double, targetBF: Double) -> IntensityMode {
        let gap = currentBF - targetBF
        switch gap {
        case let g where g > 10:       return .aggressiveCut
        case let g where g > 5:        return .standardCut
        case let g where g > 2:        return .mildCut
        case let g where g >= 0:       return .recomp
        default:                        return .bulk
        }
    }

    // MARK: - Target intake = TDEE − deficit, floored at 1500 male / 1200 female

    static func targetKcal(tdee: Double, isMale: Bool, deficit: Int = 500) -> Int {
        Int(max(tdee - Double(deficit), isMale ? 1500.0 : 1200.0))
    }

    // MARK: - Protein: 2.2 g/kg — ISSN recomposition standard (fat loss + muscle retention)

    static func proteinGrams(weightKg: Double) -> Int {
        Int((weightKg * 2.2).rounded())
    }

    // MARK: - Fat: max(25% of target kcal ÷ 9, 0.5 g/kg) — ACSM minimum for hormonal health

    static func fatGrams(targetKcal: Int, weightKg: Double) -> Int {
        let fromCalories = (0.25 * Double(targetKcal)) / 9.0
        let fromWeight   = 0.5 * weightKg
        return Int(max(fromCalories, fromWeight).rounded())
    }

    // MARK: - Carbs: fill remaining calories after protein + fat

    static func carbGrams(targetKcal: Int, proteinG: Int, fatG: Int) -> Int {
        let remaining = Double(targetKcal) - Double(proteinG * 4) - Double(fatG * 9)
        return Int(max(remaining / 4.0, 0).rounded())
    }

    // MARK: - Water: EFSA 35ml/kg, min 3L, max 5L

    static func waterLitres(bodyweightKg: Double) -> Double {
        min(max(bodyweightKg * 0.035, 3.0), 5.0)
    }

    // MARK: - MealMacros struct (used by DietView)

    struct MealMacros {
        let name: String
        let time: String
        let protein: Int
        let carbs: Int
        let fat: Int
        var kcal: Int { protein * 4 + carbs * 4 + fat * 9 }
        var summary: String { "\(protein)g P · \(carbs)g C · \(fat)g F · ~\(kcal) kcal" }
    }

    // MARK: - Split totals across 5 meals
    // Order: Pre-Workout / Breakfast / Lunch / Snack / Dinner
    // Ratios designed so PW is carb-heavy (energy), Lunch is protein-heavy, Dinner is balanced

    static func mealSplit(totalProtein: Int, totalCarbs: Int, totalFat: Int) -> [MealMacros] {
        let names  = ["Pre-Workout", "Breakfast",  "Lunch",    "Snack",    "Dinner"]
        let times  = ["6:45 AM",     "8:15 AM",    "12:30 PM", "4:30 PM",  "7:30 PM"]
        let pRatio = [0.13,           0.22,          0.29,       0.12,       0.24]
        let cRatio = [0.21,           0.23,          0.31,       0.05,       0.20]
        let fRatio = [0.07,           0.25,          0.16,       0.25,       0.27]
        return (0..<5).map { i in
            MealMacros(
                name:    names[i], time: times[i],
                protein: Int((Double(totalProtein) * pRatio[i]).rounded()),
                carbs:   Int((Double(totalCarbs)   * cRatio[i]).rounded()),
                fat:     Int((Double(totalFat)      * fRatio[i]).rounded())
            )
        }
    }

    // MARK: - FoodAmounts — computed gram quantities for meal ingredients

    struct FoodAmounts {
        let proteinSourceGrams: Int      // e.g. 160 or number of eggs
        let proteinSourceLabel: String   // e.g. "chicken breast" or "eggs"
        let carbsGrams: Int              // dry grams (rice or oats)
        let carbsLabel: String           // e.g. "dry basmati rice"
        let isEggs: Bool                 // true if protein source is eggs (display as count)
    }

    /// Compute actual ingredient gram amounts from macro targets + user's preferred protein source.
    /// - Chicken breast:  25g protein per 100g  → grams = targetP × 4
    /// - Fish (tilapia):  22g protein per 100g  → grams = targetP × 4.545
    /// - Eggs:            6g protein each        → count = ceil(targetP ÷ 6)
    /// - Oats (breakfast): 40g dry = 28g carbs  → grams = targetC × (40÷28)
    /// - Rice (lunch/dinner): 50g dry = 37g carbs → grams = targetC × (50÷37)
    static func foodAmounts(mealMacros: MealMacros, preferredProtein: String, isBreakfast: Bool) -> FoodAmounts {
        let proteinTarget = mealMacros.protein
        let carbTarget    = mealMacros.carbs

        // Protein source
        let (proteinGrams, proteinLabel, isEggs): (Int, String, Bool) = {
            switch preferredProtein {
            case "fish":
                return (Int((Double(proteinTarget) * 4.545).rounded()), "white fish (tilapia/basa)", false)
            case "eggs":
                return (Int(ceil(Double(proteinTarget) / 6.0)), "eggs", true)
            default:  // chicken
                return (Int((Double(proteinTarget) * 4.0).rounded()), "chicken breast", false)
            }
        }()

        // Carb source
        let (carbGrams, carbLabel): (Int, String) = {
            if isBreakfast {
                // Oats: 40g dry → 28g carbs → ratio = 40/28 ≈ 1.4286
                return (Int((Double(carbTarget) * 40.0 / 28.0).rounded()), "dry oats")
            } else {
                // Rice: 50g dry → 37g carbs → ratio = 50/37 ≈ 1.3514
                return (Int((Double(carbTarget) * 50.0 / 37.0).rounded()), "dry basmati rice")
            }
        }()

        return FoodAmounts(
            proteinSourceGrams: proteinGrams,
            proteinSourceLabel: proteinLabel,
            carbsGrams: carbGrams,
            carbsLabel: carbLabel,
            isEggs: isEggs
        )
    }
}
