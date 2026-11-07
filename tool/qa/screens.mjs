// 1180×820（iPad Air 横屏）全角色截图走查。
//
// 用法（先启动静态服务：python -m http.server 8787 --directory build/web）：
//   node tool/qa/screens.mjs --out=build/qa/before
//   node tool/qa/screens.mjs --out=build/qa/after --roles=student,teacher --only=home,study
//
// 参数：
//   --base=http://127.0.0.1:8787   被测站点
//   --out=build/qa/latest          输出目录（按角色分子目录）
//   --roles=guest,student,...      只跑这些角色（默认全部）
//   --only=id1,id2                 只跑这些步骤 id（前缀匹配）
//   --scale=1                      截图像素比
//
// 步骤动作见 pages.mjs：click 支持 role / nth / attempts（重试次数），optional 为 true 时
// 找不到元素不算失败。
//
// Playwright 取自机构端工程的依赖（不给本工程新增依赖），可用环境变量
// PLAYWRIGHT_FROM 指向任一装有 @playwright/test 的 package.json。
import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';

import { ROLES } from './pages.mjs';

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, ...v] = a.replace(/^--/, '').split('=');
    return [k, v.join('=') || 'true'];
  }),
);
const base = (args.base || 'http://127.0.0.1:8787').replace(/\/$/, '');
const out = path.resolve(args.out || 'build/qa/latest');
const roleFilter = args.roles ? args.roles.split(',') : null;
const onlyFilter = args.only ? args.only.split(',') : null;
const scale = Number(args.scale || 1);

const requireFrom = createRequire(
  process.env.PLAYWRIGHT_FROM || 'D:/桌面/阅卷系统/grading-web/package.json',
);
const { chromium } = requireFrom('@playwright/test');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function enableSemantics(page) {
  for (let i = 0; i < 40; i++) {
    const done = await page.evaluate(() => {
      const p = document.querySelector('flt-semantics-placeholder');
      if (p) {
        p.click();
        return true;
      }
      return document.querySelectorAll('flt-semantics').length > 0;
    });
    if (done) return;
    await sleep(250);
  }
}

async function boot(page, route) {
  // 同一地址只改 hash 不会重新载入页面，先跳空白页保证每一步都是全新状态。
  await page.goto('about:blank');
  await page.goto(`${base}/#${route}`, { waitUntil: 'load' });
  await page.waitForSelector('flutter-view, flt-glass-pane', { timeout: 30000 });
  await sleep(1200);
  await enableSemantics(page);
  await sleep(900);
}

function nameMatcher(name) {
  if (name instanceof RegExp) return name;
  return new RegExp(name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
}

async function clickByName(page, name, { role = 'button', nth = 0, attempts = 12 } = {}) {
  const matcher = nameMatcher(name);
  const roles = role === 'any' ? ['button', 'link', 'tab', 'checkbox', 'radio', 'textbox'] : [role];
  for (let attempt = 0; attempt < attempts; attempt++) {
    for (const r of roles) {
      const loc = page.getByRole(r, { name: matcher });
      const count = await loc.count();
      if (count > nth) {
        await loc.nth(nth).click({ timeout: 4000 });
        return true;
      }
    }
    const text = page.locator('flt-semantics', { hasText: matcher });
    if ((await text.count()) > nth) {
      await text.nth(nth).click({ timeout: 4000 });
      return true;
    }
    await sleep(400);
  }
  throw new Error(`找不到可点击元素：${matcher}`);
}

async function runAction(page, action) {
  if (typeof action === 'string' || action instanceof RegExp) {
    await clickByName(page, action);
  } else if (action.click) {
    try {
      await clickByName(page, action.click, action);
    } catch (e) {
      if (!action.optional) throw e;
      return;
    }
  } else if (action.tap) {
    await page.mouse.click(action.tap[0], action.tap[1]);
  } else if (action.type) {
    if (action.into) await clickByName(page, action.into, { role: 'textbox' });
    await page.keyboard.type(action.type, { delay: 40 });
    if (action.enter) await page.keyboard.press('Enter');
  } else if (action.key) {
    await page.keyboard.press(action.key);
  } else if (action.scroll) {
    await page.mouse.move(action.at?.[0] ?? 700, action.at?.[1] ?? 500);
    await page.mouse.wheel(0, action.scroll);
  } else if (action.wait) {
    await sleep(action.wait);
    return;
  } else if (action.hash) {
    await page.evaluate((h) => {
      location.hash = h;
    }, action.hash);
  }
  await sleep(action.after ?? 1300);
}

async function login(context, role) {
  const page = await context.newPage();
  await boot(page, '/login');
  await clickByName(page, role.chip);
  await sleep(3500);
  await page.close();
}

async function runRole(browser, role, report) {
  const context = await browser.newContext({
    viewport: { width: 1180, height: 820 },
    deviceScaleFactor: scale,
    locale: 'zh-CN',
    timezoneId: 'Asia/Shanghai',
  });
  if (role.chip) await login(context, role);
  const dir = path.join(out, role.id);
  mkdirSync(dir, { recursive: true });
  const page = await context.newPage();
  let currentStep = '';
  page.on('pageerror', (e) =>
    report.errors.push(
      `${role.id}/${currentStep}: ${(e.stack || e.message).split('\n').slice(0, 3).join(' | ')}`,
    ),
  );
  let index = 0;
  for (const step of role.steps) {
    index++;
    if (onlyFilter && !onlyFilter.some((f) => step.id.startsWith(f))) continue;
    const file = path.join(dir, `${String(index).padStart(2, '0')}-${step.id}.png`);
    currentStep = step.id;
    try {
      await boot(page, step.route || '/');
      for (const action of step.actions || []) {
        await runAction(page, action);
      }
      await sleep(step.settle ?? 700);
      await page.screenshot({ path: file });
      report.ok.push(`${role.id}/${path.basename(file)}`);
      process.stdout.write(`✓ ${role.id}/${step.id}\n`);
    } catch (e) {
      await page.screenshot({ path: file.replace(/\.png$/, '.failed.png') }).catch(() => {});
      report.failed.push(`${role.id}/${step.id}: ${e.message.split('\n')[0]}`);
      process.stdout.write(`✗ ${role.id}/${step.id}: ${e.message.split('\n')[0]}\n`);
    }
  }
  await context.close();
}

const report = { ok: [], failed: [], errors: [] };
const browser = await chromium.launch({ headless: true });
try {
  for (const role of ROLES) {
    if (roleFilter && !roleFilter.includes(role.id)) continue;
    await runRole(browser, role, report);
  }
} finally {
  await browser.close();
}
mkdirSync(out, { recursive: true });
writeFileSync(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
console.log(`\n完成：${report.ok.length} 张，失败 ${report.failed.length}，页面异常 ${report.errors.length}`);
for (const f of report.failed) console.log(`  失败 ${f}`);
