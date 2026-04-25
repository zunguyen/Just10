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
    @Binding var draggedItem: TodoItem?
    @Binding var dropIndicator: TodoDropIndicator?

    func dropEntered(info: DropInfo) {
        updateDropState(info: info)
    }

    func dropExited(info: DropInfo) {
        if dropIndicator?.itemID == targetItem.id {
            dropIndicator = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        updateDropState(info: info)
        moveDraggedItemIfNeeded()
        draggedItem = nil
        dropIndicator = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateDropState(info: info)
        return DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool { true }

    private func updateDropState(info: DropInfo) {
        guard let dragged = draggedItem, dragged.id != targetItem.id else { return }
        let edge: TodoDropEdge = info.location.y > Layout.lowerHalfThreshold ? .after : .before
        let indicator = TodoDropIndicator(itemID: targetItem.id, edge: edge)
        if dropIndicator != indicator {
            dropIndicator = indicator
        }
    }

    private func moveDraggedItemIfNeeded() {
        guard
            let dragged = draggedItem,
            let indicator = dropIndicator,
            indicator.itemID == targetItem.id,
            dragged.id != targetItem.id,
            let fromIdx = store.activeTodos.firstIndex(where: { $0.id == dragged.id }),
            let targetIdx = store.activeTodos.firstIndex(where: { $0.id == targetItem.id })
        else { return }

        let destination = indicator.edge == .after ? targetIdx + 1 : targetIdx
        store.move(from: IndexSet([fromIdx]), to: destination)
    }
}
