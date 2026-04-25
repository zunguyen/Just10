import Foundation
import Combine

final class DragSession: ObservableObject {
    @Published var draggedItemId: UUID?
    @Published var dropIndicator: TodoDropIndicator?

    var isActive: Bool { draggedItemId != nil }
}
