# MenuBard — Project Memory

Known bugs and patterns to avoid repeating.

---

## SwiftUI Pitfalls

**`@ViewBuilder` on multi-statement `some View` computed properties** — If a computed property has a `let` declaration before the view expression, Swift treats it as multi-statement and cannot infer the opaque return type. Raises "Function declares an opaque return type, but has no return statements." Fix: add `@ViewBuilder`. Hit on `activeList` in `TodoListView` after adding `let activeTodos = ...` at the top.

**`Color.clear` placeholder needs `.frame(height: 0)`** — `Color.clear` with no frame constraint expands to fill available vertical space in a `VStack` outside a `ScrollView`. Always use `Color.clear.frame(height: 0).accessibilityHidden(true)` as a zero-height placeholder in `trailingControls` or similar toggle-visible slots.

---

## NSPopover

**Popover repositions/shifts during drag** — `NSHostingController` includes `.preferredContentSize` in `sizingOptions` by default, so any SwiftUI layout change during drag causes the popover to resize and reposition. Fix: set `hostingController.sizingOptions = []` before assigning to `popover.contentViewController`. This locks the popover at its fixed `contentSize` (320×400) forever. Already applied in `AppDelegate.setupPopover()`.

**Menu bar title limit is 20 chars** — 28 chars was too wide; it made the status item push other menu bar icons and destabilized the popover anchor. Keep the limit at 20 in `AppDelegate.updateMenuBarTitle()`.

---

## Drag-to-Reorder Performance

**Use stable UUID identity in `ForEach`** — Never use `ForEach(activeTodos.indices, id: \.self)` — integer indices are unstable when the array reorders and cause SwiftUI to destroy/recreate rows. When you need both index and stable identity, use `ForEach(Array(activeTodos.enumerated()), id: \.element.id)`.

**`DragRowContainer: View, Equatable` + `.equatable()`** — Each draggable row is wrapped in `DragRowContainer` (bottom of `TodoListView.swift`). Precomputed value-type props (`isDragged`, `isReordering`, `isDropTarget`, `dropEdge`) are passed in and included in `==`; `dragSession` (class ref) and `@Binding editingItemId` are excluded. This lets SwiftUI skip body evaluation for unchanged rows during drag.

**`@Binding` bypasses `.equatable()` — use `@Observable` for frequently-changing drag state** — `@Binding` is a `DynamicProperty` that directly invalidates all views holding it when the underlying `@State` changes, bypassing `EquatableView`'s equality check. Putting `draggedItem` and `dropIndicator` as `@Binding` on `DragRowContainer` caused ALL 10 rows to re-render on every drag event. Fix: move drag state into `DragSession` (`@Observable` class, lives in `Views/DragSession.swift`). `TodoListView` owns `@State private var dragSession = DragSession()` and reads its properties in `activeList` to precompute per-row booleans. `DragRowContainer` holds `let dragSession: DragSession` (class reference, no binding overhead). Do NOT put mutable drag state as `@Binding` on leaf rows — always use `@Observable` for state that changes at drag-event frequency.
