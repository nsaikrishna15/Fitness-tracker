import SwiftUI

struct RootView: View {
    @StateObject private var store = HabitStore()

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
        TabView {
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

            NavigationStack {
                DietView()
            }
            .tabItem {
                Label("Diet", systemImage: "fork.knife.circle.fill")
            }

            NavigationStack {
                WorkoutView()
            }
            .tabItem {
                Label("Workout", systemImage: "dumbbell.fill")
            }

            NavigationStack {
                SettingsView()
                    .toolbarBackground(Color.cardBackground, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .tint(.accentGreen)
        .preferredColorScheme(.dark)
        .environmentObject(store)
    }
}
