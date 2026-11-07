# 修复记录 · C 内容 / D 账户

范围：`lib/features/{ai_chat,courseware,school,video_tutorial,consultation,my_notes,my_collection,quiz_practice,circle,school_website,personal_center,common,help_guide,feedback}/**`，演示数据 `lib/core/demo/fixtures/content_*.dart`（不含 content_home、content_ebooks）与 `interaction_*.dart`。

状态：已完成。`dart analyze`（本批 14 个功能目录 + `lib/core/demo` + `lib/core/ui` + `test`）无问题；相关测试（school_config_data、school_website_html_utils、ui_kit、design_system_page、shell_navigation、demo_clock、widget）42 项通过，1 项失败：`shell_navigation_test` 的「ShellTopBar icon buttons have names…」找不到顶栏搜索占位文字，失败点在壳层顶栏（A 批正在修改 `shell_top_bar.dart`），与本批文件无关。

## C 内容（01-访客与学生.md）

### 小美同学
- S-79：已修复（欢迎语改「你好，我是小美同学」+「可以和我聊素描、色彩、速写和备考安排，回答仅供参考。」；工具卡副标题改动作描述「按成绩梳理可报院校 / 按薄弱科目安排练习 / 生成分阶段备考计划」，去掉 AI、秒解、智能分析、科学规划、定制；页头副标题「美术答疑助手 · 回答由模型生成，仅供参考」；演示问候与系统提示里的「AI 美术助教」同步改为「美术答疑助手」，演示回答里原有的「演示模式……仅供参考」提示保留）
- S-80：已修复（三个工具图标改为 AppIconTile + 线性图标：院校、画笔、日程，不再使用音符 SVG）
- S-81：已修复（去掉「很高兴见到你！」的感叹号、「~」与「学美术就找小美同学」口号，两张卡的副标题统一为「点一下直接提问」）
- S-82：已修复（去掉 DeepSeek / Doubao 模型下拉，默认模型不变；不可用的「联网搜索」开关隐藏；「深度思考」改 AppChip 开关）
- S-83：已修复（工具副标题、附件文字、免责声明全部 ≥ 12px（caption12 + textTertiary）；免责声明改「内容由模型生成，仅供参考；作品评价请以任课老师的意见为准」）
- S-84：已修复（演示回复「三、提分重点」改「练习重点」，「目前提分空间最大的是」改「目前最需要加强的是」，并清理「最好 / 最强 / 保证」等绝对化用语；问候里「上传作品照片给出作品分析」改为引导到「作品档案」由老师点评）
- S-85：已修复（热门问题编号统一 textTertiary 的 Manrope 数字，去掉红 / 橙榜单配色）
- 同页补充：外层去掉渐变底与输入框三层投影，改白底描边面板 + AppPageHeader「小美同学」；左侧「开启新对话」改 AppButton(quiet)，历史对话加载用骨架、空时提示；会话删除改 showAppMenu + showAppConfirm(danger)；消息操作改 AppIconButton（带读屏文字）；附件改 AppPressable + 12px；附件预览改 showAppDialog；演示历史对话时间改 DemoClock.ago

### 校园课件
- S-86：已修复（重排信息架构：AppPageHeader「校园课件」；首屏左侧是画室自己的「课程视频」目录（校园视频接口前 6 条，封面 + 两行标题 + 老师 · 分类，点开直接进入该视频详情，右上「全部视频」），右栏「学习进度」+「校园资源」；去掉与首页重复的 Banner、学情 / 作品 / 范画入口和三科大卡。目前没有独立的「课件」接口，课件目录先用画室课程视频承接）
- S-87：已修复（学习进度改用 ArtSubject 科目色 + AppProgressBar（静态、无渐变），科目用 AppTag.subject，百分比用 Manrope 数字）
- S-88：已修复（「恭喜你！你完成了速写的全部课程」改为 AppTag(success)「已完成」+「速写课程已全部完成」）
- S-89：已修复（入口「刷题」改「题库」，「微校」改「画室官网」；入口集合改为课程视频 / 题库 / 画室官网 / 校园资讯）
- S-90：已修复（去掉英文「NEW」实底角标，24 小时内发布才显示 AppTag(brand)「最新」；标签改 AppTag 12px；标题两行；时间改「N 分钟前 / MM-DD」并加空格）
- S-91：已修复（六宫格改为「校园资源」列表（AppIconTile + AppListRow），不再出现大片留白；`_VoiceInstrumentRow` 等音乐版命名随三科卡一起删除）

