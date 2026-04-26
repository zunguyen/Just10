# Todo Task Menu Bar App — Product Requirements (v3 Final)

**Platform:** macOS 14 (Sonoma) and above

**Document status:** Locked for build

**Last updated:** April 26, 2026 (post-simplification pass: collapsible Completed folder removed, global hotkey removed, popover resized to 320×380, reactivation moves to bottom of active list)

---

## 1. Product Definition

A minimalist macOS menu bar app for capturing and tracking what you need to do today, or in the next 2 to 3 days. The user's most important todo is always visible inline in the menu bar. Everything else is one click away in a popover.

The app is deliberately simple. It does not compete with Things, Reminders, or TickTick on features. It competes on **focus**: a hard 10 todo cap forces the user to commit to a small, achievable set rather than building up a backlog of debt.

### Design principles

The app follows three principles that drive every decision below.

> **Capture must be frictionless.** A todo can be added in under 2 seconds from any application via global hotkey. No dates, no tags, no priority pickers, no project selectors.

> **The menu bar reflects deliberate user choice.** Position 1 in the list is what shows in the menu bar. The user controls position 1 by dragging. The system never reorders for them.

> **Constraints prevent debt.** A hard 10 todo cap means users finish what they start instead of accumulating an overwhelming backlog. The same cap applies to completed todos to keep the completed list useful, not archival.

---

## 2. Out of Scope

The following are **explicitly not part of this product**:

1. Due dates, time indicators, calendar integration
2. Priority levels, tags, projects, sub-tasks
3. Sections (Today, Tomorrow, Upcoming) or natural language date parsing
4. Notifications or reminders
5. Onboarding flow or tutorial screens
6. Data export, import, or backup
7. iCloud sync or any multi-device support (local only, single Mac)
8. AI features
9. Recurring todos

If a user needs any of the above, they should use a different app.

---

## 3. Core Features

### 3.1 Menu Bar Display

The menu bar shows the **`checklist` SF Symbol + the top todo's title**. The "top todo" is whichever item is at row 1 of the active list. Users control which todo appears by dragging items up or down inside the popover.

| State | Menu bar shows |
| --- | --- |
| Has 1 or more todos | Icon + top todo title, truncated to 20 characters |
| No active todos | Icon + "All done" |

**Long text behavior:** Truncate with ellipsis at 20 characters. Marquee scrolling is rejected. The full title is always visible inside the popover and on hover via the system tooltip. Width is not user-configurable in this build. (The 20-char limit is a tightening from the original 28; longer titles pushed neighboring menu bar icons and destabilized the popover anchor.)

**Promotion behavior:** When the top todo changes, the menu bar text updates immediately (no cross-fade animation in this build).

### 3.2 Popover Layout

The popover anchors beneath the menu bar icon. It is **320pt wide and 380pt tall (fixed)**. It dismisses on outside click, on `Esc`, or on re-clicking the menu bar icon.

The popover is divided into three zones, top to bottom:

1. **Input zone:** A single text field with `+` icon and "Add a todo…" placeholder. `Enter` commits and keeps the field focused for rapid entry. `Esc` blurs the field.
2. **List zone:** Scrollable column containing active todos followed inline by completed todos (no section header between them). When the list is fully empty, shows the message "Create your new todo" centered in the available space.
3. **Footer zone:** When any completed todos exist, a "Clear completed" button appears just below the scroll area (inline two-step `Clear → Confirm/Cancel`). Below that, a single thin row shows the `⌘Q Quit` hint on the left and the settings gear icon on the right.

### 3.3 Todo Row Behaviors

Every active todo row supports five interactions.

| Interaction | Trigger | Result |
| --- | --- | --- |
| Complete | Click empty checkbox | Checkmark fills, row moves to the bottom of the completed list (newly completed always appears last) |
| Edit | Click on todo text | Inline auto-growing text area opens |
| Delete | Hover row → ✕ icon appears, click it | Immediate delete (no undo toast in this build) |
| Reorder | Drag the row anywhere (no visible handle; entire active row is the drag affordance) | Row reorders, top row updates menu bar text |
| Reactivate (from completed list) | Click filled checkbox on a completed row | Todo returns to the **bottom of the active list** (no longer "keeps prior order") |

### 3.4 Inline Editing

Clicking a todo's text transforms the row into an inline multi-line text area that wraps up to 6 lines.

Keyboard shortcuts inside the editor:

1. `Enter` saves and exits edit mode
2. `Esc` cancels and reverts to the original text
3. Clicking outside the field saves the change

Newline characters are stripped on save — todo titles are single-line. Only one row may be in edit mode at a time; opening a second row's editor saves the first.

