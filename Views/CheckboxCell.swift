import SwiftUI

struct CheckboxCell: View {
    let isCompleted: Bool
    let isLocked: Bool          // true = can't tap (future day OR time not yet reached)
    let onTap: () -> Void

    var body: some View {
        Button(action: { if !isLocked { onTap() } }) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isCompleted ? Color.accentGreen.opacity(0.15) : Color.cellBackground)
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                isLocked ? Color.cellBorder.opacity(0.4) :
                                    (isCompleted ? Color.accentGreen : Color.cellBorder),
                                lineWidth: 1.5
                            )
                    )

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.accentGreen)
                        .transition(.scale.combined(with: .opacity))
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Color.secondaryText.opacity(0.4))
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isCompleted)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .opacity(isLocked ? 0.45 : 1.0)
        .frame(width: 44, height: 44)
    }
}
