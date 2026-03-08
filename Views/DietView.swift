import SwiftUI

// MARK: - Diet View

struct DietView: View {
    @EnvironmentObject private var store: HabitStore

    // Week A = odd week of year, Week B = even
    private var isWeekA: Bool {
        Calendar(identifier: .iso8601).component(.weekOfYear, from: Date()) % 2 == 1
    }

    // Computed meals — derived dynamically from store (weight, height, age, phase)
    private var computedMeals: [DietPlan.MealMacros] {
        DietPlan.mealSplit(totalProtein: store.dailyProteinG,
                           totalCarbs:   store.dailyCarbsG,
                           totalFat:     store.dailyFatG)
    }

    // Convenience shorthands used by targetsCard and the protein distribution bar
    private var totalProtein: Int { store.dailyProteinG }
    private var totalCarbs:   Int { store.dailyCarbsG }
    private var totalFat:     Int { store.dailyFatG }
    private var totalKcal:    Int { store.dailyCalories }

    // Water target: bodyweight × 35ml/kg, minimum 3L, capped at 5L — from DietPlan
    private var waterLitres: Double {
        DietPlan.waterLitres(bodyweightKg: store.latestWeight ?? 80)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                intensityBanner.padding(.top, 4)
                targetsCard

                sectionHeader("MEAL PLAN", icon: "fork.knife")
                ForEach(mealPlan(from: computedMeals, protein: store.preferredProtein)) { meal in MealCard(meal: meal) }
                sectionHeader("FRUIT ROTATION", icon: "leaf.fill")
                fruitCard(isWeekA: isWeekA)

                sectionHeader("HYDRATION", icon: "drop.fill")
                hydrationCard

                sectionHeader("SUPPLEMENTS", icon: "pill.fill")
                InfoCard(rows: supplementPlan, accentColor: .accentGreen)

                sectionHeader("WEEKLY MEAL PREP", icon: "bag.fill")
                prepCard(protein: store.preferredProtein)
            }
            .padding(16)
        }
        .background(Color.appBackground)
        .navigationTitle("Diet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.cardBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - IntensityMode banner

    private var intensityBanner: some View {
        let mode    = store.intensityMode
        let color   = Color(hex: mode.colorHex)
        let estBF   = store.estimatedBodyFatPct
        let target  = store.targetBodyFatPct

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(mode.label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(color)
                if let est = estBF {
                    Text(String(format: "~%.0f%% est. → %.0f%% target · %@",
                                est, target, mode.deficitLabel))
                        .font(.system(size: 11))
                        .foregroundColor(.secondaryText)
                } else {
                    Text(String(format: "%.0f%% target · %@", target, mode.deficitLabel))
                        .font(.system(size: 11))
                        .foregroundColor(.secondaryText)
                }
            }
            Spacer()
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: iconForMode(mode))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(color)
                )
        }
        .padding(12)
        .background(color.opacity(0.08))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.3), lineWidth: 1))
    }

    private func iconForMode(_ mode: IntensityMode) -> String {
        switch mode {
        case .aggressiveCut: return "flame.fill"
        case .standardCut:   return "arrow.down.circle.fill"
        case .mildCut:       return "minus.circle.fill"
        case .recomp:        return "arrow.left.arrow.right.circle.fill"
        case .bulk:          return "arrow.up.circle.fill"
        }
    }

    // MARK: - Targets card — totals that match the meals below

    private var targetsCard: some View {
        let w = store.latestWeight ?? 80

        return VStack(alignment: .leading, spacing: 10) {

            // Header
            HStack {
                Text("DAILY TARGETS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondaryText)
                    .tracking(0.8)
                Spacer()
                if let lbm = store.leanBodyMassKg, let wt = store.latestWeight {
                    Text(String(format: "Protein on %.0f kg LBM (%.0f kg total)", lbm, wt))
                        .font(.system(size: 10))
                        .foregroundColor(.secondaryText)
                } else {
                    Text(store.latestWeight != nil
                         ? String(format: "Based on %.0f kg", w)
                         : "Log weight to personalise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondaryText)
                }
            }

            // Calorie line
            Text("~\(totalKcal) kcal · TDEE ~\(Int(store.tdeeValue ?? 0)) · \(store.intensityMode.deficitLabel).")
                .font(.system(size: 11))
                .foregroundColor(.secondaryText)

            // BMI + goal weight block
            if let bmi = store.bmiValue, let current = store.latestWeight {
                let (category, catColor): (String, Color) = {
                    switch bmi {
                    case ..<18.5: return ("Underweight", Color(hex: "0A84FF"))
                    case ..<25:   return ("Healthy BMI", Color(hex: "30D158"))
                    case ..<30:   return ("Overweight",  Color(hex: "FF9F0A"))
                    default:      return ("Obese",       Color(hex: "FF3B30"))
                    }
                }()

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(String(format: "BMI  %.1f", bmi))
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(catColor)
                        Text(category)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(catColor)
                            .cornerRadius(4)
                        Spacer()
                        Text(String(format: "Current: %.1f kg", current))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondaryText)
                    }

                    if let targetW = store.bodyFatTargetWeightKg {
                        let tolose = max(0.0, current - targetW)
                        let targetBFpct = Int(store.targetBodyFatPct)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(String(format: "Goal: %.1f kg", targetW))
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(.primaryText)
                                        Text("at \(targetBFpct)% body fat")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondaryText)
                                    }
                                    if let bmiAtGoal = store.bmiAtTargetWeight {
                                        Text(String(format: "BMI at goal: %.1f — lean, athletic, normal for your frame", bmiAtGoal))
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondaryText)
                                    }
                                }
                                Spacer()
                                if tolose > 0.5 {
                                    Text(String(format: "−%.1f kg", tolose))
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(catColor)
                                }
                            }

                            if tolose > 0.5, let weeks = store.weeksToTargetWeight {
                                let months = weeks / 4
                                let remWeeks = weeks % 4
                                let timeStr = months > 0
                                    ? (remWeeks > 0 ? "\(months) mo \(remWeeks) wk" : "\(months) months")
                                    : "\(weeks) weeks"
                                Text("At current deficit: ~\(timeStr) to reach goal · Stay consistent.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondaryText)
                            } else if tolose <= 0 {
                                Text("You are at or below your goal weight. Focus on maintaining muscle.")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "30D158"))
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(catColor.opacity(0.10))
                        .cornerRadius(8)
                    }
                }
                .padding(.vertical, 2)
            }

            // Macro tiles
            HStack(spacing: 0) {
                macroTile("\(totalProtein)g", "Protein", .accentGreen)
                macroTile("\(totalCarbs)g",   "Carbs",   Color(hex: "FF9F0A"))
                macroTile("\(totalFat)g",     "Fat",     Color(hex: "FF6B6B"))
                macroTile("~\(totalKcal)",    "kcal",    .secondaryText)
            }

            // Progress bar — how much of the protein target each meal covers
            VStack(alignment: .leading, spacing: 4) {
                Text("Protein distribution across meals")
                    .font(.system(size: 10))
                    .foregroundColor(.secondaryText)
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(Array(zip(computedMeals.map(\.protein), ["PW", "B", "L", "S", "D"])), id: \.1) { p, label in
                            let w = CGFloat(p) / CGFloat(totalProtein) * geo.size.width
                            ZStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.accentGreen.opacity(0.7))
                                    .frame(width: max(w - 2, 0))
                                Text(label)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .frame(width: max(w - 2, 0), height: 18)
                        }
                    }
                }
                .frame(height: 18)
                Text("PW = Pre-Workout  B = Breakfast  L = Lunch  S = Snack  D = Dinner")
                    .font(.system(size: 9))
                    .foregroundColor(Color.secondaryText.opacity(0.6))
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cellBorder, lineWidth: 1))
    }

    private func macroTile(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Fruit rotation — no emojis

    private func fruitCard(isWeekA: Bool) -> some View {
        let weekLabel  = isWeekA ? "Week A" : "Week B"
        let nextLabel  = isWeekA ? "Next week: Grapes + Pear" : "Next week: Banana + Apple"
        let fruits: [(name: String, use: String, macro: String)] = isWeekA
            ? [("Banana",  "Pre-workout — 1 medium (~120 g). Sizes vary; pick one that fills your palm.", "~27g carbs, quick energy"),
               ("Apple",   "Afternoon snack — 1 medium (~180 g), any variety, eat whole",                "~25g carbs, 4g fibre")]
            : [("Grapes",  "Pre-workout or snack — 150 g (~22 grapes). Weigh on a scale; don't count by eye — grapes vary from 4 g to 10 g each.", "~26g carbs, easy to portion"),
               ("Pear",    "Afternoon snack — 1 medium (~180 g), eat whole, pairs with almonds",          "~27g carbs, 5g fibre")]

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(weekLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.accentGreen)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.accentGreen.opacity(0.12))
                    .cornerRadius(4)
                Spacer()
                Text(nextLabel)
                    .font(.system(size: 10))
                    .foregroundColor(.secondaryText)
            }

            ForEach(fruits, id: \.name) { fruit in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(fruit.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primaryText)
                        Spacer()
                        Text(fruit.macro)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondaryText)
                    }
                    Text(fruit.use)
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                }
                .padding(.vertical, 2)
            }

            Text("All options are cheap and available year-round. Rotate weekly to vary micronutrients. Buy at the start of each week — don't stockpile.")
                .font(.system(size: 11))
                .foregroundColor(.secondaryText)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.cellBackground)
                .cornerRadius(6)
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cellBorder, lineWidth: 1))
    }

    // MARK: - Hydration card — weight-based target

    private var hydrationCard: some View {
        let target = waterLitres
        let w      = store.latestWeight ?? 80

        return VStack(alignment: .leading, spacing: 0) {
            // Target banner
            HStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.accentBlue)
                Text(String(format: "Target: %.1fL / day", target))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primaryText)
                Spacer()
                Text(String(format: "%.0f kg × 35ml", w))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.cardBackground)

            Divider().background(Color.cellBorder)

            let rows: [(String, String)] = [
                ("6:30 AM",    "600ml on wakeup — water + pinch of salt"),
                ("By 10 AM",   "500ml — ideally before leaving for work"),
                ("By 1 PM",    "500ml with or after lunch"),
                ("By 4 PM",    String(format: "%.0fL total reached — halfway done", target * 0.5)),
                ("By 7 PM",    "500ml — with or after workout / walk"),
                ("By 10 PM",   String(format: "%.1fL total — target hit", target)),
                ("Note",       "Add 500ml extra on gym days — you sweat more than you think"),
            ]

            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                HStack(alignment: .top, spacing: 12) {
                    Text(row.0)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.accentBlue)
                        .frame(width: 75, alignment: .leading)
                    Text(row.1)
                        .font(.system(size: 13))
                        .foregroundColor(.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(idx % 2 == 0 ? Color.cardBackground : Color.rowAltBackground)
            }
        }
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cellBorder, lineWidth: 1))
    }

    // MARK: - Prep card

    private func prepCard(protein: String) -> some View {
        let lFoods = computedMeals.count > 2
            ? DietPlan.foodAmounts(mealMacros: computedMeals[2], preferredProtein: protein, isBreakfast: false)
            : nil
        let dFoods = computedMeals.count > 4
            ? DietPlan.foodAmounts(mealMacros: computedMeals[4], preferredProtein: protein, isBreakfast: false)
            : nil
        let snackProtein = computedMeals.count > 3 ? computedMeals[3].protein : 30
        let lG = lFoods?.proteinSourceGrams ?? (protein == "fish" ? 180 : 200)
        let dG = dFoods?.proteinSourceGrams ?? (protein == "fish" ? 180 : 170)
        let lC = lFoods?.carbsGrams ?? 90
        let dC = dFoods?.carbsGrams ?? 90
        let sections = buildPrepSections(protein: protein, lProteinGrams: lG, dProteinGrams: dG, lCarbGrams: lC, dCarbGrams: dC, snackProtein: snackProtein)
        let currentWeight = store.latestWeight
        return VStack(alignment: .leading, spacing: 0) {
            // Macro basis — always visible so the user can confirm calculations are live
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(String(format: "%dg P · %dg C · %dg F · %d kcal / day",
                                totalProtein, totalCarbs, totalFat, totalKcal))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.accentGreen)
                    Spacer()
                    Text(currentWeight.map { String(format: "%.1f kg", $0) } ?? "80 kg est.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(currentWeight == nil ? .orange : .secondaryText)
                }
                if currentWeight == nil {
                    Text("Log your weight in the Bodyweight tab — gram amounts will update automatically.")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            Divider().background(Color.cellBorder)
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: section.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.accentGreen)
                            .frame(width: 18)
                        Text(section.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primaryText)
                        if let badge = section.badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.accentGreen)
                                .cornerRadius(4)
                        }
                    }
                    ForEach(section.items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Rectangle()
                                .fill(Color.accentGreen.opacity(0.4))
                                .frame(width: 3, height: 3)
                                .padding(.top, 6)
                            Text(item)
                                .font(.system(size: 12))
                                .foregroundColor(.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let note = section.note {
                        Text(note)
                            .font(.system(size: 11))
                            .foregroundColor(.secondaryText)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.cellBackground)
                            .cornerRadius(6)
                    }
                }
                .padding(14)

                if section.id != sections.last?.id {
                    Divider().background(Color.cellBorder)
                }
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cellBorder, lineWidth: 1))
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.accentGreen)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(1.2)
        }
        .padding(.top, 4)
    }
}

