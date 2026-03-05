import Foundation

final class PersistenceManager {
    static let shared = PersistenceManager()
    private init() {}

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let store   = UserDefaults.standard

    private let habitKey   = "habit_entries_v1"
    private let weightKey  = "weight_entries_v1"
    private let workoutKey = "workout_sets_v1"

    // No-op notification — kept so HabitStore compiles without changes
    static let remoteChangeNotification = Notification.Name("PersistenceManagerRemoteChange")

    // MARK: - Generic save / load

    private func save<T: Encodable>(_ value: T, key: String) {
        do {
            let data = try encoder.encode(value)
            store.set(data, forKey: key)
        } catch {
            print("[PersistenceManager] ⚠️ Failed to encode \(key): \(error)")
        }
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = store.data(forKey: key) else { return nil }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            print("[PersistenceManager] ⚠️ Failed to decode \(key): \(error)")
            return nil
        }
    }

    // MARK: - Habit Entries

    func saveHabitEntries(_ entries: [HabitEntry]) { save(entries, key: habitKey) }
    func loadHabitEntries() -> [HabitEntry]        { load([HabitEntry].self, key: habitKey) ?? [] }

    // MARK: - Weight Entries

    func saveWeightEntries(_ entries: [WeightEntry]) { save(entries, key: weightKey) }
    func loadWeightEntries() -> [WeightEntry]        { load([WeightEntry].self, key: weightKey) ?? [] }

    // MARK: - Workout Sets

    func saveWorkoutSets(_ sets: [WorkoutSet]) { save(sets, key: workoutKey) }
    func loadWorkoutSets() -> [WorkoutSet]     { load([WorkoutSet].self, key: workoutKey) ?? [] }
}
