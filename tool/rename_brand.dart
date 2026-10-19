#!/usr/bin/env dart
// =============================================================================
// rename_brand.dart — Debrify 模板一键改名工具（模板框架 · Agent A 交付物 1）
//
// 设计依据：debrify-analysis/30-模板框架实施规划.md 第 4 节 + 25-A1-品牌替换清单.md
//
// 用法（务必在 cp -r 出的副本上操作，不要在模板库本体上 --apply）：
//   dart tool/rename_brand.dart --app-id com.mine.app --app-name MyApp --dry-run   # 默认，只预览
//   dart tool/rename_brand.dart --app-id com.mine.app --app-name MyApp --apply     # 真执行
//   可选：--bundle-id-ios com.mine.ios（缺省=--app-id）
//         --keep-tv-feature-names（默认即保护 "Debrify TV"，此参数仅显式声明）
//
// 核心原则（与 30 号规划一致）：
//   1. 默认 --dry-run，--apply 必须显式给出；
//   2. --apply 前把所有将被改的文件备份到 rename-backup-<时间戳>/（保留相对路径）；
//   3. 采用"精确替换映射表"（旧串→新串逐条匹配），不做模糊子串 sed；
//   4. 白名单显式列出不替换的标识符，并在统计里单列命中次数；
//   5. 长串先于短串替换（com.varunsalian.debrifytv → com.varunsalian.debrify
//      → com.debrify.app.personal → com.debrify.app → com.example.*）。
// =============================================================================

import 'dart:io';

// ---------------------------------------------------------------------------
// 命令行参数
// ---------------------------------------------------------------------------
class Args {
  final String appId; // 如 com.example.myapp
  final String appName; // 如 MyApp（显示名，PascalCase）
  final String bundleIdIos; // iOS/macOS bundle id（缺省=appId）
  final bool apply; // false=dry-run（默认）
  final bool keepTvFeatureNames; // 仅显式声明，默认即保护
  final String repoRoot;

  Args._({
    required this.appId,
    required this.appName,
    required this.bundleIdIos,
    required this.apply,
    required this.keepTvFeatureNames,
    required this.repoRoot,
  });

  static Args parse(List&lt;String&gt; argv) {
    String? appId;
    String? appName;
    String? bundleIdIos;
    bool apply = false;
    bool keepTv = false;
    String? root;
    for (var i = 0; i &lt; argv.length; i++) {
      final a = argv[i];
      if (a == '--apply') {
        apply = true;
      } else if (a == '--dry-run') {
        apply = false;
      } else if (a == '--keep-tv-feature-names') {
        keepTv = true;
      } else if (a.startsWith('--app-id=')) {
        appId = a.substring('--app-id='.length);
      } else if (a.startsWith('--app-name=')) {
        appName = a.substring('--app-name='.length);
      } else if (a.startsWith('--bundle-id-ios=')) {
        bundleIdIos = a.substring('--bundle-id-ios='.length);
      } else if (a == '--app-id') {
        appId = argv[++i];
      } else if (a == '--app-name') {
        appName = argv[++i];
      } else if (a == '--bundle-id-ios') {
        bundleIdIos = argv[++i];
      } else if (a.startsWith('--root=')) {
        root = a.substring('--root='.length);
      } else {
        stderr.writeln('[参数错误] 未知参数：$a');
        exit(2);
      }
    }
    if (appId == null || appId.isEmpty) {
      stderr.writeln('[参数错误] 必须提供 --app-id（如 com.example.myapp）');
      exit(2);
    }
    if (appName == null || appName.isEmpty) {
      stderr.writeln('[参数错误] 必须提供 --app-name（如 MyApp）');
      exit(2);
    }
    root ??= Directory.current.path;
    return Args._(
      appId: appId,
      appName: appName,
      bundleIdIos: bundleIdIos ?? appId,
      apply: apply,
      keepTvFeatureNames: keepTv,
      repoRoot: root,
    );
  }
}

// ---------------------------------------------------------------------------
// 替换规则：一条 = 旧串 → 新串（literal 精确替换），按顺序执行
// ---------------------------------------------------------------------------
class Rule {
  final String old;
  final String replacement;
  final String category; // 统计分类
  Rule(this.old, this.replacement, this.category);
}