// MARK: - Data models

struct MealItem: Identifiable {
    let id = UUID()
    let time: String
    let name: String
    let ingredients: [String]
    let macros: String
    let notes: String
}

struct PrepSection: Identifiable {
    let id    = UUID()
    let icon:  String
    let title: String
    let badge: String?
    let items: [String]
    let note:  String?
}

// MARK: - Meal data — macros sourced from computed DietPlan.mealSplit
// Order: Pre-Workout (0) / Breakfast (1) / Lunch (2) / Snack (3) / Dinner (4)
//
// Protein logic:
//   Breakfast + Snack → always eggs (easy to cook, always on hand)
//   Lunch + Dinner    → chicken (default) or fish (alternate), per user preference

private func mealPlan(from m: [DietPlan.MealMacros], protein: String) -> [MealItem] {
    // Breakfast: always eggs regardless of lunch/dinner preference
    let bFoods = m.count > 1 ? DietPlan.foodAmounts(mealMacros: m[1], preferredProtein: "eggs", isBreakfast: true) : nil
    let lFoods = m.count > 2 ? DietPlan.foodAmounts(mealMacros: m[2], preferredProtein: protein, isBreakfast: false) : nil
    let dFoods = m.count > 4 ? DietPlan.foodAmounts(mealMacros: m[4], preferredProtein: protein, isBreakfast: false) : nil

    // Breakfast protein — always eggs, scale count to target
    let bProteinLine: String = {
        let count = bFoods?.proteinSourceGrams ?? 5
        if count <= 4 {
            return "\(count) whole eggs — boil or scramble same morning"
        } else {
            // 3 whole + remainder as whites keeps it practical
            let whites = count - 3
            return "3 whole eggs + \(whites) egg whites — boil same morning, 10 min"
        }
    }()
    let bCarbLine = bFoods.map { "\($0.carbsGrams)g \($0.carbsLabel) cooked in water (microwave, 3 min) + banana sliced in" }
        ?? "50g dry oats cooked in water (microwave, 3 min) + 1 banana sliced in"

    // Lunch protein — chicken or fish from batch
    // Show raw target AND cooked fridge equivalent so both cook-day and fridge-day are clear.
    let lProteinLine: String = {
        guard let f = lFoods else {
            return protein == "fish"
                ? "180g raw white fish (tilapia / basa) — or ≈135g cooked from fridge"
                : "200g raw chicken breast — or ≈144g cooked from fridge"
        }
        switch protein {
        case "fish":
            let cooked = Int((Double(f.proteinSourceGrams) * 0.75).rounded())
            return "\(f.proteinSourceGrams)g raw \(f.proteinSourceLabel) — cook day: weigh raw. Fridge day: weigh ≈\(cooked)g cooked"
        case "eggs":
            return "\(f.proteinSourceGrams) eggs — fresh or from fridge"
        default: // chicken
            let cooked = Int((Double(f.proteinSourceGrams) * 0.72).rounded())
            return "\(f.proteinSourceGrams)g raw \(f.proteinSourceLabel) — cook day: weigh raw. Fridge day: weigh ≈\(cooked)g cooked"
        }
    }()
    let lCarbLine = lFoods.map { "\($0.carbsGrams)g \($0.carbsLabel) → ~\(Int(Double($0.carbsGrams) * 2.5))g cooked — measure dry before water" }
        ?? "90g dry sona masoori rice → ~225g cooked — measure dry before water"

    // Dinner protein — chicken or fish
    let dProteinLine: String = {
        guard let f = dFoods else {
            return protein == "fish"
                ? "180g raw white fish (tilapia / basa) — cook fresh, or ≈135g cooked from fridge"
                : "170g raw chicken breast — cook fresh, or ≈122g cooked from fridge"
        }
        switch protein {
        case "fish":
            let cooked = Int((Double(f.proteinSourceGrams) * 0.75).rounded())
            return "\(f.proteinSourceGrams)g raw \(f.proteinSourceLabel) — cook fresh, or ≈\(cooked)g cooked from fridge"
        case "eggs":
            return "\(f.proteinSourceGrams) eggs — scrambled or boiled"
        default: // chicken
            let cooked = Int((Double(f.proteinSourceGrams) * 0.72).rounded())
            return "\(f.proteinSourceGrams)g raw \(f.proteinSourceLabel) — cook fresh, or ≈\(cooked)g cooked from fridge"
        }
    }()
    let dCarbLine = dFoods.map { "\($0.carbsGrams)g \($0.carbsLabel) cooked fresh OR 1 medium sweet potato OR 2 rotis" }
        ?? "90g dry sona masoori rice cooked fresh OR 1 medium sweet potato OR 2 rotis"

    let lunchNote = protein == "fish"
        ? "Rice: always cook fresh — measure the dry grams shown before adding water. Fish: on cook-day weigh raw; on fridge-day take out cooked portion and weigh it (shown in brackets). Fish keeps max 2 days cooked. Veg from fridge, 2 min microwave."
        : "Rice: always cook fresh — measure the dry grams shown before adding water. Chicken: on Sunday or Wednesday evening cook-day weigh raw before grilling; on other days take cooked chicken from fridge and weigh the cooked portion shown in brackets. Chicken keeps 4 days cooked. Eat this meal properly — not at a desk."

    let dinnerNote = protein == "fish"
        ? "Pan-fry the fish in olive oil — 3 min each side, done. Salad always fresh. Olive oil provides healthy fats for hormone production. Gram amounts shown are RAW weight — weigh before cooking."
        : "Dinner is hearty — you've worked out and need to recover overnight. Olive oil provides healthy fats for hormone production. Salad always fresh. Gram amounts shown are RAW weight — weigh and season before cooking."

    return [
        MealItem(
            time: "6:45 AM", name: "Pre-Workout",
            ingredients: [
                "1 scoop whey protein in 300ml water",
                "1 piece of this week's fruit — banana: 1 medium (~120 g); grapes: weigh 150 g (~22 grapes)",
                "Optional: 5g creatine stirred into the shake",
            ],
            macros: m.count > 0 ? m[0].summary : "",
            notes: "Take this 20–30 min before your morning workout. Quick carbs from fruit + fast protein = better performance and less muscle breakdown during the session. Skip on rest days — have the shake with breakfast instead."
        ),
        MealItem(
            time: "8:15 AM", name: "Breakfast",
            ingredients: [
                bProteinLine,
                bCarbLine,
                "1 Thorne Basic Nutrients capsule",
            ],
            macros: m.count > 1 ? m[1].summary : "",
            notes: "Eggs and oats can cook in parallel — oats in the microwave (3 min), eggs on the stove (10 min). The banana goes into the oats, not as a separate snack. Scrambled eggs work equally well."
        ),
        MealItem(
            time: "12:30 PM", name: "Lunch",
            ingredients: [
                lProteinLine,
                lCarbLine,
                "Steamed broccoli + carrot — batch-cooked, reheat 2 min",
            ],
            macros: m.count > 2 ? m[2].summary : "",
            notes: lunchNote
        ),
        MealItem(
            time: "4:30 PM", name: "Snack",
            ingredients: [
                "2–3 hard-boiled eggs + 20g almonds (from batch-boiled eggs)",
                "OR: 180g plain Greek yogurt + 15g almonds",
            ],
            macros: m.count > 3 ? m[3].summary : "",
            notes: "Eggs are always in the fridge from your batch cook — grab and go. Pre-bag almonds on Sunday into 7 daily portions so you don't have to think about it mid-afternoon."
        ),
        MealItem(
            time: "7:30 PM", name: "Dinner",
            ingredients: [
                dProteinLine,
                "Fresh salad: lettuce + cucumber + tomato + lemon (3 min to chop)",
                dCarbLine,
                "1 tbsp olive oil on salad or to cook the protein",
                "1 Thorne Basic Nutrients capsule",
            ],
            macros: m.count > 4 ? m[4].summary : "",
            notes: dinnerNote
        ),
    ]
}

