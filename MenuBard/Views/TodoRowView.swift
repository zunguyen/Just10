import SwiftUI

struct TodoRowView: View {
    private enum Layout {
        static let rowMinHeight: CGFloat = 44
        static let checkboxSize: CGFloat = 16
        static let checkboxHitSize: CGFloat = 24
        static let checkboxTextSpacing: CGFloat = 8
        static let trailingControlWidth: CGFloat = 24
        static let trailingTextReserve: CGFloat = 30
        static let hoverHorizontalInset: CGFloat = 4
        static let checkboxTopInset: CGFloat = 2
    }

    let item: TodoItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    var onEdit: ((String) -> Void)? = nil
    var onDragProvider: (() -> NSItemProvider)? = nil
    var editingItemId: Binding<UUID?> = .constant(nil)
    var isReordering = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @State private var editText = ""
    @State private var isEditFocused = false

    private var isEditing: Bool { editingItemId.wrappedValue == item.id }
    private var canEdit: Bool { onEdit != nil }

    var body: some View {
        HStack(alignment: .top, spacing: Layout.checkboxTextSpacing) {
            checkbox
            content
                .padding(.trailing, Layout.trailingTextReserve)
                .modifier(OptionalDragModifier(provider: onDragProvider))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minHeight: Layout.rowMinHeight, alignment: .center)
        .background(rowBackground)
        .overlay(alignment: .trailing) {
            trailingControls
                .padding(.trailing, 12)
        }
        .contentShape(Rectangle())
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
            if nowReordering { isHovered = false }
        }
        .onChange(of: isEditing) { _, nowEditing in
            if nowEditing {
                editText = item.title
                isEditFocused = true
            }
        }
    }

    private var checkbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(item.isCompleted ? Color.secondary.opacity(0.28) : Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(item.isCompleted ? Color.clear : Color(nsColor: .separatorColor), lineWidth: 1.4)
                }

            if item.isCompleted {
                Image(systemName: "checkmark")
                    .font(Typography.checkmarkIcon)
                    .foregroundStyle(.white)
            }
        }
        .frame(width: Layout.checkboxSize, height: Layout.checkboxSize)
        .padding(.top, Layout.checkboxTopInset)
        .contentShape(Rectangle())
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: Layout.checkboxHitSize, height: Layout.checkboxHitSize)
                .contentShape(Rectangle())
                .highPriorityGesture(TapGesture().onEnded { onToggle() })
        }
        .zIndex(1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: item.isCompleted)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(item.isCompleted ? "Mark as incomplete" : "Mark as complete")
        .accessibilityAction { onToggle() }
    }

    @ViewBuilder
    private var content: some View {
        if isEditing {
            TodoTextEditor(
                text: $editText,
                isFocused: $isEditFocused,
                onCommit: saveEdit,
                onCancel: cancelEdit,
                onBlur: saveEdit
            )
            .frame(minHeight: 18)
            .accessibilityLabel("Edit todo")
        } else {
            TodoTextEditor(
                text: .constant(item.title),
                isFocused: .constant(false),
                isEditable: false,
                isCompleted: item.isCompleted
            )
                .frame(minHeight: 18)
                .contentShape(Rectangle())
                .onTapGesture {
                    if canEdit { startEdit() }
                }
                .accessibilityLabel(item.title)
        }
    }

    @ViewBuilder
    private var trailingControls: some View {
        let showsDelete = !isEditing && !isReordering && isHovered

        Button(action: onDelete) {
            Image(systemName: "trash")
                .foregroundStyle(.secondary)
                .font(Typography.actionIcon)
                .frame(width: Layout.trailingControlWidth, height: Layout.trailingControlWidth)
        }
        .buttonStyle(.plain)
        .opacity(showsDelete ? 1 : 0)
        .allowsHitTesting(showsDelete)
        .accessibilityHidden(!showsDelete)
        .accessibilityLabel("Delete todo")
        .frame(width: Layout.trailingControlWidth, height: Layout.trailingControlWidth, alignment: .center)
    }

    @ViewBuilder
    private var rowBackground: some View {
        if !isEditing && !isReordering && isHovered {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.hoverBackground)
                .padding(.horizontal, Layout.hoverHorizontalInset)
                .padding(.vertical, 2)
        }
    }

    private func startEdit() {
        editingItemId.wrappedValue = item.id
    }

    private func saveEdit() {
        guard isEditing else { return }
        let trimmed = editText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { onEdit?(trimmed) }
        editingItemId.wrappedValue = nil
    }

    private func cancelEdit() {
        editingItemId.wrappedValue = nil
    }
}

private struct OptionalDragModifier: ViewModifier {
    let provider: (() -> NSItemProvider)?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let provider {
            content.onDrag(provider)
        } else {
            content
        }
    }
}
