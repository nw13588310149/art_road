# 修复记录 · B 美术模块（学情中心 / 作品档案与作品点评 / 范画库）

范围：`lib/features/study_center/**`、`lib/features/artworks/**`、`lib/features/gallery/**`，演示数据 `lib/core/demo/data/demo_marking_data.dart`、`demo_artwork_data.dart`、`lib/core/demo/fixtures/marking_*_fixtures.dart`。画室工具箱（S-64～S-78）由其他批次处理，不在本记录内。

状态：本批次已完成。验证：`dart analyze`（三个功能目录 + `lib/core/demo` + 相关测试）无问题；`flutter test --no-pub test/study_center_logic_test.dart test/artworks_logic_test.dart test/marking_demo_consistency_test.dart test/marking_pages_smoke_test.dart` 全部通过（页面冒烟测试在 950×740 与 760×720 两个尺寸下渲染学情总览、成绩报告、成长曲线、评分标准弹窗、班级学情、作品档案、作品详情、上传弹窗、作品点评、点评工作台、点评标签、范画库与范画详情，无溢出、无异常）。

## 学生端（01-访客与学生.md）

### 学情中心
- S-35：已修复。页头副标题改为「示范画室 · 城东校区 · 学号 2027001」（学号与学生名册同一规则，演示数据 `DemoPerson.studentNo`，接口 `profile.studentNo`），准考证号只在考试卡上按场次显示。
- S-36：已修复。超过百分比统一按（参考人数 − 名次）/ 参考人数计算（`surpassedPercentOf` 与演示接口同一公式），有名次时以名次和参考人数现算；文案写明范围「超过全画室 82% 的考生」。排名写成「第 7 名 / 38 人参考」「第 4 名 / 13 人参考」，分母口径可见。
- S-37：已修复。「成长曲线」改 AppButton(primary, sm)，「超过 x%」改 AppTag(brand)，「查看完整报告」改 AppButton(quiet, sm)。
- S-38：已修复。学情中心所有日期统一 YYYY-MM-DD（坐标轴 MM-DD）；总分环中心为「265.5」+「/ 300 分」，去掉渐变弧与入场动画。首页写法由 A 批次处理。
- S-39：已修复。累计测评 / 已出分 / 待出成绩并入考试卡底部一行 AppStatTile(boxed) ×3，「待更新」改「待出成绩」。

### 作品档案
- S-40：已修复。作品卡、详情、教师端统一 `ArtworkStatusTag` → AppTag(warning「待点评」/ success「已点评」)，浅底深字 12px；张数角标改 AppTag。
- S-41：已修复。点评标签改 AppTag，无描边；问题统一提醒色、亮点统一成功色；「点评小结」里分「高频问题」「做得好的地方」两行，「细节出彩」不再列在问题里，也不进入练习建议。
- S-42：已修复。①数据：林小雨日常作品分数调整为素描均分最高、速写次之、色彩最低，与 9 月月考（素描 92.5 / 速写 88 / 色彩 85）排序一致，测试固定这一点；②文案：「最佳科目」改「得分最高科目」，「待加强」改「有待加强」，副标题写明口径「基于 6 件已点评的日常作品」。
- S-43：已修复。月份分组改 AppSectionHeader「2026 年 11 月」+ 右侧「3 件」，去掉全角方括号（`ArtworkRules.monthLabel`）。
- S-44：已修复。统一「件」；展示分数统一最多一位小数（`ArtworkRules.displayScore`，平均分显示 84.7），老师录入分数仍可到两位小数。
- S-45：已修复。去掉外层白色大面板（`ShellPageSurface`），改为 AppPageHeader + 页面底色上的统计卡、点评小结卡与按月分组的作品网格，与学情中心同一骨架；「上传作品」改 AppButton(primary, sm)。

### 作品详情
- S-46：已修复。「老师点评」改 AppSectionHeader，无竖条。
- S-47：已修复。点评标签 AppTag（问题 / 亮点两色），右上状态与列表同一个 `ArtworkStatusTag`。
- S-48：已修复。最终得分改白底 AppCard + 品牌紫 32 号数字，去掉渐变与奖杯。
- S-49：已修复。日期统一「绘于 2026-11-04」，时间统一「11-04 18:55」；老师点评按点评时间正序排列（`artworkReviewsByTime`）。
- S-50：已修复。老师头像改 AppAvatar（姓氏 + 按名字固定浅底）。
- S-51：已修复。批注显隐改 AppSegmented「原图 / 老师批注」；「对比范画」改 AppButton(quiet, sm)。