private let supplementPlan: [(String, String)] = [
    ("Breakfast",    "1× Thorne Basic Nutrients — take with food"),
    ("Dinner",       "1× Thorne Basic Nutrients — take with food"),
    ("Pre-Workout",  "1 scoop whey + fruit — this is meal 2 in the plan above"),
    ("Optional",     "Creatine monohydrate 5g — stir into pre-workout shake, any time of day. Loading not required; consistent daily use is what matters."),
    ("Optional",     "Omega-3 fish oil: 2–3g EPA+DHA per day — take with dinner (dietary fat improves absorption by 30–50%). Use triglyceride-form fish oil, not ethyl ester. 2–3 capsules of a quality concentrate (look for ≥900mg EPA+DHA per cap) covers the target. Skip if you eat fatty fish 3+ times per week. Source: ISSN Position Stand on omega-3."),
    ("Optional",     "Magnesium glycinate or malate: 300–400mg elemental magnesium at bedtime. Oxide form absorbs poorly (~4%) — avoid it. Glycinate is the least disruptive to digestion and promotes sleep quality. Malate suits those who train in the evening. Magnesium supports sleep quality, muscle recovery, and testosterone production. Source: ACSM; EFSA."),
    ("Note",         "On rest days skip the pre-workout shake. Add 30g oats to breakfast instead."),
]

