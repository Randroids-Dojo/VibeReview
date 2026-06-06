# VibeReview
Mac-native playtest capture tool for vibe-coded games. It pairs screenshots, reviewer notes, and live game state into structured Spiral-HTML artifacts so agents can turn human playtest feedback into followups, open questions, fun-factor audits, and future automated review workflows.

## What is implemented

VibeReview is a native macOS 13+ SwiftUI/AppKit app with:

- A review dashboard for starting, ending, and resuming sessions.
- A floating capture overlay while you play.
- A configurable global shortcut, defaulting to `Cmd+Shift+R`.
- A modal feedback prompt after each capture with screenshot preview, note, severity, rating, and tags.
- Screenshot capture for the main display.
- A Chrome/Chromium extension bridge that streams browser state snapshots to the app.
- Spiral-HTML export into the selected game project's docs when available.

## Build and run

```bash
./scripts/build.sh
./scripts/run.sh
```

Run unit tests:

```bash
./scripts/test.sh
```

The project is generated with XcodeGen from `project.yml`. The generated `VibeReview.xcodeproj` is checked in for normal Xcode use.

## Chrome extension setup

1. Run VibeReview.
2. Open Chrome or another Chromium browser.
3. Go to `chrome://extensions`.
4. Enable Developer Mode.
5. Click "Load unpacked" and choose this repo's `ChromeExtension` folder.
6. Open the browser game tab you want to review.

The app listens on `http://127.0.0.1:37717/snapshot`. The extension sends URL, title, viewport, scroll, selected text, DOM summary, storage values where permitted, canvas metadata, and recent console messages.

## Review workflow

1. Click "Start" and choose the game project folder.
2. VibeReview discovers the project root by walking upward to markers such as `.git`, `AGENTS.md`, `CLAUDE.md`, `package.json`, or `project.godot`.
3. Play the game in your browser.
4. Press `Cmd+Shift+R`.
5. Enter feedback in the prompt and save.
6. End the session from the dashboard when done.

## Artifact behavior

VibeReview detects the chosen project's docs shape:

- Full or partial Spiral-HTML: writes media under `docs/reviews/<session-id>/`, appends playtest evidence to `docs/PLAYTEST.html`, and creates `F-NNN` followups in `docs/FOLLOWUPS.html` for severe captures.
- Legacy Markdown docs: writes review artifacts under `docs/reviews/<session-id>/` or `Docs/reviews/<session-id>/` but does not mutate Markdown ledgers.
- No docs: creates minimal `docs/PLAYTEST.html`, `docs/FOLLOWUPS.html`, `docs/OPEN_QUESTIONS.html`, `docs/FUN_FACTOR_AUDIT.html`, and the session review folder.

Each session folder contains:

- `session.json`
- `vibereview-session.html`
- `captures/<capture-id>.png`
- `captures/<capture-id>.browser.json` when the browser bridge is connected
