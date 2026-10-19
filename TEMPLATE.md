# TEMPLATE.md — Debrify 自用模板框架说明

> 本文件是**模板视角**的使用手册，不是源码文档。
> 源码地图见同目录 `CODEMAP-TEMPLATE.md`。
> 证据标记：**[C]** confirmed（直接读到/ls 命中）/ **[I]** inferred（由上下文推断）/ **[U]** unknown（未核实）。

---

## 0. 这份仓库是什么

这是 Debrify `0.10.0-beta.1+56`（`[C]` `pubspec.yaml` / git tag 对应版本）的**自用模板副本**：

- **源码 100% 复用、功能 100% 一致**——`lib/`、`android/`、`ios/`、`macos/`、`linux/`、`windows/`、`tvos/`、`web/`、`test/`、`packages/` 全部**零修改**。
- 你不改这份模板库本身，而是 **`cp -r` 一份副本**，在副本上跑改名工具，生成你自己的新 app。
- 模板库永远保持可编译的干净基线（`[C]` 当前分支 `template-framework`，git 历史完整）。

**硬约束（重申）**：本阶段不做功能改动、不做中文化/l10n、不删功能、不拆 god class、不重写架构。只做"模板化工程层"：改名 + 裁剪 + 编译 + 文档。

---

## 1. 模板架构（三层）

```
debrify/  (模板库，零修改)
├── 第一层：源码基线（零修改）
│   ├── lib/            Dart 业务源码（971 文件 / ~62.7 万行 [C] 00 脑图）
│   ├── android/ ios/ macos/ linux/ windows/ tvos/ web/   各平台宿主工程
│   ├── packages/       本地 patch 包（media_kit 系列等 [C] ls）
│   └── test/           609 个测试文件 / 184,972 行 [C] 28-A2
│
├── 第二层：模板工具链（tool/ 下新增）
│   ├── rename_brand.dart    一键改名（包名/显示名/通道名/scheme/Keychain…）
│   └── prune_platforms.sh   平台裁剪（删 tvos/web/discord 等非目标目录）
│
└── 第三层：模板文档（根目录 + 外部分析库）
    ├── TEMPLATE.md           本文件（架构 + 使用指南）
    ├── CODEMAP-TEMPLATE.md   模板视角代码地图（kit/组件速查）
    └── 外部分析库 ../debrify-analysis/（24+ 份 .md）
        ├── 00 脑图 / 02-19 号 18 个 kit 详解 / 23 号 L0-L4 图谱
        ├── 25-A1 品牌替换清单 / 27-A4 CI 链路 / 28-A2 测试基线 / 29-A5 依赖树
        └── 30 模板实施规划 / 31 验证报告 / 30-rename-自测报告
```

**为什么是三层而不是改源码**：改名不是改模板库，是在副本上生成新项目。模板库保持干净，改名工具可重复对任意副本使用。

---

## 2. 改名使用指南

### 2.1 标准流程（推荐在副本上操作）

```bash
# 1. 复制一份新工程（不要直接在模板库里改）
cp -r debrify myapp
cd myapp

# 2. 预览（默认 dry-run，只打印将替换什么，不动文件）
dart tool/rename_brand.dart --app-id com.mine.myapp --app-name MyApp --dry-run

# 3. 确认无误后执行（--apply 显式触发；执行前自动备份）
dart tool/rename_brand.dart --app-id com.mine.myapp --app-name MyApp --apply
```

> 工具接口按 `30-模板框架实施规划.md` 第 4 节规格编写。若 Agent A 落地时参数有微调，以实际 `dart tool/rename_brand.dart --help` 为准（主 agent 会校准）。

### 2.2 参数表

