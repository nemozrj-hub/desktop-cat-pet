# GitHub 设置

## 推荐仓库

推荐仓库名：

```text
desktop-cat-pet
```

当前 GitHub 仓库：

```text
https://github.com/nemozrj-hub/desktop-cat-pet
```

## 首次设置

如果本地还不是 Git 仓库，可以在项目目录运行：

```bash
git init
git add .
git commit -m "初始化麻吉桌宠项目"
git branch -M main
git remote add origin git@github.com:<owner>/desktop-cat-pet.git
git push -u origin main
git tag v0.4.0
git push origin v0.4.0
```

如果使用 HTTPS：

```bash
git remote add origin https://github.com/<owner>/desktop-cat-pet.git
```

## 发布产物

发布包不要直接提交进源码仓库，优先上传到 GitHub Releases 或 GitHub Actions Artifacts。

当前 `v0.4.0` 发布包路径：

```text
/Users/apple/Documents/Codex/2026-07-22/wo-xian/outputs/DesktopCatPet-0.4.0-universal.zip
```

## Codex 自动化

配置好远端后，可以对 Codex 说：

```text
用 vibe-project-manager 完成这个版本收尾，并同步到 GitHub。
```

项目内脚本：

```bash
./scripts/github_sync.sh "更新麻吉桌宠" 0.4.0
```

GitHub Actions 会在远端重新构建，并把 `.zip` 作为工作流产物保存。

## 推荐 Issue 标签

- `bug`
- `feature`
- `docs`
- `release`
- `test`
- `assets`
- `behavior`
- `macos`
