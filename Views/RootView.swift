import SwiftUI

struct RootView: View {
    @StateObject private var store = HabitStore()
    @State private var selectedTab: Int = {
        // Support `-screenshotTab N` launch arg for automated screenshot capture
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-screenshotTab"), i + 1 < args.count {
            return Int(args[i + 1]) ?? 0
        }
        return 0
    }()

    var body: some View {
        Group {
            if !store.onboardingDone {
                OnboardingView()
                    .environmentObject(store)
            } else {
                mainTabs
            }
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                WeeklyGridView()
                    .navigationTitle("Habits")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(Color.cardBackground, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem {
                Label("Habits", systemImage: "checkmark.square.fill")
            }
            .tag(0)

            NavigationStack {
                BodyweightChartView()
                    .navigationTitle("Progress")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(Color.cardBackground, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem {
                Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(1)

            NavigationStack {
                DietView()
            }
            .tabItem {
                Label("Diet", systemImage: "fork.knife.circle.fill")
            }
            .tag(2)

            NavigationStack {
                WorkoutView()
            }
            .tabItem {
                Label("Workout", systemImage: "dumbbell.fill")
            }
            .tag(3)

            NavigationStack {
                SettingsView()
                    .toolbarBackground(Color.cardBackground, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(4)
        }
        .tint(.accentGreen)
        .preferredColorScheme(.dark)
        .environmentObject(store)
    }
}
