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
                prepCard
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
            HStack {
                Text("DAILY TARGETS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondaryText)
                    .tracking(0.8)
                Spacer()
                Text(store.latestWeight != nil
                     ? String(format: "Based on %.0f kg", w)
                     : "Log weight to personalise")
                    .font(.system(size: 10))
                    .foregroundColor(.secondaryText)
            }
            Text("~\(totalKcal) kcal · TDEE ~\(Int(store.tdeeValue ?? 0)) · \(store.intensityMode.deficitLabel).")
                .font(.system(size: 11))
                .foregroundColor(.secondaryText)
                .padding(.bottom, 4)

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
            ? [("Banana",  "Pre-workout — 1 medium, grab and go, no prep",    "~27g carbs, quick energy"),
               ("Apple",   "Afternoon snack — any variety, eat whole",        "~21g carbs, 4g fibre")]
            : [("Grapes",  "Pre-workout or snack — 150g handful, no cutting", "~26g carbs, easy to portion"),
               ("Pear",    "Afternoon snack — eat whole, pairs with almonds", "~21g carbs, good fibre")]

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

    private var prepCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(prepSections) { section in
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

                if section.id != prepSections.last?.id {
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

private func mealPlan(from m: [DietPlan.MealMacros], protein: String) -> [MealItem] {
    // Pre-compute dynamic amounts for meals that need them
    let bFoods = m.count > 1 ? DietPlan.foodAmounts(mealMacros: m[1], preferredProtein: protein, isBreakfast: true)  : nil
    let lFoods = m.count > 2 ? DietPlan.foodAmounts(mealMacros: m[2], preferredProtein: protein, isBreakfast: false) : nil
    let dFoods = m.count > 4 ? DietPlan.foodAmounts(mealMacros: m[4], preferredProtein: protein, isBreakfast: false) : nil

    // Breakfast protein line
    let bProteinLine: String = {
        guard let f = bFoods else { return "3 whole eggs + 2 egg whites — boil same morning, 10 min" }
        switch protein {
        case "eggs":   return "\(f.proteinSourceGrams) whole eggs — boil same morning, 10 min"
        case "fish":   return "\(f.proteinSourceGrams)g white fish — pan-fry or poach, 8 min"
        default:       return "\(f.proteinSourceGrams)g chicken breast — from batch cook, reheat 2 min"
        }
    }()
    let bCarbLine = bFoods.map { "\($0.carbsGrams)g \($0.carbsLabel) cooked in water (microwave, 3 min)" }
        ?? "50g dry oats cooked in water (microwave, 3 min) + 1 banana sliced in"

    // Lunch protein line
    let lProteinLine: String = {
        guard let f = lFoods else { return "200g chicken breast — from Sunday or Wednesday batch" }
        if f.isEggs { return "\(f.proteinSourceGrams) hard-boiled eggs — from batch cook" }
        return "\(f.proteinSourceGrams)g \(f.proteinSourceLabel) — from Sunday or Wednesday batch"
    }()
    let lCarbLine = lFoods.map { "\($0.carbsGrams)g \($0.carbsLabel) cooked fresh (→ ~\(Int(Double($0.carbsGrams) * 2.2))g cooked)" }
        ?? "90g dry basmati rice cooked fresh (→ ~200g cooked)"

    // Dinner protein line
    let dProteinLine: String = {
        guard let f = dFoods else { return "170g chicken breast or 180g white fish (tilapia / basa)" }
        if f.isEggs { return "\(f.proteinSourceGrams) whole eggs — scrambled or omelette with olive oil" }
        return "\(f.proteinSourceGrams)g \(f.proteinSourceLabel) — grilled or pan-fried"
    }()
    let dCarbLine = dFoods.map { "\($0.carbsGrams)g \($0.carbsLabel) cooked fresh OR 1 medium sweet potato OR 2 rotis" }
        ?? "90g dry rice cooked fresh OR 1 medium sweet potato OR 2 rotis"

    return [
        MealItem(
            time: "6:45 AM", name: "Pre-Workout",
            ingredients: [
                "1 scoop whey protein in 300ml water",
                "1 piece of this week's fruit (banana or grapes)",
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
            notes: "Quick morning cook — protein and oats can be done in parallel. The banana goes into the oats, not as a separate snack."
        ),
        MealItem(
            time: "12:30 PM", name: "Lunch",
            ingredients: [
                lProteinLine,
                lCarbLine,
                "Steamed broccoli + carrot — batch-cooked, reheat 2 min",
            ],
            macros: m.count > 2 ? m[2].summary : "",
            notes: "Rice cooks fresh daily — start it when you get in, 12 min. Protein and veg come straight from the fridge, 2 min microwave. This is the largest meal of the day — eat it properly, not at a desk."
        ),
        MealItem(
            time: "4:30 PM", name: "Snack",
            ingredients: [
                "Option A: 180g plain Greek yogurt + 15g almonds",
                "Option B: 2 hard-boiled eggs + 20g almonds",
            ],
            macros: m.count > 3 ? m[3].summary : "",
            notes: "Pick one option, not both. Pre-bag almonds on Sunday into 7 daily portions so you don't have to think about it mid-afternoon."
        ),
        MealItem(
            time: "7:30 PM", name: "Dinner",
            ingredients: [
                dProteinLine,
                "Fresh salad: lettuce + cucumber + tomato + lemon (3 min to chop)",
                dCarbLine,
                "1 tbsp olive oil on salad or used to cook the protein",
                "1 Thorne Basic Nutrients capsule",
            ],
            macros: m.count > 4 ? m[4].summary : "",
            notes: "Dinner is hearty — you've worked out and need to recover overnight. Olive oil provides healthy fats for hormone production. Salad always fresh."
        ),
    ]
}

private let supplementPlan: [(String, String)] = [
    ("Breakfast",    "1× Thorne Basic Nutrients — take with food"),
    ("Dinner",       "1× Thorne Basic Nutrients — take with food"),
    ("Pre-Workout",  "1 scoop whey + fruit — this is meal 2 in the plan above"),
    ("Optional",     "Creatine monohydrate 5g — stir into pre-workout shake, any time of day"),
    ("Note",         "On rest days skip the pre-workout shake. Add 30g oats to breakfast instead."),
]

private let prepSections: [PrepSection] = [
    PrepSection(
        icon: "calendar", title: "What you cook, and when",
        badge: nil,
        items: [
            "Sunday — big cook: covers Sunday, Monday, Tuesday",
            "Wednesday — refresh cook: covers Wednesday, Thursday, Friday",
            "Saturday — covers itself only, or eat out",
            "Rice, eggs, salad: always cooked or assembled fresh the same day",
        ],
        note: "Everything fits in one fridge shelf across 3 meal-prep containers labelled by day."
    ),
    PrepSection(
        icon: "flame", title: "Sunday Cook",
        badge: "SUN",
        items: [
            "Grill 1.1kg raw chicken breast — comes to roughly 800g cooked",
            "Season with cumin, garlic powder, salt, light olive oil spray",
            "Portion into 200g lunch + 170g dinner bags, label MON / TUE / WED-L",
            "Steam 400g broccoli + 300g carrot — portion into 3 lunch containers",
            "Hard-boil 12 eggs — leave unpeeled in fridge",
            "Pre-bag 7 × 15g almond portions into small zip bags",
        ],
        note: "Cooked chicken: 4 days max in fridge. Steamed veg: 3–4 days. Boiled eggs unpeeled: 7 days."
    ),
    PrepSection(
        icon: "arrow.clockwise", title: "Wednesday Refresh",
        badge: "WED",
        items: [
            "Grill another 1.1kg raw chicken breast — same method as Sunday",
            "Steam broccoli + capsicum this time for variety",
            "Hard-boil 6 more eggs if running low",
            "Restock: buy rice, yogurt, salad veg, almonds, and this week's fruit",
            "Label containers THU / FRI / SAT",
        ],
        note: "Takes around 45 minutes. Put it on while you're doing something else."
    ),
    PrepSection(
        icon: "water.waves", title: "Rice — Cook Fresh Daily",
        badge: "DAILY",
        items: [
            "Lunch: 90g dry basmati — 1 part rice to 1.5 parts water",
            "Dinner: 90g dry basmati — same method, same time",
            "Bring to boil, lid on, low heat, 12 minutes, do not lift the lid",
            "Comes to roughly 200g cooked per cook — one serving",
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
        items: [
            "Cooked chicken — airtight container, fridge, 4 days maximum",
            "Steamed vegetables — airtight container, fridge, 3–4 days",
            "Boiled eggs unpeeled — fridge, up to 7 days",
            "Greek yogurt — original pot, check use-by date",
            "Almonds — pre-portioned bags, room temperature is fine",
            "Dry rice and oats — pantry, no expiry concern",
        ],
        note: "If chicken smells off or looks grey — bin it without hesitation. Never worth the risk."
    ),
]

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
