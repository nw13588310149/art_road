# AGENTS

## Product
- 美育集: a landscape iPad app for art-exam (美术艺考) students, studio teachers and studio staff, built around the marking system (阅卷系统).
- 3.1 is a demo build: every request is answered by the local demo backend using the app's API paths. The app name is 「美育集」. The logo is the ArtEd.Hub / 美育集 lockup in `assets/images/brand/meiyuji_logo.png`; the square app icon uses the 「美育集」 wordmark.
- Product plan and implementation: `docs/美育集3.1产品与交互方案.md`, `docs/美育集3.0产品方案.md`, `docs/美育集3.0实施规格.md`. Design rules and component library: `docs/设计规范.md`. Backend gaps before going live: `docs/后端缺口清单.md`. Run instructions and demo accounts: `README.md`. Audit findings and fix records: `docs/走查问题清单.md`, `docs/走查/`.

## Current Rules
- All feature work uses Flutter. UI and business state stay strictly separated: feature folders `data/` (repository + models) → `state/` (Riverpod StateNotifier controllers) → `ui/`.
- Read this file before every change and continue with the existing architecture.
- After every change run `dart analyze lib test` (must report no issues) and `flutter test --no-pub`. `flutter analyze` crashes on this machine.
- Dependencies resolve offline only (`flutter pub get --offline`). Do not add packages without the user's approval.
- No music wording or imagery anywhere: strings, comments, asset names and pictures. Subjects are 素描 / 色彩 / 速写 (plus 美术常识 / 文化课); use `ArtSubject` for subject labels and colors.
- Every API the app calls must have a demo fixture with art-themed data, and demo data must stay consistent across modules (same students, teachers, exams, timetable, counts and scores). Demo times go through `DemoClock` so they land in daytime.
- Existing reusable pages must preserve the read-only music reference implementation: page-specific font sizes, weights, dimensions, assets and interactions take priority over the generic token restrictions below. Keep art branding, art content, current routes and working state contracts. New art pages reuse these established controls.
- UI is built from the component library `lib/core/ui` (import `ui.dart`) and follows `docs/设计规范.md`: brand #715EFE only for primary actions, selected states and key numbers; font sizes 12/13/14/16/20/24/32 only; no tap or press animations (selection switches instantly, only overlays fade, ≤200 ms); confirmations via `showAppConfirm` (`danger: true` for destructive actions); icon-only buttons need a `semanticLabel`.
- Copy must pass the banned-word list `D:\桌面\阅卷系统\yikao-marketing\brand\compliance\banned-words.json` (no absolute words, no score or admission promises, no unbacked AI claims).
- Commit locally after each verified phase. Push only when the user asks; GitHub `art_road` main feeds the Codemagic iOS preview, which keeps the 音乐之路 bundle id `com.uniapp.music`.

## Layout Notes
- Landscape dashboard shell (`ShellScaffold`: left nav + top bar) on a 1180×820 design base. `DashboardScaleScope.ui()` is identity now; kit components use fixed tokens. Kit overlays (`showAppDialog` / `showAppConfirm` / `showAppDrawer`) work inside and outside the shell; the legacy `showScaledDialog` / `showConfirmDialog` also inherit the shell scale when present and fall back to identity outside it.
- Content is split three ways; keep it that way when adding features:
  - 首页 (`/`) is the same portal for every role, laid out like the music reference: banner, nine quick actions, three subject cards, the timetable column and 最新. No role cards here.
    - `buildQuickActions(role)` returns the same nine entries in the same order (学情、工具、作业、题库、作品墙、集市、群聊、资讯、校圈). Only dorm managers swap 学情 / 作业 for 校长信箱 / 查寝.
    - The right column shows the personal timetable for students and teaching staff, the school-wide timetable for admins and principals (`homeRoleSeesSchoolTimetable`), and the duty times for dorm managers.
  - 今日 (`/today`) lists what this person has to handle today. Every role shares one skeleton: 待处理 (sorted by urgency, one number and one action per row), 今日日程 on the right, 值得关注 (at most three tiles, no charts) and 常用 shortcuts.
  - Analytics and reports stay in 学情. The principal's 全校学情 opens `PrincipalOverview` (metrics, trend, report entries).
