// 使用现有 Playwright 依赖验证全局画具，运行前先构建并启动静态站点。
// node tool/qa/floating_toolbox.mjs http://127.0.0.1:8793
import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync } from 'node:fs';
import { ROLES } from './pages.mjs';

const requireFrom = createRequire(process.env.PLAYWRIGHT_FROM || 'D:/桌面/阅卷系统/grading-web/package.json');
const { chromium, expect } = requireFrom('@playwright/test');
const base = process.argv[2] || 'http://127.0.0.1:8793';
const out = 'build/qa/floating-toolbox';
mkdirSync(out, { recursive: true });
const browser = await chromium.launch({ headless: true });
const errors = [];
const passed = [];
let activePage;
const button = (page, name) => page.getByRole('button', { name });
async function shot(page, name) {
  await page.screenshot({ path: `${out}/${name}.png` });
}
async function boot(page) {
  await page.goto(`${base}/#/login`);
  await page.waitForSelector('flutter-view, flt-glass-pane');
  await expect.poll(async () => page.evaluate(() => {
    document.querySelector('flt-semantics-placeholder')?.click();
    return document.querySelectorAll('flt-semantics').length;
  }), { timeout: 30000 }).toBeGreaterThan(0);
}
try {
  for (const role of ROLES.filter(role => role.chip)) {
    for (const width of role.id === 'student' ? [1180, 1024] : [1180]) {
      const height = width === 1180 ? 820 : 768;
      const context = await browser.newContext({ viewport: { width, height }, locale: 'zh-CN', timezoneId: 'Asia/Shanghai' });
      const page = await context.newPage();
      activePage = page;
      const id = `${role.id}-${width}`;
      page.on('pageerror', error => errors.push(`${id}: ${error.message}`));
      await boot(page);
      await expect(button(page, /打开画具/)).toHaveCount(0);
      await button(page, role.chip).click();
      const skip = button(page, /^跳过$/);
      const launcher = button(page, /打开画具/);
      await expect(skip.or(launcher).first()).toBeVisible({ timeout: 15000 });
      // 新手引导异步读取角色资料后出现，等待其稳定再进入工具。
      await page.waitForTimeout(2500);
      if (await skip.isVisible()) await skip.click();
      await expect(launcher).toBeVisible({ timeout: 15000 });
      await expect(launcher).toHaveAccessibleName(/小墨/);
      await shot(page, `${id}-home`);
      if (role.id === 'student') {
        await page.mouse.move(100, 100);
        await page.waitForTimeout(3500);
        await shot(page, `${id}-half`);
        await page.waitForTimeout(9000);
        const resting = await launcher.boundingBox();
        expect(resting.width).toBeGreaterThanOrEqual(44);
        await shot(page, `${id}-rest`);
      }
      await launcher.click();
      await expect(page.getByText('随手用画具', { exact: true })).toBeVisible();
      await expect(button(page, /全屏打开/)).toHaveCount(6);
      await expect(page.getByRole('switch', { name: '精灵动态' })).toBeVisible();
      await shot(page, `${id}-panel`);
      if (role.id === 'student') {
        const motionSwitch = page.getByRole('switch', { name: '精灵动态' });
        await motionSwitch.click();
        await expect(motionSwitch).not.toBeChecked();
        await motionSwitch.click();
        await expect(motionSwitch).toBeChecked();
        await button(page, /全屏打开构图网格/).click();
        await expect(button(page, /收起工具/)).toBeVisible();
        await button(page, /暖调静物/).click();
        await expect(button(page, /^九宫格$/)).toBeVisible();
        await shot(page, `${id}-grid`);
        await button(page, /^工具用法$/).click();
        await expect(page.getByText('叠加构图线检查主体位置，选画纸比例预览裁切范围', { exact: true })).toBeVisible();
        await page.keyboard.press('Escape');
        // 对话框支持键盘关闭；随后收起并从原页面恢复工作台。
        await button(page, /收起工具/).click();
        await launcher.click();
        await expect(button(page, /继续上次工具.*构图网格/)).toBeVisible();
        await shot(page, `${id}-resume`);
        await button(page, /继续上次工具/).click();
        await expect(button(page, /^九宫格$/)).toBeVisible();
        await button(page, /收起工具/).click();
        // 四边拖拽必须吸附，松手不得误打开面板。
        for (const [edge, x, y] of [['left', 30, height / 2], ['top', width / 2, 30], ['bottom', width / 2, height - 30], ['right', width - 30, height / 2]]) {
          const box = await launcher.boundingBox();
          await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
          await page.mouse.down();
          await page.mouse.move(x, y, { steps: 12 });
          await page.mouse.up();
          await expect(button(page, /全屏打开/)).toHaveCount(0);
          await expect.poll(async () => {
            const snapped = await launcher.boundingBox();
            const gap = edge === 'left' ? snapped.x : edge === 'top' ? snapped.y : edge === 'right' ? width - snapped.x - snapped.width : height - snapped.y - snapped.height;
            return Math.round(gap);
          }).toBe(0);
          await launcher.click();
          await expect(page.getByText('随手用画具', { exact: true })).toBeVisible();
          await shot(page, `${id}-${edge}`);
          await button(page, /收起画具/).click();
        }
        await launcher.click();
        await button(page, /全部 17 个工具/).click();
        await expect(page.getByText('看画分析', { exact: true })).toBeVisible();
        await button(page, /收起工具/).click();
      }
      passed.push(id);
      await context.close();
    }
  }
  expect(errors).toEqual([]);
} catch (error) {
  if (activePage && !activePage.isClosed()) {
    await shot(activePage, 'failure');
    writeFileSync(`${out}/failure.aria.txt`, await activePage.locator('body').ariaSnapshot());
  }
  throw error;
} finally {
  writeFileSync(`${out}/report.json`, JSON.stringify({ passed, errors }, null, 2));
  await browser.close();
}
console.log(JSON.stringify({ passed, errors }));
