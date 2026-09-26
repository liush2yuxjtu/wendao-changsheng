#!/usr/bin/env bash
# 问道长生 · 本地验证（取代 CI）。推送前在本机跑，全部通过才算可发布。
#
# 用法：
#   tools/verify.sh             全部本地检查：资源 → 脚本 → 数值 → 导出 → 手机冒烟
#   tools/verify.sh --fast      只跑不需要导出的检查（pre-push 钩子用，几秒钟）
#   tools/verify.sh --deploy    全部检查通过后，发布到 GitHub Pages（gh-pages 分支）并验证线上版
#   tools/verify.sh --regen-assets  先重新生成字体和音频（改了文案/音频脚本后用）
#
# 环境变量：GODOT=/path/to/godot（默认找 PATH 里的 4.3，找不到就下载到缓存目录）
#           CHROMIUM_PATH=/path/to/chromium（可选，默认用 playwright 自带的）
set -euo pipefail

GODOT_VERSION="4.3"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wendao-changsheng"
PAGES_URL="${PAGES_URL:-https://liush2yuxjtu.github.io/wendao-changsheng/}"
cd "$ROOT"

FAST=0; DEPLOY=0; REGEN=0
for a in "$@"; do
  case "$a" in
    --fast) FAST=1 ;;
    --deploy) DEPLOY=1 ;;
    --regen-assets) REGEN=1 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "未知参数：$a"; exit 2 ;;
  esac
done
[[ $FAST == 1 && $DEPLOY == 1 ]] && { echo "--fast 和 --deploy 不能一起用：发布前必须跑完整检查"; exit 2; }

step() { printf '\n\033[1m▶ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
die()  { printf '  \033[31m✗ %s\033[0m\n' "$*"; exit 1; }

# 下载：HTTP/1.1 + 自动重试（Mac 上 GitHub 大文件走 HTTP/2 偶发 "HTTP2 framing layer" 中断）
dl() { curl -fL --http1.1 --retry 5 --retry-delay 3 --retry-all-errors -sS -o "$2" "$1"; }

# ---------- Godot ----------
find_godot() {
  if [[ -n "${GODOT:-}" ]]; then echo "$GODOT"; return; fi
  for c in godot4 godot; do
    if command -v "$c" >/dev/null && "$c" --version 2>/dev/null | grep -q "^${GODOT_VERSION}\.stable"; then command -v "$c"; return; fi
  done
  local base="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"
  mkdir -p "$CACHE"
  case "$(uname -s)" in
    Linux)
      local bin="$CACHE/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
      if [[ ! -x "$bin" ]]; then
        echo "  下载 Godot ${GODOT_VERSION}（约 50MB，只下一次）…" >&2
        dl "$base/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" "$CACHE/godot.zip" || return 1
        unzip -qo "$CACHE/godot.zip" -d "$CACHE" && rm "$CACHE/godot.zip"
      fi
      echo "$bin" ;;
    Darwin)
      local bin="$CACHE/Godot.app/Contents/MacOS/Godot"
      if [[ ! -x "$bin" ]]; then
        echo "  下载 Godot ${GODOT_VERSION}（约 150MB，只下一次）…" >&2
        dl "$base/Godot_v${GODOT_VERSION}-stable_macos.universal.zip" "$CACHE/godot.zip" || return 1
        unzip -qo "$CACHE/godot.zip" -d "$CACHE" && rm "$CACHE/godot.zip"
      fi
      echo "$bin" ;;
    *) die "不支持的系统 $(uname -s)，请设置 GODOT=/path/to/godot" ;;
  esac
}

ensure_web_template() {
  local dir
  case "$(uname -s)" in
    Darwin) dir="$HOME/Library/Application Support/Godot/export_templates/${GODOT_VERSION}.stable" ;;
    *)      dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VERSION}.stable" ;;
  esac
  [[ -s "$dir/web_nothreads_release.zip" ]] && return
  echo "  下载 Web 导出模板（只按 Range 取官方 tpz 里的 8MB，不下整包 1GB）…"
  python3 tools/fetch_web_template.py "$GODOT_VERSION" "$dir" | sed 's/^/  /' || die "导出模板下载失败"
}

