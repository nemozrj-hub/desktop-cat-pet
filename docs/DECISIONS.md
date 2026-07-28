# 技术决策记录

## 2026-07-27：使用原生 macOS AppKit 应用

决策：MVP 使用原生 AppKit，而不是 Electron 或 Tauri。

原因：

- 对透明悬浮窗口的控制更直接。
- 运行时开销更低。
- 更适合打包 Universal binary。
- 更符合 macOS 桌宠的窗口、菜单栏和交互需求。

## 2026-07-27：使用 Objective-C + AppKit 实现可构建版本

决策：当前可构建 App 使用 Objective-C + AppKit。

原因：

- 本地 Swift 命令行工具链与 SDK 存在不匹配问题。
- Objective-C 能用当前 Command Line Tools 稳定编译。
- 项目需要的 AppKit API 稳定且直接。

## 2026-07-27：发布包不进入 Git

决策：Git 只提交源码、文档、脚本和小型资源；`.app`、`.zip`、未来 `.dmg` 等发布产物放到 GitHub Releases 或 GitHub Actions Artifacts。

原因：

- 保持仓库历史轻量。
- 发布产物更容易被用户找到。
- 避免源码仓库反复记录大体积二进制变化。

## 2026-07-28：按工作流拆分 Codex 对话

决策：项目内长期工作拆分为项目总控、产品与体验、开发实现、测试与质量、素材与资源包、发布与分发等对话线。

原因：

- 避免一个对话承载过多上下文。
- 让每条对话只负责一个清晰产出。
- 通过仓库文档和 Git 提交同步上下文，而不是依赖聊天历史。