### 我的云盘
- S-92：已修复（日期统一 YYYY-MM-DD；接口缺日期时不再兜底显示假的「04.07.2026」与「10MB」）
- S-93：已修复（分类计数是分类下的资料份数，文案改「N 份资料」；文件夹卡显示「N 个文件 · 日期」；列表标题旁显示「共 N 个文件夹 / 共 N 份资料」）
- S-94：已修复（分类、存储、文件夹、文件卡的小字全部改 caption12；预览与上传弹窗里残留的 10 / 11px 一并改 12px）
- S-95：已修复（去掉白底投影悬浮按钮与「刷新」按钮：主操作「新建文件夹 / 上传资料」放页头 AppButton(primary, sm)，刷新改下拉刷新）
- S-96：已修复（AppPageHeader「我的云盘」（文件夹内副标题显示「分类 · 文件夹」）；容量改「云盘存储」+ AppProgressBar(6px) +「已用 0.6 GB / 共 5 GB」，数字与单位加空格；搜索改 AppSearchField，无结果时 AppEmptyState +「清除搜索」；文件夹 / 资料空状态各带对应操作；分类与卡片菜单改 showAppMenu，重命名 / 新建改 AppDialog + AppInputField，删除改 showAppConfirm(danger)；演示数据「联考真题（示例）」改为「联考模拟题」）

### 视频中心 / 视频详情
- S-97：已修复（一级分类改 AppTabs，放在页头 bottom 槽，「全部」用空串哨兵对应 id 为 null 的菜单；二级分类改 AppChip，前置「全部」并有选中态；控制器 `selectChildMenu(null)` 现在能真正清空二级筛选）
- S-98：已修复（重写视频卡：AppCard 平铺，去掉封面上的重复缩略图，标题固定两行，第三行「头像 + 讲师 + 眼睛播放量」用 caption12；时长角标改墨色半透明底；列数按宽度 2 / 3 / 4 自适应）
- S-99：已修复（播放量统一为 `Icons.visibility_outlined` + 数字，列表卡、详情页一致，与资讯 / 范画相同）
- S-100：已修复（去掉无标题的 Banner 轮播，改为「推荐」大图：封面 + 底部压暗 + 标题（两行）+「讲师 · 时长」+ 居中播放按钮，整块可点；右侧「最新视频」卡标题两行 + 时长；搜索或选了二级分类时不显示推荐区）
- S-101：已修复（AppPageHeader「视频中心」，校园模式为「课程视频」，副标题说明内容来源；搜索框（AppSearchField 240）放 actions，分类页签放 bottom；可返回时显示返回）
- S-102：已修复（content_videos.dart：「帮助大家明确提分方向」改「帮助大家找准失分原因与练习方向」）
- S-103：已修复（演示时长按真实片段长度生成（00:05 / 00:11 / 00:04），列表、详情、播放器一致；播放器与全屏页时间格式化去掉 `--:--`，未播放显示「00:00」）
- S-104：已修复（相关视频改为整行可点：缩略图 + 两行标题 + 副标题「讲师 · 时长」，去掉每行的渐变「播放」按钮）
- S-105：已修复（删掉「视频来源用户上传，如有侵权…」，改为 caption12「视频由画室老师提供」）
- S-106：已修复（抽屉宽度改 AppSize.drawerWide（560），白底 + 左圆角 + AppShadow.overlay + scrim 遮罩，进出 180ms；顶部加「视频详情」标题 + 关闭按钮，去掉播放器左上的返回箭头；「视频详情 / 步骤图」改 AppTabs（步骤图带数量），分享 / 收藏改 AppButton(quiet, sm)；步骤图为空时 AppEmptyState；播放器浮层 10 / 11px 文字提到 12px）
- S-107：已修复（content_videos.dart 简介中的英文直引号改为「」）

