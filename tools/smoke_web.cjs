// 网页版冒烟测试：模拟手机打开导出的网页版，确认能加载、主循环在跑、点击不报错。
// 用法：node tools/smoke_web.cjs <url> [截图目录]
// 需要 playwright（npm i -g playwright 或 npm i --prefix ~/.cache/wendao-changsheng playwright）
const fs = require('fs');
const path = require('path');
const { chromium, devices } = require('playwright');

const url = process.argv[2];
const outDir = process.argv[3] || 'build/verify';
if (!url) { console.error('用法：node tools/smoke_web.cjs <url> [截图目录]'); process.exit(2); }
fs.mkdirSync(outDir, { recursive: true });

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || undefined,
    args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required'],
  });
  const ctx = await browser.newContext({ ...devices['iPhone 13'] });
  const page = await ctx.newPage();
  const errors = [];
  // Emscripten 在 wasm 还没下载完时会用 console.error 打印「still waiting on run dependencies」，
  // 只是慢网速下的等待提示，不是错误；真正加载失败会被下面的 90 秒超时抓到。
  const BENIGN = /still waiting on run dependencies|^dependency: |^\(end of list\)$/;
  page.on('console', m => { if (m.type() === 'error' && !BENIGN.test(m.text().trim())) errors.push(m.text()); });
  page.on('pageerror', e => errors.push(String(e)));
  page.on('requestfailed', r => errors.push(`请求失败 ${r.url()} ${r.failure()?.errorText}`));

  let failed = false;
  const fail = msg => { console.error('✗ ' + msg); failed = true; };
  try {
    const resp = await page.goto(url, { waitUntil: 'load', timeout: 60000 });
    if (!resp || !resp.ok()) fail(`打开失败 HTTP ${resp && resp.status()}`);

    // Godot 网页壳加载完成后会隐藏 #status 遮罩
    await page.waitForFunction(() => {
      const s = document.getElementById('status');
      return !s || getComputedStyle(s).display === 'none' || getComputedStyle(s).visibility === 'hidden';
    }, null, { timeout: 90000 }).catch(() => fail('90 秒内没加载完（#status 遮罩没消失）'));
    await page.waitForTimeout(3000);

    const shot1 = await page.screenshot({ path: path.join(outDir, 'mobile-1.png') });
    await page.waitForTimeout(3000);
    const shot2 = await page.screenshot({ path: path.join(outDir, 'mobile-2.png') });
    if (shot1.equals(shot2)) fail('两次截图完全相同：游戏主循环可能没在跑（修为/灵石数字应当在涨）');

    // 点「吐纳」按钮（左侧大按钮，约在屏幕 20% 宽、32% 高处）
    const vp = page.viewportSize();
    for (let i = 0; i < 5; i++) { await page.mouse.click(vp.width * 0.2, vp.height * 0.32); await page.waitForTimeout(150); }
    // 依次点 6 个页签（功法 炼丹 历练 神通 法宝 宗门），确认切换不报错
    for (const x of [0.08, 0.17, 0.26, 0.35, 0.44, 0.53]) { await page.mouse.click(vp.width * x, vp.height * 0.415); await page.waitForTimeout(300); }
    await page.screenshot({ path: path.join(outDir, 'mobile-3.png') });
    // 回到「历练」页点「外出历练」，打开俯视斗法台回放，再点底部「跳过」「离开/收下」关闭
    await page.mouse.click(vp.width * 0.26, vp.height * 0.415); await page.waitForTimeout(400);
    await page.mouse.click(vp.width * 0.265, vp.height * 0.522); await page.waitForTimeout(2500);
    await page.screenshot({ path: path.join(outDir, 'mobile-4.png') });
    for (let i = 0; i < 2; i++) { await page.mouse.click(vp.width * 0.65, vp.height * 0.955); await page.waitForTimeout(600); }
  } catch (e) {
    fail(String(e));
  }
  await browser.close();

  if (errors.length) fail('浏览器报错：\n  ' + errors.slice(0, 10).join('\n  '));
  if (failed) process.exit(1);
  console.log(`✓ 冒烟测试通过（截图在 ${outDir}/mobile-{1,2,3,4}.png）`);
})();
