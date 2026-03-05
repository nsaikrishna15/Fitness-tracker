import Foundation

struct HabitEntry: Codable, Identifiable {
    var id: String { "\(habitID.rawValue)_\(dateKey)" }
    let habitID: HabitID
    let dateKey: String
    var isCompleted: Bool
}
