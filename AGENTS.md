# AGENTS

## Current Rules
- All new feature work must use Flutter.
- UI and business state must remain strictly separated.
- Before every new modification, read this file and continue with the existing architecture.
- After every modification, run `flutter analyze` and keep the project analyzer-clean.

## Layout Notes
- The app uses a landscape dashboard shell.
- Current implementation has moved away from whole-page global scaling.
- Shared shell areas such as left navigation and top bar should remain reusable and stable.

## Implemented / In Progress
- Auth pages: migrated to Flutter 2.0 UI.
- Home page: migrated to Flutter 2.0 UI baseline.
- AI chat, courseware, cloud drive, video center, music companion, notes, collection, recording system: all have Flutter 2.0 pages connected.
- Smart campus: currently kept in a stable placeholder-safe version to avoid project-wide breakage before the full rebuild.
- Dictation secondary page: implemented with real menu + textbook APIs and 2.0 layout.
- Sight singing / music theory / answer questions / voice / instrumental secondary pages:
  - unified under `lib/features/study_catalog/`
  - share the dictation 2.0 visual structure
  - use 1.0 menu/textbook API rules and route branching
  - router now points these routes to real Flutter pages instead of placeholders
- Music play tertiary page:
  - implemented under `lib/features/music_play/`
  - route `/musicPlay` now points to a real Flutter page
  - detail data uses 1.0 `textbookDetail` API rules
  - long-audio playback uses `media_kit`
  - bottom piano interaction reuses the existing Flutter short-audio ecosystem via `flutter_soloud`
  - page startup must not block on full piano/metronome asset preload
  - musicPlay should warm up piano audio in the background and load textbook detail first
- iOS audio architecture (AppAudioService refactor):
  - The shared native short-audio player is App-lifetime owned; feature/page disposal may call `stopAll()` but must never call its `dispose()`.
  - `ios/Runner/AppAudioSessionCoordinator.swift` is the sole explicit iOS `AVAudioSession` owner; Dart session transitions go through its serialized MethodChannel.
  - Normal iOS MusicPlay long-audio playback uses the AVPlayer-backed `MusicPlayAudioPlayer`; `media_kit` is reserved for active independent pitch shifting and non-iOS platforms.
  - The native piano engine serializes all `AVAudioEngine` and node operations on one audio queue; `prepare` reports ready only after requested samples are decoded.
  - `lib/core/audio/app_audio_service.dart` — single coordinator: shared `LowLatencyNotePlayer`, `reconcilePlaybackSession()` (no cache short-circuit; fixes mpv `moviePlayback` drift), `prepareForPianoKeypress()`, fire-and-forget `playPianoFromGesture()`.
  - `lib/core/audio/native_playback_audio_session.dart` — cross-platform facade; iOS delegates session transitions to the native coordinator, while other platforms continue through `audio_session`.
  - `lib/core/audio/page_audio_lifecycle.dart` — page enter/leave wrappers (re-exported from music_companion for compat).
  - `lib/core/audio/ios_piano_bootstrap.dart` — app-launch preload of all piano + metronome assets (GarageBand-style); page nav only reconcile + ping.
  - `ios/Runner/LowLatencyNoteAudio.swift` — one persistent 24-voice `AVAudioEngine`; all engine/node work is serialized on one audio queue; requested samples must decode before `prepare` reports ready.
  - Long audio: normal iOS playback uses AVPlayer through `just_audio`; active pitch shifting and non-iOS platforms use `media_kit`.
  - Piano/metronome/dictation use native AVAudioEngine via shared player — NOT SoLoud (SoLoud is analysis-only via `NativeAudioBootstrap`).
- Smart sight singing (`/smart-singing`):
  - implemented under `lib/features/smart_sight_singing/`
  - left nav entry enabled; supports built-in demo, local `.mid/.midi` upload, and online URL
  - after MIDI parse, user selects and confirms melody track; playback + scoring use that track only
  - iPad defaults to visual-only follow (no speaker accompaniment during sing; KTV track timer only)
  - iPad ready state offers melody preview; optional toggle to enable speaker accompaniment (headphones recommended)
  - playback uses shared piano short-audio scheduler when accompaniment enabled
  - follow-along scoring uses measurement mode (visual-only) or echo-cancel session (with accompaniment)
  - online import supports `.mid` / `.midi` only; legacy YIN/mp3 path kept in code but unused for demo

## Technical Direction
- For secondary study pages, prefer a reusable catalog architecture instead of duplicating page logic.
- Shared responsibilities are split into:
  - `data/`: API repository
  - `state/`: route args, state model, controller
  - `ui/`: page and presentational widgets
- Route-specific behavior such as target page parameters should be configured, not hard-coded per screen when possible.
