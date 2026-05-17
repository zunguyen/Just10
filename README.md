# Just10

A minimalist macOS menu bar todo app. Your most important task is always visible in the menu bar — everything else is one click away.

Built to enforce focus, not accumulate backlog.

![Demo](/img/img1.png)
![Demo](/img/img2.png)

## What it does

- Shows the top todo title inline next to the `checklist` icon. You control position 1 by dragging.
- Hard cap of **10 active todos**. When you hit 10, the app blocks new entries until you complete or delete one.
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

## Release Build

Open Terminal and run these commands from the repository root:

```bash
cd /path/to/menubar-todo
```

To produce a distributable `.app` in a predictable place:

```bash
./scripts/build-release.sh
```

That copies the Release build to:

```text
dist/Just10-DD-MM-YY.app
```

To wrap the app in a `.dmg` for GitHub Releases:

```bash
./scripts/package-dmg.sh
```

That produces:

```text
dist/Just10-DD-MM-YY.dmg
```

The date uses dashes because `/` is a path separator in macOS filenames.

Notes:

- If the shell says `permission denied`, run this once:

```bash
chmod +x scripts/build-release.sh scripts/package-dmg.sh
```

- The current build is signed with `Sign to Run Locally`, which is fine for local testing but not for public distribution.
- For public GitHub Releases, use a Developer ID certificate and notarize the app or the `.dmg`.
- If you publish an unsigned build, users will hit Gatekeeper warnings and need to use Finder's `Open` flow once.

## Stack

- SwiftUI + AppKit (`NSStatusItem` / `NSPopover`)
- `@Observable` state, `UserDefaults` + JSON persistence
- `SMAppService` for Open at Login
