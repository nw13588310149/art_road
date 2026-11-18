// 用本机的 Chrome（无界面）给网页构建截整屏图。不依赖 Playwright，只用 Node 自带的能力。
// 这是「真实浏览器渲染」的那条路：字体、阴影、网络图片、随页工具栏和小画都和用户看到的一样。
// 日常改版用 tool/qa/page_preview_test.dart 更快；交付前或预览里看不到的内容用这个。
//
// 先构建并启动静态服务：
//   powershell -ExecutionPolicy Bypass -File tool\build_web.ps1
//   python -m http.server 8787 --bind 127.0.0.1 --directory build/web
//
// 用法：
//   node tool/qa/web_shot.mjs --role=student --route=/today --out=build/qa/web/student-today.png
//   node tool/qa/web_shot.mjs --role=teacher --route=/artworks --tap=开始点评 --size=1024x768 --out=...
//
// 参数：
//   --role    student teacher groupLeader headTeacher dormManager admin principal（默认 student）；
//             guest 表示不登录
//   --route   路由，默认 /
//   --tap     进入页面后依次点击的文字，多个用 | 分隔（按无障碍名称包含匹配）
//   --size    视口，默认 1180x820
//   --scale   像素比，默认 2
//   --settle  进入页面和每次点击后的等待毫秒数，默认 3500 / 1500
//   --base    站点地址，默认 http://127.0.0.1:8787
//   --out     输出文件，默认 build/qa/web/<role>-<route>.png
//
// Chrome 的位置可以用环境变量 CHROME_EXECUTABLE 指定；找不到时改用 Edge。
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, ...v] = a.replace(/^--/, '').split('=');
    return [k, v.join('=') || 'true'];
  }),
);
const base = (args.base || 'http://127.0.0.1:8787').replace(/\/$/, '');
const role = args.role || 'student';
const route = args.route || '/';
const taps = (args.tap || '').split('|').map((t) => t.trim()).filter(Boolean);
const [width, height] = (args.size || '1180x820').toLowerCase().split('x').map(Number);
const scale = Number(args.scale || 2);
const settle = Number(args.settle || 3500);
const out = path.resolve(
  args.out ||
    `build/qa/web/${role}-${route.replace(/[^A-Za-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'home'}.png`,
);

// 登录页「体验身份」按钮的开头文字。
const chips = {
  student: '学生',
  teacher: '任课老师',
  groupLeader: '组长',
  headTeacher: '班主任',
  dormManager: '宿管',
  admin: '管理员',
  principal: '校长',
};
if (role !== 'guest' && !chips[role]) {
  throw new Error(`没有这个身份：${role}。可用的有：${Object.keys(chips).join(' ')} guest`);
}

const browserPath =
  process.env.CHROME_EXECUTABLE ||
  [
    'C:/Program Files/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
    'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/usr/bin/google-chrome',
  ].find((p) => existsSync(p));