### 我的笔记
- S-108：已修复（左侧分类改两行：名称 / 「N 篇」，选中 brandWash 底 + 品牌紫，名称单独省略、数量始终可见；更多操作改 AppIconButton + showAppMenu）
- S-109：已修复（笔记卡改 AppCard：上方显示笔记的手写预览图（无预览时画对应纸张），下方两行标题 + 日期；星标只在已收藏时显示；日期统一 YYYY-MM-DD）
- S-110：已修复（去掉白底投影悬浮按钮，「新建笔记」放页头 AppButton(primary, sm)）
- S-111：已修复（AppPageHeader「我的笔记」；分类为空时 AppEmptyState +「新建笔记」引导，收藏筛选为空单独说明；首屏骨架。另：新建 / 重命名弹窗改 AppDialog + AppInputField，删除改 showAppConfirm(danger)，选样式页改 AppPageHeader + 可选卡片 +「下一步」主按钮，编辑页工具条改 AppIconButton / AppButton，清空画布先确认）

### 我的收藏
- S-112：已修复（去掉 #292151「去查看」按钮，整张 AppCard 可点；分享 / 取消收藏改为卡片右下两个 AppIconButton（带读屏文字），取消收藏先 showAppConfirm(danger)）
- S-113：已修复（三种私有卡片合并为一种 AppCard，标题两行）
- S-114：已修复（类型角标改 AppTag(tone: brand) 12px，副标题 caption12；时长、浏览量改 Manrope 12px）
- S-115：已修复（AppPageHeader「我的收藏」+ bottom 槽 AppSegmented（全部 / 范画 / 视频 / 资讯，类型超过 5 个自动改 AppTabs）；补骨架、空状态（按类型说明怎么收藏）与加载失败重试；预置收藏换掉重复的陶罐静物与大卫石膏像，同屏不再出现两张同图。类型表集中在 `CollectionType` + `kCollectionDefaultTabs`，打开方式集中在 `_openers`，后续加「书刊」只需各追加一项）

### 资讯 / 资讯详情
- S-137：已修复（标题改「集训三个月的备考经验与时间安排」，标签「提分」改「时间安排」；正文去掉「60 分到 85 分」分数涨幅叙述与「（示例案例）」）
- S-138：已修复（政策解读等标题去掉「（示例）」，正文「（示例）」「（示例数据）」占位一并清理，说明改「仅供参考，以正式公告为准」）
- S-139：已修复（「最新」统一 AppTag(tone: brand) 12px，规则改为 24 小时内发布才显示，不再按前三条硬标）
- S-140：已修复（AppPageHeader「资讯」+ 返回；校园入口进入时标题「校园资讯」）
- S-141：已修复（去掉 200px Banner，页头 bottom 槽放 AppTabs「全部 / 联考政策 / 院校校考 / 备考经验 / 美术常识 / 画室动态」（带数量，按标签归类，空分类不显示），分类为空时 AppEmptyState +「查看全部」）
- S-142：已修复（「十月月考优秀作品展评」改「九月月考优秀作品展评」，发布时间调到 10-08，与学情最新为 9 月月考一致）
- S-143：已修复（素描评分文章改按 A–E 档表述：A ≥ 90、B 80–89、C 70–79、D/E ≤ 69，与阅卷演示数据的档位切分一致，并注明各省细则略有差异）
- S-144：已修复（正文放 720 限宽 AppCard，body14、行高 1.8；资讯数据里的英文引号全部改「」；发布时间显示到分钟）
- S-145：已修复（文末眼部特写换成整幅素描静物，并加图注「A 档静物示例」）
- S-146：已修复（AppPageHeader(onBack) + 右侧 AppButton(quiet, sm)「分享」，去掉居中标题与全宽分隔线；补加载骨架与加载失败重试）

