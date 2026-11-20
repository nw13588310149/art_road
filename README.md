# 美育集

面向美术艺考生、画室老师与画室管理者的 iPad 横屏 App（艺考网出品）。围绕阅卷系统，提供学情中心、作品档案与作品点评、范画库、美术书刊、画室工具箱（三组 17 个工具），以及资讯、校园课件、云盘、视频、笔记、收藏、题库、AI 美术助教「小美同学」、校圈、智慧校园等通用模块。首页对所有身份是同一套版式；左侧导航「今日学习 / 今日工作」、新手引导和通知按学生、任课老师（含教学组长）、班主任、宿管、管理员、校长配置。

当前版本为 **3.1 演示版**。演示后端在本机提供数据，作品贯通多位任课老师独立点评、组长点评、校长查阅与可选评分；新增小课件知识专题与作品集市。产品规则见 [3.1 产品与交互方案](docs/美育集3.1产品与交互方案.md)。实施口径见 [3.0 实施规格](docs/美育集3.0实施规格.md)，界面规范见 [设计规范](docs/设计规范.md)，真实接口的待对接项见 [后端缺口清单](docs/后端缺口清单.md)。

## 3.1 体验路径

- 校长：「今日工作」集中超时督办、校长信箱、审批与教学跟进；「全校学情」查看教学趋势、切换校区，进入老师履职、班级学情的校区柱状图与作品点评链。
- 作品：学生上传时可选择多位任课老师。各位老师独立提交评价后交给科目组长；校长可以另行评分。预置「几何体明暗关系」包含 3 位老师、1 位组长、1 位校长的完整记录。
- 小课件：从左侧导航「优秀课件」进入，新增专题并选择多份 PDF / 图片书籍；多张上传图片合并成可续读的图片书。包含 8 个知识专题、4 本图片书及 3 份可阅读 PDF。PDF 使用已有 pdfrx 本地引擎，支持网页内阅读与翻页。
- 集市：支持仅展示、数字授权、实物作品；草稿与审核、地址簿、结算、模拟支付、数字交付、发货收货、评价、退货退款、举报及平台介入均可体验。买家使用「我的订单」，卖家使用「创作者工作台」，校长和管理员使用「集市审核」。全部为演示交易，不收取真实款项。接口和状态规则见 [集市商业闭环与接口契约](docs/集市商业闭环与接口契约.md)。
- 随页工具栏：右侧单列画具可拖到左右边缘，取色、测量时收起让出画面；关闭参数保留效果，结束工具清除效果。进入笔记编辑、业务弹窗或完整工具箱时自动让出操作区域。
- 我的短板：按科目查看近期已点评作品的分项、样本与老师反馈依据，制定练习、查阅相关小课件并提交练习作品；作品成长页继续跟踪。老师和校长可在学生名单记录沟通与跟进历史。
- Web 上传的 Blob 文件只在当前浏览器文档有效，刷新后需要重新上传；示例资源可重复阅读。业务记录与收藏保存在本机，原生端上传媒体按原有文件存储机制处理。
- 本次已获许可缓存 FL Chart 1.3.1；后续继续使用离线依赖解析。

## 环境

- Flutter 3.44（Dart 3.12）。
- 依赖已在本机缓存，安装时使用离线模式：`flutter pub get --offline`。
- 仓库只保留 Android、iOS、macOS、Web 四个平台目录。本机没有 Xcode 和 Android SDK，日常用 Web 验证；原生改动（包名、Bundle ID、通道名）需要在 Mac / Android 环境编译确认。

## 运行

```powershell
flutter pub get --offline
flutter run -d chrome            # 或 -d edge，浏览器窗口建议 1180×820（iPad Air 横屏）
```

Web 发布构建（Windows 上增量构建会因资源已存在而失败，脚本会先清理 `build/web/assets`）：

```powershell
powershell -ExecutionPolicy Bypass -File tool\build_web.ps1
python -m http.server 8787 --directory build/web
```

### iPad 体验包

在 macOS 或 Codemagic 上用已配置签名的 iOS 体验分支构建 Release IPA，沿用当前的导出签名选项。

```sh
flutter build ipa --release --dart-define=DEMO_MODE=true
```

Debug 包需从 Xcode 或 `flutter run` 启动。装包验证时断开调试器，从 iPad 主屏幕启动 Release 包，确认能进入登录页或首页。

画具入口「小画」是一只戴圆眼镜的猫头鹰（形象图 `assets/images/brand/xiaohua_owl.png`），点击展开单列工具栏，点击工具栏顶部的关闭按钮收回小画；取色、测量时让出画面，退出精确操作后可继续选工具。小画可四边停靠，展开后的工具栏拖动仅靠左右两边；角色动画遵循已保存的动态偏好及系统减少动态设置。

工具栏的 iOS 原生玻璃需使用 Xcode 26（Swift 6.2、iOS 26 SDK）或更新工具链编译，并在 iOS 26 或更新系统运行才启用 `UIGlassEffect`；旧系统或旧工具链分支采用原生模糊，Web 使用 Flutter 兼容材质。原生背景不接管工具操作。本机尚未完成原生编译与真机验收，详情见 [小画与玻璃工具栏验收](docs/走查/3.2小画与玻璃工具栏验收.md)。本轮未调整版本号或签名配置。

## 演示模式

默认开启（`DEMO_MODE` 默认为 `true`）：
- 请求由 `DemoApiInterceptor` 在本地应答，模拟 120–300 ms 网络延迟。
- 上传的作品、老师点评、笔记、收藏、请假等写操作保存在本机（SharedPreferences，键前缀 `demo_store:`），重启后仍在。
- 登录页「重置演示数据」可以一键恢复初始数据。

