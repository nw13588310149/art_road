# 修复记录 · F 校圈与校圈治理

范围：`lib/features/circle/**`、`lib/core/demo/fixtures/interaction_circle.dart` 及新增的 `interaction_circle_governance.dart`（`part` 文件，在 `registerCircleFixtures` 里登记，注册表不用改）、`lib/core/demo/fixtures/campus/campus_b_admin.dart`（只改 `postStatus0Count` 一行和对应 import）、新增测试 `test/circle_governance_test.dart`。

状态说明：已修复（做法）/ 部分修复（已做部分与剩余原因）/ 未修复（原因）。

汇总：5 条全部已修复（T-78、T-79、T-213、T-214、T-215）。T-78、T-79 和 T-215 的「···」菜单在 CD 批次已基本完成，本批次核对后补齐剩余部分并加了测试。

验证：
- `dart analyze lib/features/circle lib/core/demo/fixtures/interaction_circle.dart lib/core/demo/fixtures/interaction_circle_governance.dart lib/core/demo/fixtures/campus/campus_b_admin.dart test/circle_governance_test.dart`：无问题。
- `flutter test --no-pub test/circle_governance_test.dart test/admin_home_data_test.dart test/shell_navigation_test.dart test/smart_campus_views_test.dart`：46 个用例全部通过，其中新增 15 个。
- 按 `banned-words.json` 全部规则扫描改动文件：0 命中。顺带改掉两处旧文字：种子帖里的「第一层」，播放器注释里的「最大」。

## 逐条

- T-78 已修复：卡片模式下，未点赞 / 未收藏的图标用 textTertiary（#8B8993），已点赞 / 已收藏用品牌紫（CD 批次已改）。本批次补充：大图模式的白色图标和数字加一层柔和投影，压在白纸素描这类浅色画面上也看得清；激活态仍是品牌紫。测试覆盖卡片与大图两种模式下未激活 / 激活的图标颜色。
- T-79 已修复：教职工的身份由 `interaction_common.dart` 的 `demoStaffAuthor` 统一给出（CD 批次已改），赵雪显示「班主任 · 速写 · 联考冲刺1班」，评论里也一样。本批次加测试锁定：校圈接口里赵雪的身份以「班主任 · 速写」开头。
- T-213 已修复：校圈治理做成真正的治理模式。
  - 页头下方是 AppTabs「待处理 N / 已处理 / 全部动态」，默认打开「待处理」。
  - 待处理卡片：举报人数（如「3 人举报」）、原因标签（「代画作业 2」「广告营销」）、最近一次举报时间、被举报动态（缩略图、作者与身份、正文、发布时间）、最近一条举报说明，以及「保留」（secondary）和「删除」（danger）两个按钮。
  - 保留：一次普通确认后，举报标记为不成立，动态继续在校圈展示。
  - 删除：先在 AppDialog 里选删除原因（7 个选项，AppChip 单选；选「其他」必须写说明，另有选填的补充说明，最多 200 字），不选原因点「下一步」会出现红字提示；然后 `showAppConfirm(danger: true)`，确认文案里带上删除原因。
  - 处理完的记录立即从「待处理」移到「已处理」最前面，页签数字同步减少；删除的动态同时从「全部动态」里移除。
  - 已处理卡片：AppStatusTag「已删除」（danger）或「已保留」（success），删除原因或处理结果、处理人与处理时间、举报原因和人数、处理说明。删除的动态保留快照，处理记录里仍能看到原文。
  - 「全部动态」沿用卡片 / 大图两种视图，每条动态的「···」菜单里有「删除动态」，同样要填原因并二次确认，记录也进入「已处理」。
  - 数据只有一份：举报记录存放在 DemoStore 的 `circle:reports`，处理结果写入本机，重启后仍在。管理员工作台 `indexSum.postStatus0Count` 改为调用 `circlePendingReportCount()`，与「待处理」页签取同一个数，处理一条，工作台的「校圈治理」角标和统计也跟着少一条。
  - 种子数据：待处理 3 条（代画作业广告 3 人举报、不实考试信息 2 人、作品墙照片 1 人），已处理 2 条（奶茶店广告已删除、速写课示范视频已保留）。
  - 有加载骨架、空状态（待处理 / 已处理各一种）、首次加载失败的 AppErrorState（带重试）；已有数据时刷新失败只弹轻提示。
  - 普通校圈补上「举报」：别人的动态在「···」菜单里可以举报（原因弹窗与删除共用），举报进入「待处理」，工作台数字随之增加。管理员自己不显示「举报」。