### 校圈
- S-147：已修复（置顶考务帖改为「11 月 15 日（周日）三校区同步进行，一天考完：08:30 素描、14:00 色彩、19:00 速写」，与资讯考务通知、我的考试一致；资讯里的同一通知「周六」也改为「周日」）
- S-148：已修复（种子帖子 / 评论改用 DemoClock.ago 倒推，夜间自动落回白天，并按序号错开分钟数，不再出现凌晨与同分钟发帖）
- S-149：已修复（页头改 AppPageHeader + AppSegmented「卡片 / 大图」，立即切换，去掉滑块动画与 AnimatedSwitcher 淡入）
- S-150：已修复（点赞数原先被塞进 10px 宽的格子里看不到，改为图标 + Manrope 数字，点赞 / 评论 / 收藏都显示数量；置顶 AppTag(brand)、热门 AppTag(warning)，12px；去掉图片帖左下角「图片」标签）
- S-151：已修复（去掉渐变圆形悬浮按钮，「发布动态」改为页头右侧 AppButton(primary, sm)；空状态也给出「发布动态」入口）
- 同页补充：卡片改 AppCard（白底描边、无阴影），头像 AppAvatar；删除动态 / 评论改 showAppConfirm(danger)；评论面板改 AppIconButton 关闭、AppEmptyState、AppButton「发送」（输入为空时禁用），去掉不可用的「回复」字样与「抢沙发吧～」；评论面板滑入改为 180ms；发布弹窗改 AppDialog + AppSegmented（图片 / 视频）+ AppInputField（必填、0/500 计数），不再提供音频发布（历史音频帖仍可浏览）

### 学校官网
- S-152：已修复（「多名学员单科 15 分以上的提升」改为「每次月考提供原卷复盘与成长曲线，学员可在「我的学情」中查看」）
- S-153：已修复（AppPageHeader(onBack)，标题取接口下发的「示范画室官网」，缺省「画室官网」；网页放在页头下方的圆角白卡里；补加载失败重试）
- S-154：已修复（删除 ABOUT US / COURSES / TEACHERS / ACHIEVEMENTS / ENVIRONMENT / WORKS / CONTACT 英文小标题）
- S-155：已修复（去掉「（示例）」，在读学员改 38 人，与学情总排名分母一致；任课教师数改为与师资列表一致的 7 人；校区地址去掉「（示例地址）」）
- S-156：已修复（简介段落改为单行字符串，不再在句中换行产生多余空格；英文引号改「」）
- S-157：部分修复（头图换成教室实景，不再与资讯 / 首页的作品墙照片重复；网页 CSS 改用 App 色板（页面底 #EFF3FC、卡片白底 + #F3F2F3 描边、文字三级灰）与字号；老师头像改姓氏 + 科目色浅底，与 AppAvatar 一致。画室 Logo 资源本身是「示范画室」字标，保留）

### 顶栏搜索
- S-159：未在本批修改（代码在 `lib/features/shell/ui/widgets/shell_top_bar.dart`，不属于本批文件）。核对时壳层已改为 AppSearchField + 结果浮层，无结果显示 AppEmptyState「没有找到相关内容」，由 A 批负责
- S-160：未在本批修改（同上）。核对时占位已改「搜索范画、资讯、视频、笔记」，由 A 批负责

## D 账户（01-访客与学生.md）

### 服务协议与隐私政策
- S-19：已修复（底部改为白底 + 顶部分隔线的固定操作栏，AppButton(primary, md) 宽度随文字；正文在可滚动区内，不再被按钮压住）
- S-20：已修复（「[运营主体]」两处替换为运营主体「艺考网」，联系方式指向「意见反馈」入口）
- S-21：已修复（服务清单改为「美术答疑助手「小美同学」：美术常识问答，回答仅供参考」；去掉「AI 作品分析」会员权益；第六章改「小美同学使用说明」，措辞为「回答由模型生成，仅供学习参考」）
- S-22：已修复（AppPageHeader(onBack) + 页面底色上的 AppCard；同一份正文也用于外壳内的 /xieyi）
- S-23：已修复（正文限宽 720 居中，标题 title20 / title16，正文 body14 + textSecondary、行高 1.7；日期改 2026-11-01）