### 上传作品
- S-52：已修复。科目改 AppSegmented（素描 / 色彩 / 速写 / 其他）。
- S-53：已修复。弹窗改 showAppDialog + AppDialog（宽 560），底部 AppButton(secondary)「取消」+ AppButton(primary)「提交作品」平分；放弃确认改 showAppConfirm(danger)。
- S-54：已修复。作品名称、自定义科目、作品说明改 AppInputField（白底、#EAEAEA 描边、圆角 8，名称带必填星号）。
- S-55：已修复。绘画日期整行可点，外观与 AppSelect 一致，右侧日历图标。
- S-56：已修复。作品说明上限 200 字（`ArtworkRules.descriptionLimit`，比接口上限收紧），计数为 AppInputField 自带的 12px 三级色计数。

### 范画库
- S-57：已修复。分类改 AppChip，用 Wrap 换行排列，不再横向溢出被切。
- S-58：已修复。科目 AppSegmented、排序 AppSegmented、分类 AppChip（可取消，取消即全部，去掉第二个「全部」）；选「全部科目」时只显示跨科分类（联考高分卷），选科目后只显示该科分类并去掉重复前缀（「素描 · 石膏」→「石膏」）。
- S-59：已修复（本页范围）。高分卷只取最近一场已出分月考（9 月），图片与学情原卷同源；与高分卷同图的范画不再同时出现，范画库内每张图只出现一次（测试固定）；相近的陶罐静物错开发布日期，不再挤在首屏；原卷轮换池去掉示意线稿 `papers/*.jpg`。跨页面（视频、收藏、校圈）复用同一批演示图属于素材不足，见共享文件修改请求。
- S-60：已修复。「优秀作品」改 AppTag(success)，「高分卷」改 AppTag(brand)，12px 浅底深字。
- S-61：已修复。浏览量按来源分量级并打散（学生作品 180–1600、名师范画 860–7200、高分卷 3200–12800，过万显示「1.2 万」）；标题与分类分隔统一「 · 」，物品并列用「、」（「酒瓶、陶碗与洋葱 · 重调子」）。
- S-62：已修复（范画库）。从侧栏进入不显示返回；只有从其他页面带参数打开（首页科目卡、收藏、群聊、作品档案「看范画」）才显示返回。工具箱由其他批次处理。
- S-63：部分修复。页内搜索改 AppSearchField（限定范画，输入停顿 450ms 或回车搜索，清空立即生效）；顶栏搜索在本页带入关键字需要改外壳，见共享文件修改请求。

### 相关条目（其他批次为主，本批只改了自己的数据）
- S-142：未修复（属 C 批次）。阅卷系统里 10 月月考仍是阅卷中（2026-10-18 考、未出分），学情、班级学情、考试记录都按「阅卷中」展示（测试固定）；资讯「十月月考优秀作品展评」与视频「十月月考色彩讲评」需改为九月月考，见共享文件修改请求。
- S-143：未修复（属 C 批次）。阅卷档位表为 A ≥ 90、B 80–89.5（`DemoMarkingData.bands`），学情里色彩 85 分为 B 档与此一致（测试固定）；资讯文章「85 分以上一档」需按档位表改写或注明口径。
- S-167：部分修复。学情排名分母写明「13 人参考」（城东校区 14 人，9 月月考 1 人缺考）；我的班级页的人数口径属 E 批次。

## 教职工（02-教职工.md）

### 班级学情
- T-5：已修复。考试选择改为「最近 3 场直接点选 + 更多考试（AppSelect）」，不再横向溢出；次要文字 12px。
- T-6：已修复。阅卷中用 AppStatusTag(warning)；选中考试为 brandWash 底 + 品牌紫描边，去掉渐变；点阅卷中的考试给出轻提示。
- T-7：已修复。六个指标改 AppStatTile(boxed)，数字统一墨色。
- T-8：已修复。坐标轴、人数、分数段文字全部 12px（Manrope / caption12），柱子纯色无渐变、无入场动画，底部留白按是否有区间行动态计算。
- T-9：已修复。校区条统一用当前科目色（总分为品牌紫），不再按名次换色；差值统一一位小数「↑ 5.0 分」，用 AppTag(success / danger)；「13 人参考 · 最高 273.5 分」。
- T-10：已修复。整页换为 AppPageHeader / AppSegmented / AppCard / AppStatTile / AppTag / AppSearchField / AppAvatar / AppErrorState / AppEmptyState；`study_common.dart` 里的 StudyCard、StudyChip、StudyStatTile、StudyProgressBar（带动画）、StudyErrorView、StudyDialogShell 等私有组件已删除，学情各视图之间切换不再有 220ms 淡入淡出。

