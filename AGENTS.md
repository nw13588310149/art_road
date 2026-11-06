# AGENTS

## Product
- 美术之路 (The Road of Art): a landscape iPad app for art-exam (美术艺考) students, studio teachers and studio staff, built around the marking system (阅卷系统).
- v1 is a demo build: every request is answered by the local demo backend while keeping the real API paths.
- Product plan: `docs/美术之路产品规划.md`. Backend gaps before going live: `docs/后端缺口清单.md`. Run instructions and demo accounts: `README.md`.

## Current Rules
- All feature work uses Flutter. UI and business state stay strictly separated: feature folders `data/` (repository + models) → `state/` (Riverpod StateNotifier controllers) → `ui/`.
- Read this file before every change and continue with the existing architecture.
- After every change run `dart analyze` (must report no issues) and `flutter test --no-pub`. `flutter analyze` crashes on this machine; use `dart analyze`.
- Dependencies resolve offline only (`flutter pub get --offline`). Do not add packages without the user's approval.
- No music wording or imagery anywhere: strings, comments, asset names and pictures. Subjects are 素描 / 色彩 / 速写 (plus 美术常识 / 文化课); use `ArtSubject` for subject labels and colors.
- Every API the app calls must have a demo fixture with art-themed data, and demo data must stay consistent across modules (same students, teachers, exams and scores).
- Commit locally after each verified phase; never push.

## Layout Notes
- Landscape dashboard shell (`ShellScaffold`: left nav + top bar) on a 1180×820 design base. `DashboardScaleScope` provides `ui()` scaling inside the shell only; auth pages use their own design canvas, so don't call `showScaledDialog` / `showConfirmDialog` from them.
- Shared shell areas such as the left navigation and top bar stay reusable and stable.
- Navigation labels are role-based (`isStaffRole`): students see 我的学情 / 作品档案, staff see 班级学情 / 作品点评.

## Architecture
- Routing: Navigator 1.0 `onGenerateRoute` with `RoutePaths`. Art routes and their arguments:
  - `/study` → `StudyCenterPage` (`examId`, `view`, `subjectId`)
  - `/artworks` → `ArtworksPage` (`artworkId`)
  - `/gallery` → `GalleryPage` (`subject`, `keyword`, `category`, `workId`)
  - `/toolbox` → `ArtToolboxPage` (`tool`, `imageUrl`, `title`)
- Two API clients in `lib/core/providers/app_providers.dart`:
  - `apiClientProvider`: platform API (api-v2), paths `/app/user|common|msg|courseware/*` and `/app/school/v2/*`.
  - `markingApiClientProvider`: marking API (exam-api), students send `app-token`, teachers `school-token`.
- Art kit: `lib/core/art/` (`ArtSubject`, `ArtColors`, `ArtText`, `formatScore`), `lib/core/widgets/art_widgets.dart`, `art_subject_card.dart`.
- Art modules: `study_center`, `artworks`, `gallery`, `art_toolbox`. Toolbox tools work fully offline and run image processing through `compute`.
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
- Identity: `DemoAccounts` (student / teacher / head teacher / dorm manager / admin, mobiles 13809310001–05). Tokens look like `demo.<role>.<mobile>`; resolve them with `DemoAccounts.fromToken`.
- Data:
  - `DemoMarkingData` is a deterministic port of the uni-app mock data (mulberry32 RNG): 示范画室, three campuses, exams 21–27, 40 students, judges / trimmed mean / arbitration, A–E bands.
  - `DemoCampusData` covers classes, staff, timetable and dorm beds; `DemoArtworkData` and `DemoFavorites` cover artworks and favorites.
  - Smart campus part A and part B keep separate stores; only leave records are bridged between them.

## Platform Notes
- The `windows/` and `linux/` folders were removed (plugin symlinks require Developer Mode on this machine).
- iOS: `AppAudioSessionCoordinator` (channel `com.yyzl.art/audio_session`) is the only `AVAudioSession` owner, used by voice messages and recording; `NoteCanvasZoomCoordinator` uses channel `the_road_of_art_flutter/note_canvas_zoom`.
- Android `MainActivity` sets `FLAG_SECURE`. All platforms are landscape only.
- Native changes can't be compiled on this machine (no Xcode / Android SDK); verify them on a Mac.
- Web QA:
  - build with `tool/build_web.ps1` and serve `build/web`;
  - in automated browsers, enable Flutter semantics (click `flt-semantics-placeholder`) before clicking;
  - Flutter text fields ignore injected keystrokes, so cover text input with tests instead.