// 扫描范围：这些目录下的文本文件才参与替换
final Set&lt;String&gt; _scanDirs = {
  'lib',
  'android',
  'ios',
  'macos',
  'tvos',
  'linux',
  'windows',
  'web',
  'packages',
};

// 扫描的文件扩展名（文本文件）
final Set&lt;String&gt; _scanExt = {
  '.dart',
  '.kt',
  '.kts',
  '.java',
  '.swift',
  '.m',
  '.h',
  '.xml',
  '.plist',
  '.pbxproj',
  '.xcconfig',
  '.cmake',
  '.txt',
  '.desktop',
  '.cc',
  '.c',
  '.iss',
  '.html',
  '.json',
  '.yaml',
  '.yml',
  '.rc',
  '.gradle',
};

// 显式排除的路径片段（文档/测试/构建产物/二进制资源/本工具目录本身）
final Set&lt;String&gt; _excludeSegments = {
  '/.git/',
  '/docs/',
  '/dev/',
  '/.claude/',
  '/.github/',
  '/tool/', // 本工具所在目录，避免自我引用
  '/.dart_tool/',
  '/build/',
  '/assets/',
  '/.idea/',
};

final Set&lt;String&gt; _excludeExt = {
  '.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.icns', '.car',
  '.otf', '.ttf', '.woff', '.woff2', '.mp4', '.webm', '.mp3', '.wav',
  '.pdf', '.zip', '.tar', '.gz', '.so', '.dll', '.dylib', '.a',
};

// ---------------------------------------------------------------------------
// 白名单：命中即"保护不替换"，并在统计里单列
// 说明：
//  - "Debrify TV" / "Debrify Player" 是功能/产品概念名，不是品牌（A1 §0/§2）；
//  - debrify_tv_* 资源 key / pref key 由词边界 \bdebrify\b 天然保护（下划线是词字符），
//    这里仍显式登记以便报告"命中保护"；
//  - banner_debrify 是 drawable 资源引用，改文件名需同步 Manifest，留给手动（A1 F2）；
//  - varunsalian/debrify、r/debrify 是指向开源上游的外部链接，不作为 app 身份替换。
// ---------------------------------------------------------------------------
final List&lt;({String pattern, String reason})&gt; whitelist = [
  (pattern: 'Debrify TV', reason: '功能名/产品概念（收藏频道行），非品牌'),
  (pattern: 'Debrify Player', reason: '外部播放器模式概念名，注释/功能语义'),
  (pattern: 'debrify_tv_', reason: 'Android 资源 key / pref key（内部名，值不含品牌）'),
  (pattern: 'banner_debrify', reason: 'drawable 资源引用，改名需同步 AndroidManifest，留手动'),
  (pattern: 'varunsalian/debrify', reason: '指向上游 GitHub 仓库的外部 URL'),
  (pattern: 'reddit.com/r/debrify', reason: '指向上游 subreddit 的外部 URL'),
];

bool _isScannable(String absPath, String root) {
  final rel = absPath.substring(root.length);
  if (rel.startsWith('/test/')) return false; // 仅根级 Dart test/ 排除（A1 §5：留 flutter test 统一修）
  if (_excludeSegments.any((s) =&gt; rel.contains(s))) return false;
  final lower = absPath.toLowerCase();
  if (_excludeExt.any((e) =&gt; lower.endsWith(e))) return false;
  final dotIdx = lower.lastIndexOf('.');
  if (dotIdx &lt; 0) return false;
  final ext = lower.substring(dotIdx);
  if (!_scanExt.contains(ext)) return false;
  // 根目录的 pubspec.yaml 单独放行（不在 _scanDirs 内）
  return true;
}

List&lt;File&gt; _collectFiles(String root) {
  final out = &lt;File&gt;[];
  // 1) 扫描目录
  for (final d in _scanDirs) {
    final dir = Directory('$root/$d');
    if (!dir.existsSync()) continue;
    dir
        .listSync(recursive: true, followLinks: false)
        .whereType&lt;File&gt;()
        .where((f) =&gt; _isScannable(f.path, root))
        .forEach(out.add);
  }
  // 2) 根目录关键文件
  for (final name in ['pubspec.yaml']) {
    final f = File('$root/$name');
    if (f.existsSync()) out.add(f);
  }
  return out;
}