### 作品点评
- T-11：已修复。「开始点评」改 AppButton(primary, sm) + 点评图标（rate_review）；「点评标签」改 AppButton(quiet, sm)。
- T-12：已修复。去掉三张统计卡；待点评数量并入 AppSegmented 的 badge，筛选行显示「共 N 件」。
- T-13：已修复。状态词统一「待点评 / 已点评」（AppTag），不再出现「待我点评 / 我已点评」。
- T-14：已修复。卡内文字最小 12px，张数改 AppTag，科目 AppTag.subject。
- T-15：已修复。演示作品提交时间分散在 18:30–21:30（`_submitTimes`），老师点评时间分散在次日晚自习（测试固定）；「石膏头像结构练习」李静点评时间对齐平台消息（11-06 09:10，消息 09:12）。本地演示数据键升级为 v2，旧数据不再沿用。
- T-16：已修复。学生头像改 AppAvatar（有照片显示照片，没有显示姓氏）。
- T-17：已修复。搜索改 AppSearchField（宽 280）。
- T-18：已修复。空状态改 AppEmptyState「暂无待点评作品 / 学生提交作品后会出现在这里」，搜索为空时给「清除搜索」；开始点评无作品时提示「暂无待点评的作品」。另补列表加载骨架与 AppErrorState（控制器新增 `listFailed`）。

### 作品点评工作台
- T-19：已修复。页头改「点评 · 王俊辰」，副标题「色彩风景写生 · 色彩 · 提交于 11-02 20:04」；状态移进学生卡。
- T-20：部分修复。舞台底色统一 surfaceSubtle（范画详情同），工具条为 AppIconButton「还原缩放」「全屏查看原图」，可双指缩放；未单独做「适应 / 原图」切换（全屏查看即原图）。
- T-21：已修复。「绘于 2026-11-02」「提交于 11-02 20:04」。
- T-22：已修复。右侧分区改 AppSectionHeader（评分 / 点评标签 / 评语），提示文字 12px。
- T-23：已修复。本页写「已选 0 个，最多 8 个」，管理弹窗写「共 7 个，最多 50 个」。
- T-24：已修复。标签分「问题」「亮点」两组（亮点为「细节出彩」），类型同步到标签管理。
- T-25：已修复。可选标签改 AppChip（选中 brandWash 底 + 品牌紫描边），去掉 7 色轮换；标签颜色字段只用来区分问题（琥珀）/ 亮点（绿）。
- T-26：已修复。学生卡显示「城东校区 · 学号 2027030」（接口新增 `studentNo`，与名册同一规则，测试固定），档案号不再展示。

### 点评标签
- T-27：已修复。改 showAppDialog + AppDialog（宽 560），右上角为 AppIconButton 关闭。
- T-28：已修复。列表不再有红色删除图标：整行点击进入编辑，删除放在编辑页「删除标签」按钮，删除前 showAppConfirm(danger: true)。
- T-29：已修复。「新建标签」改 AppButton(primary, sm)，放在弹窗右下角。
- T-30：已修复。「使用 N 次」改 caption12 三级色；颜色选择改为「问题 / 亮点」AppSegmented。

### 范画库（教职工）
- T-31：已修复。副标题「名师范画 · 联考高分卷 · 学生优秀作品 · 共 24 幅」。
- T-32：已修复。名师范画作者全部改为画室在册老师且科目对应（素描：李静、张明远；色彩：刘芳、王海波；速写：赵雪、周强，测试固定），作者说明为「示范画室 · 速写」；没有外部作品。
- T-33：已修复。作品卡改 AppCard（1px lineSoft 描边，无阴影）；收藏按钮去掉投影与缩放动画。

### 相关条目（其他批次）
- T-65：未修复（属 E 批次）。学情中心的成绩确实来自阅卷系统，班级学情保留「成绩来自艺考网阅卷系统」；建议在考评管理页改为只读成绩 + 复核入口。

## 跨页面共性问题（本批页面）

