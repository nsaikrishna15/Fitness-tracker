import SwiftUI

struct WeightInputCell: View {
    let date: Date
    let isFuture: Bool
    @EnvironmentObject private var store: HabitStore

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("kg", text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.primaryText)
            .frame(width: 36, height: 22)
            .background(Color.cellBackground)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isFocused ? Color.accentBlue : Color.cellBorder, lineWidth: 1)
            )
            .focused($isFocused)
            .disabled(isFuture)
            .opacity(isFuture ? 0.35 : 1.0)
            .onAppear { syncFromStore() }
            .onChange(of: date) { _ in syncFromStore() }
            .onChange(of: isFocused) { focused in
                if !focused { commitValue() }
            }
    }

    private func syncFromStore() {
        if let kg = store.weight(on: date) {
            text = String(format: "%.1f", kg)
        } else {
            text = ""
        }
    }

    private func commitValue() {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty {
            store.setWeight(nil, on: date)
        } else if let val = Double(cleaned) {
            store.setWeight(val, on: date)
        }
    }
}
