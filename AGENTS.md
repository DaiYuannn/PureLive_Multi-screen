# Repository Guidelines

## Windows-First Personal Build (Current Goal)

This repository is now maintained with a **Windows personal-use first** target.
Cross-platform compatibility is still welcome, but implementation decisions should prioritize:

- Stable behavior on Windows desktop
- Faster iteration for a single developer workflow
- Practical performance trade-offs for one machine

### Environment Baseline (Windows)

- Use FVM-managed Flutter from `.fvmrc` (`stable`)
- Prefer `fvm flutter ...` and `fvm dart ...` commands in this repo
- If downloading is slow in mainland China, set mirrors:
  - `PUB_HOSTED_URL=https://pub.flutter-io.cn`
  - `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`

### Windows-Focused Run/Check Commands

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm dart format .
fvm flutter run -d windows
```

## Project Structure & Module Organization

- `lib/`: Flutter/Dart source
  - `lib/core/`: site integrations, danmaku, IPTV, shared helpers
  - `lib/common/`: shared services/widgets/models/styles and i18n (`lib/common/l10n/`)
  - `lib/modules/`: feature modules (GetX), e.g. `live_play/`, `settings/`, `search/`
  - `lib/routes/`, `lib/player/`, `lib/plugins/`: routing, playback, and integrations
- `assets/`: icons/images/emotes plus app config like `assets/version.json`
- `test/`: Flutter tests (`*_test.dart`)
- Platform folders: `android/`, `ios/`, `macos/`, `windows/`, `linux/`

## Build, Test, and Development Commands

Use Flutter from `.fvmrc` (`stable`) and run through FVM.

- `fvm flutter pub get`: install dependencies
- `fvm flutter run`: run on a device/emulator
- `fvm flutter analyze`: static analysis/lints (`analysis_options.yaml`)
- `fvm dart format .`: auto-format Dart code
- `fvm flutter test`: run the test suite
- Packaging examples (see `run.MD` and `.github/workflows/release.yml`):
  - Android: `fvm flutter build apk --split-per-abi`
  - Windows: `fvm dart run msix:create`
  - macOS: `fvm flutter build macos --release`

## Multi-Live Roadmap (Confirmed)

The current player path is single-room/single-player. For this personal Windows-focused version, follow a two-phase plan.

### Phase 1 (P0/P1): Single-window multi-room split-screen (recommended first)

This is the default path and should be completed before true multi-window:

- Add a dedicated `MultiLivePage` + `MultiLiveController`
- Do not hard-couple new logic into existing single-room page
- One tile = one independent player instance
- Independent per-tile load/retry/mute/close state
- Grid switching: 1 / 2 / 4 / 6 / 9
- Audio policy: only one focused tile has sound by default
- Lifecycle: dispose all tile players and danmaku resources on page exit
- Entry: add "join multi-live queue" + "open multi-live" from room cards

Suggested data model:

- `MultiRoomItem`: room, loading/error status, mute flag, danmaku flag
- `MultiLiveController`:
  - `RxList<MultiRoomItem> rooms`
  - `RxInt gridCount`
  - `Map<String, VideoController> tileControllers`

Performance guardrails (Windows first):

- Default to 4 tiles
- Allow manual switch up to 9 tiles
- Prefer enabling danmaku only on focused tile

### Phase 2 (P2): True system multi-window (Windows enhancement)

After phase 1 is stable, add system windows:

- Use `desktop_multi_window` (or equivalent)
- Main window handles room management
- Child windows each own one player instance
- Pass room init data via route/windowId arguments

Windows-specific blockers to handle first:

- Existing single-instance lock may block extra windows
- Keep single process, but allow multiple app windows
- Handle focus sync, close sync, and tray behavior

## High-Risk Points (Must Avoid)

- Reusing singleton global player state in multi-tile mode
- Enabling full danmaku + decode on all tiles on low-end hardware
- Ignoring concurrent-source throttling/retry for some platforms
- Keeping strict single-instance window lock when implementing multi-window

## Coding Style & Naming Conventions

- Keep code `dart format`-clean; follow `flutter_lints` defaults.
- Dart conventions: `lower_snake_case.dart` files, `UpperCamelCase` types, `lowerCamelCase` members.
- Module files typically follow `*_page.dart`, `*_controller.dart`, `*_binding.dart` (GetX bindings/routing).

## Testing Guidelines

- Framework: `flutter_test`. Place tests under `test/` and name files `*_test.dart`.
- Add or update tests for bug fixes and non-trivial logic (services, parsers, site adapters).

## Commit & Pull Request Guidelines

- Git history favors short, imperative messages like `fix(*)`, `fix(scope)`, and occasional Chinese summaries.
- PRs should include: what changed, repro steps, linked issues, screenshots/recordings for UI changes, and platforms tested (e.g. Android/Windows).

## Security & Configuration Tips

- Do not commit real signing material or credentials. Keep local-only files (e.g. `android/key.properties`) out of PRs.
- Supabase settings live in `assets/keystore/supabase.json`; if you use your own backend, change it locally and avoid publishing private keys.
