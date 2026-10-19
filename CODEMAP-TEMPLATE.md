# CODEMAP-TEMPLATE.md — 模板视角代码地图

> 这不是源码分析，是**"从这份模板我能拿到什么"的导航图**。
> 配套使用：改名前看 `debrify-analysis/25-A1`；裁剪看 `26-A3`/`29-A5`；发布看 `27-A4`；可复用能力看 `00` 脑图 + `23` 号 L0-L4 图谱。
> 证据标记：**[C]** confirmed（ls/grep/读文件命中）/ **[I]** inferred / **[U]** unknown。
> 仓库快照：Debrify `0.10.0-beta.1+56`，`lib/` 971 文件 / ~62.7 万行（`[C]` 00 脑图）。

---

## 1. 顶层目录表

| 目录 | 一句话职责 | 对应可复用 kit / 组件 |
|---|---|---|
| `lib/main.dart` | App 入口：启动管线、平台分支、通道注册 | L4 启动管线；K01/K14 |
| `lib/services/` | 业务服务层（最大目录，300+ 文件）：debrid/IPTV/同步/下载/远程/元数据 | K02-K12/K16-K18 主体 |
| `lib/screens/` | 页面层：搜索/播放器/设置/profiles/iptv/tv | K09/K13/K14 主体（含 god class） |
| `lib/widgets/` | UI 零件 + 导航壳 + 启动初始化 | L1 全部 + L2.5 导航壳 + K01 |
| `lib/models/` | 数据模型（纯 Dart 对象） | L0 之上的数据结构 |
| `lib/utils/` | 纯函数工具类（格式化/解析/平台判定） | **L0 全部**（30+ 零件） |
| `lib/theme/` | 主题系统（7 套 Look / 取色 / shader） | **K15 ThemeKit** |
| `packages/` | 本地 patch 包（media_kit 系列 / sqflite / path_provider tvos） | K09 的二进制依赖 |
| `test/` | 609 个测试文件 / 184,972 行（`[C]` 28-A2） | 回归基线（见第 4 节） |
| `tool/` | 工具脚本（build_personal.sh / 审计脚本 + 本模板新增的 rename/prune） | 模板工具链 |
| `android/` | Android 宿主工程（kotlin/ 68 文件、Manifest、资源、签名） | K08/K11 原生桥、通道原生侧 |
| `ios/` | iOS Runner 工程（Swift AppDelegate、pbxproj、Assets.xcassets） | 通道原生侧、Keychain |
| `macos/` | macOS Runner（MainFlutterWindow.swift、xcconfig） | 桌面壳、通道原生侧 |
| `linux/` | Linux CMake 宿主（gtk、.desktop、libmpv） | 桌面壳 |
| `windows/` | Windows CMake 宿主 + Inno Setup installer.iss | 桌面壳 |
| `tvos/` | tvOS Runner（Swift AppDelegate、TopShelf extension、App Group） | K11 直播 / K09 TV 原生桥 |
| `web/` | PWA（manifest.json、index.html、icons/） | Web 壳 |
| `dev/` | 开发资源：design 设计计划、tool 本地脚本、scripts 构建脚本 | 扩展指南来源（见 TEMPLATE.md 第 5 节） |
| `docs/` | 官方文档（架构/personal build/扩展指南/release notes） | 扩展指南来源 |

---

## 2. Kit 映射表（K01-K18，入口文件）

> 编号对照 `00-可复用能力脑图.md` 与 `02-19` 号 kit 详解文档。路径为 `lib/` 下入口（`[C]` ls + 00 脑图标注；个别入口 `[I]` 按命名推断）。