- Shared shell areas such as the left navigation and top bar stay reusable and stable.
- Left nav keeps 首页、今日、小美同学、学情（教职）、电子书刊、校园资料（学校开启时）、优秀课件、素材中心、我的云盘、视频中心、智慧校园、个人中心, plus a fixed footer 「意见反馈」.
  - 今日 sits right below 首页: students see 「今日学习」, staff see 「今日工作」 (`todayNavLabel`). Its badge is the number of pending items (`todayPendingCountProvider`, applied in `ShellScaffold`).
  - 电子书刊 sits above 校园资料 and opens `/ebooks` (精选书刊). 优秀课件 sits below 校园资料 and opens `/micro-lessons`. 素材中心 sits below 优秀课件 and opens `/gallery`.
  - Staff see 班级学情 and the principal sees 全校学情; students open 学情 from the home quick actions; dorm managers do not see 学情.
  - 我的笔记 and 我的收藏 open from 个人中心 and highlight it. Staff have twelve items, which fit 1180×820 and 1024×768 without scrolling; move an entry elsewhere before adding a thirteenth.

## Architecture
- Routing: Navigator 1.0 `onGenerateRoute` with `RoutePaths`. Art routes and their arguments:
  - `/today` → `TodayPage` (no arguments; the role comes from the session)
  - `/study` → `StudyCenterPage` (`examId`, `view`, `subjectId`)
  - `/artworks` → `ArtworksPage` (`artworkId`)
  - `/gallery` → `GalleryPage` (`subject`, `keyword`, `category`, `workId`)
  - `/toolbox` → `ArtToolboxPage` (`tool`, `imageUrl`, `title`); `tool` is an `ArtTool.key` from `art_toolbox/data/toolbox_catalog.dart` (17 tools in three groups). Other modules deep-link by key, so never rename an existing key.
  - `/ebooks` → `EbooksPage` (`bookId`)
  - `/micro-lessons` → `LearningTopicsPage`; `/market` → `MarketplacePage` (creative_hub data/state/ui).
- Creative Hub fixtures use DemoStore for topics, resources, listings, per-user favorites and immutable order snapshots. Purchases are explicitly demo transactions.
- Artwork teacher reviews are independent per assigned teacher; `teacherStageComplete` gates leader review. Principal scores remain separate from the teaching reference score.
- FL Chart 1.3.1 is cached with the user's one-time download approval; keep future dependency resolution offline.
- Notifications carry `targetType` + `targetId`; the mapping to routes lives in `lib/features/shell/navigation/shell_notice_routes.dart`.
- First-login guide per role: content in `lib/features/help_guide/data/role_guides.dart`, seen flags `role_guide_seen_v1:<role>` in SharedPreferences.
- Two API clients in `lib/core/providers/app_providers.dart`:
  - `apiClientProvider`: platform API (api-v2), paths `/app/user|common|msg|courseware/*` and `/app/school/v2/*`.
  - `markingApiClientProvider`: marking API (exam-api), students send `app-token`, teachers `school-token`.
- Art kit: `lib/core/art/` (`ArtSubject`, `ArtColors`, `ArtText`, `formatScore`), `lib/core/widgets/art_widgets.dart`, `art_subject_card.dart`.
- Art modules: `study_center`, `artworks`, `gallery`, `ebooks`, `art_toolbox`, `today`. Toolbox tools work fully offline and run image processing through `compute`.
- Today (`lib/features/today`):
  - `TodayRepository.load(role)` only reads APIs that other modules already use and returns a `TodaySnapshot`. Each source fails on its own, so one failed request does not blank the page. Do not add an endpoint just for this page.
  - `buildTodayBoard(snapshot)` in `state/today_board.dart` is a pure function with one builder per role. Rows that need the person to act set `pending: true` and count toward the nav badge; finished rows and plain entries do not.
  - Show a number only when an API provides it. 到岗打卡 has no status API, so it is an entry without a count.
  - Rows open their destination through `TodayTarget`. Smart-campus views go through `CampusEntry` (`smart_campus/state/campus_entry.dart`), which the home quick actions share.
- Generic modules kept from the original platform and art-ified: `ai_chat`, `courseware` (incl. cloud drive), `video_tutorial`, `my_notes`, `my_collection`, `quiz_practice`, `circle`, `school`, `smart_campus`, `personal_center`, `help_guide`, `feedback`, `consultation`.

