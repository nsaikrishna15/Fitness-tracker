import SwiftUI

struct GridRowView: View {
    let definition: HabitDefinition
    let days: [Date]
    let isAlternate: Bool
    /// Passed in from parent so every row doesn't maintain its own timer.
    let currentMinute: Int

    @EnvironmentObject private var store: HabitStore

    private let labelWidth: CGFloat = 150
    private let cellWidth: CGFloat  = 44
    private let rowHeight: CGFloat  = 56

    var body: some View {
        HStack(spacing: 0) {
            // Label
            HStack(spacing: 7) {
                Image(systemName: definition.icon)
                    .font(.system(size: 11))
                    .foregroundColor(.accentGreen)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(definition.time)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondaryText)
                        Text(definition.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primaryText)
                            .lineLimit(1)
                    }
                    Text(definition.detail)
                        .font(.system(size: 9))
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: labelWidth, alignment: .leading)
            .padding(.leading, 10)

            // Day cells
            ForEach(Array(days.enumerated()), id: \.offset) { idx, day in
                if isActiveDay(dayIndex: idx) {
                    // Use currentMinute to invalidate this cell when the clock ticks
                    let locked = !definition.isUnlocked(for: day)
                    CheckboxCell(
                        isCompleted: store.isCompleted(habit: definition.id, on: day),
                        isLocked: locked,
                        onTap: { store.toggle(habit: definition.id, on: day) }
                    )
                    .id("\(definition.id.rawValue)_\(day.dateKey)_\(currentMinute)")
                    .frame(width: cellWidth, height: rowHeight)
                } else {
                    Text("–")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(Color.secondaryText.opacity(0.4))
                        .frame(width: cellWidth, height: rowHeight)
                }
            }
        }
        .frame(height: rowHeight)
        .background(isAlternate ? Color.rowAltBackground : Color.appBackground)
    }

    private func isActiveDay(dayIndex: Int) -> Bool {
        guard let mask = definition.activeDays else { return true }
        return mask.contains(dayIndex)
    }
}