### 3.5 Checkbox Top Alignment

For todos that wrap to 2 or more lines, the checkbox is **top-aligned with the first line of text**, not vertically centered with the row. This holds true in three states:

1. Active todos that wrap in the list
2. Todos being actively edited in the multi-line text area
3. Completed todos with strikethrough that wrap to multiple lines

SwiftUI implementation uses `HStack(alignment: .top)` with matching top padding on the checkbox to align it with the first text baseline.

### 3.6 Completed List

Completed todos render **inline at the bottom of the same scroll list as active todos**, with no "Completed" header, no count badge, and no expand/collapse control. The simplification was deliberate: the collapsed-by-default folder hid the result of the user's action (the just-completed todo) and added a click to reach it.

Completed rows are visually distinguished by the filled checkmark icon (`checkmark.circle.fill` in secondary color) and a strikethrough on the title text.

**Sort order:** Completed todos are sorted by `completedAt` **ascending** (oldest at top of completed group, newest at the very bottom of the list). The most recently completed todo always appears last.

**Completed list cap:** Holds a maximum of **10 completed todos**. When an 11th todo is completed, the oldest completed todo is automatically removed (FIFO). This prevents the list from becoming an archive and keeps the app focused on recent activity.

> The 10 cap on completed todos mirrors the 10 cap on active todos. Together they enforce the product's core principle: this is a tool for what you are doing now, not a record of what you have ever done.

**Clear completed button:** When at least one completed todo exists, a "Clear completed" button appears just below the scroll list (above the footer). Tapping it swaps inline for `Confirm` (red) + `Cancel`. `Confirm` deletes all completed todos immediately. There is no undo toast in this build — a system-level confirmation dialog (`.confirmationDialog`/`.alert`) is intentionally avoided because it triggers `NSViewBridgeErrorCanceled` console noise inside `NSPopover`.

**Reactivation behavior:** When the user clicks the filled checkbox of a completed todo, the todo returns to the active list at the **bottom** (its `order` is reassigned to `max(activeOrders) + 1`). The previous "keeps prior order" behavior was changed because reactivated todos slotting into the middle of the active list felt like a surprise; landing at the bottom matches the natural reading order of "this is the next thing I'm working on again."

### 3.7 Active Todo Cap

The active list has a **hard cap of 10 todos**. This is the central constraint of the product.

The cap exists to prevent the user from accumulating debt. The product's purpose is to track what gets done today or in the next 2 to 3 days. More than 10 todos signals the user is using the wrong tool.

**Visual cue as the user approaches the cap:** When the active list reaches 8 of 10, a small counter appears in the footer: `8 / 10`. At 10 of 10, the counter shifts to the warning color and the input placeholder changes from "Add a todo…" to "List full · complete one to continue".

**Behavior when adding the 11th todo:** The input field rejects the entry with an inline message that appears below the input.

> **You've reached 10 todos.** Complete or delete one to add more.

The user's typed text is preserved in the input field so they don't lose what they wrote. The message dismisses automatically when the count drops below 10 or when the user clicks elsewhere.

**Drag-and-drop scope (locked decision):** Drag-and-drop reordering only works **within the active list**. Users cannot drag from the completed list back into active todos. Reactivation is done via the checkbox.

---

## 4. Empty State

When the active list is empty, the list zone shows the message "Create your new todo" as a single line of secondary-color text, centered horizontally and vertically within the available space.

There is no illustration, no call-to-action button, and no extra copy. The input field above remains the obvious next action.

There is no first-run onboarding. The interface is simple enough that a single empty state message is the only guidance needed.

---

## 5. App Lifecycle

### 5.1 Quit

`⌘Q` quits the app and removes it from the menu bar. On the very first quit ever, a confirmation dialog appears.

> "Quit Todo? Your todos are saved. You can reopen anytime from Applications."
> [Cancel] [Quit]
> 
> ☐ Don't ask again

After the user dismisses this dialog (with or without checking the box), subsequent quits are instant.

### 5.2 Launch at Login

Settings includes a single labeled toggle.

> **Launch at Login**
> Launch automatically when you sign in to your Mac.

**Default:** Off. The user opts in.

**Implementation:** `SMAppService.mainApp.register()` (the modern macOS 13+ API, fully supported on macOS 14). On first toggle, macOS may prompt the user to approve in System Settings → General → Login Items. If registration fails, the settings panel shows a help link to the relevant System Settings pane.

### 5.3 Global Hotkey