- 学生端 1 / 教职工 1（三套组件并存）：本批三个模块已全部改用 `lib/core/ui`，删除 Study* / Artwork* 私有组件与 `artworkInputDecoration`；页面只引入 `core/ui/ui.dart` 与业务文件（`art_tokens.dart` 只用 `formatScore` 与 `fromHex`）。
- 学生端 2 / 教职工 2（页头）：全部 AppPageHeader，页头直接排在页面底色上（与组件库演示页一致），筛选与考试选择放 bottom 槽。
- 学生端 3 / 教职工 3（选中态）：AppSegmented / AppChip / AppTabs 规则执行；去掉 AnimatedContainer、AnimatedSwitcher、TweenAnimationBuilder（分数环、柱状图、折线图、进度条入场动画全部去掉）。
- 学生端 4 / 教职工 6（按钮）：全部 AppButton / AppIconButton，每个区域一个 primary。
- 学生端 5 / 教职工 5（标签与状态）：AppTag / AppStatusTag，档位标签 A 档品牌色、D 档及以下提醒色、其余中性（`StudyGradeTag`），不再用色板外的档位色。
- 学生端 6 / 教职工 18（字号）：本批文件没有小于 12px 的文字（扫描确认）。
- 学生端 7 / 教职工 14（演示时间）：作品提交与点评时间固定在晚自习时段；范画发布时间在白天；本批数据都是固定日期，不按当前时间倒推。
- 学生端 8 / 教职工 11（跨页数据）：准考证号 / 学号、超过百分比、得分最高科目、学号与档案号、档位口径、10 月月考状态都从 `demo_marking_data.dart` / `demo_artwork_data.dart` 派生，新增 `test/marking_demo_consistency_test.dart` 固定这些对应关系。
- 学生端 9 / 教职工 17（合规）：去掉「最佳」「第一时间」「最大分差」等措辞，banned-words.json 规则扫描本批文件无命中；无感叹号。
- 学生端 11（假数据外露）：浏览量、重复图片已处理（S-59、S-61）。
- 学生端 12 / 教职工 19（颜色）：本批文件没有 `Color(0x…)` / `Colors.xxx`，科目色只取 ArtSubject；批注笔颜色由 AppColors 与素描科目色换算成 `#HEX`。
- 学生端 14 / 教职工 20（截断与留白）：考试选择、分类筛选改换行；冒烟测试在两种宽度下无溢出（过程中发现并修复了范画卡高分卷信息行、成长曲线涨跌标签两处溢出）。
- 学生端 15（输入框）：AppInputField / AppSearchField。
- 学生端 16 / 教职工 21（格式）：日期 YYYY-MM-DD，列表时间 MM-DD HH:mm，不显示秒；分数最多一位小数；分数差固定一位小数；中文与数字之间空格。
- 学生端 18 / 教职工 8（头像）：AppAvatar。
- 学生端 19（返回逻辑）：范画库一级页不显示返回（S-62）。
- 学生端 20 / 教职工 15（三态）：学情总览、班级学情、报告、成长曲线、作品档案、作品点评、范画库都有骨架 / AppEmptyState / AppErrorState；作品与范画列表的控制器新增 `listFailed` / `loadFailed`，首屏失败不再显示成「暂无作品」。

## 组件库新增

- `lib/core/ui/app_notice.dart`：AppNotice 页内提示条（AppTone 浅底深字 + 图标 + 可选右侧操作），`ui.dart` 增加一行导出。用于「阅卷中，出分后会通知你」「全部老师点评完成后可查看分数」「分差在阈值内」这类持续性说明；工具箱倒计时提示条（S-77）也可直接使用。

## 共享文件修改请求

1. `lib/core/demo/fixtures/content_news.dart`、`content_videos.dart`（C 批次）：「十月月考优秀作品展评」「城西校区十月月考色彩讲评」改为九月月考（10 月月考在阅卷系统中仍是阅卷中）；档位说明文章按阅卷系统档位表（A ≥ 90、B 80–89.5、C 70–79.5、D 60–69.5）写，或注明「各省口径不同」（S-142、S-143）。
2. `lib/features/home/ui/widgets/home_study_snapshot.dart`（A 批次）：「较上次 +9」改用学情同款写法「↑ 9.0 分」（`formatScoreDelta`）；如展示超过百分比，用 `surpassedPercentOf`（（参考人数 − 名次）/ 参考人数），与学情一致（S-30）。
3. `lib/features/shell/ui/widgets/shell_top_bar.dart`（A 批次）：在范画库页使用顶栏搜索时，用 `Navigator.pushNamed(RoutePaths.gallery, arguments: {'keyword': …})` 带入关键字，页内搜索框会同步显示（S-63）。
4. `lib/features/smart_campus/ui/student_my_class_view.dart`（E 批次）：班级人数旁写明「9 月月考 13 人参考」或与学情同口径，避免「全班 14」与「城东校区 13 人参考」被误读（S-167）。
5. `lib/core/art/art_tokens.dart`：`ArtColors.grade()` 的 B–E 档位色（#5479D1、#479982、#AF7B30、#C45867）与 `ArtColors.brandGradient` 已不在本批页面使用，建议在其他页面迁移后删除或改为 AppTone；`lib/core/widgets/art_widgets.dart` 的 ArtGradeBadge 等同理。
6. 演示素材（assets）：色彩静物 5 张是同一组陶罐水果的不同色调，视频中心、我的收藏、校圈也在复用；建议补充石膏、风景、人物等题材的演示图，一条内容一张图（S-59 跨页部分）。