# 过滤 Godot 退出时的无害泄漏提示，其余 ERROR / SCRIPT ERROR / Parse Error 都算失败
godot_errors() { grep -E "SCRIPT ERROR|Parse Error|^ERROR:|^USER ERROR:" | grep -vE "resources still in use at exit|ObjectDB instances leaked" || true; }

# ---------- 1. 资源 ----------
step "1/5 资源：字体与音频"
if [[ $REGEN == 1 ]]; then
  python3 tools/make_font.py && python3 tools/make_audio.py
fi
[[ -s assets/fonts/NotoSerifSC-wendao.otf ]] || die "缺字体，运行：python3 tools/make_font.py"
[[ -s assets/fonts/NOTO-LICENSE.txt ]] || die "缺字体授权文件 assets/fonts/NOTO-LICENSE.txt"
for f in drone qin_00 qin_09 sfx_tap sfx_win sfx_death; do
  [[ -s "assets/audio/$f.ogg" ]] || die "缺音频 assets/audio/$f.ogg，运行：python3 tools/make_audio.py"
done
ok "资源齐全"
# macOS 自带 bash 3.2 在非 UTF-8 locale 下会把紧跟在 $var 后的中文字节当成变量名的一部分，
# 配合 set -u 会直接退出。要写成 ${var}。
bad="$(LC_ALL=C grep -nE '[$][A-Za-z_][A-Za-z0-9_]*[^ -~]' tools/*.sh .githooks/* || true)"
[[ -z "$bad" ]] || die "脚本里有 \$变量 紧跟非 ASCII 字符（macOS bash 3.2 会出错），改成 \${变量}：
$bad"
ok "shell 脚本兼容 macOS bash 3.2"
python3 -c "import fontTools" 2>/dev/null || die "缺 fonttools：pip install fonttools"
python3 tools/check_font.py 2>&1 | sed 's/^/  /' || die "字体缺字"

# ---------- 2. 脚本 ----------
step "2/5 脚本：导入并无界面运行主场景"
G="$(find_godot)" && [[ -x "$G" ]] || die "准备 Godot ${GODOT_VERSION} 失败（下载或解压出错，见上方输出）；也可以设置 GODOT=/path/to/godot"
"$G" --version | grep -q "^${GODOT_VERSION}\." || die "Godot 版本不是 ${GODOT_VERSION}：$("$G" --version)"
out="$("$G" --headless --import 2>&1 || true)"
errs="$(godot_errors <<<"$out")"; [[ -z "$errs" ]] || die "导入报错：
$errs"
TO="$(command -v timeout || command -v gtimeout || true)"   # macOS 默认没有 timeout
out="$(${TO:+$TO 120} "$G" --headless --quit-after 900 2>&1 || true)"
errs="$(godot_errors <<<"$out")"; [[ -z "$errs" ]] || die "运行报错：
$errs"
ok "900 帧无脚本错误"

# ---------- 3. 数值 ----------
step "3/5 数值：模拟首次飞升用时"
sim() {  # $1=模式名 $2=SIM_LAZY $3=下限小时 $4=上限小时
  local out h n
  out="$(SIM_LAZY=$2 "$G" --headless -s tools/sim_balance.gd 2>&1)"
  errs="$(godot_errors <<<"$out")"; [[ -z "$errs" ]] || die "$1 模拟报错：
$errs"
  h="$(sed -nE 's/^结束 ([0-9.]+) 小时.*/\1/p' <<<"$out")"
  n="$(sed -nE 's/.*飞升次数=([0-9]+).*/\1/p' <<<"$out")"
  [[ -n "$h" && "$n" == "1" ]] || die "$1 模拟 24 小时内没飞升：$(tail -3 <<<"$out")"
  awk -v h="$h" -v lo="$3" -v hi="$4" 'BEGIN{exit !(h>=lo && h<=hi)}' || die "$1 首次飞升 ${h}h，超出预期 ${3}–${4}h（改了 game_data.gd 数值？）"
  ok "$1：${h} 小时首次飞升（预期 ${3}–${4}h）"
}
sim "全勤" 0 1 3
sim "佛系" 1 3 12