private func buildPrepSections(
    protein: String,
    lProteinGrams: Int,
    dProteinGrams: Int,
    lCarbGrams: Int,
    dCarbGrams: Int,
    snackProtein: Int
) -> [PrepSection] {
    let isFish = protein == "fish"
    let weeklyEggs = Int(ceil(Double(snackProtein) / 6.0)) * 7

    // Chicken: Sunday 4-day batch (Sun/Mon/Tue/Wed), Wednesday evening 3-day batch (Thu/Fri/Sat)
    let sunChickenRaw    = lProteinGrams * 4 + dProteinGrams * 4
    let sunChickenCooked = Int((Double(sunChickenRaw) * 0.72).rounded())
    let wedChickenRaw    = lProteinGrams * 3 + dProteinGrams * 3
    let wedChickenCooked = Int((Double(wedChickenRaw) * 0.72).rounded())

    // Fish: 2-day batch (cooked fish keeps max 2 days in fridge)
    let fishBatchRaw = lProteinGrams * 2 + dProteinGrams * 2
    let fishBatchLabel = fishBatchRaw >= 1000
        ? String(format: "%.1fkg", Double(fishBatchRaw) / 1000.0)
        : "\(fishBatchRaw)g"

    // Rice cooked equivalents (dry × 2.5 for sona masoori)
    let lCookedRice = Int((Double(lCarbGrams) * 2.5).rounded())
    let dCookedRice = Int((Double(dCarbGrams) * 2.5).rounded())

    let sundayCook = PrepSection(
        icon: "flame", title: "Sunday Cook",
        badge: "SUN",
        items: isFish ? [
            "Buy \(fishBatchLabel) raw tilapia/basa (L:\(lProteinGrams)g + D:\(dProteinGrams)g × 2 days) — covers Sun + Mon (max 2 days cooked)",
            "Pan-fry in batches: 3 min each side on medium-high, season with lemon + cumin + salt",
            "Portion into containers labelled SUN / MON — fridge immediately after cooling",
            "Steam 400g broccoli + 300g carrot — portion into 4 lunch containers",
            "Hard-boil \(weeklyEggs) eggs — leave unpeeled in fridge (lasts all week)",
            "Pre-bag 7 × 20g almond portions into small zip bags",
        ] : [
            "Grill \(sunChickenRaw)g raw chicken breast (L:\(lProteinGrams)g + D:\(dProteinGrams)g × 4 days) → ~\(sunChickenCooked)g cooked",
            "Season with cumin, garlic powder, salt, light olive oil spray",
            "Label containers: SUN / MON / TUE / WED — fridge immediately after cooling",
            "Steam 400g broccoli + 300g carrot — portion into 4 lunch containers",
            "Hard-boil \(weeklyEggs) eggs — leave unpeeled in fridge (lasts all week)",
            "Pre-bag 7 × 20g almond portions into small zip bags",
        ],
        note: isFish
            ? "Cooked fish: 2 days max in fridge — buy again Tuesday. Steamed veg: 3–4 days. Boiled eggs unpeeled: 7 days."
            : "Cooked chicken: 4 days max in fridge — carries you through Wednesday. Steamed veg keeps 3–4 days. Boiled eggs unpeeled: 7 days."
    )

    let midweekRefresh = PrepSection(
        icon: "arrow.clockwise", title: isFish ? "Tuesday + Thursday Refresh" : "Wednesday Evening Cook",
        badge: isFish ? "TUE/THU" : "WED EVE",
        items: isFish ? [
            "Buy another \(fishBatchLabel) raw fish on Tuesday (L:\(lProteinGrams)g + D:\(dProteinGrams)g × 2 days) — covers Tue + Wed",
            "Buy \(fishBatchLabel) more raw fish on Thursday (same amounts) — covers Thu + Fri",
            "Saturday: cook 1 fresh portion or eat out",
            "Same cook method: pan-fry in batches, 3 min each side",
            "Steam capsicum + zucchini this time for variety",
            "Top up eggs if running below 6",
            "Restock: rice, yogurt, salad veg, almonds, this week's fruit",
        ] : [
            "Grill \(wedChickenRaw)g raw chicken breast (L:\(lProteinGrams)g + D:\(dProteinGrams)g × 3 days) → ~\(wedChickenCooked)g cooked — same method as Sunday",
            "Steam broccoli + capsicum — portion into 3 lunch containers",
            "Hard-boil 6 more eggs if running low",
            "Restock: buy rice, yogurt, salad veg, almonds, and this week's fruit",
            "Label containers THU / FRI / SAT",
        ],
        note: isFish
            ? "Fish cooks in under 10 minutes — do it the evening before or morning of. No long batch session needed."
            : "Takes around 45 minutes. Covers the rest of the week — Thursday, Friday, Saturday."
    )

    let storageItems: [String] = isFish ? [
        "Cooked fish — airtight container, fridge, 2 days maximum",
        "Raw fish — fridge max 1–2 days, or freeze immediately",
        "Steamed vegetables — airtight container, fridge, 3–4 days",
        "Boiled eggs unpeeled — fridge, up to 7 days",
        "Greek yogurt — original pot, check use-by date",
        "Almonds — pre-portioned bags, room temperature is fine",
        "Dry rice and oats — pantry, no expiry concern",
    ] : [
        "Cooked chicken — airtight container, fridge, 4 days maximum",
        "Steamed vegetables — airtight container, fridge, 3–4 days",
        "Boiled eggs unpeeled — fridge, up to 7 days",
        "Greek yogurt — original pot, check use-by date",
        "Almonds — pre-portioned bags, room temperature is fine",
        "Dry rice and oats — pantry, no expiry concern",
    ]

    return [
        PrepSection(
            icon: "calendar", title: "What you cook, and when",
            badge: nil,
            items: isFish ? [
                "Sunday — first cook: Sun + Mon fish",
                "Tuesday — refresh: Tue + Wed fish",
                "Thursday — refresh: Thu + Fri fish",
                "Saturday — cook fresh or eat out",
                "Rice, eggs, salad: always cooked or assembled fresh the same day",
            ] : [
                "Sunday — big cook (4 days): covers Sunday, Monday, Tuesday, Wednesday",
                "Wednesday evening — cook (3 days): covers Thursday, Friday, Saturday",
                "Rice, eggs, salad: always cooked or assembled fresh the same day",
            ],
            note: "Everything fits in one fridge shelf across containers labelled by day."
        ),
        sundayCook,
        midweekRefresh,
        PrepSection(
            icon: "water.waves", title: "Rice — Cook Fresh Daily",
            badge: "DAILY",
            items: [
                "Lunch: \(lCarbGrams)g dry sona masoori rice — 1 part rice to 1.5 parts water",
                "Dinner: \(dCarbGrams)g dry sona masoori rice — same method, same time",
                "Bring to boil, lid on, low heat, 12 minutes, do not lift the lid",
                "Lunch comes to ~\(lCookedRice)g cooked; dinner ~\(dCookedRice)g cooked",
                "Do not refrigerate and reheat. Refrigerated rice turns dense and starchy.",
            ],
            note: nil
        ),
        PrepSection(
            icon: "leaf", title: "Salad — Assemble Fresh Daily",
            badge: "DAILY",
            items: [
                "Quarter iceberg lettuce, half cucumber, one tomato — roughly chop",
                "Squeeze of lemon, pinch of salt, optional half tbsp olive oil",
                "Three minutes start to finish. Do not pre-make — lettuce wilts badly.",
            ],
            note: nil
        ),
        PrepSection(
            icon: "snowflake", title: "Storage Reference",
            badge: nil,
            items: storageItems,
            note: isFish
                ? "If fish smells off or looks cloudy — bin it without hesitation. Never worth the risk."
                : "If chicken smells off or looks grey — bin it without hesitation. Never worth the risk."
        ),
    ]
}

