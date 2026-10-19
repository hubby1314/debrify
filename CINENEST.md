# CINENEST 分支说明 — CineNest 应用生成手册

> 本分支是**使用手册**，不是代码快照。代码在 `template-framework` 分支（上游 Debrify 全量源码 + 改名/裁剪工具链，零修改）。
> 按本手册操作，5 分钟即可重放出与本地工作区 `ac11e95a` 提交完全一致的 **CineNest**（`com.cinenest.app`）。

---

## 为什么本分支只有文档

- **模板分支已含全部源码**：`template-framework` = Debrify 0.10.0-beta.1+56 完整源码 + `tool/rename_brand.dart`（一键改名）+ `tool/prune_platforms.sh`（平台裁剪）+ `TEMPLATE.md` + `CODEMAP-TEMPLATE.md`。
- **改名工具已验证**：dry-run 扫描 1790 文本文件 / 282 文件 / 1025 处替换，白名单保护实测生效（`Debrify TV` 329 处、`debrify_tv_` 140 处全部掩码未替换）。
- **CineNest = 模板 + 一次改名**，无需推送 886 个差异文件；用工具重放比推送快照更可靠、可复现。

---

## 生成 CineNest（标准步骤）

```bash
# 1. clone 模板分支（含全部源码 + 工具链）
git clone -b template-framework https://github.com/hubby1314/debrify.git cinenest
cd cinenest

# 2. 改名（--apply 自动备份；以下参数即本地已验证的 CineNest 定名）
dart tool/rename_brand.dart --app-id com.cinenest.app --app-name CineNest --apply

# 3. 改名收尾（工具按设计不改 test/、根级、dev/、tool/ 的 package: 导入；必须手动同步）
grep -rl "package:debrify/" test/ | xargs sed -i 's|package:debrify/|package:cinenest/|g'
grep -rl "package:debrify/" flutter_test_config.dart dev/ tool/ --include="*.dart" \
  | grep -v rename_brand | xargs sed -i 's|package:debrify/|package:cinenest/|g'
# 校验：以下应返回 0（rename_brand 规则定义行除外）
grep -rn "package:debrify/" --include="*.dart" . | grep -v '/\.git/' | grep -v 'tool/rename_brand' | wc -l

# 4. 编译与测试复验
flutter pub get
dart analyze        # 预期：lib/ 0 error（85 warning 为上游既有）
flutter test        # 预期：核心组全过（本地已验证 148 文件）

# 5. 提交你的第一版
git add -A && git commit -m "feat: 应用定名 CineNest（com.cinenest.app）"
```

---

## 已验证结果（本地工作区，2026-10-19）

| 项 | 结果 |
|---|---|
| `dart analyze` | lib/ 0 error、test/ 0 error（85 warning 为上游既有，非改名引入） |
| `flutter test` 核心组 | `test/services/` 66 文件 + `test/profiles/` 80 文件 + 备份加密/版本信息 2 文件 = **148 文件全部通过** |
| 改名 dry-run | 282 文件 / 1025 处替换；白名单保护：`Debrify TV` 329、`Debrify Player` 13、`debrify_tv_` 140、`banner_debrify` 1、上游 URL 3 |
| 平台核验 | Android 包名 `com.cinenest.app`、iOS/tvOS bundle id `com.cinenest.app(.tv)`、scheme `cinenest://`、27 通道两端同步 |
| iOS 侧载 | macOS 上 `dev/scripts/build_ipa.sh` 产出 `cinenest-<版本>.ipa`（脚本产物名已对齐） |

---

## 与本地工作区的等价性

本地工作区 `cinenest/` 的 git 历史：`9619c10b → 637d858a → babd8661（定名 CineNest）→ b4ca2b4f → ac11e95a`。
按本手册生成的结果 = 上述历史执行到 `ac11e95a` 的工作树状态（源码零改动原则下逐字节一致；唯一差异是本地已有 `.git` 提交历史，新生成的是单 commit）。

---

## 后续操作

- **换图标**：见 `TEMPLATE.md` 第 2.6 节（Android mipmap / iOS AppIcon / tvOS brandassets / web icons）。
- **裁剪平台**：`bash tool/prune_platforms.sh --apply`（删 tvos/web/discord 等；可恢复）。
- **想换新名字**：重新 clone 模板分支，换 `--app-id` / `--app-name` 再跑一次改名工具即可（工具可重复使用）。
- **功能定制**：在生成的 `cinenest/` 上开发，每次改动 `git commit` 存档。