| Kit | 名称 | 入口文件（lib/ 下） | 说明 |
|---|---|---|---|
| **K01** | LaunchIdent 开屏动画 | `widgets/launch/`、`services/launch_animation/`、`widgets/app_initializer.dart`、`widgets/auto_launch_overlay.dart` | 抽象契约 + 21 套内置 painter + IdentPalette 桥；扩展见 `dev/launch_animations/CREATOR_GUIDE.md` |
| **K02** | LanRemote 局域网远程+配置迁移 | `services/remote_control/`、`widgets/remote/` | ZRTP 握手 + AES-GCM + 6 位 SAS 配对码 + 可靠 UDP 分片（~1.2 万行） |
| **K03** | ProgressSync 跨设备进度同步 | `services/media_server_watch_sync.dart`、`services/{trakt,simkl,mdblist}/` | Emby LWW 谓词 + 三家 tracker scrobble |
| **K04** | BackupRestore 加密备份 | `services/backup_restore_service.dart` | Argon2id 加密备份包 + 分类恢复报告 |
| **K05** | Profile 多用户作用域 | `services/profiles/`、`screens/profiles/`、`services/profile_registry.dart` | 60+ 文件；PIN 锁、功能门控 ProfileFeature |
| **K06** | SecretVault / PrefsStore 加密 KV | `services/secret_vault.dart`、`services/storage_service.dart` | AES-GCM 凭据保险库 + 作用域 Prefs（god class 需拆） |
| **K07** | WebDavSync 自托管配置同步 | `services/webdav_sync/`、`services/webdav_sync_engine.dart` | 4700 行引擎；8 trigger + LWW 三级破平 + tombstone |
| **K08** | DownloadManager 后台下载 | `services/download_service.dart`、`android/.../download/MediaStoreDownloadService.kt` | 四条进度流 + Range 断点 + SAF scoped storage |
| **K09** | MediaPlayerShell 播放器壳 | `screens/video_player_screen.dart`、`screens/video_player/`、`services/video_player_launcher.dart`、`packages/media_kit_*` | 三后端（libmpv/ExoPlayer/External）；18063 行 god |
| **K10** | DebridProvider 离线下载 API | `services/{debrid,torbox,premiumize,alldebrid,pikpak}_service.dart`、`services/torrent_playback_service.dart` | 五家 API 封装 + playBest 选文件；加 provider 见 `dev/design/ADDING_A_PROVIDER.md` |
| **K11** | IPTV M3U/Xtream/EPG/DVR | `services/iptv_*.dart`、`utils/m3u_parser.dart`、`android/.../recording/LiveRecordingService.kt` | 频道目录 SQLite + catchup + DVR 录制 |
| **K12** | AddonCatalog / Stremio 协议 | `services/stremio_*.dart`、`screens/addons/`、`screens/stremio_tv/` | Stremio 三层协议 + badge 隔离 |
| **K13** | DiscoveryBoard / Home rail | `screens/search_screen.dart`、`widgets/home/`、`services/home_*.dart` | 20865 行主页 god；HomeReturnCache 5 分钟返回缓存 |
| **K14** | Navigation 多壳导航 | `services/main_page_bridge.dart`、`widgets/{tv,desktop,mobile}_*_nav.dart` | MainTab 常量表 + 5 种导航壳（手机/桌面/TV） |
| **K15** | Theme 主题系统 | `lib/theme/` | 7 套 Look 预设 + 海报取色 + 动态背景 shader |
| **K16** | DeepLink magnet/分享路由 | `services/deep_link_service.dart`、`services/magnet_link_handler.dart` | preflight consume-once + 30s infohash 去重 |
| **K17** | SearchEngine YAML 聚合搜索 | `services/engine/`、`services/torrent_service.dart` | YAML engine + Torznab（Jackett/Prowlarr）+ 聚合去重；加引擎见 `docs/engines/creating-custom-engines.md` |
| **K18** | Metadata TMDB/TVMaze/IMDB | `services/{tmdb,tvmaze,imdb}_*.dart`、`widgets/trailer_engine.dart` | TMDB 双域名 LRU + 预告片引擎 |

---

## 3. L0-L4 可复用组件表（代表文件）

> 分级定义与完整清单见 `23-可复用能力完整图谱L0-L4.md`。本表只列每层代表。

### L0 — 基础工具类（纯函数，无 UI 无状态，30+）

| 零件 | 文件 | 用途 |
|---|---|---|
| TimeFormatters / Formatters | `utils/time_formatters.dart`、`utils/formatters.dart` | "2h ago" / "1.2GB" / 时长格式化 |
| PlatformUtil | `utils/platform_util.dart` | iOS/Android/TV/macOS 判定 |
| M3UParser | `utils/m3u_parser.dart` | M3U 播放列表解析 |
| SeriesParser / MovieParser | `utils/series_parser.dart`、`utils/movie_parser.dart` | 文件名解析 SxxExx / 电影名 |
| FormatTagDetector / TorrentFilterMatcher / SourceQuality | `utils/format_tag_detector.dart`、`utils/torrent_filter_matcher.dart`、`utils/source_quality.dart` | 标签检测 / 过滤 / 源质量评分 |
| DominantColor | `utils/dominant_color.dart` | 海报主色提取 |
| Concurrency / JsonIsolate / CanonicalJson | `utils/concurrency.dart`、`utils/json_isolate.dart`、`utils/canonical_json.dart` | 并发限流 / 大 JSON isolate / 规范化 JSON |
| TvKeys / HomeRailMetrics / SpotlightInteractionPolicy | `utils/tv_keys.dart`、`utils/home_rail_metrics.dart`、`utils/spotlight_interaction_policy.dart` | TV 遥控器/行高/焦点规则 |

