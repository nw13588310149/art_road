// 用「美育集」字标渲染 App 图标源图，再交给 flutter_launcher_icons 生成各端图标：
//   node tool/brand/render_icons.mjs && dart run flutter_launcher_icons
// 输出：assets/icon/app_icon.png（白底，iOS / Web / 旧版 Android）
//       assets/icon/app_icon_foreground.png（透明底，Android 自适应图标前景，位于安全区内）
// 横版组合标在 assets/images/brand/meiyuji_logo.png，不进方形图标。
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const requireFrom = createRequire(
  process.env.PLAYWRIGHT_FROM || 'D:/桌面/阅卷系统/grading-web/package.json',
);
const { chromium } = requireFrom('@playwright/test');

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const png = readFileSync(path.join(root, 'assets/images/brand/meiyuji_mark.png'));
const dataUrl = `data:image/png;base64,${png.toString('base64')}`;

const targets = [
  { file: 'assets/icon/app_icon.png', background: '#FFFFFF', width: 820, height: 420 },
  { file: 'assets/icon/app_icon_foreground.png', background: 'transparent', width: 620, height: 280 },
];

const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
  for (const t of targets) {
    await page.setContent(`<!doctype html><html><body style="margin:0;width:1024px;height:1024px;
      display:flex;align-items:center;justify-content:center;background:${t.background}">
      <img src="${dataUrl}" style="width:${t.width}px;height:${t.height}px;object-fit:contain"></body></html>`);
    await page.waitForTimeout(200);
    await page.screenshot({
      path: path.join(root, t.file),
      omitBackground: t.background === 'transparent',
    });
    console.log(`✓ ${t.file}`);
  }
} finally {
  await browser.close();
}
