# Test Plan

## Automated Checks

Run:

```bash
./scripts/package_app.sh
```

Then verify:

- App package exists
- `Info.plist` is valid
- Binary is Universal: `x86_64 + arm64`
- Code signing verification passes
- Sprite JSON is valid
- App package resources match source resources

## State Smoke Test

Run from a regular Terminal session:

```bash
./scripts/state_smoke_test.sh
```

Coverage:

- Launch
- Sleep / wake
- Scale
- Opacity
- Click-through
- Random movement toggle
- Body-part click state change
- Behavior modes
- Quit

## GUI Smoke Test

Run from a regular Terminal session with Accessibility and Screen Recording permissions:

```bash
./scripts/gui_smoke_test.sh
```

Coverage:

- Visible floating window
- Screenshot capture
- Walk frame screenshot
- Click animation
- Drag movement
- Sleep / wake
- Scale
- Opacity
- Click-through
- Random movement
- Quit

## Manual Checklist

- Open app by double-clicking `DesktopCatPet.app`
- Confirm `Cat` appears in the menu bar
- Confirm pet appears with transparent background
- Click head, body, and paws
- Long-press and drag the pet
- Right-click the pet
- Switch all behavior modes
- Test with Dock at bottom, left, and right when possible
- Test with multiple displays when possible
- Quit and reopen; confirm position/settings persist