### L1 — UI 零件（纯展示，60+）

| 类别 | 代表文件 |
|---|---|
| 骨架/加载 | `widgets/shimmer.dart`、`widgets/skeleton_poster.dart`、`widgets/animated_background.dart`、`widgets/recoverable_network_image.dart` |
| Badge/标签 | `widgets/format_badge.dart`、`widgets/stream_badge_strip.dart`、`widgets/addon_identity.dart` |
| 列表/网格卡片 | `widgets/horizontal_playlist_row.dart`、`widgets/playlist_grid_card.dart`、`widgets/episode_tile.dart`、`widgets/torrent_result_row.dart`、`widgets/source_row.dart` |
| 输入/选择 | `widgets/text_field_suggestions.dart`、`widgets/tv_text_field.dart`、`widgets/tv_keyboard.dart` |
| 设置页模板 | `screens/settings/widgets/settings_widgets.dart`（SettingsPageScaffold / Section / ToggleTile / Tile / Header） |
| 桌面/TV 增强 | `widgets/horizontal_mouse_wheel.dart`、`widgets/window_drag_area.dart`、`widgets/tv_ambient_art_stage.dart`、`widgets/hero_trailer_backdrop.dart` |

### L2 — 功能组件（UI+逻辑，独立可运行，40+）

| 类别 | 代表 |
|---|---|
| 播放器交互 | 手势控制器、双击快进退、字幕/音轨/倍速选择器、锁屏、SkipSegment、Resume、Next Episode、D-pad 状态机 |
| 下载/进度 | `widgets/file_progress_bar.dart`、`widgets/bulk_add_progress_dialog.dart` |
| 选择器对话框 | `widgets/add_source_picker_dialog.dart`、`widgets/channel_picker_dialog.dart`、`widgets/file_selection_dialog.dart`、`widgets/provider_picker_dialog.dart` |
| App 系统能力 | `services/update_service.dart`、`services/diagnostic_log.dart`、`services/app_migration_service.dart`、`services/deep_link_service.dart`、`widgets/app_initializer.dart`、`widgets/initial_setup_flow.dart` |
| 导航壳 | `widgets/{mobile_floating_nav,mobile_classic_nav,desktop_sidebar_nav,desktop_pill_nav,tv_sidebar_nav}.dart`、`services/main_page_bridge.dart` |

### L3 — 业务模块 = 18 个 kit（见第 2 节 K01-K18）

### L4 — 子系统/壳（app 级组装，5 个）

| 子系统 | 组成 | 干啥 |
|---|---|---|
| App 启动管线 | AppInitializer + SecretVault.warm + ProfileScope.warm + DeepLink preflight + LaunchIdent | 冷启动 2 秒进首页 |
| 主页 Rail 系统 | DiscoveryBoard + HomeReturnCache + HomeListRows + HomeRowOrder + SpotlightBoard | 多行业务聚合 + 5 分钟返回缓存 |
| 设置系统 | SettingsPageScaffold + 72 子页面 + Profile/Device 双写 | 按 profile 隔离 + 跨 profile 6 个 key |
| 播放器完整管线 | VideoPlayerLauncher → PlayerBackend(libmpv/ExoPlayer/External) → 手势+字幕+音轨+倍速+Skip+Resume+Next | 点播放到出画面 |
| 媒体源聚合管线 | TorrentService.searchAllEngines → YAMLEngine+Torznab → AggregateDedup → SourceQuality 排序 → DebridProvider 解析 → playBest → VideoPlayerLauncher | 从搜索到播放 |

> **依赖方向**：`L4 子系统 → L3 kit → L2 组件 → L1 零件 → L0 工具`（`[C]` 23 号图谱依赖图）。

---

## 4. 测试地图（test/，609 文件 / 184,972 行）

> 数据 `[C]` 28-A2-测试基线盘点。CI **完全不跑测试**（`.github/workflows/build.yml` grep `flutter test` 零命中）。

### 4.1 子目录分组

