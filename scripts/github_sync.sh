#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MESSAGE="${1:-Update DesktopCatPet project}"
VERSION="${2:-}"

if ! git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$ROOT_DIR" init
  git -C "$ROOT_DIR" branch -M main
fi

if ! git -C "$ROOT_DIR" config user.name >/dev/null; then
  git -C "$ROOT_DIR" config user.name "Codex"
fi

if ! git -C "$ROOT_DIR" config user.email >/dev/null; then
  git -C "$ROOT_DIR" config user.email "codex@local"
fi

"$ROOT_DIR/scripts/project_finalize.sh" "${VERSION:-}"

git -C "$ROOT_DIR" add .

if git -C "$ROOT_DIR" diff --cached --quiet; then
  echo "No source changes to commit."
else
  git -C "$ROOT_DIR" commit -m "$MESSAGE"
fi

if [[ -n "$VERSION" ]]; then
  git -C "$ROOT_DIR" tag -f "v$VERSION"
fi

if git -C "$ROOT_DIR" remote get-url origin >/dev/null 2>&1; then
  git -C "$ROOT_DIR" push -u origin HEAD
  if [[ -n "$VERSION" ]]; then
    git -C "$ROOT_DIR" push -f origin "v$VERSION"
  fi
else
  echo "No GitHub remote configured yet."
  echo "Add one with: git remote add origin git@github.com:<owner>/desktop-cat-pet.git"
fi
