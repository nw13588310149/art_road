// 用艺考网标识（矢量）渲染 App 图标源图，再交给 flutter_launcher_icons 生成各端图标：
//   node tool/brand/render_icons.mjs && dart run flutter_launcher_icons
// 输出：assets/icon/app_icon.png（白底，iOS / Web / 旧版 Android）
//       assets/icon/app_icon_foreground.png（透明底，Android 自适应图标前景，位于安全区内）
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const requireFrom = createRequire(
  process.env.PLAYWRIGHT_FROM || 'D:/桌面/阅卷系统/grading-web/package.json',
);
const { chromium } = requireFrom('@playwright/test');

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const svg = readFileSync(path.join(root, 'assets/images/brand/yikaowang_mark.svg'), 'utf8');
const dataUrl = `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;

const targets = [
  { file: 'assets/icon/app_icon.png', background: '#FFFFFF', ratio: 0.62 },
  { file: 'assets/icon/app_icon_foreground.png', background: 'transparent', ratio: 0.46 },
];

const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
  for (const t of targets) {
    const size = Math.round(1024 * t.ratio);
    await page.setContent(`<!doctype html><html><body style="margin:0;width:1024px;height:1024px;
      display:flex;align-items:center;justify-content:center;background:${t.background}">
      <img src="${dataUrl}" style="width:${size}px;height:${size}px"></body></html>`);
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
