@AGENTS.md

# CLAUDE.md

本项目的完整规范是上方导入的 `AGENTS.md`，**每次改动前先读它，并沿用现有架构**。本文件只补充本机事实和常用入口，不新增规则。

## 本机环境事实

- 本机没有 Xcode / Android SDK，原生改动无法在这里编译，需到 Mac 上验证。
- `flutter analyze` 在本机会崩溃，统一改用 `dart analyze`，必须 0 issue。
- 依赖只能离线解析：`flutter pub get --offline`；未经允许不得新增 package。
- 每次改动后必须跑 `flutter test --no-pub`。
- Web QA：`tool/build_web.ps1` 构建，`node tool/qa/screens.mjs --out=build/qa/after` 截图。

## 关键文档

- 产品规划：`docs/美术之路产品规划.md`
- 设计规范与组件库：`docs/设计规范.md`、`lib/core/ui`（`import 'ui.dart'`）
- 后端缺口：`docs/后端缺口清单.md`
- 走查与修复记录：`docs/走查问题清单.md`、`docs/走查/`
- 运行说明与演示账号：`README.md`

## 分层约定（摘自 AGENTS.md，改动时不得打破）

`data/`（repository + models）→ `state/`（Riverpod StateNotifier）→ `ui/`。
