import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: HabitStore
    @State private var notificationsEnabled: Bool = false
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    // Profile edit state
    @State private var heightText: String = ""
    @State private var ageText: String = ""
    @State private var targetFatText: String = ""

    private enum SettingsField { case height, age, targetFat }
    @FocusState private var focusedField: SettingsField?

    private let manager = NotificationManager.shared

    var body: some View {
        List {
            // MARK: - Profile Section
            Section {
                // Sex
                HStack {
                    Text("Biological Sex")
                        .font(.system(size: 14))
                        .foregroundColor(.primaryText)
                    Spacer()
                    Picker("", selection: $store.isMale) {
                        Text("Male").tag(true)
                        Text("Female").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
                .listRowBackground(Color.cardBackground)

                // Height
                HStack {
                    Text("Height")
                        .font(.system(size: 14))
                        .foregroundColor(.primaryText)
                    Spacer()
                    TextField("cm", text: $heightText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.accentGreen)
                        .frame(width: 70)
                        .focused($focusedField, equals: .height)
                        .onChange(of: heightText) { val in
                            if let h = Double(val), h > 100 { store.heightCm = h }
                        }
                    Text("cm")
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                }
                .listRowBackground(Color.cardBackground)

                // Age
                HStack {
                    Text("Age")
                        .font(.system(size: 14))
                        .foregroundColor(.primaryText)
                    Spacer()
                    TextField("yrs", text: $ageText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.accentGreen)
                        .frame(width: 70)
                        .focused($focusedField, equals: .age)
                        .onChange(of: ageText) { val in
                            if let a = Int(val), a > 15, a < 90 { store.age = a }
                        }
                    Text("yrs")
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                }
                .listRowBackground(Color.cardBackground)

                // Body fat target
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Target Body Fat")
                            .font(.system(size: 14))
                            .foregroundColor(.primaryText)
                        Text("From trainer / doctor")
                            .font(.system(size: 11))
                            .foregroundColor(.secondaryText)
                    }
                    Spacer()
                    TextField("%", text: $targetFatText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.accentGreen)
                        .frame(width: 50)
                        .focused($focusedField, equals: .targetFat)
                        .onChange(of: targetFatText) { val in
                            let n = val.replacingOccurrences(of: ",", with: ".")
                            if let f = Double(n), f > 3 { store.targetBodyFatPct = f }
                        }
                    Text("%")
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                }
                .listRowBackground(Color.cardBackground)

                // Estimated BF% — read-only
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Estimated BF%")
                            .font(.system(size: 14))
                            .foregroundColor(.primaryText)
                        Text("Deurenberg formula · updates with weight")
                            .font(.system(size: 11))
                            .foregroundColor(.secondaryText)
                    }
                    Spacer()
                    if let bf = store.estimatedBodyFatPct {
                        Text(String(format: "~%.0f%%", bf))
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.accentGreen)
                    } else {
                        Text("Log weight to calculate")
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                    }
                }
                .listRowBackground(Color.cardBackground)

                // Current Mode — reactive display
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Mode")
                            .font(.system(size: 14))
                            .foregroundColor(.primaryText)
                        Text("Updates when weight or target changes")
                            .font(.system(size: 11))
                            .foregroundColor(.secondaryText)
                    }
                    Spacer()
                    Text(store.intensityMode.label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: store.intensityMode.colorHex))
                }
                .listRowBackground(Color.cardBackground)

                // Preferred Protein
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Preferred Protein")
                            .font(.system(size: 14))
                            .foregroundColor(.primaryText)
                        Text("Lunch & dinner. Eggs always included at breakfast + snack.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondaryText)
                    }
                    Picker("", selection: $store.preferredProtein) {
                        Text("Chicken").tag("chicken")
                        Text("Fish").tag("fish")
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.cardBackground)

            } header: {
                Text("PROFILE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondaryText)
            }
            // MARK: - Notifications Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Daily Reminders")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primaryText)
                        Text("15 daily reminders — one per habit block")
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: $notificationsEnabled)
                        .tint(.accentGreen)
                        .onChange(of: notificationsEnabled) { enabled in
                            handleToggle(enabled)
                        }
                }
                .listRowBackground(Color.cardBackground)

                if authStatus == .denied {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 13))
                        Text("Notifications are blocked. Enable them in Settings → Notifications.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                    }
                    .listRowBackground(Color.cardBackground)
                }
            } header: {
                Text("NOTIFICATIONS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondaryText)
            }

            // MARK: - Schedule Section
            Section {
                ForEach(manager.schedules, id: \.id) { schedule in
                    HStack {
                        Text(timeString(hour: schedule.hour, minute: schedule.minute))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.accentGreen)
                            .frame(width: 60, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(schedule.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primaryText)
                            Text(schedule.body)
                                .font(.system(size: 11))
                                .foregroundColor(.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .listRowBackground(Color.cardBackground)
                    .opacity(notificationsEnabled ? 1.0 : 0.45)
                }
            } header: {
                Text("SCHEDULE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondaryText)
            }

            // MARK: - App Info
            Section {
                HStack {
                    Text("Version")
                        .font(.system(size: 14))
                        .foregroundColor(.primaryText)
                    Spacer()
                    Text("1.0.0")
                        .font(.system(size: 14))
                        .foregroundColor(.secondaryText)
                }
                .listRowBackground(Color.cardBackground)

                Button(action: { store.onboardingDone = false }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13))
                        Text("Re-run Setup")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.orange)
                }
                .listRowBackground(Color.cardBackground)
            } header: {
                Text("APP")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondaryText)
            }

            // MARK: - About
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentGreen.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Text("dm")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundColor(.accentGreen)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("debugmonk")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.primaryText)
                            Text("debugmonk.com")
                                .font(.system(size: 12))
                                .foregroundColor(.accentGreen)
                        }
                    }
                    Text("BodyPhase is an open-source iOS body transformation app built by debugmonk. Source code available on GitHub.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Link(destination: URL(string: "https://github.com/nsaikrishna15/Fitness-tracker")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11))
                            Text("View source on GitHub")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.accentGreen)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.cardBackground)
            } header: {
                Text("ABOUT")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondaryText)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.accentGreen)
            }
        }
        .onAppear {
            refreshStatus()
            if store.heightCm > 0 { heightText = String(Int(store.heightCm)) }
            if store.age > 0 { ageText = String(store.age) }
            targetFatText = String(format: "%.0f", store.targetBodyFatPct)
        }
    }

    // MARK: - Helpers

    private func handleToggle(_ enabled: Bool) {
        if enabled {
            manager.requestPermissionAndSchedule { granted in
                notificationsEnabled = granted
                refreshStatus()
            }
        } else {
            manager.removeAll()
        }
    }

    private func refreshStatus() {
        manager.checkAuthorizationStatus { status in
            authStatus = status
            if status == .authorized {
                UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
                    DispatchQueue.main.async {
                        let ids = Set(reqs.map { $0.identifier })
                        notificationsEnabled = manager.schedules.allSatisfy { ids.contains($0.id) }
                    }
                }
            } else {
                notificationsEnabled = false
            }
        }
    }

    private func timeString(hour: Int, minute: Int) -> String {
        let suffix = hour >= 12 ? "PM" : "AM"
        let h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return String(format: "%d:%02d %@", h, minute, suffix)
    }
}
