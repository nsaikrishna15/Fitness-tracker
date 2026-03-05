# BodyPhase

An iOS body-transformation app built with SwiftUI. Tracks daily habits, progressive-overload strength training, and a fully personalised nutrition plan — all derived mathematically from the user's body statistics and goal body fat percentage.

---

## Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Build and Run](#build-and-run)
- [First Launch](#first-launch)
- [How Calculations Work](#how-calculations-work)
- [Exercise Program](#exercise-program)
- [Nutrition Plan](#nutrition-plan)
- [Food Amounts and Measurements](#food-amounts-and-measurements)
- [App Architecture](#app-architecture)
- [Data Persistence](#data-persistence)
- [Notifications](#notifications)
- [Project File Generation](#project-file-generation)

---

## Overview

BodyPhase is a 120-day structured program that combines:

- A daily habit checklist covering sleep, hydration, sun exposure, meals, and workouts
- A 4-phase progressive-overload gym program built around a small commercial gym (dual cable machine, leg press, leg extension/curl, dumbbells, kettlebells, adjustable bench)
- A fully dynamic nutrition plan that calculates every macro and ingredient gram amount from the user's current body stats — no hardcoded numbers in the UI

Everything adapts automatically when the user logs a new weight or updates their settings.

---

## Requirements

| Tool | Minimum version |
|---|---|
| Xcode | 16.0 |
| iOS deployment target | 16.0 |
| Swift | 5.9 |
| xcodegen | 2.x (only required to regenerate `.xcodeproj` after editing `project.yml`) |

---

## Build and Run

### Option A — Open directly (no dependencies)

```bash
git clone https://github.com/nsaikrishna15/Fitness-tracker.git
cd Fitness-tracker
open BodyPhase.xcodeproj
```

Select a simulator or connected device from the Xcode toolbar and press Cmd+R.

### Option B — Regenerate the project file

Only needed if you have edited `project.yml`.

```bash
brew install xcodegen
xcodegen generate
open BodyPhase.xcodeproj
```

### Build from the command line

```bash
xcodebuild \
  -project BodyPhase.xcodeproj \
  -scheme BodyPhase \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

### Physical device

1. Open `BodyPhase.xcodeproj` in Xcode.
2. Select your iPhone from the destination picker.
3. Under Signing and Capabilities, set your Apple ID as the Team.
4. Press Cmd+R.

Free Apple Developer accounts produce 7-day certificates. The app must be re-signed after 7 days. A paid Apple Developer Program membership ($99/year) is required for TestFlight distribution and 1-year certificates.

---

## First Launch

The onboarding screen collects six inputs. All nutrition and workout targets are derived from these values and can be updated at any time in Settings.

| Input | How it is used |
|---|---|
| Biological sex | BMR formula constant; body fat formula sex coefficient |
| Height (cm) | BMI calculation; Deurenberg body fat estimate |
| Current weight (kg) | BMR; TDEE; all macro targets; lean body mass; goal weight |
| Age (years) | BMR; Deurenberg body fat estimate |
| Target body fat % | IntensityMode selection; goal weight calculation |
| Preferred protein source | Selects chicken or fish gram amounts in meal plan |
| Program start date | Determines current phase (1-4) and locks past/future days |

---

## How Calculations Work

All formulas live in `Models/DietPlan.swift`. There are no hardcoded macro values anywhere in the UI — every number shown is computed at runtime from the user's stored stats.

### Basal Metabolic Rate

Mifflin-St Jeor (1990) — the most validated BMR equation per ACSM guidelines.

```
Male:   BMR = (10 x weight_kg) + (6.25 x height_cm) - (5 x age) + 5
Female: BMR = (10 x weight_kg) + (6.25 x height_cm) - (5 x age) - 161
```

### Total Daily Energy Expenditure

BMR multiplied by an ACSM activity factor that increases with program phase.

| Phase | Days | Activity factor |
|---|---|---|
| Phase 1 — Foundation | 1-30 | 1.375 (light activity) |
| Phase 2 — Volume | 31-60 | 1.550 (moderate activity) |
| Phase 3 — Strength | 61-90 | 1.725 (very active) |
| Phase 4 — Peak | 91-120 | 1.725 (very active) |

### Estimated Body Fat Percentage

Deurenberg et al. (1991), derived from BMI, age, and sex.

```
Male:   BF% = (1.20 x BMI) + (0.23 x age) - 16.2
Female: BF% = (1.20 x BMI) + (0.23 x age) - 5.4
```

Result is clamped to [3, 60] to prevent physiologically impossible values. This estimate can overestimate body fat in highly muscular individuals and underestimate it in the elderly.

### IntensityMode

The gap between estimated current body fat and the user's target body fat determines the daily calorie adjustment.

| Current BF% minus target BF% | Mode | Daily calorie adjustment |
|---|---|---|
| Greater than 10 | Aggressive Cut | -750 kcal |
| 5 to 10 | Standard Cut | -500 kcal |
| 2 to 5 | Mild Cut | -250 kcal |
| 0 to 2 | Recomp | 0 kcal |
| Below 0 | Bulk | +200 kcal |

IntensityMode is a computed property on HabitStore. It updates reactively whenever the user logs a new weight or changes their target body fat in Settings.

### Target Daily Calories

```
target_kcal = max(TDEE - deficit, calorie_floor)
calorie_floor = 1500 kcal (male) / 1200 kcal (female)
```

The floor prevents the plan from dropping below safe minimum intake thresholds per WHO and ACSM.

### Lean Body Mass

```
LBM_kg = weight_kg x (1 - estimated_BF% / 100)
```

LBM is the basis for the protein target rather than total body weight. Using total body weight for overweight individuals inflates the protein requirement significantly. Example: a 100 kg person at 30% body fat receives 220 g/day on total weight vs the correct 154 g/day on LBM. The excess protein displaces carbohydrates and makes the plan unsustainable.

### Protein Target

```
protein_g = LBM_kg x 2.2
```

Source: ISSN 2017 Position Stand; Phillips and Van Loon (2011). The 2.2 g/kg LBM value is within the ISSN-recommended range of 2.3-3.1 g/kg LBM for athletes in a caloric deficit seeking to preserve lean mass. Falls back to total body weight when body composition data is unavailable (height or age not entered).

### Fat Target

```
fat_g = max(target_kcal x 0.25 / 9,  weight_kg x 0.5)
```

Fat is set to 25% of total calories, with a minimum floor of 0.5 g/kg total body weight to preserve hormonal function (testosterone production, fat-soluble vitamin absorption). Source: ACSM; ISSN.

### Carbohydrate Target

```
carbs_g = (target_kcal - (protein_g x 4) - (fat_g x 9)) / 4
```

Carbohydrates fill the remaining calories after protein and fat are allocated.

Caloric densities used throughout: protein 4 kcal/g, carbohydrate 4 kcal/g, fat 9 kcal/g (Atwater factors).

### Goal Weight

Goal weight is calculated from lean body mass and the user's target body fat percentage. BMI is not used as a physique target — it is a population-level screening tool and sets unrealistic individual targets. A lean athletic male at 180 cm with 15% body fat will naturally sit at BMI 24-25, not BMI 22.

```
goal_weight_kg = LBM_kg / (1 - target_BF% / 100)
```

Example: 93 kg at 25% estimated body fat, targeting 15% body fat.

```
LBM         = 93 x 0.75         = 69.75 kg
Goal weight = 69.75 / 0.85      = 82.1 kg
```

The app also calculates the user's BMI at their goal weight for informational context.

### Weight Loss Timeline

```
weekly_loss_kg = daily_deficit_kcal x 7 / 7700
weeks_to_goal  = ceil((current_weight - goal_weight) / weekly_loss_kg)
```

Source: Wishnofsky (1958). 1 kg of body fat contains approximately 7,700 kcal. This is a linear estimate and does not account for metabolic adaptation. Returns nil for recomp and bulk modes.

### Hydration Target

```
water_litres = clamp(weight_kg x 0.035, min=3.0, max=5.0)
```

Source: EFSA guidelines. The 35 ml/kg formula is standard in clinical and sports nutrition. The 3-litre minimum reflects active daily training. The 5-litre cap prevents excessive intake.

### Meal Distribution

Total daily macros are split across 5 meals in fixed ratios, front-loading carbohydrates around the morning training window.

| Meal | Time | Protein | Carbs | Fat |
|---|---|---|---|---|
| Pre-Workout | 6:45 AM | 13% | 21% | 7% |
| Breakfast | 8:15 AM | 22% | 23% | 25% |
| Lunch | 12:30 PM | 29% | 31% | 16% |
| Snack | 4:30 PM | 12% | 5% | 25% |
| Dinner | 7:30 PM | 24% | 20% | 27% |

---

## Exercise Program

### Weekly Schedule

The schedule is fixed for all 120 days. Phase affects only sets, reps, and weight — not which movement is trained on which day.

| Day | Session | Primary focus |
|---|---|---|
| Monday | Upper A | Compound push and pull; chest, back, shoulders, triceps |
| Tuesday | Lower A | Quad dominant; leg press, goblet squat, hamstring curl, reverse lunge |
| Wednesday | Cardio | Conditioning; walk to KB circuit to HIIT across phases |
| Thursday | Upper B | Incline press, lat pulldown, lateral raise, face pull, bicep curl |
| Friday | Cardio | Active recovery; steady-state walk or incline walk |
| Saturday | Lower B | Posterior chain; RDL, hip thrust, leg extension, kettlebell swing |
| Sunday | Rest | Full rest |

All gym days include an evening session: foam rolling, full-body stretch, dead bug core hold, and kegel holds.

### Phase Progression

| Phase | Days | Sets | Reps (compound) | Reps (isolation) |
|---|---|---|---|---|
| 1 — Foundation | 1-30 | 3 | 12 | 15 |
| 2 — Volume | 31-60 | 4 | 10 | 12 |
| 3 — Strength | 61-90 | 4 | 8 | 10 |
| 4 — Peak | 91-120 | 4 | 6-8 | 10-12 |

### Progressive Overload Engine

Every exercise tracks a current working weight in `Models/WorkoutProgression.swift`. Rules applied after each logged session:

- All sets completed at target reps: weight increases by the exercise increment
- One failed session: weight stays the same
- Two consecutive failed sessions: weight reduces by 10%, rounded to nearest 2.5 kg
- Deload week (program days 50-56): no progression, no penalty

Weight increments by exercise category:

| Category | Increment per session |
|---|---|
| Leg press (both sides) | 5.0 kg |
| Kettlebell swing | 4.0 kg (tracks standard KB sizes: 12, 16, 20, 24, 28, 32 kg) |
| All other lower body | 2.5 kg |
| All upper body | 2.5 kg |
| Bodyweight and cardio | None |

Starting weights are calibrated for a 90 kg user and scaled linearly for other body weights, then rounded to the nearest 2.5 kg.

### Equipment

The program is designed around the following equipment and is compatible with any small commercial gym.

| Equipment | Used for |
|---|---|
| Hoist Dual Cable Functional Trainer (HD-3000) | Lat pulldown (wide and narrow grip), cable row, cable face pull, cable tricep pushdown; pull-up bar for hanging knee raise |
| Hoist Leg Press | Quad-stance (Tuesday), glute-stance (Saturday) |
| Hoist Leg Extension/Curl combo | Leg extension, hamstring curl |
| Adjustable FID bench | Flat dumbbell bench press, incline dumbbell press, dumbbell hip thrust |
| Dumbbells (full rack) | Shoulder press, bicep curl, lateral raise, Romanian deadlift, reverse lunge, goblet squat |
| Kettlebells | Goblet squat, kettlebell swing |
| Foam roller | Evening recovery |
| Bodyweight | Plank, dead bug, kegels |

All machine exercises have noted alternatives for users without gym access.

---

## Nutrition Plan

### Protein Sources

Protein gram amounts shown in the meal plan are **raw weight** — weigh before cooking, as the ingredient comes off the store packaging. This is the standard used by USDA, MyFitnessPal, and Cronometer, and matches how food is bought and portioned in practice.

| Source | USDA protein per 100g raw | Gram formula |
|---|---|---|
| Chicken breast (boneless, skinless) | 23.2 g | target_protein x (100 / 23.2) |
| Tilapia / white fish | 20.1 g | target_protein x (100 / 20.1) |
| Eggs | 6.0 g per large egg | ceil(target_protein / 6) |

Source: USDA FoodData Central SR Legacy — FDC #171477 (chicken), FDC #175177 (tilapia), FDC #748967 (egg).

Note on basa: basa (Pangasius hypophthalmus) contains approximately 14.7 g protein per 100 g raw per FSANZ NUTTAB, which is materially lower than tilapia. The app uses tilapia values for all white fish. Users buying basa should either increase the portion or substitute tilapia.

### Carbohydrate Sources

Carbohydrate gram amounts are **dry weight** — measure before adding water or cooking.

| Source | USDA carbs per 100g dry | Reference portion | Carbs in reference portion |
|---|---|---|---|
| Rolled oats | 66.3 g | 40 g dry | 26.5 g |
| Basmati rice (long-grain white) | 79.3 g | 50 g dry | 39.7 g |

Source: USDA FoodData Central SR Legacy — FDC #173904 (oats), FDC #169756 (rice).

Gram formulas:

```
Oats: carb_target x (40 / 26.5)
Rice: carb_target x (50 / 39.7)
```

Cooked rice reference weight shown in the UI: dry_weight x 2.4 (1:1.5 water absorption method, stovetop).

### Fruit Carb Reference Values

Fruit carbs are shown for reference only and are not included in the meal macro calculation.

| Fruit | Portion | Approximate carbs |
|---|---|---|
| Banana | 1 medium (118 g) | 27 g |
| Apple | 1 medium (182 g) | 25 g |
| Grapes | 150 g | 26 g |
| Pear | 1 medium (178 g) | 27 g |

Source: USDA FoodData Central.

---

## Food Amounts and Measurements

### What to measure raw and what to measure dry

| Ingredient | When to measure | Unit shown in app |
|---|---|---|
| Chicken breast | Before cooking (raw) | grams |
| White fish / tilapia | Before cooking (raw) | grams |
| Eggs | Count only | whole eggs |
| Oats | Before cooking (dry) | grams |
| Basmati rice | Before cooking (dry) | grams |
| Almonds | Pre-portioned from bag | grams (20 g per portion) |
| Greek yogurt | As purchased | grams (180 g) |

### Snack reference nutrition

These are fixed portions and are not recalculated from individual macro targets.

| Option | Protein | Fat | Carbs | Calories |
|---|---|---|---|---|
| 3 eggs + 20 g almonds | 22 g | 20 g | 4 g | 275 kcal |
| 180 g plain nonfat Greek yogurt + 15 g almonds | 21 g | 9 g | 10 g | 193 kcal |

Almond values: USDA FDC #170567 — 20 g = 4.2 g protein, 10.0 g fat, 4.3 g carbs, 2.1 g fibre, 116 kcal.

Greek yogurt values: USDA nonfat plain — 180 g = 18.4 g protein, 1.3 g fat, 6.5 g carbs, 106 kcal.

---

## App Architecture

```
BodyPhase/
  HabitTrackerApp.swift           App entry point (BodyPhaseApp)
  Models/
    DietPlan.swift                All nutrition formulas, IntensityMode enum, FoodAmounts
    Habit.swift                   HabitID enum, HabitDefinition, static daily schedule
    HabitEntry.swift              Logged habit completions (Codable)
    WeightEntry.swift             Daily weight log entries (Codable)
    WorkoutModels.swift           ExerciseDefinition, WorkoutSession, DaySession,
                                  ProgramPhase, WorkoutSchedule
    WorkoutProgression.swift      ProgressionEngine, ProgramDayStore, WorkoutSet
  ViewModels/
    HabitStore.swift              Single ObservableObject; all published state and
                                  computed diet, workout, and body composition values
  Views/
    RootView.swift                Tab bar container
    OnboardingView.swift          First-launch profile setup
    DietView.swift                Full nutrition plan, meal cards, prep guide
    WorkoutView.swift             Workout logging, set tracking
    SettingsView.swift            Profile editing, notification toggle
    WeeklyGridView.swift          Daily habit grid with week navigation
    BodyweightChartView.swift     Weight trend chart
  Services/
    NotificationManager.swift     UNUserNotificationCenter scheduling
    PersistenceManager.swift      JSON serialisation to UserDefaults / iCloud KV store
  Extensions/
    Color+Theme.swift             App colour palette (dark theme)
    Date+Week.swift               ISO week and dateKey helpers
  project.yml                     XcodeGen project specification
```

### State flow

`HabitStore` is the single source of truth, injected as an `@EnvironmentObject` from the app entry point. No view owns persistent state independently. All reads and writes go through `HabitStore`.

Key reactive chain triggered by a new weight log entry:

```
latestWeight changes (Published)
  -> estimatedBodyFatPct recomputes  (Deurenberg formula)
  -> leanBodyMassKg recomputes       (weight x (1 - BF%))
  -> intensityMode recomputes        (BF gap -> cut/recomp/bulk)
  -> targetKcal recomputes           (TDEE - deficit, floored)
  -> dailyProteinG recomputes        (LBM x 2.2)
  -> dailyFatG recomputes            (25% kcal or 0.5 g/kg floor)
  -> dailyCarbsG recomputes          (remaining calories / 4)
  -> bodyFatTargetWeightKg recomputes (LBM / (1 - targetBF%))
  -> weeksToTargetWeight recomputes   (weight delta / weekly loss rate)
  -> DietView re-renders with all updated values
```

---

## Data Persistence

All data is stored on-device. There is no server, no user account, and no analytics.

| Data | UserDefaults key | Format |
|---|---|---|
| Profile settings | Individual keys (heightCm, age, isMale, etc.) | Primitive types |
| Habit completions | habitEntries_v1 | JSON-encoded array |
| Weight log | weightEntries_v1 | JSON-encoded array |
| Workout sets | workoutSets_v1 | JSON-encoded array |
| Exercise progressions | exerciseProgressions_v1 | JSON-encoded array |
| Program day tracking | programDayStore_v1 | JSON-encoded struct |

`PersistenceManager` attempts NSUbiquitousKeyValueStore (iCloud key-value store) first for automatic cross-device sync, and falls back to UserDefaults when iCloud is unavailable. The iCloud entitlement is not required for the app to function.

---

## Notifications

BodyPhase schedules 15 daily reminders covering wake-up hydration, each meal, workout slots, and wind-down. They are toggled in Settings.

- Permissions are requested the first time notifications are enabled.
- If the user previously denied permission, a prompt links to iOS Settings to re-enable.
- All pending delivered notifications are cleared each time the app enters the foreground, preventing stale banners from accumulating after reinstallation or long inactivity.

---

## Project File Generation

`project.yml` is the XcodeGen specification for `BodyPhase.xcodeproj`. The `.xcodeproj` is committed to the repository so no build tools are required to open it. It can be regenerated at any time:

```bash
xcodegen generate
```

Run this after adding or removing source files, changing deployment targets, or modifying build settings. Do not edit `project.pbxproj` directly.

---

## License

MIT License — 2026 debugmonk

See LICENSE for full terms.