| 目录 | 文件数 | 行数 | 主要覆盖 |
|---|---|---|---|
| `test/services/` | 65 | 38,819 | 核心服务逻辑（96.9% 纯 Unit） |
| `test/profiles/` | 79 | 29,951 | 用户配置/多 profile 切换 |
| `test/theme/` | 25 | 6,466 | 主题/颜色渲染 |
| `test/onboarding/` | 11 | 2,707 | 引导/初始化流程 |
| `test/widgets/` | 5 | 2,380 | 通用 UI 组件（全 testWidgets） |
| `test/launch_animation/` | 8 | 1,300 | 开屏动画 |

### 4.2 根目录主题前缀分组（节选）

| 前缀 | 文件数 | 行数 | 覆盖 |
|---|---|---|---|
| `webdav_*` | 53 | 35,741 | WebDAV 同步/备份（100% Unit） |
| `iptv_*` | 41 | 15,568 | IPTV/EPG/频道 |
| `home_*` | 21 | 5,851 | 首页布局/续看 |
| `remote_*` | 16 | 4,572 | 远程控制/设备配对 |
| `settings_*` | 26 | 4,353 | 设置页/偏好 |
| `metadata_*` | 23 | 3,820 | 元数据/TMDB/Trakt |
| `stremio_*` / `trakt_*` / `subtitle_*` / `player_*` / `backup_*` / `download_*` | 各 5-13 | — | 对应业务域 |

### 4.3 Unit vs Widget

- Widget 测试（含 `testWidgets`）：**223 文件（36.6%）**；纯 Unit：**386 文件（63.4%）**（`[C]` 28-A2）。
- **模板回归建议保留核心子集**（`[C]` 28-A2 5.2）：`test/services/` + `webdav_*` + `test/profiles/`(Unit) + `episode_*`+`player_*` + `metadata_*`+`trakt_*` ≈ 228 文件 / ~10.6 万行（57.4%）。
- **改名注意**：`test/` 可能写死 `"Debrify"` 断言（`[U]` 25-A1 第 5 节），改名后跑 `flutter test` 统一修。

---

## 5. 模板化入口速查

| 你要做什么 | 先看哪份文档 |
|---|---|
| **改名前**：有哪些品牌硬编码要换 | `debrify-analysis/25-A1-品牌替换清单.md`（12 包名 / 16 显示名 / 27 通道名 / scheme / Keychain / App Group / 广播 action / 通知组 / 图标路径） |
| **改名工具用法** | 本仓库 `TEMPLATE.md` 第 2 节 + `tool/rename_brand.dart --help` |
| **裁剪看什么**：原生层职责、依赖树 | `debrify-analysis/26-A3-android原生层职责清单.md`、`debrify-analysis/29-A5-依赖树治理.md` |
| **裁剪工具用法** | `TEMPLATE.md` 第 3 节 + `tool/prune_platforms.sh --help` |
| **编译/发布看什么** | `debrify-analysis/27-A4-CI发布链路.md`（7 job CI 矩阵、secret 全集、JDK 17/21 切换、media_kit 编 libmpv） |
| **可复用能力有哪些** | `debrify-analysis/00-可复用能力脑图.md` + `23-可复用能力完整图谱L0-L4.md` + `02-19` 号 18 kit 详解 |
| **编译基线是否健康** | `debrify-analysis/31-模板验证报告.md`（flutter analyze / pub get 基线） |
| **改名工具是否覆盖全** | `debrify-analysis/30-rename-自测报告.md` |

---

## 6. God Class 警告（模板照抄前须知，`[C]` 23 号图谱）

| 文件 | 行数 | 建议 |
|---|---|---|
| `screens/search_screen.dart` | 20,865 | 主页 god，按 L4 重组 |
| `screens/video_player_screen.dart` | 18,063 | 播放器 UI god，按 L2/L3 拆 |
| `services/storage_service.dart` | 10,728 | 只按域拆 L0 Prefs |
| `screens/settings_screen.dart` | 8,828 | 设置入口，按 L1 模板重写 |
| `services/profile_registry.dart` | 6,919 | 抽 L3 K05 facade |
| `services/webdav_sync_engine.dart` | 4,700 | 抽 L3 K07 合并算法 |
| `services/download_service.dart` | 4,672 | 抽 L2 接口不抽实现 |

> 本模板阶段**不拆**（功能 100% 一致是硬约束）；这些行号是后续独立重构任务的靶点。
