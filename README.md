# FitTrack

A personal iOS fitness & habit tracker built with SwiftUI. Tracks daily habits, lifting workouts with progressive overload, and a fully dynamic nutrition plan — all calculated from your body stats.

---

## Features

### Habits
- Daily habit grid (Mon–Sun) with tap-to-complete checkboxes
- Week navigation — review and backfill any past week
- Completion percentage shown per week

### Workout
- 120-day structured program across 4 phases (Foundation → Volume → Strength → Peak)
- Fixed weekly schedule: Upper A / Lower A / Cardio / Upper B / Cardio / Lower B / Rest
- Progressive overload engine — auto-suggests next session's weight based on your logged sets
- Log reps + kg per set; completion syncs back to the habit grid automatically
- Future days show the upcoming plan in read-only preview mode
- Days before your program start date are locked

### Diet (fully dynamic)
- All macros calculated from your body weight, height, age, sex, and program phase
- **IntensityMode** — automatically selects deficit/surplus based on estimated vs target body fat:
  - Aggressive Cut (>10% gap) → 750 kcal deficit
  - Standard Cut (5–10%) → 500 kcal deficit
  - Mild Cut (2–5%) → 250 kcal deficit
  - Recomp (0–2%) → maintenance
  - Bulk (<0%) → 200 kcal surplus
- Meal plan with 5 meals/day; ingredient gram amounts scale to your targets
- **Eggs always** at breakfast and snack — choose Chicken or Fish for lunch & dinner
- Weekly meal prep guide adjusts to your protein choice (batch chicken vs cook-fresh fish)
- Fruit rotation (Week A/B), hydration target (35ml/kg), supplement schedule

### Settings
- Edit height, age, sex, target body fat, preferred protein at any time
- Shows estimated current body fat % and current intensity mode (reactive — updates immediately when you log weight or change target)
- Notification schedule toggle (15 daily reminders)

---

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 16.0+ |
| iOS Deployment Target | 16.0+ |
| Swift | 5.9+ |
| [xcodegen](https://github.com/yonaskolb/XcodeGen) | 2.x (only needed to regenerate the `.xcodeproj`) |

---

## How to Build & Run

### Option A — Open directly in Xcode (simplest)

```bash
git clone https://github.com/nsaikrishna15/Fitness-tracker.git
cd Fitness-tracker
open FitTrack.xcodeproj
```

Then in Xcode:
1. Select a simulator (e.g. iPhone 16) or your connected iPhone from the scheme toolbar
2. Press **Cmd + R** to build and run

### Option B — Regenerate the project file first (if you modify `project.yml`)

```bash
brew install xcodegen      # first time only
xcodegen generate
open FitTrack.xcodeproj
```

### Building for a physical iPhone

1. Open **FitTrack.xcodeproj** in Xcode
2. Select your iPhone from the destination picker
3. Go to **Signing & Capabilities** and set your Apple ID under Team
4. Press **Cmd + R**

> **Note:** Free Apple Developer accounts sign with a 7-day certificate. The app will stop launching after 7 days and needs to be re-signed. To distribute beyond your own device, a paid Apple Developer Program membership ($99/year) is required for 1-year certificates and TestFlight access.

---

## First Launch

On first open you'll see a **Quick Setup** screen:

1. **Biological Sex** — affects BMR formula and body fat range suggestions
2. **Height + Weight** — drives all nutrition targets; live body fat estimate shows as you type
3. **Age** — used in BMR and Deurenberg BF% formula
4. **Target Body Fat %** — range tags auto-adjust by sex (Athlete / Fitness / Average); tap a range to see suggested values
5. **Preferred Protein** — Chicken (batch-cook Sunday/Wednesday) or Fish (cook fresh every 2 days)
6. **Program Start Date** — Day 1 of your 120-day plan

Tap **Start My Program** — all tabs become active immediately.

---

## App Structure

```
FitTrack/
├── HabitTrackerApp.swift        # App entry point (FitTrackApp)
├── Models/
│   ├── DietPlan.swift           # All nutrition math + IntensityMode
│   ├── Habit.swift              # Habit definitions and IDs
│   ├── HabitEntry.swift         # Logged completions
│   ├── WeightEntry.swift        # Logged weight entries
│   ├── WorkoutModels.swift      # Exercises, phases, schedule
│   └── WorkoutProgression.swift # Progressive overload engine
├── ViewModels/
│   └── HabitStore.swift         # Single ObservableObject — all state
├── Views/
│   ├── RootView.swift           # Tab container
│   ├── OnboardingView.swift     # First-launch setup
│   ├── DietView.swift           # Nutrition plan
│   ├── WorkoutView.swift        # Workout logging
│   ├── SettingsView.swift       # Profile + notifications
│   ├── WeeklyGridView.swift     # Habit grid
│   └── BodyweightChartView.swift
├── Services/
│   ├── NotificationManager.swift
│   └── PersistenceManager.swift # JSON via NSUbiquitousKeyValueStore + UserDefaults
├── Extensions/
│   ├── Color+Theme.swift        # App colour palette
│   └── Date+Week.swift          # ISO week helpers
└── project.yml                  # XcodeGen project spec
```

---

## Data Persistence

All data is stored locally in **UserDefaults** (profile settings) and serialised JSON (habit entries, weight log, workout sets). The persistence layer uses `NSUbiquitousKeyValueStore` where available and falls back to `UserDefaults`.

No account, no server, no analytics — everything stays on device.

---

## Notifications

FitTrack schedules 15 daily reminders across the day (wake-up water, meals, workout, wind-down). Toggle them in **Settings → Notifications**. Permissions are requested on first toggle — if denied, a prompt directs you to iOS Settings.

Delivered notifications are cleared automatically each time the app comes to foreground, so stale banners don't accumulate after reinstallation.

---

## License

MIT License — © 2026 [debugmonk](https://debugmonk.com)

See [LICENSE](./LICENSE) for full terms.

---

## About

Built by **debugmonk** — a developer channel focused on building real things fast.

- Website: [debugmonk.com](https://debugmonk.com)
- YouTube: coming soon
