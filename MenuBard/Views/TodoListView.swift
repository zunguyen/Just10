import SwiftUI

struct TodoListView: View {
    private enum Layout {
        static let outerPadding: CGFloat = 4
        static let cardRadius: CGFloat = 10
        static let inputHeight: CGFloat = 56
        static let inputVerticalPadding: CGFloat = 14
    }

    @Environment(TodoStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onSettings: () -> Void

    @State private var newTodoText = ""
    @StateObject private var dragSession = DragSession()
    @State private var editingItemId: UUID?
    @State private var showCapWarning = false
    @State private var isConfirmingClearCompleted = false
    @State private var isTextFieldFocused = false

    private var activeCount: Int { store.activeTodos.count }
    private var atCap: Bool { store.isAtActiveCap }
    private var nearCap: Bool { activeCount >= 8 }
    private var hasCompleted: Bool { !store.completedTodos.isEmpty }

    var body: some View {
        VStack(spacing: 4) {
            header
            addField
            if showCapWarning {
                capMessage
            }
            todoList
        }
        .padding(.horizontal, Layout.outerPadding)
        .padding(.top, Layout.outerPadding)
        .padding(.bottom, Layout.outerPadding)
        .background(Color.appBackground)
        .onAppear { isTextFieldFocused = true }
        .onChange(of: activeCount) { _, newCount in
            if newCount < TodoStore.activeCap, showCapWarning {
                showCapWarning = false
            }
        }
        .onChange(of: hasCompleted) { _, nowHasCompleted in
            if !nowHasCompleted { isConfirmingClearCompleted = false }
        }
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

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Just 10")
                .font(Typography.title)
                .foregroundStyle(.primary)

            Spacer()

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(Typography.titleIcon)
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }

    private var addField: some View {
        TodoTextEditor(
            text: $newTodoText,
            isFocused: $isTextFieldFocused,
            placeholder: addPlaceholder,
            verticalTextInset: 5,
            onCommit: addTodo
        )
        .frame(height: 28)
        .padding(.horizontal, 12)
        .padding(.vertical, Layout.inputVerticalPadding)
        .frame(height: Layout.inputHeight)
        .background {
            RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: isTextFieldFocused ? 1.2 : 0.8)
        }
    }

    private var addPlaceholder: String {
        atCap ? "List full · complete one to continue" : "Add to do"
    }

    private var capMessage: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(Typography.bodyIcon)
                .accessibilityHidden(true)
            Text("You've reached \(TodoStore.activeCap) todos. Complete or delete one to add more.")
                .font(Typography.secondary)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
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
                        VStack(spacing: 14) {
                            if !activeTodos.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(Array(activeTodos.enumerated()), id: \.element.id) { _, item in
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
                                }
                                .padding(.vertical, 14)
                                .background {
                                    RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                                        .fill(Color(nsColor: .textBackgroundColor))
                                }
                                .clipShape(RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
                                }
                            }

                            if !completedTodos.isEmpty {
                                VStack(spacing: 4) {
                                    ForEach(completedTodos) { item in
                                        TodoRowView(
                                            item: item,
                                            onToggle: { store.toggle(item) },
                                            onDelete: { store.delete(item) }
                                        )
                                        .id("completed-\(item.id)")
                                    }
                                }
                            }
                        }
                        .padding(.top, 0)
                        .padding(.bottom, 2)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
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
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { isConfirmingClearCompleted = true }
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
            .accessibilityLabel("Quit Just 10")

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
                    .font(Typography.bodyIcon)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func addTodo() {
        let trimmed = normalizedTodoTitle(newTodoText)
        guard !trimmed.isEmpty else { return }
        if store.add(title: trimmed) {
            newTodoText = ""
            isTextFieldFocused = true
            showCapWarning = false
        } else {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { showCapWarning = true }
        }
    }

    private func clearEditingAndSelection() {
        editingItemId = nil
    }

    private func normalizedTodoTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
            onDragProvider: {
                onStartDrag()
                dragSession.draggedItemId = item.id
                return NSItemProvider(object: item.id.uuidString as NSString)
            },
            editingItemId: $editingItemId,
            isReordering: isReordering
        )
        .opacity(isDragged ? 0.4 : 1.0)
        .overlay(alignment: dropEdge == .before ? .top : .bottom) {
            if isDropTarget { dropIndicatorLine }
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
