import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var order: Int
    var createdAt: Date
    var completedAt: Date?

    init(title: String, order: Int) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.order = order
        self.createdAt = Date()
        self.completedAt = nil
    }
}
