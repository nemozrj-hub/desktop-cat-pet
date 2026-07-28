# DesktopCatPet

DesktopCatPet is an independent macOS desktop pet app built with native AppKit. It runs as a transparent floating companion window and does not depend on Codex at runtime.

## Current Version

`0.4.0`

## Features

- Transparent floating desktop pet window
- Menu bar controls
- Universal binary support for Intel Mac and Apple Silicon Mac
- Sprite sheet animation playback from JSON frame metadata
- Idle, walk, click, drag, and sleep animations
- Right-click pet context menu
- Settings window
- Size, opacity, always-on-top, click-through, and launch-at-login controls
- Behavior modes: auto, Dock sitting, edge walking, mouse following, and looking at mouse
- Multi-display aware movement boundaries
- Mood, intimacy, fatigue, and active time tracking
- Desktop speech bubbles for greetings, reminders, and status feedback
- Different reactions for head, body, and paw clicks
- Long-press hold behavior and drop feedback

## Build

```bash
./scripts/package_app.sh
```

The packaged app is written to:

```text
/Users/apple/Documents/Codex/2026-07-22/wo-xian/outputs/DesktopCatPet.app
```

## Smoke Tests

State-only smoke test:

```bash
./scripts/state_smoke_test.sh
```

GUI smoke test with screenshots:

```bash
./scripts/gui_smoke_test.sh
```

The GUI test requires macOS Accessibility and Screen Recording permissions for the process running the script.

## Finish a Version

```bash
./scripts/project_finalize.sh
```

Commit and push when a GitHub remote is configured:

```bash
./scripts/github_sync.sh "Update DesktopCatPet" 0.4.0
```

## Project Management

- Product requirements: [docs/PRD.md](docs/PRD.md)
- Roadmap: [ROADMAP.md](ROADMAP.md)
- Changelog: [CHANGELOG.md](CHANGELOG.md)
- Test plan: [docs/TEST_PLAN.md](docs/TEST_PLAN.md)
- Release notes: [docs/RELEASE_NOTES](docs/RELEASE_NOTES)
- Vibe coding workflow: [docs/VIBE_CODING_WORKFLOW.md](docs/VIBE_CODING_WORKFLOW.md)
