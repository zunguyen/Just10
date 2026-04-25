# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Requirements

Must read `Docs/Requirements.md`. The spec is the source of truth for product behavior; CLAUDE.md only covers how the code is laid out.

## Build & Run

Open `MenuBard.xcodeproj` in Xcode and press **⌘R**. No package dependencies, no SPM, no Tuist, no pre-build steps.

```bash
xcodebuild -project MenuBard.xcodeproj -scheme MenuBard -configuration Debug build
```

There are no tests or linters configured.

## Architecture

macOS-only menu bar app (no dock icon — `LSUIElement=YES`). SwiftUI lifecycle with an AppKit delegate for the status bar and global hotkey. Minimum target: **macOS 14**.

### State

- `TodoStore` (`@Observable`) — todo CRUD, `activeCap = 10` and `completedCap = 10`. `add(title:) -> Bool` returns `false` when the active cap is reached. `enforceCompletedCap()` runs FIFO eviction in `toggle(_:)` after marking complete. `moveActive(_:by:)` is the keyboard-reorder helper.
- `AppSettings` (`@Observable`) — `theme`, `hotkey: HotkeyCombo`, `hasShownQuitConfirmation`. Persists each property to `UserDefaults` in its `didSet`.
- Both stores are owned by `AppDelegate` and injected into SwiftUI via `.environment(store).environment(settings)`. Read with `@Environment(TodoStore.self)` / `@Environment(AppSettings.self)`. For writable bindings to `AppSettings` properties, use `Bindable(settings).theme` inline (or `@Bindable var settings = settings` in body) — `@Environment` itself doesn't yield bindings.
- AppDelegate uses `withObservationTracking` (re-registered on each fire) to (a) update the `NSStatusItem` title and (b) re-register the Carbon hot key when `settings.hotkey` changes.
- Persistence: `UserDefaults` + `JSONEncoder/JSONDecoder`. No Core Data.

### View hierarchy

- `ContentView` — thin router between `TodoListView` and `SettingsView`. Applies `.preferredColorScheme(settings.theme.colorScheme)` for the System/Light/Dark theme picker.
- `TodoListView` — owns add-field state, drag state, edit-coordination state (`editingItemId: UUID?`), and row-focus state (`@FocusState focusedItemId: UUID?`). Hosts the cap UX: `8/10` counter (visible when active count ≥ 8, orange when at 10), `"You've reached 10 todos…"` inline message after a rejected add, and `"List full · complete one to continue"` placeholder.
- `TodoRowView` — checkbox, title `Text` with `.onTapGesture` to enter edit mode (no pencil button), inline multiline `TextField(axis: .vertical, lineLimit: 1...6)`, hover-only ✕. Coordinated edit via `editingItemId: Binding<UUID?>` (only one row edits at a time; focus loss saves; Esc cancels). Conditionally focusable via `RowFocusModifier` — completed rows pass `nil` and stay non-focusable.
- `TodoDropDelegate` — DropDelegate struct that calls `store.move(from:to:)` live as items are dragged.

### Per-row keyboard nav (Requirements §7.3)

Wired in `TodoRowView` via `.onKeyPress`:

- `Space` → toggle complete
- `Enter` → enter edit mode (when row focused, not editing)
- `⌘⌫` → delete
- `⌥↑` / `⌥↓` → reorder (calls `store.moveActive`)
- Arrow up/down without `⌥` is ignored so SwiftUI's default focus traversal handles `Tab`/arrow movement.

Note: getting the `KeyPress` value (for modifier inspection) requires the `onKeyPress(keys:_:)` form — the single-`KeyEquivalent` overload's closure takes no arguments.

### NSPopover constraints (do not break)

- **No `List`** — `NSTableView` (List's backing) breaks inside `NSPopover` with ViewBridge errors.
- **No `.confirmationDialog`, `.alert`, or `.sheet`** inside the popover — they present via a remote view service that gets cancelled when the popover loses key-window status (`NSViewBridgeErrorCanceled` / code 18). Use inline two-step confirmation (`Clear → Confirm/Cancel`) instead.
- The first-quit confirmation in `applicationShouldTerminate` uses `NSAlert` (an AppKit window), not SwiftUI presentation — that's fine because it runs after the popover has terminated state.
- `code=18` console messages can still appear from system components (login-items helper, status menu, text-input services); Apple flags them as benign and we cannot suppress them from app code.

### Project layout

- `MenuBard.xcodeproj/project.pbxproj` is hand-crafted (no Tuist). When adding a new Swift file, register it in **four places**: `PBXBuildFile`, `PBXFileReference`, the appropriate `PBXGroup`, and `PBXSourcesBuildPhase`. UUIDs follow the pattern `1A…N` (file ref) and `2A…N` (build file).

### Skills

Read skills in `skills/` — `swiftui-pro`, `swiftui-design-principles-main`, `swift-accessibility-skill`, and `macos-menubar-tuist-app` apply.