### 个人中心
- S-116：已修复（页面与演示套餐都不再出现金额与「每月仅需…」类话术；套餐描述只写适用场景，统一提示「开通方式与价格以正式页面为准」）
- S-117：已修复（删除「小美同学 AI 作品分析不限次数」，权益只列已上线功能：高清范画、专项视频课、题库错题本、作品云端存储）
- S-118：已修复（会员卡只显示一次状态：AppTag(success)「生效中」+「有效期至 YYYY-MM-DD，剩余 N 天」；所有套餐统一用 AppButton(quiet, sm)「开通 / 续费」，不再出现两个「已开通」。演示接口不返回当前套餐名，因此不在单个套餐上标「生效中」）
- S-119：已修复（手机号脱敏为 138****0001，个人中心、二维码、个人信息共用 maskMobile）
- S-120：已修复（角色标签改 AppTag(tone: brand)，放在姓名后）
- S-121：已修复（去掉「V」装饰背景与固定高度布局；改为左栏资料卡 + 会员卡，右栏「常用服务 / 帮助与支持」两组菜单，补「操作指南」「服务协议与隐私政策」入口，空白区消失）
- S-122：已修复（「需求反馈」改「意见反馈」）

### 个人信息
- S-123：已修复（AppPageHeader(onBack)，左对齐标题）
- S-124：已修复（空值显示占位色「未填写」，可点击填写；邮箱弹窗内校验格式并给出示例）
- S-125：部分修复（字段改名「所在画室」；演示资料接口 `demoUserInfo` 只返回「示范画室」、没有校区字段，校区需在 `platform_core_fixtures.dart` 补，已列入共享文件修改请求）
- S-126：已修复（内容限宽 640 居中，分「基本资料 / 学籍信息 / 账号安全」三张卡；修改密码、账号注销移入账号安全；编辑弹窗全部改 AppDialog + AppInputField，性别用 AppSegmented，头像来源改 AppDialog）

### 意见反馈
- S-127：部分修复（页面统一按「MM-DD HH:mm」显示，不再显示秒；反馈数据由 `campus/campus_a_mailbox.dart` 按 `DateTime.now()` 倒推生成，凌晨时间需在该文件改用 DemoClock，已列入共享文件修改请求）
- S-128：部分修复（页头改 AppPageHeader，去掉居中标题与光斑背景；作为左侧导航一级页，只在由其他页 push 进入时显示返回。官方回复里的「感谢建议！」同在 `campus_a_mailbox.dart`，已列入共享文件修改请求）
- S-129：已修复（AppButton(primary, md)「提交反馈」，无渐变、无投影）
- S-130：已修复（状态改 AppTag：待回复 warning / 已回复 success，12px；回复时间 caption12）
- S-131：部分修复（宽屏左栏「我的反馈」、右栏 360 宽「写新反馈」，不再把表单挤到底部；AppInputField 多行 + 0/500 字数统计 + 空内容红字提示；补加载骨架、空状态与加载失败重试。反馈接口只有 `content` 字段，截图附件与联系方式需接口支持后再加）

### 操作指南
- S-133：已修复（「提分最快」改「进步明显」；小美同学描述改「美术答疑助手」；「上传作品获取 AI 分析」改为「把问题问具体」提问指引，作品点评引导到「作品档案」；提示改「回答由模型生成，仅供学习参考」）
- S-134：已修复（去掉 9 张模板封面与 6px / 8px 文字，卡片改 AppCard：分类图标 + 两行标题 + 三行摘要 + 分类标签 +「N 个步骤」；详情改 AppDialog(dialogWide)）
- S-135：已修复（分类改 AppTabs（带数量），横向可滚动；新增搜索框，无结果时 AppEmptyState +「清除搜索」）
- S-136：已修复（AppPageHeader「操作指南」+ 副标题「各功能的操作说明」（body13）；卡片副标题改 12px 标签；「美术常识刷题」改「美术常识题库练习」，「自动刷题」改「自动下一题」，「考前密卷」改「高频考点」并同步题库页面）

