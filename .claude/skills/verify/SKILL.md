---
name: verify
description: 问道长生的全部测试与发布流程（本项目没有 CI）。改了 scripts/、scenes/、数值、文案、资源之后，推送或合并之前，或者用户说「验证 / 测试 / 发布 / 部署 / 上线」时使用。跑资源与字体覆盖、无界面脚本运行、数值模拟、网页导出、手机冒烟；加 --deploy 发布到 GitHub Pages 并验证线上版。
---

# /verify — 问道长生本地验证与发布

本项目**不用 CI**。所有检查都在本机做，通过了才推送或发布。入口只有一个脚本：`tools/verify.sh`。

## 怎么选

| 情况 | 命令 | 用时 |
|---|---|---|
| 改了代码，想快速确认没坏 | `bash tools/verify.sh --fast` | 几秒 |
| 推送 / 合并前（默认跑这个） | `bash tools/verify.sh` | 首次要下载 Godot 和模板；之后约 1 分钟 |
| 改了中文文案或 `tools/make_audio.py` | `bash tools/verify.sh --regen-assets`，然后提交 `assets/` | +几秒 |
| 发布到线上 | `bash tools/verify.sh --deploy` | 完整检查 + 1–3 分钟等 Pages 刷新 |

用户没说具体要哪个时：只是改了代码 → 跑完整版（不带参数）；用户说发布、上线、部署 → `--deploy`。

## 检查了什么（任何一项失败，整个脚本就失败）

1. **资源**：字体、字体授权文件、关键音频都在；`tools/check_font.py` 确认脚本里出现的每个中文字符字体里都有。改了文案却没重新裁剪字体，这一步会失败，并列出缺哪些字。
2. **脚本**：`godot --headless --import`，然后无界面跑主场景 900 帧。任何 `SCRIPT ERROR`、`Parse Error`、`ERROR:` 都算失败（退出时的资源泄漏提示除外）。
3. **数值**：`tools/sim_balance.gd` 模拟两种玩法。全勤首次飞升要在 1–3 小时之间，佛系在 3–12 小时之间。改了 `scripts/game_data.gd` 数值导致节奏跑偏，这一步会失败。模拟带随机性，在边界附近偶尔失败时重跑一次；稳定失败才是真问题。
4. **导出**：Godot 4.3 单线程 Web 预设导出到 `build/web/`，检查四个产物都在。
5. **手机冒烟**：本地起 HTTP 服务，Playwright 模拟 iPhone 13 打开，要求：加载完成、控制台零报错、主循环在跑（隔 3 秒的两张截图不同）、点「吐纳」和 5 个页签不报错。截图在 `build/verify/local/`。

`--deploy` 额外做：
6. 源码有未提交改动就拒绝发布；否则把 `build/web` 加上 `.nojekyll` 和 `version.txt`（当前 commit）强制推到 `gh-pages` 分支。
7. 轮询线上 `version.txt`，直到它等于当前 commit，然后对线上地址再跑一次手机冒烟。截图在 `build/verify/live/`。

## 你（agent）的做法

1. 在仓库根目录运行对应命令，看完整输出。
2. **通过**：一句话说结论，列出各阶段结果（包括两次模拟的飞升用时）；有截图就看一眼 `mobile-3.png`，确认画面正常再下结论。
3. **失败**：按脚本给的修复提示改（缺字 → `python3 tools/make_font.py`；脚本错 → 修对应 `.gd`；数值超界 → 先问用户是不是故意调的节奏，是的话同步改 `verify.sh` 里的预期区间）。改完从头重跑，直到通过。不要为了通过去放宽检查，除非用户同意。
4. 除非用户明确要求，不要用 `git push --no-verify` 跳过钩子。

## 环境

- Godot：`GODOT=/path/to/godot` 优先；否则用 PATH 里的 4.3；都没有就自动下载到 `~/.cache/wendao-changsheng/`（Linux x86_64 / macOS）。Web 模板由 `tools/fetch_web_template.py` 用 HTTP Range 从官方 tpz 里只取 8MB（不下整包 1GB），只下载一次。
- Python 3 + `fonttools`（`pip install fonttools`）。`--regen-assets` 还需要 `numpy`、`ffmpeg` 和系统 Noto Serif CJK 字体。
- Node + Playwright：`npm i --prefix ~/.cache/wendao-changsheng playwright && npx --prefix ~/.cache/wendao-changsheng playwright install chromium`。已有 Chromium 的话设 `CHROMIUM_PATH`。
- macOS 自带没有 `timeout`，可以 `brew install coreutils`；没有也能跑，只是第 2 步没有超时保护。

## 一次性设置

```bash
chmod +x tools/verify.sh .githooks/pre-push
git update-index --chmod=+x tools/verify.sh .githooks/pre-push   # 把可执行位提交进仓库（钩子文件必须可执行，git 才会运行它）
git commit -m "chore: 钩子与验证脚本加可执行位"
git config core.hooksPath .githooks                              # 以后每次 push 前自动跑 --fast
```

发布前还要在 GitHub 仓库 **Settings → Pages → Build and deployment** 把 Source 设成 **Deploy from a branch**，分支选 `gh-pages`、目录选 `/ (root)`，只设一次。没设的话 `--deploy` 会推送成功，但第 7 步会超时，并提示去检查这个设置。