// MARK: - Reusable subviews

struct MealCard: View {
    let meal: MealItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(meal.time)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentGreen)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.accentGreen.opacity(0.12))
                    .cornerRadius(4)
                Text(meal.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primaryText)
                Spacer()
            }

            Text(meal.macros)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondaryText)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(meal.ingredients, id: \.self) { ingredient in
                    HStack(alignment: .top, spacing: 10) {
                        Rectangle()
                            .fill(Color.accentGreen)
                            .frame(width: 3, height: 3)
                            .padding(.top, 6)
                        Text(ingredient)
                            .font(.system(size: 13))
                            .foregroundColor(.primaryText)
                    }
                }
            }

            if !meal.notes.isEmpty {
                Text(meal.notes)
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cellBackground)
                    .cornerRadius(6)
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cellBorder, lineWidth: 1))
    }
}

struct InfoCard: View {
    let rows: [(String, String)]
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                HStack(alignment: .top, spacing: 12) {
                    Text(row.0)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(accentColor)
                        .frame(width: 90, alignment: .leading)
                    Text(row.1)
                        .font(.system(size: 13))
                        .foregroundColor(.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(idx % 2 == 0 ? Color.cardBackground : Color.rowAltBackground)
            }
        }
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cellBorder, lineWidth: 1))
    }
}
