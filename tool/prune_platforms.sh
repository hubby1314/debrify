#!/usr/bin/env bash
# =============================================================================
# prune_platforms.sh — Debrify 模板平台裁剪工具（模板框架 · Agent A 交付物 2）
#
# 依据：debrify-analysis/30-模板框架实施规划.md 第 3 节（Agent A 裁剪工具）
#
# 用途：把全平台模板裁成"自用最小集"。删除后可从 git 历史恢复
#   （template-framework 分支尚未 commit 前，git checkout -- <路径> 即可还原）。
#
# 用法：
#   bash tool/prune_platforms.sh                # 默认 dry-run，只列出将删内容
#   bash tool/prune_platforms.sh --dry-run       # 显式 dry-run
#   bash tool/prune_platforms.sh --apply         # 真删除，并写 prune-log-<时间戳>.txt
#
# 默认裁剪清单（模板默认不执行，仅提供能力；在副本上按需 --apply）：
#   - tvos/                                  tvOS 平台
#   - web/                                  Web/PWA 平台
#   - dev/tool/discord/                      Discord 发布机器人
#   - dev/tool/iptv_fault_server.py         IPTV 故障模拟服务
#   - dev/tool/mock_xtream_server.py        Xtream mock 服务
#
# 安全：禁止删除源码目录（lib/ android/ ios/ macos/ windows/ linux/
#       test/ packages/ tool/）与仓库根关键文件；命中保护清单直接报错退出。
# =============================================================================
set -euo pipefail

# 以脚本所在位置反推仓库根（tool/ 的上一级），保证任意 cwd 下都正确
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

MODE="dry-run"
for arg in "$@"; do
  case "$arg" in
    --apply)   MODE="apply" ;;
    --dry-run) MODE="dry-run" ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "[参数错误] 未知参数：$arg（可用 --dry-run / --apply）" >&2; exit 2 ;;
  esac
done

# ---- 默认裁剪清单 ----------------------------------------------------------
PRUNE_LIST=(
  "tvos"
  "web"
  "dev/tool/discord"
  "dev/tool/iptv_fault_server.py"
  "dev/tool/mock_xtream_server.py"
)

# ---- 保护清单：这些路径片段绝不允许被裁剪 -----------------------------------
# 命中即报错（防止误删源码 / 工具自身 / 根关键文件）
PROTECT=(
  "lib" "android" "ios" "macos" "windows" "linux"
  "test" "packages" "tool" "docs" "assets"
  "pubspec.yaml" "pubspec.lock" "README.md" "LICENSE"
)

is_protected() {
  local rel="$1"
  # 归一化：去掉开头 ./，取首段
  local first="${rel#./}"
  first="${first%%/*}"
  for p in "${PROTECT[@]}"; do
    if [[ "$rel" == "$p" || "$rel" == "$p"/* || "$first" == "$p" ]]; then
      return 0
    fi
  done
  return 1
}

echo "=============================================================="
echo " Debrify 模板平台裁剪工具  |  模式：$MODE"
echo " 仓库根目录：$ROOT_DIR"
echo "=============================================================="

# ---- 安全预检：清单里任何一项落在保护清单里就拒绝 --------------------------
for rel in "${PRUNE_LIST[@]}"; do
  if is_protected "$rel"; then
    echo "[安全拦截] 裁剪清单命中受保护路径：$rel —— 终止执行，避免误删源码。" >&2
    exit 3
  fi
done

# ---- 汇总 ------------------------------------------------------------------
echo ""
echo "---------------- 待裁剪清单 ----------------"
total_files=0
total_bytes=0
existing=()
for rel in "${PRUNE_LIST[@]}"; do
  if [[ ! -e "$rel" ]]; then
    echo "  跳过（不存在）：$rel"
    continue
  fi
  existing+=("$rel")
  nfiles=$(find "$rel" -type f | wc -l | tr -d ' ')
  sz=$(du -sh "$rel" | cut -f1)
  bytes=$(du -sb "$rel" | cut -f1)
  total_files=$((total_files + nfiles))
  total_bytes=$((total_bytes + bytes))
  kind="目录"; [[ -f "$rel" ]] && kind="文件"
  printf "  [%s] %-38s  %s 文件  %s\n" "$kind" "$rel" "$nfiles" "$sz"
done

echo "--------------------------------------------"
printf "  合计：%d 个路径  %d 个文件  %s\n" \
  "${#existing[@]}" "$total_files" "$(numfmt --to=iec "$total_bytes" 2>/dev/null || echo "$total_bytes B")"

# ---- 执行 ------------------------------------------------------------------
if [[ "$MODE" == "dry-run" ]]; then
  echo ""
  echo "[DRY-RUN] 未删除任何内容。确认无误后加 --apply 执行。"
  echo "  恢复方式：template-framework 分支未 commit 前，"
  echo "            git checkout -- tvos web dev/tool/discord ...  即可还原。"
  exit 0
fi

# apply
TS="$(date +%Y%m%d-%H%M%S)"
LOG="prune-log-${TS}.txt"
{
  echo "# Debrify 模板平台裁剪日志  $TS"
  echo "# 仓库：$ROOT_DIR"
  echo "# 模式：apply"
} > "$LOG"

echo ""
echo "---------------- 执行删除 ----------------"
for rel in "${existing[@]}"; do
  if [[ -d "$rel" ]]; then
    rm -rf "$rel"
  else
    rm -f "$rel"
  fi
  echo "  已删除：$rel"
  echo "deleted: $rel" >> "$LOG"
done

echo ""
echo "  完成。删除清单已写入：$LOG"
echo "  恢复方式：git checkout -- <路径>（未 commit 前）。"
echo "=============================================================="
