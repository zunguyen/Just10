import SwiftUI
import UniformTypeIdentifiers

enum TodoDropEdge: Equatable {
    case before
    case after
}

struct TodoDropIndicator: Equatable {
    let itemID: UUID
    let edge: TodoDropEdge
}

struct TodoDropDelegate: DropDelegate {
    private enum Layout {
        static let lowerHalfThreshold: CGFloat = 28
    }

    let targetItem: TodoItem
    let store: TodoStore
    let dragSession: DragSession

    func dropEntered(info: DropInfo) {
        updateDropState(info: info)
    }

    func dropExited(info: DropInfo) {
        if dragSession.dropIndicator?.itemID == targetItem.id {
            dragSession.dropIndicator = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        updateDropState(info: info)
        moveDraggedItemIfNeeded()
        dragSession.draggedItemId = nil
        dragSession.dropIndicator = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateDropState(info: info)
        return DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool { true }

    private func updateDropState(info: DropInfo) {
        guard let draggedId = dragSession.draggedItemId, draggedId != targetItem.id else { return }
        let edge: TodoDropEdge = info.location.y > Layout.lowerHalfThreshold ? .after : .before
        let indicator = TodoDropIndicator(itemID: targetItem.id, edge: edge)
        if dragSession.dropIndicator != indicator {
            dragSession.dropIndicator = indicator
        }
    }

    private func moveDraggedItemIfNeeded() {
        guard
            let draggedId = dragSession.draggedItemId,
            let indicator = dragSession.dropIndicator,
            indicator.itemID == targetItem.id,
            draggedId != targetItem.id,
            let fromIdx = store.activeTodos.firstIndex(where: { $0.id == draggedId }),
            let targetIdx = store.activeTodos.firstIndex(where: { $0.id == targetItem.id })
        else { return }

        let destination = indicator.edge == .after ? targetIdx + 1 : targetIdx
        store.move(from: IndexSet([fromIdx]), to: destination)
    }
}
