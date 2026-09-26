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

## Agent 操作手册：不在本机时怎么做

这一节是实际做过一遍后的经验。你（agent）经常不在装好环境的本机上，而是在云端沙箱或远程 shell 里。先判断自己在哪，再按对应做法来。

### 先弄清三件事

| 要确认的 | 怎么查 | 决定了什么 |
|---|---|---|
| 能不能 `git push` | `git push --dry-run origin HEAD:main` | 能 → 正常提交推送；不能 → 走下面的「云端沙箱」做法，用 GitHub 工具提交 |
| 能不能跑 Godot | `bash tools/verify.sh --fast` | 能 → 本机验证；不能 → 找能跑的机器（下面的「远程 shell」） |
| 当前 Pages 来源 | 看 `version.txt` 是否存在：`curl -fsS https://liush2yuxjtu.github.io/wendao-changsheng/version.txt` | 404 说明还没从 `gh-pages` 发布过，`--deploy` 前要让用户切 Pages 来源 |

### 云端沙箱（有 Godot，但不能 git push）

- **验证**：照常 `bash tools/verify.sh`。沙箱里 Chromium 在 `/opt/pw-browsers/chromium`，要设 `CHROMIUM_PATH`。
- **提交**：用 GitHub MCP 的 `push_files` 或 `create_or_update_file`，一次提交多个文本文件。推完之后，逐个比对远端 blob SHA（`get_file_contents` 列目录时带 `sha`）和本地 `git hash-object <文件>`，全部一致才算推成功。
- **中文全角字符**（比如 `make_font.py` 里的全角空格 `　`）粘贴时容易丢，所以比对 SHA 这一步不能省。
- **推完后同步本地**：`git fetch && git reset origin/main`，不带 `--hard`，只移动 HEAD，工作区文件不动。之后 `git status` 应该是空的。
- **这条路做不到的事**：设置可执行位（MCP 只能写 100644）、推二进制文件、推 `gh-pages`。这些只能交给能 git push 的机器。

### 远程 shell（比如用户的 Mac mini，经 executor-sh 连接）

- **先摸底**：`uname -sm; which git gh node python3; gh auth status; df -h ~`。磁盘紧张时，别下完整的 1GB 模板包；`verify.sh` 已经改成按 Range 只取 8MB。
- **单条命令最长 120 秒**。长任务用后台跑，再定时查看日志：
  `nohup bash tools/verify.sh > ~/.cache/wendao-changsheng/verify.log 2>&1 &`
  之后每隔 1–2 分钟 `cat` 一次日志，用 `pgrep -f tools/verify.sh` 判断是否跑完。
- **把云端改动搬到远程**：`git diff --binary | gzip -9 | base64` 放进命令参数，在远程 `base64 -d | gunzip | git apply`，然后用 `git hash-object` 比对 SHA。
- **可执行位只能在这里补**：`chmod +x …` 加 `git update-index --chmod=+x …`，然后提交。
- **浏览器**：Mac 上可以直接用 `CHROMIUM_PATH='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'`，Playwright 用 `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm i --prefix ~/.cache/wendao-changsheng playwright` 装，不下浏览器。
- **网络**：国内网络直连 github.com 可能超时，用户靠本机代理（Clash 等）上网。**不要**自己去读、设置或接管用户的代理（改脚本也不行），这会被安全策略拦下，也不该由 agent 决定。直接告诉用户，由他自己 `export https_proxy=…` 再跑，或者明确授权你这样做。

### 发布顺序（第一次从 CI 切到 gh-pages 时）

1. 本机或远程跑通 `bash tools/verify.sh`。
2. 跑 `bash tools/verify.sh --deploy`，推出 `gh-pages` 分支。第 7 步会等线上版本号，这时来源还没切，会超时，属正常。
3. 用户在 **Settings → Pages** 把来源切到 `gh-pages` / `/ (root)`。一定要在第 2 步之后切，否则网站会空白。
4. 再跑一次 `--deploy`，线上版本号等于当前 commit、线上冒烟通过才算发布完成。

### 改了验证本身时，要证明它能失败

改 `verify.sh` 或检查规则后，在临时目录复制一份项目，故意制造 3 种错误，确认每种都让脚本退出码为 1：在 `.gd` 里加一个字体没有的字、加一行调用不存在函数的语法错误、把 `base_speed` 乘 0.3 让数值跑偏。改 `--deploy` 的话，用本地 bare 仓库当 origin，再起一个 `python3 -m http.server` 模拟 Pages，并设置 `PAGES_URL=http://127.0.0.1:<端口>/` 跑完整流程。

### 踩过的坑

- 远程 shell 的一次调用如果超时或报错，它启动的后台进程可能被一起杀掉（跑 `--deploy` 时就是在推送那一刻被杀的）。启动长任务的那次调用要马上返回：`nohup bash tools/verify.sh --deploy > log 2>&1 < /dev/null & disown`，不要在同一次调用里 `sleep` 等它。等待和查看日志放到后面的调用里。
- `pkill -f <模式>` 会连同自己所在的 shell 一起杀掉（命令行里也包含这个模式）。先 `pgrep` 拿到 PID，再按 PID 杀。
- `git stash` 之后如果后续命令失败，stash 会一直留着，工作区就成了旧版本。事后 `git stash list` 检查一下，并和远端比对。
- 不要为了让 git 状态干净去删文件或 `reset --hard`。先确认文件在远端或历史里有同样的内容（`git show <commit>:<路径> | cmp - <文件>`），再恢复或删除。
- 对 Godot 的输出要过滤：退出时的 `resources still in use` 和 `ObjectDB instances leaked` 属正常，其余 `ERROR` 都算失败，`verify.sh` 已经按这个规则处理。
- 数值模拟有随机性（佛系玩法跑出过 4.9–8.1 小时）。只在接近区间边界时失败，重跑一次再下结论。

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
