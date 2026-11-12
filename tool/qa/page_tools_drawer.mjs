// node tool/qa/page_tools_drawer.mjs http://127.0.0.1:8793
import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync } from 'node:fs';
import { ROLES } from './pages.mjs';
const require = createRequire('D:/桌面/阅卷系统/grading-web/package.json');
const { chromium, expect } = require('@playwright/test');
const out = 'build/qa/page-tools-drawer';
mkdirSync(out, { recursive: true });
const browser = await chromium.launch({ headless: true });
const errors = [], passed = [];
let activePage;
// CanvasKit 的语义占位层可能互相覆盖；使用目标几何位置执行真实鼠标点击，
// 再断言实际工具结果，避免把 DOM 占位层误判成 Flutter 命中区域。
async function tap(locator) {
  await locator.scrollIntoViewIfNeeded();
  const box = await locator.boundingBox();
  if (!box) throw new Error('Missing control bounds');
  await activePage.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
}
const base = process.argv[2] || 'http://127.0.0.1:8793';
const button = (page, name) => page.getByRole('button', { name });
try {
  for (const role of ROLES.filter(r => r.chip)) {
    for (const width of role.id === 'student' ? [1180, 1024, 720] : [1180]) {
      const height = width === 720 ? 400 : width === 1024 ? 768 : 820;
      const id = `${role.id}-${width}`;
      const context = await browser.newContext({ viewport: { width, height }, locale: 'zh-CN' });
      const page = activePage = await context.newPage();
      page.setDefaultTimeout(15000);
      page.on('pageerror', e => errors.push(`${id}: ${e.message}`));
      await page.goto(`${base}/#/login`);
      await expect.poll(async () => page.evaluate(() => {
        document.querySelector('flt-semantics-placeholder')?.click();
        return document.querySelectorAll('flt-semantics').length;
      }), { timeout: 30000 }).toBeGreaterThan(0);
      await tap(button(page, role.chip));
      const launcher = button(page, /打开画具/);
      const skip = button(page, /^跳过$/);
      await expect(skip.or(launcher).first()).toBeVisible({ timeout: 20000 });
      await page.waitForTimeout(2500);
      if (await skip.isVisible()) await skip.click();
      await tap(launcher);
      await expect(button(page, /在当前页面使用/)).toHaveCount(6);
      await expect(button(page, '进入完整工具箱 · 17 个工具')).toBeVisible();
      await page.screenshot({ path: `${out}/${id}-drawer.png` });
      if (role.id === 'student') {
        for (const name of ['构图网格', '明度检查', '镜像翻转', '比例测量', '取色与色卡']) {
          await tap(button(page, `在当前页面使用${name}`));
          await expect(button(page, '结束工具')).toBeVisible();
          const results = { '构图网格': '九宫格', '明度检查': '五阶明度参考 · 从暗到亮', '镜像翻转': '水平镜像', '比例测量': 'A : B = ', '取色与色卡': '复制色值' };
          await expect.poll(() => page.locator('body').ariaSnapshot()).toContain(results[name]);
          await expect(button(page, '收起工具')).toHaveCount(0);
          if (name === '比例测量') {
            const point = page.getByLabel('测量端点 1', { exact: true });
            const box = await point.boundingBox();
            await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
            await page.mouse.down(); await page.mouse.move(180, 220, { steps: 8 }); await page.mouse.up();
            await expect(page.getByText(/^A : B = /)).toBeVisible();
          }
          if (name === '取色与色卡') {
            await page.mouse.click(220, 110);
            await expect(button(page, '存入色卡')).toBeEnabled({ timeout: 15000 });
            await tap(button(page, '存入色卡'));
            await expect(button(page, /选择色卡/)).toHaveCount(1);
            await expect(button(page, /选择色卡/)).toHaveAccessibleName(/选择色卡 ff[0-9a-f]{6}$/);
          }
          await page.screenshot({ path: `${out}/${id}-${name}.png` });
        }
        await tap(button(page, '在当前页面使用速写计时练习'));
        await tap(button(page, /^开始计时$/));
        await tap(button(page, '收起画具抽屉'));
        await page.waitForTimeout(1200);
        await expect.poll(() => page.locator('body').ariaSnapshot()).toMatch(/速写 00:5[0-9]/);
        await page.screenshot({ path: `${out}/${id}-timer.png` });
        await tap(button(page, '调整'));
        await tap(button(page, '进入完整工具箱 · 17 个工具'));
        await expect(page.getByText('看画分析', { exact: true })).toBeVisible();
        await tap(button(page, '收起工具'));
        await expect(launcher).toBeVisible();
      }
      passed.push(id); await context.close();
    }
  }
  expect(errors).toEqual([]);
} catch (error) {
  if (activePage && !activePage.isClosed()) {
    await activePage.screenshot({ path: `${out}/failure.png` });
    writeFileSync(`${out}/failure.aria.txt`, await activePage.locator('body').ariaSnapshot());
  }
  throw error;
} finally {
  writeFileSync(`${out}/report.json`, JSON.stringify({ passed, errors }, null, 2));
  await browser.close();
}
console.log(JSON.stringify({ passed, errors }));
