# Architecture Decisions

## 2026-07-27: Native macOS AppKit App

Decision: Build the MVP as a native AppKit app instead of Electron or Tauri.

Reason:

- Strong control over transparent floating windows
- Low runtime overhead
- Easier Universal binary packaging
- Better fit for macOS desktop pet behavior

## 2026-07-27: Objective-C AppKit Implementation

Decision: Use Objective-C + AppKit for the buildable app.

Reason:

- The local Swift command line toolchain was mismatched with the SDK in this environment
- Objective-C compiled cleanly with Command Line Tools
- AppKit APIs needed for this project are stable and direct

## 2026-07-27: Keep Release Packages Out of Git

Decision: Commit source, docs, scripts, and small assets to Git. Store packaged `.app`, `.zip`, and future `.dmg` files in GitHub Releases.

Reason:

- Keeps repository history small
- Makes release artifacts easier to find
- Avoids repeated binary churn in source history

