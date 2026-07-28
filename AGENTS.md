# 麻吉桌宠 Codex 项目规则

## 默认语言

- 除非用户明确要求，否则面向用户的沟通、总结、项目文档和任务拆分默认使用中文。
- 代码、命令、文件名、API 名称、系统错误信息和专有名词可以保留英文。

## 项目中心

- 这个仓库是“麻吉桌宠”的正式项目中心。
- 重要结论不要只留在 Codex 对话里，要沉淀到仓库文件。
- 产品范围写入 `docs/PRD.md`。
- 版本计划写入 `ROADMAP.md`。
- 技术选择写入 `docs/DECISIONS.md`。
- 测试策略写入 `docs/TEST_PLAN.md`。
- 任务拆分写入 `docs/TASK_BOARD.md`。
- 对话分工写入 `docs/PROJECT_WORKSTREAMS.md`。

## 对话拆分

- 一个 Codex 对话只负责一个主要产出。
- 产品、开发、测试、发布、素材资源尽量拆成不同对话。
- 开新对话前先读取 `README.md`、`AGENTS.md` 和对应工作流文档。
- 对话结束前，把结论更新到仓库文档或提交到 Git。

## 版本收尾

完成一个版本时默认执行：

1. 检查变更文件。
2. 更新相关文档。
3. 运行 `scripts/project_finalize.sh`。
4. 提交代码。
5. 稳定版本打 `vX.Y.Z` 标签。
6. 推送到 GitHub。
7. 用中文汇报提交号、标签、产物路径和未验证风险。

## Git 规则

- 提交源代码、文档、脚本、测试和小型运行资源。
- 不提交 `.build/`、`.app`、`.zip`、`.dmg`、密钥、证书、本机临时截图和本机状态文件。
- 发布产物优先放 GitHub Releases 或 GitHub Actions Artifacts。
