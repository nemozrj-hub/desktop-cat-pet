# Vibe Coding Workflow

This document defines how Codex should finish each development pass for this project.

## Standard Finish Flow

1. Inspect changed files.
2. Confirm files belong to the current project scope.
3. Update docs:
   - `README.md`
   - `CHANGELOG.md`
   - `ROADMAP.md` when plans change
   - `docs/RELEASE_NOTES/vX.Y.Z.md`
   - `docs/DECISIONS.md` for major technical decisions
4. Run build and validation scripts.
5. Package the app.
6. Confirm release artifact path.
7. Commit with a concise message.
8. Tag stable versions, for example `v0.4.0`.
9. Push to GitHub when a remote exists.
10. Create a GitHub Release for stable versions and upload release assets.

Shortcut:

```bash
./scripts/github_sync.sh "Update DesktopCatPet" 0.4.0
```

## Repository Rules

Commit:

- Source code
- Scripts
- Documentation
- Small runtime assets
- Test files

Do not commit:

- `.build/`
- `.app`
- `.zip`
- `.dmg`
- temporary screenshots
- local credentials
- API keys

## Version Rule

- Feature version: `0.x.0`
- Bugfix version: `0.x.y`
- Stable public version: `1.0.0`

## Codex Prompt

Use this prompt after a version is complete:

```text
Please run the DesktopCatPet project finish flow:
1. inspect changed files
2. update README, CHANGELOG, ROADMAP, release notes, and decisions if needed
3. run build and validation
4. package the app
5. prepare git commit and tag
6. push to GitHub if the remote is configured
7. prepare release notes for GitHub Releases
```
