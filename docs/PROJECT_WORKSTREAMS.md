# 项目工作流与 Codex 对话拆分

本文档定义“麻吉桌宠”在 Codex 中如何拆分项目、任务和对话。

## 总原则

- 仓库是长期记忆，对话是短期工作台。
- 每个对话只负责一个清晰产出。
- 每条对话结束前，要把结论沉淀到文档、代码、测试或 Git 提交中。
- 如果一个对话开始同时讨论产品、开发、测试、发布三件以上事情，应拆出新对话。

## 推荐对话线

### 1. 项目总控

用途：

- 维护项目规则和拆分方式。
- 统筹版本节奏。
- 决定任务归属。
- 做版本收尾和 GitHub 同步。

主要文件：

- `AGENTS.md`
- `docs/PROJECT_WORKSTREAMS.md`
- `docs/TASK_BOARD.md`
- `ROADMAP.md`
- `CHANGELOG.md`

### 2. 产品与体验

用途：

- 明确用户、场景、需求和优先级。
- 规划桌宠行为、互动、气泡、设置项。
- 定义每个版本的验收标准。

主要文件：

- `docs/PRD.md`
- `ROADMAP.md`
- `docs/RELEASE_NOTES/`

适合的问题：

- v0.6 应该做哪些功能？
- 用户怎么理解“资源包”？
- 哪些互动是必须做，哪些可以以后做？

### 3. 开发实现

用途：

- 编写和修改 AppKit 桌宠代码。
- 实现行为系统、窗口交互、资源加载、设置项。
- 保持代码与现有 Objective-C/AppKit 实现一致。

主要文件：

- `ObjC/main.m`
- `ObjC/GuiTestDriver.m`
- `Info.plist`
- `Sources/DesktopCatPet/Resources/`
- `scripts/`

适合的问题：

- 实现 v0.6 资源包系统。
- 修复行走动画或窗口交互 bug。
- 优化多屏幕边界和 Dock 贴边逻辑。

### 4. 测试与质量

用途：

- 设计自动化测试和手动验收清单。
- 跑状态测试、GUI 测试、打包验证。
- 记录缺陷和回归风险。

主要文件：

- `docs/TEST_PLAN.md`
- `scripts/state_smoke_test.sh`
- `scripts/gui_smoke_test.sh`
- `scripts/project_finalize.sh`

适合的问题：

- v0.4 的 GUI 交互是否全部可验证？
- 新增功能后需要补哪些测试？
- 打包产物是否仍支持 Intel 和 Apple Silicon？

### 5. 素材与资源包

用途：

- 管理 sprite sheet、JSON 帧数据、资源清理脚本。
- 规划未来资源包格式。
- 验证资源边界、透明背景和动画参数。

主要文件：

- `Sources/DesktopCatPet/Resources/`
- `scripts/clean_sprite_sheet.py`
- `docs/DECISIONS.md`

适合的问题：

- 如何支持多个宠物？
- 如何校验 sprite sheet 不串帧？
- 资源包格式如何设计？

### 6. 发布与分发

用途：

- 打包 `.app`、`.zip`、未来 `.dmg`。
- 处理签名、公证、GitHub Releases。
- 维护发布说明。

主要文件：

- `scripts/package_app.sh`
- `scripts/project_finalize.sh`
- `scripts/github_sync.sh`
- `docs/GITHUB_SETUP.md`
- `docs/RELEASE_NOTES/`

适合的问题：

- 完成 v0.6 并同步 GitHub。
- 生成可下载版本。
- 准备 v1.0 公共发布。

## 新对话启动模板

产品与体验：

```text
这是“麻吉桌宠”的产品与体验对话。请先读取 README.md、AGENTS.md、docs/PROJECT_WORKSTREAMS.md、docs/PRD.md、ROADMAP.md，然后只围绕产品范围、用户体验和版本优先级工作。不要修改代码，除非我明确要求。
```

开发实现：

```text
这是“麻吉桌宠”的开发实现对话。请先读取 README.md、AGENTS.md、docs/PROJECT_WORKSTREAMS.md、docs/DECISIONS.md 和相关源码，然后围绕指定功能或 bug 实现。完成后更新必要文档和测试。
```

测试与质量：

```text
这是“麻吉桌宠”的测试与质量对话。请先读取 README.md、AGENTS.md、docs/PROJECT_WORKSTREAMS.md、docs/TEST_PLAN.md 和 scripts/，然后设计或执行验证流程，记录缺陷和风险。
```

发布与分发：

```text
这是“麻吉桌宠”的发布与分发对话。请先读取 README.md、AGENTS.md、docs/PROJECT_WORKSTREAMS.md、CHANGELOG.md、docs/GITHUB_SETUP.md 和 scripts/，然后执行版本收尾、打包、标签和 GitHub 同步。
```

## 归档规则

- 已完成的一次性对话可以归档。
- 经常使用的总控对话可以置顶。
- 每个重要版本至少保留一个开发对话和一个发布对话。
- 对话标题应包含项目名和工作流，例如“麻吉桌宠：v0.6 资源包开发”。