## Demo Mode
- `kDemoMode` comes from `--dart-define=DEMO_MODE` (default `true`). `main.dart` initializes `DemoStore`, `DemoMedia` and the fixtures before `runApp`.
- Each `ApiClient` gets a `DemoApiInterceptor` that answers through a `DemoRouter` (`DemoBackend.platform` / `DemoBackend.marking`):
  - handlers return the `data` payload; the interceptor wraps `{code: 0, msg: 'ok', data}`;
  - throw `DemoApiException` for business errors;
  - literal routes win over `{param}` routes;
  - unmatched routes return null data and are logged, so add a fixture instead of relying on that.
- Fixtures live in `lib/core/demo/fixtures/` (`platform_core_*`, `content_*`, `interaction_*`, `campus/campus_a_*`, `campus/campus_b_*`, `marking_*`). Register new groups in `demo_fixtures.dart`.
- `DemoStore` (memory + SharedPreferences, key prefix `demo_store:`) holds all writable demo state. `DemoStore.reset()` restores the seeds and is wired to 「重置演示数据」 on the login page, so never keep mutable demo state in static fields.
- `DemoMedia`: on io a loopback HTTP server serves bundled assets (`/a/<asset>`) and uploads (`/f/<id>`, with Range support); on web it uses asset URLs and blob URLs (blob uploads don't survive a reload). Reference assets as `asset:assets/demo/...` and resolve them with `DemoMedia.url`.
- `DemoSocketBridge` injects frames into `ChatSocketService`: AI streaming (type 10004 deltas + 10005 final) and chat pushes (type 2001).
- Identity: `DemoAccounts` (student / teacher / head teacher / dorm manager / admin / principal, mobiles 13809310001–06, plus the group leader 张明远 on 13809310012). Tokens look like `demo.<role>.<mobile>`; resolve them with `DemoAccounts.fromToken`.
  - A group leader (教学组长) is a teacher with leader rights, not a backend role: `myInfo.user.role` stays `teacher` and `myInfo.user.groupLeader.subjects` lists the subjects they lead (`ShellUser.groupLeaderSubjects`). Branch on `DemoRole.teaches` / `DemoRole.managesSchool` in fixtures instead of comparing single roles.
  - The principal (`principal`) sees all three campuses, shares the admin console in 智慧校园 and owns the 校长信箱 inbox.
- Data:
  - `DemoMarkingData` is a deterministic port of the uni-app mock data (mulberry32 RNG): 示范画室, three campuses, exams 21–27, 40 students, judges / trimmed mean / arbitration, A–E bands.
  - `DemoCampusData` covers classes, staff, timetable and dorm beds; `DemoArtworkData` and `DemoFavorites` cover artworks and favorites.
  - `DemoArtworkStore` owns artwork versions and tasks. Campus homework adapters project their existing response shapes from this store. Teaching reports combine the same works and tasks with the campus sign records and marking results.
  - Smart campus part A and part B keep separate stores; only leave records are bridged between them.

## Platform Notes
- The `windows/` and `linux/` folders were removed (plugin symlinks require Developer Mode on this machine).
- iOS: `AppAudioSessionCoordinator` (channel `com.yyzl.art/audio_session`) is the only `AVAudioSession` owner, used by voice messages and recording; `NoteCanvasZoomCoordinator` uses channel `the_road_of_art_flutter/note_canvas_zoom`.
- Android `MainActivity` sets `FLAG_SECURE`. All platforms are landscape only.
- Native changes can't be compiled on this machine (no Xcode / Android SDK); verify them on a Mac.
- Web QA:
  - build with `tool/build_web.ps1` and serve `build/web`;
  - screenshot every role at 1180×820 with `node tool/qa/screens.mjs --out=build/qa/after` (steps in `tool/qa/pages.mjs`; Playwright is loaded from `grading-web`, no new dependency); add a step when you add a page or entry;
  - in automated browsers, enable Flutter semantics (click `flt-semantics-placeholder`) before clicking;
  - Web QA enters Chinese text with Playwright `keyboard.insertText`. Use widget tests for field geometry and validation states.
  - for UI changes, use `D:\桌面\music\musicDemo` at `80e9dd3c` as the read-only reference. Compare the affected entry, subviews and interaction states at 1180×820 and 1024×768 (`screens.mjs --width=1024 --height=768`), record any deliberate differences for art-specific content in `docs/走查/音乐之路界面对照.md`, and repeat affected checks after fixes. Add an expected visible control or result to new QA interaction steps so a fallback page cannot pass on screenshots alone.
