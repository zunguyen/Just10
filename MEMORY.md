# MenuBard — Project Memory

Known bugs and patterns to avoid repeating.

---

## SwiftUI Pitfalls

**`@ViewBuilder` on multi-statement `some View` computed properties** — If a computed property has a `let` declaration before the view expression, Swift treats it as multi-statement and cannot infer the opaque return type. Raises "Function declares an opaque return type, but has no return statements." Fix: add `@ViewBuilder`. Hit on `activeList` in `TodoListView` after adding `let activeTodos = ...` at the top.

**`Color.clear` placeholder needs `.frame(height: 0)`** — `Color.clear` with no frame constraint expands to fill available vertical space in a `VStack` outside a `ScrollView`. Always use `Color.clear.frame(height: 0).accessibilityHidden(true)` as a zero-height placeholder in `trailingControls` or similar toggle-visible slots.

**Same UUID across two `ForEach` instances corrupts row state** — `TodoListView` renders active items via `ForEach(activeTodos)` and completed items via `ForEach(completedTodos)` in the same `VStack`. When a todo is toggled, its UUID jumps from one ForEach to the other, and SwiftUI's identity diff reuses the wrong view: completed items rendered without checkmark/strikethrough, unchecked items rendered without title text. Two-part fix: (1) use `VStack` not `LazyVStack` (already done — lazy recycling makes it worse), (2) namespace the identity per section with `.id("active-\(item.id)")` and `.id("completed-\(item.id)")` on each row. Without the prefix, SwiftUI treats the two slots as the same view.

---

## NSPopover

**Popover position-shift requires TWO independent fixes — any one missing and you'll see drift.** Both live in `AppDelegate.swift`:
  1. `hostingController.sizingOptions = []` — stops SwiftUI from telling the popover to resize when content height changes (e.g., the inline "Clear completed" button appearing). Without it, NSHostingController auto-propagates `preferredContentSize` and the popover grows/shrinks vertically.
  2. `statusItem = NSStatusBar.system.statusItem(withLength: Self.statusItemSlotWidth)` — fixed slot width, **never variable, never freeze/restore**. `statusItemSlotWidth` is computed once from font metrics for the worst case (`" " + 20×"W" + "…"`). Why fixed-from-start: any time the slot resizes (variable length + title change, OR freeze-on-open + title change), NSPopover re-anchors to the new bounds and the popover visibly shifts. Live title updates while the popover is open are only safe because the slot can't grow or shrink. Don't reintroduce `NSStatusItem.variableLength` or freeze/restore — it will look like it works until you hit a check/uncheck/reorder that flips the top todo to a different-length title.

`popover.contentSize` should match the SwiftUI root frame (currently 320×380). A mismatch isn't the shifter but leaves dead space inside the popover.

**Menu bar title limit is 20 chars** — 28 chars was too wide; it made the status item push other menu bar icons and destabilized the popover anchor. Keep the limit at 20 in `AppDelegate.updateMenuBarTitle()`.

---

## Drag-to-Reorder Performance

**Use stable UUID identity in `ForEach`** — Never use `ForEach(activeTodos.indices, id: \.self)` — integer indices are unstable when the array reorders and cause SwiftUI to destroy/recreate rows. When you need both index and stable identity, use `ForEach(Array(activeTodos.enumerated()), id: \.element.id)`.

**`DragRowContainer: View, Equatable` + `.equatable()`** — Each draggable row is wrapped in `DragRowContainer` (bottom of `TodoListView.swift`). Precomputed value-type props (`isDragged`, `isReordering`, `isDropTarget`, `dropEdge`) are passed in and included in `==`; `dragSession` (class ref) and `@Binding editingItemId` are excluded. This lets SwiftUI skip body evaluation for unchanged rows during drag.

**`@Binding` bypasses `.equatable()` — use `@Observable` for frequently-changing drag state** — `@Binding` is a `DynamicProperty` that directly invalidates all views holding it when the underlying `@State` changes, bypassing `EquatableView`'s equality check. Putting `draggedItem` and `dropIndicator` as `@Binding` on `DragRowContainer` caused ALL 10 rows to re-render on every drag event. Fix: move drag state into `DragSession` (`@Observable` class, lives in `Views/DragSession.swift`). `TodoListView` owns `@State private var dragSession = DragSession()` and reads its properties in `activeList` to precompute per-row booleans. `DragRowContainer` holds `let dragSession: DragSession` (class reference, no binding overhead). Do NOT put mutable drag state as `@Binding` on leaf rows — always use `@Observable` for state that changes at drag-event frequency.
