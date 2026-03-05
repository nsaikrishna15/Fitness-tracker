import Foundation

struct WeightEntry: Codable, Identifiable {
    var id: String { dateKey }
    let dateKey: String
    var weightKg: Double?
    /// Previous value before the last correction — nil if never edited.
    var previousKg: Double?
    /// Timestamp of the last edit (for display in history).
    var lastEditedAt: Date?

    init(dateKey: String, weightKg: Double?) {
        self.dateKey      = dateKey
        self.weightKg     = weightKg
        self.previousKg   = nil
        self.lastEditedAt = nil
    }

    /// Parsed Date for use in SwiftUI Charts — uses shared formatter, not a new one per call.
    var date: Date {
        SharedDateFormatter.dateKey.date(from: dateKey) ?? Date()
    }
}
