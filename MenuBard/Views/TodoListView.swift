import SwiftUI

struct TodoListView: View {
    @Environment(TodoStore.self) private var store
    let onSettings: () -> Void

    @State private var newTodoText = ""
    @StateObject private var dragSession = DragSession()
    @State private var editingItemId: UUID?
    @State private var showCapWarning = false
    @State private var isConfirmingClearCompleted = false
    @FocusState private var isTextFieldFocused: Bool

    private var activeCount: Int { store.activeTodos.count }
    private var atCap: Bool { store.isAtActiveCap }
    private var nearCap: Bool { activeCount >= 8 }
    private var hasCompleted: Bool { !store.completedTodos.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            addField
            if showCapWarning {
                capMessage
            }
            Divider().opacity(0.5)
            todoList
            if hasCompleted {
                clearCompletedButton
            }
            Divider().opacity(0.5)
            footer
        }
        .onAppear { isTextFieldFocused = true }
        .onChange(of: activeCount) { _, newCount in
            if newCount < TodoStore.activeCap, showCapWarning {
                showCapWarning = false
            }
        }
        .onChange(of: hasCompleted) { _, nowHasCompleted in
            if !nowHasCompleted { isConfirmingClearCompleted = false }
        }
        // Defensive: clear editingItemId if the edited item leaves activeTodos
        // (toggled to completed, deleted, evicted). Without this, the next time
        // that item returns to active (e.g., un-checked) the new TodoRowView
        // sees editingItemId == item.id and renders a TextField with the fresh
        // empty @State editText — visually a checkbox with no text.
        // Reproduces only when SwiftUI's @FocusState onChange doesn't fire
        // during view destruction (intermittent).
        .onChange(of: store.activeTodos) { _, newActive in
            guard let editingId = editingItemId else { return }
            if !newActive.contains(where: { $0.id == editingId }) {
                editingItemId = nil
            }
        }
        .onDisappear {
            if dragSession.isActive {
                dragSession.draggedItemId = nil
                dragSession.dropIndicator = nil
            }
        }
    }

    private var addField: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))
                .accessibilityHidden(true)
            TextField(addPlaceholder, text: $newTodoText)
                .textFieldStyle(.plain)
                .font(Typography.body)
                .focused($isTextFieldFocused)
                .onSubmit { addTodo() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var addPlaceholder: String {
        atCap ? "List full · complete one to continue" : "Add a todo…"
    }

    private var capMessage: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 13))
                .accessibilityHidden(true)
            Text("You've reached \(TodoStore.activeCap) todos. Complete or delete one to add more.")
                .font(Typography.secondary)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .transition(.opacity)
    }

    @ViewBuilder private var todoList: some View {
        let activeTodos = store.activeTodos
        let completedTodos = store.completedTodos
        let draggedItemId = dragSession.draggedItemId
        let dropIndicator = dragSession.dropIndicator

        Group {
            if activeTodos.isEmpty && completedTodos.isEmpty {
                Spacer()
                Text("Create your new todo")
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ZStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { clearEditingAndSelection() }

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(activeTodos.enumerated()), id: \.element.id) { index, item in
                                DragRowContainer(
                                    item: item,
                                    isDragged: draggedItemId == item.id,
                                    isReordering: draggedItemId != nil,
                                    isDropTarget: dropIndicator?.itemID == item.id,
                                    dropEdge: dropIndicator?.itemID == item.id ? dropIndicator?.edge : nil,
                                    dragSession: dragSession,
                                    editingItemId: $editingItemId,
                                    store: store,
                                    onStartDrag: clearEditingAndSelection
                                )
                                .equatable()
                                .id("active-\(item.id)")
                            }
                            ForEach(completedTodos) { item in
                                TodoRowView(
                                    item: item,
                                    onToggle: { store.toggle(item) },
                                    onDelete: { store.delete(item) }
                                )
                                .id("completed-\(item.id)")
                            }
                        }
                        .padding(.top, 6)
                    }
                }
            }
        }
    }

    @ViewBuilder private var clearCompletedButton: some View {
        if isConfirmingClearCompleted {
            HStack(spacing: 12) {
                Button("Confirm") {
                    store.deleteCompleted()
                    isConfirmingClearCompleted = false
                }
                .font(Typography.secondary)
                .foregroundStyle(.red)
                .buttonStyle(.plain)
                .accessibilityLabel("Confirm clear completed todos")

                Button("Cancel") { isConfirmingClearCompleted = false }
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        } else {
            Button("Clear completed") {
                withAnimation(.easeInOut(duration: 0.15)) { isConfirmingClearCompleted = true }
            }
            .font(Typography.secondary)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .accessibilityLabel("Clear completed todos")
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                NSApp.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Text("⌘Q").font(Typography.secondary).foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("Quit").font(Typography.secondary).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
            .accessibilityLabel("Quit Jet10")

            Spacer()

            if nearCap {
                Text("\(activeCount)/\(TodoStore.activeCap)")
                    .font(Typography.secondary)
                    .foregroundStyle(atCap ? AnyShapeStyle(Color.orange) : AnyShapeStyle(Color.secondary))
                    .accessibilityLabel("\(activeCount) of \(TodoStore.activeCap) todos used")
            }

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func addTodo() {
        let trimmed = newTodoText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if store.add(title: trimmed) {
            newTodoText = ""
            showCapWarning = false
        } else {
            withAnimation(.easeInOut(duration: 0.15)) { showCapWarning = true }
        }
    }

    private func clearEditingAndSelection() {
        editingItemId = nil
    }

}

private struct DragRowContainer: View, Equatable {
    let item: TodoItem
    let isDragged: Bool
    let isReordering: Bool
    let isDropTarget: Bool
    let dropEdge: TodoDropEdge?
    let dragSession: DragSession
    @Binding var editingItemId: UUID?
    let store: TodoStore
    let onStartDrag: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.item == rhs.item &&
        lhs.isDragged == rhs.isDragged &&
        lhs.isReordering == rhs.isReordering &&
        lhs.isDropTarget == rhs.isDropTarget &&
        lhs.dropEdge == rhs.dropEdge
    }

    var body: some View {
        TodoRowView(
            item: item,
            onToggle: { store.toggle(item) },
            onDelete: { store.delete(item) },
            onEdit: { newTitle in store.update(item, title: newTitle) },
            editingItemId: $editingItemId,
            isReordering: isReordering
        )
        .opacity(isDragged ? 0.4 : 1.0)
        .overlay(alignment: dropEdge == .before ? .top : .bottom) {
            if isDropTarget { dropIndicatorLine }
        }
        .onDrag {
            onStartDrag()
            dragSession.draggedItemId = item.id
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .onDrop(
            of: [.plainText],
            delegate: TodoDropDelegate(
                targetItem: item,
                store: store,
                dragSession: dragSession
            )
        )
    }

    private var dropIndicatorLine: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(height: 2)
            .padding(.leading, 36)
            .padding(.trailing, 12)
    }
}