**Removed from this build.** The product opens via the menu bar icon only. A `GlobalHotkey` helper class still exists in `Helpers/` from earlier exploration but is not wired up; the hotkey setting and recorder UI were removed when the Settings panel was simplified. Click the menu bar icon (or use the standard `Esc` to dismiss) — there is no system-wide keyboard activation.

---

## 6. Settings Panel

Accessed via the gear icon in the popover footer. Two settings total, reflecting the minimalist spirit of the app.

| Setting | Type | Default |
| --- | --- | --- |
| Launch at Login | Toggle | Off |
| Theme | Segmented: System / Light / Dark | System |

Removed in the simplification pass: global hotkey recorder, "Clear all todos" destructive action, "Show menu bar text" toggle. Menu bar text width remains fixed (20-char truncation, see §3.1).

Settings persist via `UserDefaults`. Changes take effect immediately without requiring an app restart.

---

## 7. Accessibility

Accessibility is a first-class requirement, not an afterthought. The app must pass an Apple accessibility audit before shipping. **Caveat for this build:** keyboard-only operation (§7.3) is intentionally minimal and will not pass a full audit on its own; per-row keyboard navigation is deferred to a later build. Typography (§7.1), VoiceOver labels (§7.2), and system-preference respect (§7.4–7.5) are in scope and must pass.

### 7.1 Typography

> **No text below 13pt anywhere in the UI.** Body text is 14pt regular. Secondary metadata (counters, hints, footer labels) is 13pt. Menu bar text follows the system size, which the user can adjust in System Settings → Displays.

This exceeds the macOS minimum and reads comfortably on Retina and non-Retina displays.

### 7.2 VoiceOver

Every interactive element has a descriptive label. Examples of expected announcements:

1. Menu bar item: "Todo. Top todo: Portfolio with playground. Click to open list."
2. Active todo row: "Todo: Portfolio with playground. Not completed. Actions available."
3. Completing a todo: "Todo completed. Moved to bottom of completed list."
4. Reactivating a todo: "Todo reactivated. Moved to bottom of active list."

VoiceOver rotor groups todos into "Active" and "Completed" sections (logical grouping by `isCompleted`, even though the visual list is one continuous scroll).

### 7.3 Keyboard Support

Keyboard support in this build is intentionally minimal — limited to the input field, dialog dismissal, and quit. Per-row keyboard navigation (Tab to a row, `Space` to toggle, `Enter` to edit, `⌘⌫` to delete, `↑`/`↓` to move focus, `⌥↑`/`⌥↓` to reorder) is **not implemented**. Rows are mouse-driven only.

**What works today:**

| Shortcut | Where | Action |
| --- | --- | --- |
| `Enter` | Add-todo input field | Commits the new todo, keeps the field focused |
| `Esc` | Inside a row's edit field | Cancels the edit, reverts the title |
| `Esc` | Settings panel | Returns to the todo list |
| `⌘Q` | Anywhere in the popover | Quits the app (with first-run confirmation per §5.1) |

**Out of scope for this build:** focusable rows, focus rings on rows, `Space`/`Enter`/`⌘⌫` per-row shortcuts, arrow-key row navigation, `⌥↑`/`⌥↓` reorder, undo toast for delete. `TodoStore.moveActive(_:by:)` exists in the model layer as scaffolding for future keyboard reordering, but no view currently calls it.

**If keyboard navigation is added later:** it should go through `@FocusState focusedItemId: UUID?` on `TodoListView` (matching the existing `editingItemId` pattern), and rows should opt in via a focus modifier — completed rows pass `nil` and stay non-focusable.

### 7.4 System Preferences Respected

| Preference | Behavior |
| --- | --- |
| Reduce Motion | Disables fade and slide animations, instant state changes |
| Increase Contrast | Strengthens borders to 1pt, removes vibrancy, max-contrast text |
| Reduce Transparency | Replaces popover material with solid background |
| Differentiate Without Color | Adds icons and patterns where color alone conveys meaning |
| Larger Text (Dynamic Type) | All text scales proportionally up to user's preferred size |

### 7.5 Light and Dark Mode

SwiftUI's `@Environment(\.colorScheme)` drives all colors. No hardcoded hex values are permitted in the codebase. The test matrix covers both modes plus Increase Contrast variants of each, for 4 total visual states per screen.

---

## 8. Technical Architecture