| 参数 | 说明 | 是否必填 |
|---|---|---|
| `--app-id <reverse.domain>` | 新 Android namespace / applicationId / iOS bundle id 前缀，如 `com.mine.myapp` | 必填 |
| `--app-name <Name>` | 新用户可见显示名，如 `MyApp` | 必填 |
| `--bundle-id-ios <id>` | 可选；不显式传则默认与 `--app-id` 相同 | 可选 |
| `--keep-tv-feature-names` | 显式保留 "Debrify TV" 功能名（**默认已自动识别，一般无需传**） | 可选 |
| `--dry-run` | 默认模式：只输出替换报告，不改任何文件 | 默认 |
| `--apply` | 显式执行替换（不带此参数一律 dry-run） | 执行时必传 |

### 2.3 工具覆盖的替换范围（对应 25-A1 清单）

工具内置规则覆盖 A1 全部条目（`[C]` 25-A1 全文）：

1. **Android 包名**：`com.debrify.app`（含 personal 分支 `com.debrify.app.personal`）→ gradle namespace/applicationId + Kotlin `package com.debrify.app` 声明（68 个 `.kt` 文件）+ Kotlin 物理目录移动 `com/debrify/app/` → 新路径。
2. **iOS/tvOS bundle id**：`com.varunsalian.debrify` / `com.varunsalian.debrifytv` → 新 id（含 debug/release/profile 三 target + TopShelf extension + RunnerTests）。
3. **模板残留一并修**：macOS `com.example.torrentSearchApp`、Linux `com.example.debrify`（Flutter 脚手架默认值从未改过，`[C]` A8/A11）。
4. **27 个 MethodChannel/EventChannel 通道名两端同步**：
   - 全路径前缀 `com.debrify.app/<feat>`（11 个，Android 主桥）；
   - 短前缀 `debrify/<feat>`（16 个，tvOS/辅助桥）；
   - **Dart 侧 `MethodChannel('...')` 与 Kotlin/Swift 原生侧逐字符同步替换**，避免运行时 `MissingPluginException`。
5. **URL scheme**：`debrify://` 五平台（AndroidManifest、iOS/macOS/tvOS Info.plist、Linux .desktop、Windows installer.iss、Dart 里 Reddit 回调 `debrify://reddit/callback`、远程控制 `debrify://file`）。
6. **系统级标识**：Keychain service `com.debrify.app.profile-device-secret`、tvOS App Group `group.com.varunsalian.debrifytv`、Android 广播 action（PIP / UPDATE_EPISODE_METADATA / 下载录制 action）、通知组 `com.debrify.app.downloads.GROUP` 等。
7. **显示名 / 二进制名**：Android resValue + strings.xml、iOS/tvOS `DEBRIFY_APP_DISPLAY_NAME`、web manifest/index.html title、Linux/windows 二进制名与 desktop 入口、pubspec Dart 包名 `debrify` → 新下划线小写名。
8. **外部可见串**：Jellyfin/Emby 客户端识别串 `Client="Debrify"`、磁盘下载文件夹 `debrify-torrents`。

### 2.4 白名单（不会被误改，重要）

工具内置白名单，以下**不替换**（`[C]` 25-A1 第 2 节）：

- **`"Debrify TV"`**——这是"收藏关键词频道"的**功能名/产品概念**，不是品牌；误改会破坏功能语义（`[C]` `search_screen.dart` 等）。
- **`debrify_tv_control_*` 资源 key**——Android strings.xml 里 10 个 TV 遥控器控制资源 key（如 rewind/forward 提示文案的 key），是内部命名，value 是通用英文，不含品牌。
- **`debrify-torrents` 之外的纯内部类名**（如 `DebrifyApplication`、`DebrifyTvPlayerStyle`）——`[I]` 工具默认不动 Kotlin/Swift 类名（改类名要同步 Manifest，风险高，留给手动）。
- **外部标准协议 `magnet://` / `stremio://`**——这是行业标准协议，不是品牌，**不改**（`[C]` D11）。

### 2.5 备份机制

