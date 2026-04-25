import SwiftUI

struct TodoRowView: View {
    private enum Layout {
        static let dragHandleWidth: CGFloat = 18
        static let checkboxWidth: CGFloat = 24
        static let trailingControlWidth: CGFloat = 20
        static let firstLineHeight: CGFloat = 22
        static let dragHandleTopInset: CGFloat = 4
        static let checkboxTopInset: CGFloat = 2
        static let trailingControlTopInset: CGFloat = 3
    }

    let item: TodoItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    var onEdit: ((String) -> Void)? = nil
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil
    var editingItemId: Binding<UUID?> = .constant(nil)
    var focusedItemId: FocusState<UUID?>.Binding? = nil
    var isReordering = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @State private var editText = ""
    @FocusState private var isEditFocused: Bool

    private var isEditing: Bool { editingItemId.wrappedValue == item.id }
    private var canEdit: Bool { onEdit != nil }
    private var isFocused: Bool { focusedItemId?.wrappedValue == item.id }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            leadingDragHandle
            checkbox
            content
            trailingControls
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(rowBackground)
        .onHover { hovered in
            guard !isReordering else {
                isHovered = false
                return
            }
            if reduceMotion {
                isHovered = hovered
            } else {
                withAnimation(.easeInOut(duration: 0.1)) { isHovered = hovered }
            }
        }
        .onChange(of: isReordering) { _, nowReordering in
            if nowReordering {
                isHovered = false
            }
        }
        .onChange(of: isEditing) { _, nowEditing in
            if nowEditing {
                editText = item.title
                isEditFocused = true
            }
        }
        .modifier(RowFocusModifier(focusedItemId: focusedItemId, itemId: item.id))
        .onKeyPress(.space) {
            guard isFocused, !isEditing else { return .ignored }
            onToggle()
            return .handled
        }
        .onKeyPress(.return) {
            guard isFocused, !isEditing, canEdit else { return .ignored }
            startEdit()
            return .handled
        }
        .onKeyPress(keys: [.delete, .deleteForward]) { keyPress in
            guard isFocused, !isEditing,
                  keyPress.modifiers.contains(.command) else { return .ignored }
            onDelete()
            return .handled
        }
        .onKeyPress(keys: [.upArrow]) { keyPress in
            guard isFocused, !isEditing else { return .ignored }
            if keyPress.modifiers.contains(EventModifiers.option) {
                onMoveUp?()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(keys: [.downArrow]) { keyPress in
            guard isFocused, !isEditing else { return .ignored }
            if keyPress.modifiers.contains(EventModifiers.option) {
                onMoveDown?()
                return .handled
            }
            return .ignored
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isFocused && !isEditing {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.accentColor, lineWidth: 2)
                .padding(.horizontal, 4)
        }
    }

    private var checkbox: some View {
        Button(action: onToggle) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isCompleted ? Color.secondary : Color.accentColor)
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: item.isCompleted)
        }
        .buttonStyle(.plain)
        .frame(width: Layout.checkboxWidth, height: Layout.firstLineHeight, alignment: .topLeading)
        .accessibilityLabel(item.isCompleted ? "Mark as incomplete" : "Mark as complete")
    }

    @ViewBuilder
    private var leadingDragHandle: some View {
        if item.isCompleted {
            Color.clear
                .frame(width: Layout.dragHandleWidth)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .font(.system(size: 13, weight: .medium))
                .frame(width: Layout.dragHandleWidth, height: Layout.firstLineHeight, alignment: .topLeading)
                .padding(.top, Layout.dragHandleTopInset)
                .accessibilityLabel("Drag to reorder")
        }
    }

    @ViewBuilder
    private var content: some View {
        if isEditing {
            TextField("", text: $editText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Typography.body)
                .lineLimit(1...6)
                .focused($isEditFocused)
                .onSubmit { saveEdit() }
                .onKeyPress(.escape) { cancelEdit(); return .handled }
                .onChange(of: isEditFocused) { _, focused in
                    if !focused { saveEdit() }
                }
                .accessibilityLabel("Edit todo")
        } else {
            Text(item.title)
                .font(Typography.body)
                .foregroundStyle(item.isCompleted ? .secondary : .primary)
                .strikethrough(item.isCompleted, color: .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture {
                    if canEdit { startEdit() }
                }
        }
    }

    @ViewBuilder
    private var trailingControls: some View {
        Group {
            if !isEditing && !isReordering && isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete todo")
            } else {
                Color.clear
                    .accessibilityHidden(true)
            }
        }
        .frame(width: Layout.trailingControlWidth, alignment: .topTrailing)
        .padding(.top, Layout.trailingControlTopInset)
    }

    private func startEdit() {
        editingItemId.wrappedValue = item.id
    }

    private func saveEdit() {
        guard isEditing else { return }
        let trimmed = editText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        if !trimmed.isEmpty { onEdit?(trimmed) }
        editingItemId.wrappedValue = nil
        focusedItemId?.wrappedValue = nil
    }

    private func cancelEdit() {
        editingItemId.wrappedValue = nil
        focusedItemId?.wrappedValue = nil
    }
}

/// Conditionally applies `.focusable() + .focused(...)` only when a binding is provided.
/// Completed rows in `CompletedSectionView` pass nil and stay non-focusable.
private struct RowFocusModifier: ViewModifier {
    let focusedItemId: FocusState<UUID?>.Binding?
    let itemId: UUID

    func body(content: Content) -> some View {
        if let focusedItemId {
            content
                .focusable()
                .focusEffectDisabled()
                .focused(focusedItemId, equals: itemId)
        } else {
            content
        }
    }
}
