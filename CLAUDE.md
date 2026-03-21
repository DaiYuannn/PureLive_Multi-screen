# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Pure Live (纯粹直播) is a Flutter-based third-party live streaming application that supports multiple platforms including Bilibili, Douyu, Huya, Douyin, Kuaishou, CC, and custom M3U8 sources. The app is designed for Android, iOS, Windows, macOS, and TV platforms.

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

## Common Commands

### Development Setup
```bash
flutter pub get                    # Install dependencies
flutter clean                     # Clean build artifacts
flutter pub run build_runner build # Generate code
```

### Building and Packaging

#### Android
```bash
flutter build apk                  # Universal APK
flutter build apk --split-per-abi  # Separate APKs for different architectures
```

#### Windows
```bash
dart run msix:create --signtool-options "/td SHA256"  # Windows MSIX package
```

#### iOS/macOS
Requires Xcode for building iOS and macOS versions.

### Code Generation
```bash
flutter pub run build_runner build --delete-conflicting-outputs  # Regenerate all generated files
flutter pub run json_serializable   # JSON serialization
flutter pub run protoc_builder      # Protocol buffer generation
flutter pub run flutter_launcher_icons  # Update app icons
```

### Localization
```bash
flutter pub run intl_utils:generate  # Generate localization files
```

### Linting
The project uses `flutter_lints` package with configuration in `analysis_options.yaml`.

## Architecture Overview

### Core Structure
- **`lib/core/`**: Core business logic and platform integrations
  - `site/`: Platform-specific implementations (Bilibili, Douyu, Huya, etc.)
  - `danmaku/`: Danmaku (live chat) handling for each platform
  - `interface/`: Abstract interfaces for live sites and danmaku
  - `iptv/`: M3U8 playlist parsing and IPTV support
  - `common/`: Shared utilities and helpers

- **`lib/common/`**: Shared application components
  - `services/`: Global services (Settings, Authentication, etc.)
  - `widgets/`: Reusable UI components
  - `models/`: Data models and structures
  - `utils/`: Utility functions and helpers
  - `l10n/`: Internationalization support (Chinese/English)

- **`lib/modules/`**: Feature modules organized by functionality
  - Each module typically contains: `*_page.dart`, `*_controller.dart`, `*_binding.dart`
  - Major modules: `live_play/`, `areas/`, `settings/`, `account/`, `search/`

### State Management
The application uses **GetX** for state management, routing, and dependency injection:
- Controllers extend `BaseController` from `lib/common/base/base_controller.dart`
- Services are initialized in `main.dart` using `Get.put()`
- Bindings are used for lazy loading of controllers

### Platform Support
- **Android/TV**: Multiple video players (ExoPlayer, IjkPlayer, MpvPlayer)
- **Windows**: Media Kit for video playback, Windows-specific utilities
- **Mobile**: Touch-optimized UI with gestures and mobile-specific features
- **Cross-platform**: SharedPreferences for settings, file system access

### Live Streaming Integration
Each streaming platform has its own implementation in `lib/core/site/`:
- `LiveSite` interface defines common methods for all platforms
- Platform-specific classes handle API calls, authentication, and stream URL extraction
- Danmaku systems are separate implementations per platform
- Support for custom M3U8 playlists through IPTV functionality

### Key Features
- Multi-platform live streaming support
- Real-time danmaku (live chat) with filtering and merging
- User authentication via Supabase
- WebDAV backup/restore functionality  
- Custom M3U8 playlist imports
- Platform-specific optimizations and player selection
- Internationalization (Chinese/English)
- Theme customization with dynamic colors

### Dependencies and Services
- **Media playback**: `media_kit` for cross-platform video
- **Network**: `dio` for HTTP requests with cookie management
- **Database**: `supabase_flutter` for user authentication and data
- **UI framework**: Flutter with Material Design and custom theming
- **Storage**: `shared_preferences` for app settings, file system for caching

## Development Notes

### Platform-Specific Code
- Windows initialization includes window management and single-instance checking
- Android handles share intents for M3U8 file imports  
- Platform-specific video player selection based on capabilities

### Build Configuration
- Uses Flutter Version Manager (FVM) - see `.fvmrc`
- MSIX configuration for Windows Store deployment
- Custom app icons and launcher configurations
- Localization files auto-generated in `lib/common/l10n/generated/`

### Testing and Quality
- Uses `flutter_lints` for code quality
- Excludes generated files from analysis
- Protocol buffer definitions for platform-specific messaging