体验身份（登录页直接点选，或输入手机号 + 任意密码）：

| 身份 | 手机号 | 姓名 | 说明 |
| --- | --- | --- | --- |
| 学生 | 13809310001 | 林小雨 | 城东校区，查看今日学习、作品成长、分项与改画版本 |
| 任课老师 | 13809310002 | 李静 | 发布素描作品任务，点评作品并提交组长复核 |
| 组长 | 13809310012 | 张明远 | 素描组长：任课老师 + 组长权限，后端身份仍是任课老师 |
| 班主任 | 13809310003 | 赵雪 | 班级工作台、请假审批、家校沟通 |
| 宿管 | 13809310004 | 马红梅 | 按宿舍查寝、查寝历史、到岗打卡 |
| 管理员 | 13809310005 | 王敏 | 学生 / 教师 / 班级 / 排课 / 通知管理、校圈治理 |
| 校长 | 13809310006 | 陈建华 | 切换三个校区的驾驶舱，查看履职、学情与点评链，点评和推优 |

每个身份第一次进入首页会弹出新手引导；演示或截图时可在帮助页一次跳过全部身份的引导。体验点评链时，先用李静发布城东联考冲刺1班素描作品任务，再用林小雨提交照片并选择任课老师。每位指定老师完成独立点评后，作品进入张明远的组长队列；陈建华可以查看全链条、独立点评打分和推优。林小雨可在作品详情查看时间线并改画重交。没有独立登录入口的共同点评老师由演示后端延迟补全记录。

演示画室为「示范画室」（甘肃兰州，城东 / 城西 / 安宁三个校区），2026 年 4–10 月共 7 场月考，40 名学生；10 月月考处于阅卷中。所有人物与成绩均为虚构。

### 接入真实接口

默认启动演示模式。使用专用测试账号在联调环境运行时，关闭演示并指定新后端的 HTTPS 根地址：

```powershell
flutter run -d chrome --dart-define=DEMO_MODE=false --dart-define=ART_ROAD_API_BASE_URL=https://ipad-test.example.com/
flutter build ipa --release --dart-define=DEMO_MODE=false --dart-define=ART_ROAD_API_BASE_URL=https://ipad-test.example.com/
```

把示例地址换成测试负责人提供的地址。传入 `ART_ROAD_API_BASE_URL` 后，平台、阅卷、云盘与群聊 WebSocket 统一接入该服务。省略地址参数且关闭演示时，继续使用原平台和阅卷地址。真机还需验证登录与默认学校、文件预览和下载、WSS 收发与重连。

正式包中，学生可从「我的作品」提交带作业 ID 的图片，随后在教师待批列表、点评结果和重交状态中核对同一份作品。班主任家校沟通保留入口和历史，暂不开放发送。学年从 8 月起算，教师和校长页面标明哪些数字仅统计已同步作品。作品集市暂缓，老系统作品读全与增量读取待确认。完整的真机场景与证据记录方式见同级后端仓库 `art_road_api/docs/integration/`。

## 目录

```
lib/
  app/            路由（RoutePaths + onGenerateRoute）与 MaterialApp
  core/
    art/          科目（素描 / 色彩 / 速写）、色板与字号
    demo/         演示后端：拦截器、路由、本地存储、本地媒体服务、WebSocket 模拟、演示数据
    network/      ApiClient（Dio）、聊天 Socket、文件地址解析
    ui/           组件库（ui.dart 统一导出，规范见 docs/设计规范.md）
    widgets/      早期通用组件（新页面改用 core/ui）
  features/<模块>/
    data/         接口仓库与数据模型
    state/        Riverpod 控制器与状态
    ui/           页面与组件
docs/             产品规划、设计规范、后端缺口清单、走查问题与修复记录（docs/走查/）
test/             单元测试与组件测试
tool/
  qa/             1180×820 全角色截图走查脚本
  brand/          美育集图标渲染脚本
  ebooks/         示例书刊页面生成脚本
```

## 检查

每次修改后执行：

```powershell
dart analyze lib test
flutter test --no-pub
```

界面改动后跑一遍截图走查（先构建并启动 `build/web` 的静态服务；Playwright 取自机构端工程 `grading-web` 的依赖，不给本工程新增依赖）：

```powershell
node tool/qa/screens.mjs --out=build/qa/after                       # 全部身份
node tool/qa/screens.mjs --out=build/qa/after --roles=student --only=home,study
```

步骤清单在 `tool/qa/pages.mjs`，截图按身份分目录保存，失败的步骤另存 `.failed.png` 并汇总在 `report.json`。

## 上线前需要替换

- 演示素材：`assets/demo/**`（示例作品、原卷、视频、头像、画室 Logo、示例书刊）为演示生成或制作，需要换成画室授权的素材与书刊。
- 品牌：App 图标 `assets/icon/app_icon.png`（由 `tool/brand/render_icons.mjs` 用「美育集」字标渲染，`flutter_launcher_icons` 生成各端图标）、侧栏与登录页 Logo `assets/images/brand/meiyuji_logo.png`（ArtEd.Hub / 美育集 横版组合）、登录插画 `assets/images/auth/bg_art.jpg`，上线前需品牌方确认。
- 包名：Android `com.yyzl.the_road_of_art_flutter`，iOS / macOS `com.uniapp.art`，与应用商店账号核对后再改签名配置。推送到 GitHub 供 Codemagic 构建的 iOS 体验包临时沿用音乐之路的 `com.uniapp.music` 与其开发证书。
- 协议文本：`lib/features/common/ui/terms_page.dart` 中的服务协议与隐私政策为模板，需法务审核。
- AI 作品分析：演示版只返回分析模板，正式版需接入支持图片理解的模型。