| Layer | Choice | Rationale |
| --- | --- | --- |
| UI Framework | SwiftUI lifecycle + AppKit `NSStatusItem`/`NSPopover` via `NSApplicationDelegateAdaptor` | `MenuBarExtra` is too restrictive for a custom popover anchored to a status item; AppKit gives precise control. |
| State | Swift `@Observable` (Observation framework) | Zero-dependency, native, sufficient for a 10+10 dataset. TCA was evaluated and rejected as overkill. |
| Storage | `UserDefaults` + `JSONEncoder/JSONDecoder` | Tiny dataset (≤20 items). Core Data + SQLite was evaluated and rejected — the migration tooling and ceremony are not justified at this scale. |
| Hotkeys | None in current build. A `GlobalHotkey` Carbon helper exists in `Helpers/` from earlier exploration but is not wired up. | Cut to simplify the surface area; revisit if user feedback demands it. |
| Login Items | `SMAppService.mainApp` | Modern macOS 13+ API, requires only a valid bundle ID. |

**Storage:** `UserDefaults` key `menubard.todos` (JSON-encoded `[TodoItem]`). No soft-delete (no undo toast in this build, see §3.6).

**Schema:** `TodoItem { id: UUID, title: String, isCompleted: Bool, order: Int, createdAt: Date, completedAt: Date? }`.

---

## 9. Performance Targets

> **Cold launch under 400ms.** Popover open under 80ms from icon click. Quick capture global shortcut response under 120ms end-to-end. Memory footprint under 80MB. Idle CPU under 1%.

These targets are achievable for an app with a 10 active todo cap and 10 completed todo cap. The dataset is intentionally tiny.

---

## 10. Locked Decisions

For clarity, here are all the explicit decisions made during this spec, in one place.

| # | Decision | Choice |
| --- | --- | --- |
| 1 | Maximum active todos | 10 hard cap |
| 2 | Maximum completed todos | 10 (FIFO eviction — oldest completed evicted first) |
| 3 | Newly completed placement | Bottom of completed list (sorted by `completedAt` ascending) |
| 4 | Drag-and-drop scope | Within active list only |
| 5 | Long menu bar text behavior | Truncate with ellipsis, no scrolling |
| 6 | Single delete confirmation | None, immediate, no undo |
| 7 | Clear all confirmation | Inline two-step `Clear → Confirm/Cancel`, no undo toast |
| 8 | Quit confirmation | First time only, dismissable |
| 9 | Launch at Login default | Off |
| 10 | First-run onboarding | None |
| 11 | Data export and import | Out of scope |
| 12 | Sync across devices | Out of scope |
| 13 | Empty state message | "Create your new todo" |
| 14 | Cap-reached message | "You've reached 10 todos. Complete or delete one to add more." |
| 15 | Counter visibility threshold | 8 of 10 |
| 16 | Reactivation placement | Bottom of active list (`order` reassigned to `max+1`). **Changed from earlier "keeps prior order".** |
| 17 | Completed list presentation | Inline at bottom of scroll list (no collapsible "Completed" folder, no header, no count badge). **Changed from earlier collapsible folder.** |
| 18 | Tech stack | `@Observable` + `UserDefaults`+JSON (no SPM, no TCA, no Core Data, no global hotkey) |
| 19 | Menu bar display | `checklist` SF Symbol + title (20-char truncation; no width slider, no show/hide toggle) |
| 20 | Popover size | Fixed 320×380pt. **Changed from earlier 280×400.** |
| 21 | Global hotkey | Removed from product (Settings panel simplified to Launch at Login + Theme only) |

---

## 11. Open Items for Build Phase

These are not blocking the spec but should be addressed during implementation.

1. **Final menu bar icon design.** Filled vs outlined states, single-color SF Symbol vs custom asset.
2. **Sound effects.** Should completing a todo play a subtle sound? Default off, settings toggle if added.
3. **Undo toast position and animation.** Bottom of popover, slides up with 200ms ease-out.
4. **What happens to the menu bar text when the popover is open?** Recommend: stays the same, since the user can already see the full list. No special state.
5. **Behavior when the user's system accent color changes mid-session.** Recommend: live update, no restart.

---

## 12. Success Metrics

> **North Star metric:** *Average active todos per user per day* — target range is 3 to 7. Below 3 means users aren't capturing enough. Above 7 means users are accumulating debt despite the cap.

Supporting metrics:

1. **D7 retention:** Target 40% or higher
2. **Completion rate:** Percentage of created todos that get marked complete within 7 days. Target 70% or higher.
3. **Cap-hit frequency:** Percentage of users who hit the 10 todo cap in a given week. Target under 15%, since hitting the cap regularly suggests the cap is too low or the user is mismatched with the product.
4. **Average time-to-complete:** Median hours between todo creation and completion. Target under 24 hours, supporting the "today plus 2 to 3 days" use case.

## Reference

Check `reference` folder to see some visual reference images