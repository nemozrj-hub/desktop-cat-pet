# GitHub Setup

## Recommended Repository

Create a private GitHub repository named:

```text
desktop-cat-pet
```

## First-Time Setup

From this project directory:

```bash
git init
git add .
git commit -m "Initialize DesktopCatPet project"
git branch -M main
git remote add origin git@github.com:<owner>/desktop-cat-pet.git
git push -u origin main
git tag v0.4.0
git push origin v0.4.0
```

If you use HTTPS instead of SSH:

```bash
git remote add origin https://github.com/<owner>/desktop-cat-pet.git
```

## Release Assets

Upload packaged files to GitHub Releases instead of committing them:

```text
/Users/apple/Documents/Codex/2026-07-22/wo-xian/outputs/DesktopCatPet-0.4.0-universal.zip
```

## Codex Automation

After the remote is configured, ask Codex:

```text
Run the DesktopCatPet finish flow and sync it to GitHub.
```

Codex should use:

```bash
./scripts/github_sync.sh "Update DesktopCatPet" 0.4.0
```

GitHub Actions will build the app again and keep the packaged `.zip` as a workflow artifact.

## Issue Labels

Recommended labels:

- `bug`
- `feature`
- `docs`
- `release`
- `test`
- `assets`
- `behavior`
- `macos`
