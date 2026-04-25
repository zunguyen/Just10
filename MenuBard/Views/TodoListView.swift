import SwiftUI

struct TodoListView: View {
    @Environment(TodoStore.self) private var store
    let onSettings: () -> Void

    @State private var newTodoText = ""
    @State private var draggedItem: TodoItem?
    @State private var dropIndicator: TodoDropIndicator?
    @State private var editingItemId: UUID?
    @State private var showCapWarning = false
    @FocusState private var isTextFieldFocused: Bool
    @FocusState private var focusedItemId: UUID?

    private var activeCount: Int { store.activeTodos.count }
    private var atCap: Bool { store.isAtActiveCap }
    private var nearCap: Bool { activeCount >= 8 }

    var body: some View {
        VStack(spacing: 0) {
            addField
            if showCapWarning {
                capMessage
            }
            Divider().opacity(0.5)
            activeList
            if !store.completedTodos.isEmpty {
                Divider().opacity(0.5)
                CompletedSectionView()
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
        .onChange(of: draggedItem?.id) { _, draggedId in
            if draggedId == nil {
                focusedItemId = nil
                dropIndicator = nil
                NotificationCenter.default.post(name: .todoDragDidEnd, object: nil)
            }
        }
        .onDisappear {
            if draggedItem != nil {
                draggedItem = nil
                dropIndicator = nil
                NotificationCenter.default.post(name: .todoDragDidEnd, object: nil)
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

    @ViewBuilder private var activeList: some View {
        let activeTodos = store.activeTodos

        Group {
            if activeTodos.isEmpty {
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
                        LazyVStack(spacing: 0) {
                            ForEach(Array(activeTodos.enumerated()), id: \.element.id) { index, item in
                                TodoRowView(
                                    item: item,
                                    onToggle: { store.toggle(item) },
                                    onDelete: { store.delete(item) },
                                    onEdit: { newTitle in store.update(item, title: newTitle) },
                                    onMoveUp: { store.moveActive(item, by: -1) },
                                    onMoveDown: { store.moveActive(item, by: 1) },
                                    editingItemId: $editingItemId,
                                    focusedItemId: $focusedItemId,
                                    isReordering: draggedItem != nil
                                )
                                .opacity(draggedItem?.id == item.id ? 0.4 : 1.0)
                                .overlay(alignment: dropIndicatorAlignment(for: item.id)) {
                                    if let indicator = dropIndicator, indicator.itemID == item.id {
                                        dropIndicatorLine
                                    }
                                }
                                .onDrag {
                                    clearEditingAndSelection()
                                    draggedItem = item
                                    NotificationCenter.default.post(name: .todoDragDidStart, object: nil)
                                    return NSItemProvider(object: item.id.uuidString as NSString)
                                }
                                .onDrop(
                                    of: [.plainText],
                                    delegate: TodoDropDelegate(
                                        targetItem: item,
                                        store: store,
                                        draggedItem: $draggedItem,
                                        dropIndicator: $dropIndicator
                                    )
                                )
                                if index < activeTodos.count - 1 {
                                    Divider().padding(.leading, 36).opacity(0.3)
                                }
                            }
                        }
                    }
                }
            }
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
            .accessibilityLabel("Quit MenuBard")

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

    private var dropIndicatorLine: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(height: 2)
            .padding(.leading, 36)
            .padding(.trailing, 12)
    }

    private func addTodo() {
        let trimmed = newTodoText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if store.add(title: trimmed) {
            newTodoText = ""
            showCapWarning = false
        } else {
            // Cap reached — preserve typed text, surface the inline message.
            withAnimation(.easeInOut(duration: 0.15)) { showCapWarning = true }
        }
    }

    private func clearEditingAndSelection() {
        editingItemId = nil
        focusedItemId = nil
    }

    private func dropIndicatorAlignment(for itemID: UUID) -> Alignment {
        guard let indicator = dropIndicator, indicator.itemID == itemID else { return .top }
        return indicator.edge == .before ? .top : .bottom
    }
}
