import SwiftUI

struct CompletedSectionView: View {
    @Environment(TodoStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var isConfirmingClear = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if isExpanded {
                Divider().opacity(0.4)
                ForEach(store.completedTodos) { item in
                    TodoRowView(
                        item: item,
                        onToggle: { store.toggle(item) },
                        onDelete: { store.delete(item) }
                    )
                    if item.id != store.completedTodos.last?.id {
                        Divider().padding(.leading, 36).opacity(0.3)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                if reduceMotion {
                    isExpanded.toggle()
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isExpanded)
                        .accessibilityHidden(true)
                    Text("Completed")
                        .font(Typography.secondaryMedium).foregroundStyle(.primary)
                    Text("\(store.completedTodos.count)")
                        .font(Typography.secondary).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Completed todos, \(store.completedTodos.count)")
            .accessibilityHint(isExpanded ? "Collapse" : "Expand")
            .accessibilityAddTraits(isExpanded ? [.isHeader, .isSelected] : .isHeader)

            Spacer()

            clearControl
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var clearControl: some View {
        if isConfirmingClear {
            HStack(spacing: 8) {
                Button("Confirm") {
                    store.deleteCompleted()
                    isConfirmingClear = false
                }
                .font(Typography.secondary)
                .foregroundStyle(.red)
                .buttonStyle(.plain)
                .accessibilityLabel("Confirm clear all completed todos")

                Button("Cancel") { isConfirmingClear = false }
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
        } else {
            Button("Clear") {
                if reduceMotion {
                    isConfirmingClear = true
                } else {
                    withAnimation(.easeInOut(duration: 0.15)) { isConfirmingClear = true }
                }
            }
            .font(Typography.secondary)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .accessibilityLabel("Clear all completed todos")
        }
    }
}