- 执行 `--apply` 前，工具自动把将被修改的文件复制到 **`rename-backup-<时间戳>/`** 目录（与仓库根同级的工作区内）。
- 替换后在终端输出**统计**：每一类替换 N 处（包名 X 处 / 通道名 Y 处 / 显示名 Z 处 …）。
- 回滚：`cp -r rename-backup-<时间戳>/* .` 或直接删掉副本重来（因为你是在 `cp -r` 的副本上操作，最干净的回滚就是重新 `cp -r`）。

### 2.6 图标替换（手动，工具不自动换二进制资源）

工具只改文本标识符，**图标是二进制文件，需手动替换**（`[C]` 25-A1 1.F）：

| 平台 | 图标路径 |
|---|---|
| Android 启动图标 | `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher*` + `mipmap-anydpi-v26/` adaptive icon XML |
| Android TV 横幅 | `android/app/src/main/res/drawable*/banner_debrify.png`（4 密度；若改名建议改名为 `banner.png` 并同步 `AndroidManifest.xml` 的 `android:banner` 引用） |
| iOS | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` + `LaunchImage.imageset/` |
| tvOS | `tvos/Runner/Assets.xcassets/AppIcon.brandassets/` + `LaunchImage.launchimage/` |
| Web/PWA | `web/icons/Icon-192.png`、`Icon-512.png`、`Icon-maskable-192.png`、`Icon-maskable-512.png` |

> `ic_launcher` 是 Flutter 模板默认资源名，不含品牌，**可保留不改**（`[C]` F7）。

### 2.7 改名后必做检查（A1 第 3.3 节）

```bash
# 以下应返回 0（注释/文档除外）
git grep -n "com\.debrify\.app" -- '*.dart' '*.kt' '*.swift' '*.kts' '*.xml' '*.plist'
git grep -n "com\.varunsalian" -- '*.pbxproj' '*.xcconfig' '*.swift' '*.plist'
git grep -n "debrify://" -- '*.dart' '*.xml' '*.desktop' '*.iss'
git grep -n "package com\.debrify" -- '*.kt'
git grep -n "com\.example\.torrentSearchApp" -- '*.pbxproj' '*.xcconfig'   # macOS 残留应为 0
```

> **注意**：`test/` 里可能写死了 `"Debrify"` 断言，改名后跑 `flutter test` 统一修。Keychain/App Group 改名 = 老用户加密数据读不出（自用可接受，清空重装即可）。
>
> **改名收尾（必须执行）**：rename_brand v2+ 按设计不改 Dart 根级 `test/` 目录（A1 §5 排除），`--apply` 后 `flutter test` 会编译失败。在副本上手动批量替换：
>
> ```bash
> # 把 test/ 下的 package:debrify/ 导入改成新短名（MyApp → myapp）
> grep -rl "package:debrify/" test/ | xargs sed -i 's|package:debrify/|package:myapp/|g'
> # 校验：以下应返回 0
> grep -rn "package:debrify/" test/ | wc -l
> ```
>
> **根级/工具脚本导入也必须同步**（工具不扫根目录、`/tool/`、`/dev/`；漏改会让 `flutter test` 加载根级 `flutter_test_config.dart` 失败、dev/tool 脚本跑不起来）：
>
> ```bash
> # flutter_test_config.dart（根目录）、dev/、tool/（rename_brand.dart 本体除外）
> grep -rl "package:debrify/" flutter_test_config.dart dev/ tool/ --include="*.dart" \
>   | grep -v rename_brand | xargs sed -i 's|package:debrify/|package:myapp/|g'
> # 校验：以下应返回 0（rename_brand 的规则定义行保留属正常）
> grep -rn "package:debrify/" --include="*.dart" . | grep -v '/\.git/' | grep -v 'tool/rename_brand' | wc -l
> ```
>
> 短名派生规则：`MyApp` → 去非字母数字 → 全小写 → `myapp`（rename_brand 的 scheme/二进制名/短通道统一用它）。
>
> **v2/v3 行为说明（相对 v1 的修复）**：
> - **业务标识符不再替换**：代码文件（dart/kt/java/swift…）只改 3 个精确品牌模式（通道 `debrify/`、scheme `debrify://`、导入 `package:debrify/`），`\bdebrify\b` 独立词（枚举值、pref 存储值、JSON 值、`.debrify` 文件扩展名、第三方 API 参数如 Simkl app name、注释）**全部天然保留** → 功能一致天生成立，无需事后还原。配置/资源文本（yaml/plist/xml/json/desktop/iss…）才做全量品牌替换（pubspec name、CFBundleName、manifest name 等）。
> - **覆盖 .java 与 android/app/src/test/**:`_scanExt` 含 `.java`；根级 `test/` 仍排除，但 `android/app/src/test/kotlin` 原生测试会扫描（package 声明与路径断言自动改），且目录移动覆盖 main/kotlin + test/kotlin + main/java 三处。
> - **路径形式规则**：`com/debrify/app` → `com/<新包名>/app`（测试里写死的主源码路径断言自动同步）。

---

## 3. 平台裁剪指南

### 3.1 工具用法

```bash
# 预览将删除什么（默认 dry-run）
bash tool/prune_platforms.sh --dry-run

# 确认后执行
bash tool/prune_platforms.sh --apply
```

### 3.2 默认裁剪清单（列在文档里；裁剪工具只提供能力，模板默认不执行）

`prune_platforms.sh` 的默认删除候选（`[C]` 任务书指定 + 27-A4 第 4/5 节）：

| 路径 | 为什么可删 |
|---|---|
| `tvos/` | 若你不做 Apple TV；注意删后 `packages/media_kit_libs_tvos_video`、`path_provider_tvos_patched` 等 tvOS 专用 patch 包也无意义 |
| `web/` | 若你不做 PWA/Web |
| `dev/tool/discord/` | Discord 社区 bot + tracker repo + launchd triage，**与发布链路无任何引用**（`[C]` 27-A4 第 4 节：build.yml 零引用），自用模板无 Discord guild，整目录可删 |
| `dev/tool/iptv_fault_server.py` | 本地 IPTV 故障 mock 服务器，开发调试用 |
| `dev/tool/mock_xtream_server.py` | 本地 Xtream mock 服务器，开发调试用 |

### 3.3 可恢复说明

- 裁剪只是 `rm -rf` 工作区目录，**模板库源码在 git 里完整保留**。
- 恢复任意被删目录：`git checkout -- tvos/`（或对应路径）。
- 裁剪后若编译报缺依赖，先看 `29-A5-依赖树治理.md` 与 `packages/` 里哪个 patch 包被该平台引用。

> **[I] 提醒**：删 `tvos/` 前确认你不用 `flutter-tvos` fork 构建（27-A4 第 1.1 节 tvOS job 依赖外部 fork `fluttertv/flutter-tvos`，pin 了 SHA）。删平台目录比删代码安全，但跨平台 import 可能残留，编译期会暴露。

---

## 4. 编译指南

### 4.1 通用前提

- **Flutter SDK**：CI 用 **3.44.8**（`[C]` 27-A4 build.yml；README badge 标 "Flutter 3.8+" 为最低线，自用建议对齐 3.44.8 避免 media_kit patch 包不兼容）。
- 首次：`flutter pub get`（拉主项目依赖 + 本地 patch 包 `packages/`）。
- **子包需各自 bootstrap**：`packages/` 下 9 个子包（media_kit_patched、media_kit_video_patched、media_kit_libs_*_patched、sqflite_android_patched、flutter_cache_manager_patched、path_provider_tvos_patched 等）是独立 package，**不随主项目 pub get 解析**，首次或在 `packages/` 有改动后需逐个执行 `flutter pub get`（`[C]` 30 号验证报告 C 段）。
- 编译期需要 **TMDB token**：CI 用 `--dart-define-from-file` 注入 `TMDB_READ_ACCESS_TOKEN`（`[C]` 27-A4 1.2 节，全部 7 个 job 都用）。自用不接 TMDB 可整段删注入逻辑。

### 4.2 各平台依赖与命令

| 平台 | 系统/工具链 | 构建命令 | 特殊点 |
|---|---|---|---|
| **Android** | JDK 17/21（见下）+ Android Studio/Android SDK | `flutter build apk --release`（或 `assembleDebug`） | **media_kit PGS 字幕需切 JDK 17 跑 `build_android_media_kit_libraries.sh` 编 libmpv，再切回 JDK 21**（`[C]` 27-A4 1.1 android job）；签名用 `android/key.properties` + keystore（debug 装可跳过） |
| **iOS** | macOS + Xcode | `flutter build ios --release --no-codesign` | 产物 unsigned，走 ad-hoc 签名侧载（AltStore/Sideloadly），不上架 App Store（`[C]` 27-A4 1.3） |
| **macOS** | macOS + Xcode + Nix（装 pinned libmpv） | `flutter build macos --release` | media_kit macOS 需 `build_macos_media_kit_frameworks.sh` 编 framework；DMG 用 `create-dmg`（`[C]` 27-A4 macos job） |
| **tvOS** | macOS + 外部 fork `fluttertv/flutter-tvos`（pin SHA `0e32f18…`） | `flutter-tvos build tvos --release` | **不用官方 Flutter**，用 fork；首次 `flutter-tvos precache` 拉 ~1GB tvOS engine + `packages/media_kit_libs_tvos_video/fetch_frameworks.sh` 拉 ~830MB xcframeworks（`[C]` 27-A4 tvos job） |
| **Windows** | Windows 10/11 + Inno Setup（ISCC） | `flutter build windows --release` → `ISCC windows\installer.iss` 打 setup.exe | installer.iss 注入 `DEBRIFY_VERSION`（`[C]` 27-A4 windows job） |
| **Linux** | Ubuntu 22.04（glibc 2.35 floor）+ Docker + apt 依赖 | `flutter build linux --release` | **media_kit 在 Linux 不带 libmpv，必须自己编**：docker 内 `build_linux_libmpv.sh`（meson）+ `bundle_linux_mpv.sh` 塞进 bundle；AppImage 用 appimagetool（`[C]` 27-A4 linux job） |

### 4.3 运行时依赖（Linux 分发用户需装）

`[C]` README "Linux" 节：

```bash
# Debian/Ubuntu
sudo apt install libmpv2 libsqlite3-dev libfuse2      # 老发行版用 libmpv1
# Fedora
sudo dnf install mpv-libs sqlite-devel fuse-libs
```

### 4.4 media_kit 需要"现场编二进制"的特殊性（重点）

`[C]` 27-A4 + 23 号图谱标注：media_kit（libmpv）在 **Android / macOS / Linux / tvOS** 四个平台都不带预编译 libmpv，必须用仓库里的 `dev/scripts/build_*_media_kit*.sh` / `build_linux_libmpv.sh` 在本机现编。这是"功能 100% 一致"里最折腾的一块——它是核心功能（PGS 字幕、libmpv 播放）的二进制补丁，与品牌无关，**不能随裁剪删掉**。Windows 走 `packages/media_kit_libs_windows`（若存在），CI 未单独编。

### 4.5 本地脚本（不进 CI，自用可参考）

- `tool/build_personal.sh <platform> [Debug|Release]`——"第二安装身份"构建，让你和正式版并存（参数化 `DEBRIFY_BUNDLE_SUFFIX`/`DEBRIFY_APP_DISPLAY_NAME`，改个名就能复用，`[C]` 27-A4 3.3）。
- `dev/scripts/build_ipa.sh`——iOS 侧载 IPA 本地打包（mirror CI 的 ad-hoc 签名段）。
- `docs/PERSONAL_BUILD.md`——personal 构建官方说明与 bundle id 对照表。

---

## 5. 扩展指南索引

> 以下文件已 `ls` 核查存在性（`[C]` 2026-10-19）。存在的列出用途；路径待确认的标注。

### 5.1 核心扩展入口（你点名的三个，全部存在）

| 文档 | 用途 | 状态 |
|---|---|---|
| `dev/design/ADDING_A_PROVIDER.md` | 如何新增一个 debrid / 云存储 provider（对接 K10 DebridProviderKit） | ✅ 存在 [C] |
| `docs/engines/creating-custom-engines.md` | 如何写自定义搜索 engine（YAML/脚本引擎，对接 K17 SearchEngineKit） | ✅ 存在 [C] |
| `dev/launch_animations/CREATOR_GUIDE.md` | 如何做新的开屏启动动画（LaunchIdent painter，对接 K01） | ✅ 存在 [C] |

### 5.2 其它扩展/架构文档（`ls` glob 命中，按需）

| 文档 | 一句话用途 |
|---|---|
| `docs/PERSONAL_BUILD.md` | personal 第二安装构建说明 + bundle id 对照表 |
| `docs/metadata-provider-implementation.md` | 元数据 provider 实现指南（K18） |
| `docs/stremio/building-local-catalogs.md` | 本地构建 Stremio catalog（K12） |
| `docs/architecture/profile-*.md` | Profile 存储归属/备份覆盖/威胁模型（K05/K06） |
| `docs/architecture/webdav-*.md` | WebDAV 同步性能/人工门禁（K07） |
| `docs/media-servers.md` | Emby/Jellyfin 媒体服务器对接（K03） |
| `docs/stream-badges.md` | 流徽章外观定制 |
| `docs/tv-performance-*.md` | TV 端性能研究/渐进加载（K09/K13） |
| `dev/design/plans/*.md` | 60+ 份历史设计计划（IPTV、播放器、主题、profiles 等），看历史决策用 |
| `dev/design/mockups/*/README.md` | 16 组 UI mockup 说明 |
| `dev/launch_animations/VERIFICATION.md` | 开屏动画验证流程 |

> **路径待确认**：无。点名的三个扩展文档全部命中；上表其它文档均为 `find` 实测存在。

---

## 6. 自用说明（定位）

- **本模板不公开发布**：不做上架合规、不做 Google Play/App Store 元数据、不做签名证书管理（自用走 debug 装或自签）。
- **不改功能**：源码零修改，功能 100% 与 Debrify 原版一致。本阶段不拆 god class（`search_screen.dart` 20865 行、`video_player_screen.dart` 18063 行等，`[C]` 23 号图谱"God Class 警告"），拆分留给后续独立任务。
- **仅自用改名**：模板的唯一用途是"复制一份 → 改名 → 换成自己的图标 → 编译自用"。
- **AGPL 提醒**：Debrify 是 AGPL-3.0-only（`[C]` README License 节）。自用内部分发不触发开源义务；若对外发布修改版，需遵守 AGPL 对应源码要求。
- **源码零修改原则重申**：除 `tool/rename_brand.dart`、`tool/prune_platforms.sh`、本文件、`CODEMAP-TEMPLATE.md` 外，不新增/修改任何 `lib/ android/ ios/ …` 下文件。如发现必须改源码才能完成的事，停下报告，不要擅自动源码。

---

## 7. 快速开始（TL;DR）

```bash
cp -r debrify myapp && cd myapp
dart tool/rename_brand.dart --app-id com.mine.myapp --app-name MyApp --dry-run
dart tool/rename_brand.dart --app-id com.mine.myapp --app-name MyApp --apply
# 手动换图标（见 2.6）；按需 bash tool/prune_platforms.sh --apply
flutter pub get && flutter run
```
