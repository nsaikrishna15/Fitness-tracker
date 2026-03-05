import SwiftUI

struct WeekNavigatorView: View {
    @EnvironmentObject private var store: HabitStore

    var body: some View {
        HStack(spacing: 16) {
            Button(action: { store.goToPreviousWeek() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primaryText)
                    .frame(width: 36, height: 36)
                    .background(Color.cardBackground)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Button(action: { store.goToCurrentWeek() }) {
                    Text(weekRangeLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primaryText)
                }
                .buttonStyle(.plain)

                Text(String(format: "%.0f%% complete", store.currentWeekCompletionPct))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.accentGreen)
            }

            Spacer()

            Button(action: { store.goToNextWeek() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primaryText)
                    .frame(width: 36, height: 36)
                    .background(Color.cardBackground)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.cardBackground)
    }

    private var weekRangeLabel: String {
        let days = store.currentWeekStart.weekDays()
        guard let first = days.first, let last = days.last else { return "" }
        return "\(SharedDateFormatter.monthDay.string(from: first)) – \(SharedDateFormatter.monthDay.string(from: last))"
    }
}
