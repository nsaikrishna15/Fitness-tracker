import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: HabitStore

    @State private var heightText: String = ""
    @State private var weightText: String = ""
    @State private var ageText: String = ""
    @State private var isMale: Bool = true
    @State private var targetFatText: String = ""
    @State private var startDate: Date = Calendar(identifier: .iso8601).startOfDay(for: Date())
    @State private var preferredProtein: String = "chicken"

    @FocusState private var heightFocused: Bool
    @FocusState private var weightFocused: Bool
    @FocusState private var ageFocused: Bool
    @FocusState private var fatFocused: Bool

    private var canProceed: Bool {
        guard let h = Double(heightText), h > 100, h < 250 else { return false }
        guard let w = Double(weightText), w > 30, w < 300 else { return false }
        guard let a = Int(ageText), a > 15, a < 90 else { return false }
        guard let f = Double(targetFatText), f > 3, f < 50 else { return false }
        return true
    }

    /// Live-computed BF% estimate shown while the user is entering stats
    private var liveEstimatedBF: Double? {
        guard let h = Double(heightText), h > 100,
              let w = Double(weightText), w > 30,
              let a = Int(ageText), a > 15 else { return nil }
        return DietPlan.estimatedBodyFatPct(weightKg: w, heightCm: h, age: a, isMale: isMale)
    }

    /// Default target: lower end of "Fitness" range for the selected sex
    private var defaultTarget: String { isMale ? "14" : "21" }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "figure.stand")
                            .font(.system(size: 48))
                            .foregroundColor(.accentGreen)
                            .padding(.top, 60)
                            .padding(.bottom, 4)

                        Text("Quick Setup")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primaryText)

                        Text("Enter your stats once.\nAll targets calculate automatically.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 40)

                    VStack(spacing: 16) {

                        // Sex
                        fieldCard {
                            VStack(alignment: .leading, spacing: 10) {
                                label("Biological Sex")
                                HStack(spacing: 12) {
                                    sexButton("Male",   icon: "figure.stand",       selected: isMale)  {
                                        isMale = true
                                        if targetFatText.isEmpty { targetFatText = defaultTarget }
                                    }
                                    sexButton("Female", icon: "figure.stand.dress", selected: !isMale) {
                                        isMale = false
                                        if targetFatText.isEmpty { targetFatText = defaultTarget }
                                    }
                                }
                            }
                        }

                        // Height + Weight side by side
                        HStack(spacing: 12) {
                            fieldCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    label("Height")
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        TextField("175", text: $heightText)
                                            .keyboardType(.numberPad)
                                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                                            .foregroundColor(.accentGreen)
                                            .focused($heightFocused)
                                        Text("cm")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.secondaryText)
                                    }
                                }
                            }
                            fieldCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    label("Current Weight")
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        TextField("80", text: $weightText)
                                            .keyboardType(.decimalPad)
                                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                                            .foregroundColor(.accentGreen)
                                            .focused($weightFocused)
                                        Text("kg")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.secondaryText)
                                    }
                                    // Live BF% estimate
                                    if let bf = liveEstimatedBF {
                                        Text(String(format: "Estimated body fat: ~%.0f%%", bf))
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.accentGreen.opacity(0.8))
                                    }
                                }
                            }
                        }

                        // Age
                        fieldCard {
                            VStack(alignment: .leading, spacing: 10) {
                                label("Age")
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    TextField("e.g. 28", text: $ageText)
                                        .keyboardType(.numberPad)
                                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                                        .foregroundColor(.accentGreen)
                                        .focused($ageFocused)
                                        .frame(maxWidth: .infinity)
                                    Text("yrs")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.secondaryText)
                                }
                            }
                        }

                        // Body fat target
                        fieldCard {
                            VStack(alignment: .leading, spacing: 10) {
                                label("Target Body Fat %")
                                Text("As recommended by your trainer or doctor.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondaryText)
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    TextField(defaultTarget, text: $targetFatText)
                                        .keyboardType(.decimalPad)
                                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                                        .foregroundColor(.accentGreen)
                                        .focused($fatFocused)
                                        .frame(maxWidth: .infinity)
                                    Text("%")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.secondaryText)
                                }
                                // Sex-adjusted range tags
                                if isMale {
                                    HStack(spacing: 0) {
                                        rangeTag("Athlete", "6–13%",  false)
                                        rangeTag("Fitness", "14–17%", true)
                                        rangeTag("Average", "18–24%", false)
                                    }
                                } else {
                                    HStack(spacing: 0) {
                                        rangeTag("Athlete", "16–20%", false)
                                        rangeTag("Fitness", "21–24%", true)
                                        rangeTag("Average", "25–31%", false)
                                    }
                                }
                            }
                        }

                        // Preferred protein source
                        fieldCard {
                            VStack(alignment: .leading, spacing: 10) {
                                label("Preferred Protein Source")
                                Text("Used to calculate meal amounts in the Diet tab.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondaryText)
                                HStack(spacing: 10) {
                                    proteinButton("Chicken", selected: preferredProtein == "chicken") {
                                        preferredProtein = "chicken"
                                    }
                                    proteinButton("Fish", selected: preferredProtein == "fish") {
                                        preferredProtein = "fish"
                                    }
                                    proteinButton("Eggs", selected: preferredProtein == "eggs") {
                                        preferredProtein = "eggs"
                                    }
                                }
                            }
                        }

                        // Program start date
                        fieldCard {
                            VStack(alignment: .leading, spacing: 10) {
                                label("Program Start Date")
                                Text("Day 1 of your 120-day plan. Pick today unless you already started.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondaryText)
                                DatePicker("", selection: $startDate, in: ...Date(), displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .accentColor(.accentGreen)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Done button
                    Button(action: save) {
                        Text("Start My Program")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canProceed ? Color.accentGreen : Color.accentGreen.opacity(0.3))
                            .cornerRadius(12)
                    }
                    .disabled(!canProceed)
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Pre-fill default target on first appear
            if targetFatText.isEmpty { targetFatText = defaultTarget }
        }
        .onTapGesture {
            heightFocused = false
            weightFocused = false
            ageFocused    = false
            fatFocused    = false
        }
    }

    // MARK: - Save

    private func save() {
        store.heightCm         = Double(heightText) ?? 175
        store.age              = Int(ageText) ?? 25
        store.isMale           = isMale
        store.targetBodyFatPct = Double(targetFatText.replacingOccurrences(of: ",", with: ".")) ?? 12
        store.preferredProtein = preferredProtein
        store.programStartDate = Calendar(identifier: .iso8601).startOfDay(for: startDate)

        // Log opening weight so nutrition calculates immediately
        if let kg = Double(weightText.replacingOccurrences(of: ",", with: ".")), kg > 30 {
            store.setWeight(kg, on: startDate)
        }

        store.onboardingDone = true
    }

    // MARK: - Helpers

    @ViewBuilder
    private func fieldCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cellBorder, lineWidth: 1))
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondaryText)
            .tracking(0.5)
    }

    private func sexButton(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(selected ? .black : .primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected ? Color.accentGreen : Color.cellBackground)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cellBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func proteinButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selected ? .black : .primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(selected ? Color.accentGreen : Color.cellBackground)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cellBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func rangeTag(_ label: String, _ range: String, _ highlight: Bool) -> some View {
        VStack(spacing: 2) {
            Text(range)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(highlight ? .accentGreen : .secondaryText)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(highlight ? Color.accentGreen.opacity(0.08) : Color.clear)
        .cornerRadius(6)
    }
}