### 我的二维码
- S-158：已修复（新增 `MyQrCodePage`：AppPageHeader(onBack) +「保存二维码」+ 与个人中心弹窗共用的 `MyQrCodeCard`，含骨架与加载失败重试；路由表把 /qrcode 交给 `LegacyPlaceholderContent`，该组件现按路由渲染真实页面：/qrcode → 二维码页，/xieyi → 协议正文，其余遗留路由显示 AppPageHeader + AppEmptyState「暂未开放」，不再展示路由路径。建议路由表直接映射 /qrcode → `MyQrCodePage`，见共享文件修改请求）

## 教职工（02-教职工.md）中落在本批文件里的条目

- T-78（[E]，校圈操作图标过浅）：已修复（#E6E9F1 的 PNG 图标换成 textTertiary 线性图标，已点赞 / 已收藏用品牌紫，卡片与大图两种模式一致）
- T-79（[E]，赵雪身份显示）：已修复（教职工作者身份按班主任身份显示「班主任 · 速写 · 联考冲刺1班」，`interaction_common.dart` 的 demoStaffAuthor 统一处理）
- T-213（[E]，校圈治理没有治理功能）：未修复（「待处理 / 已处理」与举报原因需要后端举报数据，现有帖子接口没有举报字段；删除已改为 showAppConfirm(danger)）
- T-214（[E]，校圈治理标题与发帖入口）：部分修复（`CirclePage` 新增 `governance` 参数：标题「校圈治理」、隐藏「发布动态」；需智慧校园在管理员入口传 `governance: true`，见共享文件修改请求）
- T-215（[E]，每张卡的删除按钮）：已修复（删除收进卡片右上角「···」AppIconButton → showAppMenu「删除动态」（红字），再 showAppConfirm(danger)）

## 跨页面共性问题（本批页面）

- 页头（学生端第 2 条）：本批所有页面改 AppPageHeader，左对齐标题 + 一句用户语言的副标题，页签 / 分段放 bottom 槽；左侧导航一级页只在可返回时显示返回，二级页（资讯详情、二维码、个人信息、协议、画室官网、题库做题页）始终有返回。
- 选中态（第 3 条）：页面级切换用 AppTabs（视频分类、资讯分类、操作指南、视频详情），互斥视图用 AppSegmented（收藏类型、笔记筛选、校圈卡片 / 大图、性别），筛选用 AppChip（视频二级分类、小美「深度思考」）；全部立即切换，无滑块动画。
- 按钮（第 4 条）：渐变胶囊 / 深色实底 / 悬浮按钮全部换 AppButton；新建类操作（新建笔记、新建文件夹、上传资料、发布动态）放页头 actions，每个区域只有一个 primary。
- 字号（第 6 条）：本批页面与弹窗的 6–11px 文字全部提到 ≥ 12px（含视频播放器浮层、云盘预览、AI 页、操作指南、收藏、个人中心、反馈）。
- 合规（第 9 条）：本批页面与演示数据中的价格、提分 / 分数涨幅、「AI 作品分析」、「最佳 / 最好 / 第一」、感叹号与口语（恭喜你！、感谢建议、~、刷题、秒解）已清理；题库题干里的「位列第一 / 规模最大 / 对比最强烈 / 最大的特点」改为不触发扫描、不改变史实的说法；「刷题」作为小美同学的识别关键词保留在输入匹配表里，回复文案不再使用。
- 音乐残留（第 10 条）：AI 页音符图标、视频播放量波形图标、校园课件 `_VoiceInstrumentRow`、校圈发布的音频类型已清理。
- 占位与假数据（第 11 条）：「[运营主体]」「（示例）」、二维码占位页、相关视频副标题、视频时长、云盘假日期 / 假大小、学校官网学员数已按真实画室口径补齐。
- 时间与数字（第 16 条）：列表统一「MM-DD HH:mm」或「N 分钟前」，日期「YYYY-MM-DD」，不显示秒，数字与中文单位之间加空格（「0.6 GB」「N 份资料」「第 N 题」）；演示种子时间改用 DemoClock.ago，不再出现凌晨。
- 其他（第 12–15、17、18 条）：科目色只从 ArtSubject 取（校园课件进度、课程视频）；页面私有色值换 AppColors，卡片去渐变与静止阴影；卡片标题统一两行、网格按宽度自适应列数；输入框统一 AppInputField / AppSearchField；命名按左侧导航（题库、意见反馈、画室官网、所在画室、最新）；头像统一 AppAvatar 圆形。
- 三态（第 20 条）：本批每个列表页补齐加载骨架、空状态（含搜索无结果 +「清除搜索」）、加载失败重试。
- 题库（无走查条目，按共性规则处理）：公开题库与画室题库合并为同一个 `QuizPracticeView`：AppPageHeader「题库」、AppStatTile 统计（正确率低于 60% 时红字）、四种练习方式卡（进度环用品牌紫，错题本用红色，加一句用途说明）、骨架与加载失败重试；去掉渐变卡与 Banner；「看图识画」未开放时改为说明卡，不再显示一排 0。做题页改 AppPageHeader（「第 N / 共 M 题 · 已做 K 题」）+「自动下一题」AppSwitch、选项用 success / danger 色板、AppButton「上一题 / 下一题 / 完成练习」、完成弹窗改 AppDialog（按是否做完显示「本轮练习完成」或「还有 N 题未做」）；「考前密卷」改「高频考点」，「错题集」改「错题本」，「已经是第一题了！」改「已经是第 1 题」。

