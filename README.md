# MenuBard

A minimalist macOS menu bar todo app. Your most important task is always visible in the menu bar — everything else is one click away.

Built to enforce focus, not accumulate backlog.

## What it does

- Shows the top todo title inline next to the `checklist` icon. You control position 1 by dragging.
- Hard cap of **10 active todos**. When you hit 10, the app blocks new entries until you complete or delete one.
- **Completed folder** with its own 10-item cap (FIFO eviction). Not an archive — just recent history.
- Drag to reorder, click text to edit inline, hover to delete, click checkbox to complete or reactivate.
- Theme picker (System / Light / Dark), Open at Login toggle.

## What it does not do

No due dates, reminders, tags, projects, priorities, sub-tasks, natural language input, sync, export, or AI. If you need any of those, use a different app.

## Platform

macOS 14 (Sonoma) and above.

## Build

Open `MenuBard.xcodeproj` in Xcode and press **⌘R**.

```bash
xcodebuild -project MenuBard.xcodeproj -scheme MenuBard -configuration Debug build
```

No package dependencies, no SPM, no Tuist, no pre-build steps.

## Stack

- SwiftUI + AppKit (`NSStatusItem` / `NSPopover`)
- `@Observable` state, `UserDefaults` + JSON persistence
- Carbon `RegisterEventHotKey` for the global shortcut (no SPM dependencies)
- `SMAppService` for Open at Login
