# Vibe Coding 工作流

本文档定义 Codex 在“麻吉桌宠”项目中完成一次开发或版本收尾时应该遵守的流程。

## 标准收尾流程

1. 检查变更文件。
2. 确认变更属于当前项目范围。
3. 根据实际变化更新文档：
   - `README.md`
   - `CHANGELOG.md`
   - `ROADMAP.md`
   - `docs/RELEASE_NOTES/vX.Y.Z.md`
   - `docs/DECISIONS.md`
   - `docs/TASK_BOARD.md`
4. 运行构建和验证脚本。
5. 打包 App。
6. 确认发布产物路径。
7. 用简洁明确的信息提交 Git。
8. 稳定版本打标签，例如 `v0.4.0`。
9. 如果已经配置远端仓库，推送到 GitHub。
10. 稳定版本需要准备 GitHub Release，并上传发布产物。

快捷命令：

```bash
./scripts/github_sync.sh "更新麻吉桌宠" 0.4.0
```

## 仓库规则

应该提交：

- 源代码
- 脚本
- 文档
- 小型运行资源
- 测试文件
- GitHub 模板和 CI 配置

不应该提交：

- `.build/`
- `.app`
- `.zip`
- `.dmg`
- 临时截图
- 本机凭据
- API key

## 版本规则

- 功能版本：`0.x.0`
- Bugfix 版本：`0.x.y`
- 稳定公开版本：`1.0.0`

## Codex 提示词

版本完成后，可以这样对 Codex 说：

```text
请执行麻吉桌宠项目收尾流程：
1. 检查变更文件
2. 根据需要更新 README、CHANGELOG、ROADMAP、release notes、技术决策和任务看板
3. 运行构建和验证
4. 打包 App
5. 准备 Git 提交和版本标签
6. 如果远端仓库已配置，推送到 GitHub
7. 准备 GitHub Releases 发布说明
```
