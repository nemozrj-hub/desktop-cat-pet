# 麻吉桌宠 / DesktopCatPet

麻吉桌宠是一个原生 macOS 桌宠应用，基于 AppKit 实现。它以透明悬浮窗口的形式运行在桌面上，可以独立启动和使用，运行时不依赖 Codex。

## 当前版本

`0.4.0`

## 当前能力

- 透明悬浮桌宠窗口
- 菜单栏控制入口
- 同时支持 Intel Mac 和 Apple Silicon Mac 的 Universal binary
- 基于 sprite sheet 和 JSON 帧数据播放动画
- 支持待机、行走、点击、拖拽、睡觉等动画状态
- 支持右键点击桌宠弹出菜单
- 支持设置窗口
- 支持大小、透明度、置顶、点击穿透、开机启动等控制项
- 支持自动行为、坐在 Dock 上、贴边走、跟随鼠标、看向鼠标等行为模式
- 支持多屏幕边界感知
- 支持心情、亲密度、疲劳、活跃时间等状态
- 支持桌面气泡，用于打招呼、提醒和状态反馈
- 点击头部、身体、爪子会触发不同反应
- 长按可以抱起，松手后落地

## 构建

```bash
./scripts/package_app.sh
```

打包后的 App 默认输出到：

```text
/Users/apple/Documents/Codex/2026-07-22/wo-xian/outputs/DesktopCatPet.app
```

## 冒烟测试

状态测试：

```bash
./scripts/state_smoke_test.sh
```

GUI 截图测试：

```bash
./scripts/gui_smoke_test.sh
```

GUI 测试需要在 macOS“系统设置 > 隐私与安全性”中给运行脚本的工具开启“辅助功能”和“屏幕录制”权限。

## 版本收尾

```bash
./scripts/project_finalize.sh
```

如果已经配置 GitHub 远端，可以提交并推送：

```bash
./scripts/github_sync.sh "更新麻吉桌宠" 0.4.0
```

## 项目管理入口

- 项目规则：[AGENTS.md](AGENTS.md)
- 产品需求：[docs/PRD.md](docs/PRD.md)
- 路线图：[ROADMAP.md](ROADMAP.md)
- 变更记录：[CHANGELOG.md](CHANGELOG.md)
- 测试计划：[docs/TEST_PLAN.md](docs/TEST_PLAN.md)
- 任务看板：[docs/TASK_BOARD.md](docs/TASK_BOARD.md)
- Codex 对话拆分：[docs/PROJECT_WORKSTREAMS.md](docs/PROJECT_WORKSTREAMS.md)
- 技术决策：[docs/DECISIONS.md](docs/DECISIONS.md)
- GitHub 设置：[docs/GITHUB_SETUP.md](docs/GITHUB_SETUP.md)
- 发布说明：[docs/RELEASE_NOTES](docs/RELEASE_NOTES)
- Vibe coding 工作流：[docs/VIBE_CODING_WORKFLOW.md](docs/VIBE_CODING_WORKFLOW.md)