// ---------------------------------------------------------------------------
// 主逻辑
// ---------------------------------------------------------------------------
Future&lt;void&gt; main(List&lt;String&gt; argv) async {
  final args = Args.parse(argv);
  final root = args.repoRoot;

  // 派生新值
  final appId = args.appId;
  final appName = args.appName;
  final bundleIos = args.bundleIdIos;
  final bundleTvos = '${bundleIos}tv';
  // 短名：小写、仅保留字母数字（用于 scheme / CFBundleName / 二进制名 / Dart 包名 /
  // package: 导入 / 短通道前缀 debrify/&lt;feat&gt;）
  final shortName = appName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (shortName.isEmpty) {
    stderr.writeln('[参数错误] --app-name 无法派生出合法短名（需含字母数字）');
    exit(2);
  }

  stdout.writeln('==============================================================');
  stdout.writeln(' Debrify 模板改名工具  |  模式：${args.apply ? "APPLY（执行）" : "DRY-RUN（预览，不写盘）"}');
  stdout.writeln(' 仓库根目录：$root');
  stdout.writeln('   app-id(Android/Linux/AppStream) = $appId');
  stdout.writeln('   iOS/macOS bundle id             = $bundleIos');
  stdout.writeln('   tvOS bundle id                  = $bundleTvos');
  stdout.writeln('   显示名 app-name                 = $appName');
  stdout.writeln('   短名 shortName(scheme/包名)     = $shortName');
  stdout.writeln('==============================================================');

  // ---- 构造有序替换规则（长串优先）---------------------------------------
  final rules = &lt;Rule&gt;[
    // 第 1 组：系统身份（包名 / bundle id）
    Rule('com.varunsalian.debrifytv', bundleTvos, 'pkg-bundle/tvOS'),
    Rule('com.varunsalian.debrify', bundleIos, 'pkg-bundle/iOS'),
    Rule('com.debrify.app.personal', '$appId.personal', 'pkg-bundle/Android-personal'),
    Rule('com.debrify.app', appId, 'pkg-bundle/Android(含通道/Keychain/广播/通知组/ComponentName)'),
    Rule('com.example.torrentSearchApp', appId, 'pkg-bundle/macOS·iOS模板残留'),
    Rule('com.example.debrify', appId, 'pkg-bundle/Linux'),
    Rule('com/debrify/app', appId.split('.').join('/'), 'pkg-bundle/路径形式(测试断言/字符串路径)'),
  ];
  // 注意：小写 token 与大写显示名用正则在每条规则后单独处理（见 _applyToContent）。

  // ---- 收集文件 ----------------------------------------------------------
  final files = _collectFiles(root);
  stdout.writeln('[扫描] 命中 ${files.length} 个可处理文本文件');

  // ---- 白名单命中计数 ----------------------------------------------------
  final whitelistHits = &lt;String, int&gt;{};

  // ---- 逐文件处理 --------------------------------------------------------
  final ruleCounts = &lt;String, int&gt;{}; // category -&gt; 总替换次数
  int filesTouched = 0;
  final backupDir = 'rename-backup-${DateTime.now().millisecondsSinceEpoch}';
  final changedRelPaths = &lt;String&gt;[];

  for (final f in files) {
    final rel = f.path.substring(root.length + 1);
    String content;
    try {
      content = await f.readAsString();
    } catch (_) {
      continue; // 非 UTF-8 跳过
    }
    final original = content;

    // (a) 白名单掩码：把受保护片段换成占位符，避免被后续规则误伤
    // 占位符定宽 3 位（WL000/WL042…）：还原 replaceAll 按整串匹配，
    // 避免 'WL4' 前缀误伤 'WL42' 等两位数字占位符（文件内白名单命中 &gt;10 次时触发）。
    final mask = &lt;String, String&gt;{}; // placeholder -&gt; 原文
    var masked = content;
    for (final w in whitelist) {
      var count = 0;
      while (masked.contains(w.pattern)) {
        count++;
        final ph = 'WL${mask.length.toString().padLeft(3, '0')}';
        mask[ph] = w.pattern;
        masked = masked.replaceFirst(w.pattern, ph);
      }
      if (count &gt; 0) {
        whitelistHits[w.pattern] = (whitelistHits[w.pattern] ?? 0) + count;
      }
    }

    // (b) 有序 literal 替换
    for (final r in rules) {
      if (!masked.contains(r.old)) continue;
      final hits = r.old.allMatches(masked).length;
      if (hits == 0) continue;
      masked = masked.replaceAll(r.old, r.replacement);
      ruleCounts[r.category] = (ruleCounts[r.category] ?? 0) + hits;
    }

    // (c) 品牌 token（保守策略，v2）：
    //   - 代码文件（.dart/.kt/.kts/.java/.swift/.m/.h）：只改 3 个精确品牌模式
    //     （通道前缀 debrify/、scheme debrify://、Dart 导入 package:debrify/），
    //     绝不碰 \bdebrify\b 独立词——枚举值/pref 存储值/JSON 值/文件扩展名/
    //     第三方 API 参数/注释里的业务标识符全部天然保留，功能一致天生成立。
    //   - 配置/资源文本（yaml/plist/xml/json/desktop/iss/cmake/gradle/rc/txt/html…）：
    //     \bdebrify\b → shortName（pubspec name、CFBundleName、manifest name、
    //     desktop Exec、web title、installer 标识等品牌字段）。
    final relLower = rel.toLowerCase();
    final isCodeFile = relLower.endsWith('.dart') ||
        relLower.endsWith('.kt') ||
        relLower.endsWith('.kts') ||
        relLower.endsWith('.java') ||
        relLower.endsWith('.swift') ||
        relLower.endsWith('.m') ||
        relLower.endsWith('.h');
    if (isCodeFile) {
      // 精确品牌模式：debrify:// → medianest://、debrify/ → medianest/、
      // package:debrify/ → package:medianest/（幂等，顺序无碍）
      final pats = [
        ('debrify://', '$shortName://'),
        ('debrify/', '$shortName/'),
        ('package:debrify/', 'package:$shortName/'),
      ];
      for (final (old, neu) in pats) {
        if (!masked.contains(old)) continue;
        final hits = old.allMatches(masked).length;
        masked = masked.replaceAll(old, neu);
        ruleCounts['short-token(通道/scheme/包导入)'] =
            (ruleCounts['short-token(通道/scheme/包导入)'] ?? 0) + hits;
      }
    } else {
      final lowerRe = RegExp(r'\bdebrify\b');
      final lowerHits = lowerRe.allMatches(masked).length;
      if (lowerHits &gt; 0) {
        masked = masked.replaceAll(lowerRe, shortName);
        ruleCounts['short-token(配置品牌字段)'] =
            (ruleCounts['short-token(配置品牌字段)'] ?? 0) + lowerHits;
      }
    }

    // (d) 大写显示名：\bDebrify\b → appName（白名单已掩码 "Debrify TV" 等）
    final dispRe = RegExp(r'\bDebrify\b');
    final dispHits = dispRe.allMatches(masked).length;
    if (dispHits &gt; 0) {
      masked = masked.replaceAll(dispRe, appName);
      ruleCounts['display-name(显示名/外部识别串)'] =
          (ruleCounts['display-name(显示名/外部识别串)'] ?? 0) + dispHits;
    }

    // (e) 还原白名单占位符
    mask.forEach((ph, orig) {
      masked = masked.replaceAll(ph, orig);
    });

    if (masked != original) {
      filesTouched++;
      changedRelPaths.add(rel);
      if (args.apply) {
        // 备份（保留相对路径）
        final bf = File('$root/$backupDir/$rel');
        await bf.parent.create(recursive: true);
        await bf.writeAsString(original);
        await f.writeAsString(masked);
      }
    }
  }

  // ---- 源包目录移动（package 声明已随 rule 改，物理目录需对齐）----------
  // 覆盖 main/kotlin、test/kotlin、main/java 三处（Java 残留是 v1 漏扫教训）
  final movePlans = &lt;(String, String)&gt;[
    ('android/app/src/main/kotlin', 'kotlin 主源'),
    ('android/app/src/test/kotlin', 'kotlin 测试'),
    ('android/app/src/main/java', 'java 主源'),
  ];
  final newPkgRel = appId.split('.').join('/'); // com/example/myapp
  final plannedMoves = &lt;(String, String)&gt;[];
  for (final (rel, _) in movePlans) {
    final oldPkgDir = '$root/$rel/com/debrify/app';
    if (Directory(oldPkgDir).existsSync()) {
      plannedMoves.add((oldPkgDir, '$root/$rel/$newPkgRel'));
    }
  }

  // ---- 输出统计 ----------------------------------------------------------
  stdout.writeln('');
  stdout.writeln('---------------- 替换统计（按类别） ----------------');
  if (ruleCounts.isEmpty) {
    stdout.writeln('  （无替换命中）');
  } else {
    final total = ruleCounts.values.fold&lt;int&gt;(0, (a, b) =&gt; a + b);
    ruleCounts.forEach((k, v) =&gt; stdout.writeln('  ${v.toString().padLeft(5)} 处  $k'));
    stdout.writeln('  ----------------------------------------');
    stdout.writeln('  ${total.toString().padLeft(5)} 处  合计字符串替换');
  }
  stdout.writeln('');
  stdout.writeln('  扫描文件：${files.length}   将改动文件：$filesTouched');

  stdout.writeln('');
  stdout.writeln('---------------- 白名单保护（不替换） ----------------');
  if (whitelistHits.isEmpty) {
    stdout.writeln('  （本仓库未命中受保护片段）');
  } else {
    whitelistHits.forEach((k, v) =&gt; stdout.writeln('  保护 $v 处  "$k"'));
  }

  stdout.writeln('');
  stdout.writeln('---------------- 源包目录对齐 ----------------');
  if (plannedMoves.isEmpty) {
    stdout.writeln('  （未发现 com/debrify/app 源包目录，跳过目录移动）');
  } else {
    for (final (oldDir, newDir) in plannedMoves) {
      stdout.writeln('  ${args.apply ? "执行" : "预览"}：移动目录');
      stdout.writeln('    旧：$oldDir');
      stdout.writeln('    新：$newDir');
      if (args.apply) {
        if (Directory(newDir).existsSync()) {
          // 目标已存在（残留/重复 apply）：先移除目标再移动，避免 rename 崩溃
          await Directory(newDir).delete(recursive: true);
        }
        await Directory(newDir).parent.create(recursive: true);
        await Directory(oldDir).rename(newDir);
        // 清理空的 com/debrify 父目录
        final debrifyParent = Directory('$root/android/app/src/main/kotlin/com/debrify');
        if (debrifyParent.existsSync() &amp;&amp; debrifyParent.listSync().isEmpty) {
          await debrifyParent.delete();
        }
      }
    }
    stdout.writeln('  （package 声明已随 pkg-bundle 规则改写；目录移动使包路径与物理目录一致）');
    if (args.apply) {
      stdout.writeln('  目录移动完成。');
    }
  }

  stdout.writeln('');
  stdout.writeln('---------------- 备份 ----------------');
  if (args.apply) {
    stdout.writeln('  已备份 $filesTouched 个文件到：$root/$backupDir/');
  } else {
    stdout.writeln('  （dry-run 不备份；--apply 时将备份到 rename-backup-<时间戳>/）');
  }

  stdout.writeln('');
  stdout.writeln('---------------- 手动收尾（工具不自动做） ----------------');
  stdout.writeln('  1. 图标：android mipmap-*/ic_launcher*、drawable*/banner_debrify.png、');
  stdout.writeln('     ios/Runner/Assets.xcassets/AppIcon.appiconset、tvOS brandassets、web/icons/');
  stdout.writeln('     需替换图片文件本身（见 TEMPLATE.md 图标章节）。');
  stdout.writeln('  2. test/ 未扫描：测试断言可能写死 "Debrify"，改名后跑 flutter test 统一修。');
  stdout.writeln('  3. 外部链接（GitHub 仓库 / Reddit 子版）按白名单保留指向上游，未改动。');
  stdout.writeln('  4. Kotlin 类名 DebrifyApplication / tv 包内部类名为可选项，本工具不重命名类。');
  stdout.writeln('  5. 改完建议：flutter pub get && flutter analyze && flutter test 复验。');
  stdout.writeln('==============================================================');

  if (!args.apply) {
    stdout.writeln('提示：以上为 DRY-RUN 预览。确认无误后加 --apply 执行（会先备份）。');
  }
}