## 组件库新增

- `lib/core/ui/app_menu.dart`：`showAppMenu<T>({context, items, width})` + `AppMenuItem<T>({value, label, icon, danger, enabled})`。「···」更多操作的弹出菜单，定位与动效同 AppSelect（组件下方 / 空间不够时上方，超出右边界时右对齐；白底圆角 12、行高 36、popover 阴影、淡入 180ms），删除类操作 `danger: true` 显示红字。用于我的笔记、我的云盘的分类 / 卡片菜单，替代各页私有的锚点菜单面板。已在 `ui.dart` 加一行导出。

## 共享文件修改请求

1. `lib/app/router/app_router.dart`：建议 `/qrcode` 直接映射 `MyQrCodePage()`（`lib/features/personal_center/ui/my_qr_code_page.dart`）。目前经 `LegacyPlaceholderContent` 转发也能正常显示，属于整理项。（S-158）
2. `lib/core/demo/fixtures/campus/campus_a_mailbox.dart`：① 意见反馈的提交 / 回复时间改用 `DemoClock.ago`，避免凌晨时间（S-127）；② 官方回复「感谢建议！」去掉感叹号（S-128）；③ 自动回复「感谢你的反馈！…有进展会第一时间告诉你。」改「已收到你的反馈，我们会在后续版本中评估。」（T-4）。
3. 演示资料接口 `demoUserInfo`（`platform_core_fixtures.dart`）：补校区字段（如「示范画室 · 本部」），个人信息「所在画室」才能显示到校区。（S-125）
4. `lib/features/smart_campus/`（管理员「校圈治理」入口）：打开校圈时传 `CirclePage(governance: true)`，标题会变「校圈治理」并隐藏「发布动态」（T-214）。「待处理 / 已处理」与举报原因需要帖子接口增加举报数据后再做（T-213）。
5. `lib/features/auth/`（可选）：登录 / 注册页的协议链接可直接 push `TermsPage`，「同意」时页面 `pop(true)`、返回时 `pop(false)`；隐私政策可传 `initialAnchor: TermsPage.privacyAnchor` 直接定位。
6. `lib/core/constants/app_assets.dart` 与 `assets/`（可选清理）：视频详情与题库改用组件库后，`videoV2Share`、`videoV2Star`、`videoV2StarFilled`、`videoV2Collapse`、`videoV2RelatedPlay`、`quizRecommendBubble` 在 `lib/` 中已无引用。