if [[ $FAST == 1 ]]; then
  printf '\n\033[32m快速检查通过\033[0m（导出与手机冒烟未跑；发布前请跑完整 tools/verify.sh）\n'
  exit 0
fi

# ---------- 4. 导出 ----------
step "4/5 导出：单线程网页版"
ensure_web_template
rm -rf build/web && mkdir -p build/web
out="$("$G" --headless --export-release "Web" build/web/index.html 2>&1 || true)"
errs="$(godot_errors <<<"$out")"; [[ -z "$errs" ]] || die "导出报错：
$errs"
for f in index.html index.js index.wasm index.pck; do [[ -s "build/web/$f" ]] || die "导出缺 build/web/$f"; done
ok "导出完成：$(du -sh build/web | cut -f1)"

# ---------- 5. 手机冒烟 ----------
step "5/5 手机冒烟：iPhone 13 模拟打开本地导出"
NODE_PATH="${NODE_PATH:-}:$(npm root -g 2>/dev/null || true):$CACHE/node_modules"
export NODE_PATH
node -e "require('playwright')" 2>/dev/null || die "缺 playwright：npm i --prefix $CACHE playwright && npx --prefix $CACHE playwright install chromium"
port=$(( 20000 + RANDOM % 20000 ))
python3 -m http.server "$port" --bind 127.0.0.1 --directory build/web >/dev/null 2>&1 &
srv=$!; trap 'kill $srv 2>/dev/null || true' EXIT
sleep 1
node tools/smoke_web.cjs "http://127.0.0.1:$port/index.html" build/verify/local 2>&1 | sed 's/^/  /' || die "本地冒烟失败"
kill $srv 2>/dev/null || true; trap - EXIT

if [[ $DEPLOY == 0 ]]; then
  printf '\n\033[32m全部检查通过\033[0m。发布：tools/verify.sh --deploy\n'
  exit 0
fi

# ---------- 发布 ----------
step "发布：build/web → gh-pages 分支"
[[ -z "$(git status --porcelain -- scripts scenes assets project.godot export_presets.cfg)" ]] \
  || die "游戏源码有未提交改动，先提交再发布（线上版要能对应到一个 commit）"
sha="$(git rev-parse --short HEAD)"
remote="$(git remote get-url origin)"
tmp="$(mktemp -d)"
cp -R build/web/. "$tmp/"
touch "$tmp/.nojekyll"
echo "$sha" > "$tmp/version.txt"   # 线上验证用：确认 CDN 上是这次的版本
(
  cd "$tmp"
  git init -q -b gh-pages
  git add -A
  git -c user.name="$(git -C "$ROOT" config user.name || echo verify)" \
      -c user.email="$(git -C "$ROOT" config user.email || echo verify@localhost)" \
      commit -qm "deploy: ${sha}（tools/verify.sh --deploy）"
  git push -qf "$remote" gh-pages
) || die "推送 gh-pages 失败（见上方 git 输出；网络问题时检查代理，例如 export https_proxy=...）"
rm -rf "$tmp"
ok "已推送 gh-pages（源码 ${sha}）"

step "验证线上版：$PAGES_URL"
live=""
for i in $(seq 1 40); do   # Pages 构建 + CDN 刷新，一般 1–3 分钟
  live="$(curl -fsS "${PAGES_URL}version.txt?t=$RANDOM" 2>/dev/null | tr -d '[:space:]' || true)"
  [[ "$live" == "$sha" ]] && break; sleep 15
done
[[ "$live" == "$sha" ]] || die "10 分钟内线上版本仍是「${live:-无}」而不是 ${sha}——检查仓库 Settings → Pages 来源是否为 gh-pages 分支 /(root)"
ok "线上版本 = $sha"
node tools/smoke_web.cjs "$PAGES_URL" build/verify/live 2>&1 | sed 's/^/  /' || die "线上冒烟失败"
printf '\n\033[32m已发布并验证\033[0m：%s\n' "$PAGES_URL"
