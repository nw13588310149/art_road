# 美术之路（The Road of Art）

面向美术艺考生、画室老师与画室管理者的 iPad 横屏 App（艺考网出品）。围绕阅卷系统，提供学情中心、作品档案与作品点评、范画库、美术书刊、画室工具箱（三组 17 个工具），以及资讯、校园课件、云盘、视频、笔记、收藏、题库、AI 美术助教「小美同学」、校圈、智慧校园等通用模块。首页、新手引导和通知按学生、任课老师、班主任、宿管、管理员五种身份配置。

当前版本 2.0 为**演示版**：所有接口由本地演示后端应答，接口路径与真实后端保持一致。产品规划见 [docs/美术之路产品规划.md](docs/美术之路产品规划.md)，界面规范与组件库见 [docs/设计规范.md](docs/设计规范.md)，接入真实接口前的缺口见 [docs/后端缺口清单.md](docs/后端缺口清单.md)。

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

## 演示模式

默认开启（`DEMO_MODE` 默认为 `true`）：
- 请求由 `DemoApiInterceptor` 在本地应答，模拟 120–300 ms 网络延迟。
- 上传的作品、老师点评、笔记、收藏、请假等写操作保存在本机（SharedPreferences，键前缀 `demo_store:`），重启后仍在。
- 登录页「重置演示数据」可以一键恢复初始数据。

体验身份（登录页直接点选，或输入手机号 + 任意密码）：

| 身份 | 手机号 | 姓名 | 说明 |
| --- | --- | --- | --- |
| 学生 | 13809310001 | 林小雨 | 城东校区，七场月考全勤，8 件作品 |
| 任课老师 | 13809310002 | 李静 | 素描老师，7 件作品待点评 |
| 班主任 | 13809310003 | 赵雪 | 班级工作台、请假审批、家校沟通 |
| 宿管 | 13809310004 | 马红梅 | 按宿舍查寝、查寝历史、到岗打卡 |
| 管理员 | 13809310005 | 王敏 | 学生 / 教师 / 班级 / 排课 / 通知管理、校圈治理 |

每个身份第一次进入首页会弹出新手引导；演示或截图时可在帮助页一次跳过全部身份的引导。

演示画室为「示范画室」（甘肃兰州，城东 / 城西 / 安宁三个校区），2026 年 4–10 月共 7 场月考，40 名学生；10 月月考处于阅卷中。所有人物与成绩均为虚构。

### 接入真实接口

```powershell
flutter run -d chrome --dart-define=DEMO_MODE=false
```

关闭后体验身份入口隐藏，App 请求两套真实接口：

- 平台接口 `https://api-v2.yyzl0931.com/`：账号、资讯、课件、视频、智慧校园等通用模块。
- 阅卷接口 `https://exam-api.yyzl0931.com/`：学情、作品档案与点评、范画库（学生 `app-token`，老师 `school-token`）。

班级学情（任课老师）、范画库、学生端评分标准、老师批注、我的高频问题还需要后端补接口，平台账号与阅卷账号也需要打通，详见 [docs/后端缺口清单.md](docs/后端缺口清单.md)。

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
  brand/          艺考网图标渲染脚本
  ebooks/         示例书刊页面生成脚本
```

## 检查

每次修改后执行：

```powershell
dart analyze        # 本机 flutter analyze 的分析服务会崩溃，用 dart analyze 代替
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
- 品牌：App 图标 `assets/icon/app_icon.png`（由 `tool/brand/render_icons.mjs` 用艺考网图形标渲染，`flutter_launcher_icons` 生成各端图标）、侧栏与登录页 Logo `assets/images/brand/`（艺考网标志，取自品牌规范包）、登录插画 `assets/images/auth/bg_art.jpg`，上线前需品牌方确认。
- 包名：Android `com.yyzl.the_road_of_art_flutter`，iOS / macOS `com.uniapp.art`，与应用商店账号核对后再改签名配置。推送到 GitHub 供 Codemagic 构建的 iOS 体验包临时沿用音乐之路的 `com.uniapp.music` 与其开发证书。
- 协议文本：`lib/features/common/ui/terms_page.dart` 中的服务协议与隐私政策为模板，需法务审核。
- AI 作品分析：演示版只返回分析模板，正式版需接入支持图片理解的模型。