if (!browserPath) throw new Error('没有找到 Chrome 或 Edge，请设置 CHROME_EXECUTABLE');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const profile = mkdtempSync(path.join(os.tmpdir(), 'art-road-shot-'));
const browser = spawn(
  browserPath,
  [
    '--headless=new',
    '--remote-debugging-port=0',
    `--user-data-dir=${profile}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--hide-scrollbars',
    '--mute-audio',
    `--window-size=${width},${height}`,
    'about:blank',
  ],
  { stdio: ['ignore', 'ignore', 'pipe'] },
);

/** 等 Chrome 报出调试端口。 */
const debugPort = await new Promise((resolve, reject) => {
  let text = '';
  const timer = setTimeout(() => reject(new Error('Chrome 没有启动调试端口')), 20000);
  browser.stderr.on('data', (chunk) => {
    text += chunk;
    const match = text.match(/DevTools listening on ws:\/\/[^:]+:(\d+)\//);
    if (match) {
      clearTimeout(timer);
      resolve(Number(match[1]));
    }
  });
  browser.on('exit', () => reject(new Error('Chrome 提前退出')));
});

let socket;
try {
  const targets = await (await fetch(`http://127.0.0.1:${debugPort}/json/list`)).json();
  const pageTarget = targets.find((t) => t.type === 'page');
  socket = new WebSocket(pageTarget.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });
  let nextId = 0;
  const waiting = new Map();
  socket.addEventListener('message', (event) => {
    const message = JSON.parse(event.data);
    const entry = waiting.get(message.id);
    if (!entry) return;
    waiting.delete(message.id);
    if (message.error) entry.reject(new Error(message.error.message));
    else entry.resolve(message.result);
  });
  const send = (method, params = {}) =>
    new Promise((resolve, reject) => {
      const id = ++nextId;
      waiting.set(id, { resolve, reject });
      socket.send(JSON.stringify({ id, method, params }));
    });
  /** 在页面里执行一段表达式（可以是 async 函数调用），返回它的值。 */
  const evaluate = async (expression) => {
    const result = await send('Runtime.evaluate', {
      expression,
      awaitPromise: true,
      returnByValue: true,
    });
    if (result.exceptionDetails) {
      throw new Error(result.exceptionDetails.exception?.description || '页面脚本出错');
    }
    return result.result.value;
  };

  await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride', {
    width,
    height,
    deviceScaleFactor: scale,
    mobile: false,
  });

  /** 同一地址只改 # 后面的部分不会重新载入，先回空白页。 */
  const open = async (target) => {
    await send('Page.navigate', { url: 'about:blank' });
    await sleep(150);
    await send('Page.navigate', { url: `${base}/#${target}` });
    for (let i = 0; i < 120; i++) {
      if (await evaluate(`!!document.querySelector('flutter-view, flt-glass-pane')`)) return;
      await sleep(250);
    }
    throw new Error(`页面没有加载出来：${base}/#${target}（静态服务启动了吗？）`);
  };
  /** 打开 Flutter 的无障碍树，之后才能按名称找到控件。 */
  const enableSemantics = () =>
    evaluate(`(async () => {
      const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
      for (let i = 0; i < 40; i++) {
        const placeholder = document.querySelector('flt-semantics-placeholder');
        if (placeholder) { placeholder.click(); break; }
        if (document.querySelector('flt-semantics')) break;
        await sleep(250);
      }
      await sleep(600);
    })()`);
  /** 点击名称里包含这段文字的第一个可点控件，找不到时重试几次。 */
  const tap = (text) =>
    evaluate(`(async () => {
      const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
      const wanted = ${JSON.stringify(text)};
      const nameOf = (n) => (n.getAttribute('aria-label') || n.textContent || '').trim();
      for (let i = 0; i < 16; i++) {
        const nodes = [...document.querySelectorAll('flt-semantics[role=button], flt-semantics[flt-tappable], flt-semantics[role=tab], flt-semantics[role=link]')];
        const exact = nodes.find((n) => nameOf(n) === wanted);
        const node = exact || nodes
          .filter((n) => nameOf(n).includes(wanted))
          .sort((a, b) => nameOf(a).length - nameOf(b).length)[0];
        if (node) { node.click(); return true; }
        await sleep(400);
      }
      return false;
    })()`);

  if (role !== 'guest') {
    await open('/login');
    await enableSemantics();
    if (!(await tap(`${chips[role]} · `))) throw new Error('登录页上没有找到体验身份按钮');
    let signedIn = false;
    for (let i = 0; i < 40 && !signedIn; i++) {
      await sleep(250);
      signedIn = await evaluate(`!!localStorage.getItem('flutter.token')`);
    }
    if (!signedIn) throw new Error('体验身份登录没有成功');
    // 新手引导只在第一次进首页时弹出，截图时当作已经看过。
    await evaluate(`(() => {
      for (const key of ['student', 'teacher', 'headTeacher', 'dormManager', 'admin', 'principal']) {
        localStorage.setItem('flutter.role_guide_seen_v1:' + key, 'true');
      }
    })()`);
    await sleep(1200);
  }

  await open(route);
  await sleep(settle);
  if (taps.length) await enableSemantics();
  for (const text of taps) {
    if (!(await tap(text))) throw new Error(`找不到要点击的「${text}」`);
    await sleep(Number(args.settle || 1500));
  }

  const shot = await send('Page.captureScreenshot', { format: 'png' });
  mkdirSync(path.dirname(out), { recursive: true });
  writeFileSync(out, Buffer.from(shot.data, 'base64'));
  console.log(`${path.relative(process.cwd(), out)}  ${width * scale}x${height * scale}`);
} finally {
  try {
    socket?.close();
  } catch {}
  browser.kill();
  await sleep(400);
  try {
    rmSync(profile, { recursive: true, force: true });
  } catch {}
}