- T-214 已修复：治理模式标题是「校圈治理」，不提供任何发布入口。页头没有「发布动态」；卡片模式和大图模式的空状态都不再显示「发布动态」按钮，也不再用「分享一张作品……」这类引导发布的文案；校圈里没有悬浮发帖按钮。普通校圈保留「发布动态」（有测试）。
- T-215 已修复：每张卡片右上角的删除方块改为「···」AppIconButton（semanticLabel「更多操作」）加 showAppMenu。自己的动态：「删除动态」（红字）后 `showAppConfirm(danger)`。别人的动态：「举报」。治理模式：「删除动态」，需填原因并二次确认。大图模式右上角原来的删除图标也换成同一个「···」菜单，白色图标放在半透明墨色底上。两个操作都不可用时不显示菜单，所以管理员在普通校圈里只有自己的动态有菜单。

## 新增演示接口（供后端缺口清单）

举报和删除共用的原因选项（客户端定义，接口接受任意非空文字）：广告营销、代画作业、不实考试信息、攻击或嘲讽他人、未经同意发布他人照片或作品、与画室学习无关、其他（选「其他」时 `remark` 必填）。说明 `remark` 最多 200 字。

| 方法 | 路径 | 谁能调 | 参数 | 返回 |
| --- | --- | --- | --- | --- |
| POST | `/app/school/v2/posts/postsReport` | 登录用户 | `postsId`、`reason`、`remark`（选填） | `true`。报错：不能举报自己发布的动态；请选择举报原因；选择「其他」时请写明原因；你已经举报过这条动态，请等待管理员处理 |
| POST | `/app/school/v2/manager/postsReportList` | 管理员 | `status`（0 待处理 / 1 已处理 / 不传为全部）、`current`、`size` | 分页 `{records, total, size, current, pages}`，每条记录字段见下。待处理按举报人数、再按最近举报时间倒序；已处理按处理时间倒序。`status=0` 的 `total` 等于 `indexSum.postStatus0Count` |
| POST | `/app/school/v2/manager/postsReportHandle` | 管理员 | `id`（举报记录 id）、`result`（1 保留 / 2 删除）、`reason`（删除时必填；保留不传时记为「举报不成立」）、`remark`（选填） | 处理后的单条记录。删除时同时删掉动态和评论。报错：举报记录不存在；这条举报已经处理过了；处理结果不正确；请选择删除原因 |
| POST | `/app/school/v2/manager/postsDelete` | 管理员 | `id`（动态 id）、`reason`（必填）、`remark`（选填） | 处理记录（没有被举报过时 `reportCount` 为 0）；这条动态有待处理的举报时一并结案 |

举报记录字段：同一条动态的多次举报合并成一条记录。
- 基本字段：`id`、`postsId`、`status`（0 待处理 / 1 已处理）、`result`（0 未处理 / 1 保留 / 2 删除）。
- 举报情况：`reportCount`；`reasons: [{reason, count}]`，按人数从多到少；`reports: [{reason, remark, createTime}]`，按时间倒序，不含举报人身份；`lastReportTime`。
- 处理情况：`handleReason`、`handleRemark`、`handlerName`、`handleTime`。
- 动态：`postDeleted`（0 / 1）；`post`，结构与 `postsList` 的单条相同，已删除的动态为删除时的快照。

已有接口的行为变化：
- `POST /app/school/v2/posts/postsDelete`：作者或管理员走普通删除时，这条动态待处理的举报自动结案（`result` 2，原因「作者已自行删除」或「管理员已删除」）。
- `POST /app/school/v2/manager/indexSum`：`postStatus0Count` 由固定的 3 改为待处理举报数（按动态计）。

## 需要其他文件配合（未改）

1. `lib/features/smart_campus/ui/admin_home_view.dart` 约 195 行：统计项「今日校圈」建议改为「校圈待处理」。这个数字现在是待处理的举报数，不是今天的发帖数。入口名「校圈治理」不变。
2. `campus_b_admin.dart`：按约定只改了 `postStatus0Count`。如果「今日待办」`toDoTodayCount` 和 `workReminders` 也要算上校圈举报，可以直接调用 `circlePendingReportCount()`。
3. `lib/app/router/app_router.dart` 的独立 `/circle` 路由总是打开普通校圈。管理员从这里进入可以发布、可以删除自己的动态，看不到别人动态的菜单，也不能举报；治理只在智慧校园「校圈治理」入口。是否让管理员从这里也进入治理，请协调者决定。
4. `docs/后端缺口清单.md`：请把上表的接口加进去。
5. 本机已有演示数据落盘的设备，要在登录页「重置演示数据」后才能看到新增的两条被举报动态。不重置时「待处理」只有作品墙 1 条，工作台和页签的数字仍然一致。

协调结果：1 已改为「校圈待处理」；2 `workReminders` 增加「N 条校圈举报待处理」提醒，「今日待办」仍只统计审批类事项；3 保持现状，独立「校圈」页对管理员是普通校圈（可发布学校动态），治理只在智慧校园「校圈治理」入口；4 已加入后端缺口清单。
