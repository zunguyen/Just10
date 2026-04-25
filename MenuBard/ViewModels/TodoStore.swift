import Foundation
import Observation

@MainActor
@Observable
final class TodoStore {
    static let activeCap = 10
    static let completedCap = 10

    private(set) var items: [TodoItem] = []
    private(set) var activeTodos: [TodoItem] = []
    private(set) var completedTodos: [TodoItem] = []
    private(set) var isAtActiveCap = false

    private let storageKey = "menubard.todos"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
        refreshDerivedState()
    }

    @discardableResult
    func add(title: String) -> Bool {
        guard !isAtActiveCap else { return false }
        mutateItems { items in
            let maxOrder = items.map(\.order).max() ?? -1
            items.append(TodoItem(title: title, order: maxOrder + 1))
        }
        return true
    }

    func delete(_ item: TodoItem) {
        mutateItems { items in
            items.removeAll { $0.id == item.id }
        }
    }

    func deleteCompleted() {
        mutateItems { items in
            items.removeAll { $0.isCompleted }
        }
    }

    func toggle(_ item: TodoItem) {
        mutateItems { items in
            guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
            items[idx].isCompleted.toggle()
            items[idx].completedAt = items[idx].isCompleted ? Date() : nil
            if items[idx].isCompleted {
                enforceCompletedCap(in: &items)
            }
        }
    }

    func update(_ item: TodoItem, title: String) {
        mutateItems { items in
            guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
            items[idx].title = title
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        mutateItems { items in
            var active = items
                .filter { !$0.isCompleted }
                .sorted { $0.order < $1.order }
            active.move(fromOffsets: source, toOffset: destination)
            for (i, todo) in active.enumerated() {
                if let idx = items.firstIndex(where: { $0.id == todo.id }) {
                    items[idx].order = i
                }
            }
        }
    }

    func moveActive(_ item: TodoItem, by delta: Int) {
        let active = activeTodos
        guard let from = active.firstIndex(where: { $0.id == item.id }) else { return }
        let to = max(0, min(active.count - 1, from + delta))
        guard to != from else { return }
        // SwiftUI's move uses an insertion-index convention.
        let target = to > from ? to + 1 : to
        move(from: IndexSet([from]), to: target)
    }

    func clearAll() {
        mutateItems { items in
            items.removeAll()
        }
    }

    /// FIFO eviction — keep only the `completedCap` most recently completed.
    private func enforceCompletedCap(in items: inout [TodoItem]) {
        let completed = items
            .filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        guard completed.count > Self.completedCap else { return }
        let evictedIds = Set(completed.dropFirst(Self.completedCap).map(\.id))
        items.removeAll { evictedIds.contains($0.id) }
    }

    private func mutateItems(_ mutation: (inout [TodoItem]) -> Void) {
        var updatedItems = items
        mutation(&updatedItems)
        items = updatedItems
        refreshDerivedState()
        save()
    }

    private func refreshDerivedState() {
        let active = items
            .filter { !$0.isCompleted }
            .sorted { $0.order < $1.order }
        activeTodos = active
        completedTodos = items
            .filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        isAtActiveCap = active.count >= Self.activeCap
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = userDefaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([TodoItem].self, from: data)
        else { return }
        items = decoded
    }
}
