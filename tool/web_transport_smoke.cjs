// Run from the Flutter project: node tool/web_transport_smoke.cjs
const { createServer } = require('node:http');
const { spawn, spawnSync } = require('node:child_process');
const { mkdtempSync, readFileSync, rmSync } = require('node:fs');
const { join, relative, resolve, sep } = require('node:path');

function serve(handler) {
  return new Promise((done) => {
    const server = createServer(handler);
    server.listen(0, '127.0.0.1', () => done(server));
  });
}

(async () => {
  let redirected = 0;
  let sawRedirect = false;
  let finish;
  const result = new Promise((done) => { finish = done; });
  const sink = await serve((req, res) => { redirected++; res.end(); });
  const repo = resolve(__dirname, '..');
  const artifacts = resolve(repo, '.dart_tool');
  const dir = mkdtempSync(join(artifacts, 'web-transport-smoke-'));
  const safeRelative = relative(artifacts, dir);
  if (!safeRelative.startsWith('web-transport-smoke-') || safeRelative.includes(sep)) {
    throw new Error('Unexpected test output directory');
  }
  process.on('exit', () => {
    try { rmSync(dir, { recursive: true, force: true, maxRetries: 5, retryDelay: 150 }); } catch {}
  });
  const output = join('.dart_tool', safeRelative, 'client.js');
  const compiled = spawnSync('dart', [
    'compile', 'js', '-o', output, 'tool/web_transport_smoke.dart',
  ], { cwd: repo, shell: process.platform === 'win32', stdio: 'inherit', windowsHide: true });
  if (compiled.status !== 0) {
    sink.close();
    throw new Error('Could not compile the browser transport smoke test');
  }
  const js = readFileSync(resolve(repo, output));
  const app = await serve((req, res) => {
    switch (req.url) {
      case '/':
        res.writeHead(200, { 'Content-Type': 'text/html' })
          .end('<!DOCTYPE html><meta charset="utf-8"><script src="/client.js"></script>');
        break;
      case '/client.js':
        res.writeHead(200, { 'Content-Type': 'application/javascript' }).end(js);
        break;
      case '/redirect':
        sawRedirect = req.headers['app-token'] === 'local-test-token';
        res.writeHead(307, { Location: 'http://127.0.0.1:' + sink.address().port + '/sink' }).end();
        break;
      case '/file':
        res.writeHead(200, { 'Content-Type': 'application/octet-stream' }).end(Buffer.from([4, 5, 6]));
        break;
      case '/slow':
        res.writeHead(200, { 'Content-Type': 'application/octet-stream' });
        res.flushHeaders();
        break;
      case '/upload': {
        const chunks = [];
        req.on('data', (chunk) => chunks.push(chunk));
        req.on('end', () => {
          const body = Buffer.concat(chunks);
          const multipart = req.headers['content-type'].startsWith('multipart/form-data; boundary=') &&
            body.includes('filename="study.png"') && body.includes(Buffer.from([1, 2, 3]));
          res.writeHead(200, { 'Content-Type': 'application/json' }).end(JSON.stringify({
            multipart, token: req.headers['app-token'] === 'local-test-token',
            school: req.headers['schoolid'] === '501',
          }));
        });
        break;
      }
      case '/result': {
        const chunks = [];
        req.on('data', (chunk) => chunks.push(chunk));
        req.on('end', () => { res.end(); finish(Buffer.concat(chunks).toString()); });
        break;
      }
      default:
        res.writeHead(404).end();
    }
  });
  const chromePath = process.env.CHROME_EXECUTABLE || (process.platform === 'win32'
    ? 'C:/Program Files/Google/Chrome/Application/chrome.exe' : 'google-chrome');
  const chrome = spawn(chromePath, [
    '--headless', '--disable-gpu', '--disable-background-networking', '--disable-component-update',
    '--no-first-run', '--no-default-browser-check', '--no-proxy-server',
    '--user-data-dir=' + join(dir, 'browser-profile'), 'http://127.0.0.1:' + app.address().port + '/',
  ], { windowsHide: true, stdio: 'ignore' });
  const timeout = setTimeout(() => finish('Chrome timed out'), 20000);
  chrome.on('error', (error) => finish(error.message));
  const outcome = await result;
  clearTimeout(timeout);
  chrome.kill();
  for (const server of [app, sink]) {
    server.closeAllConnections();
    server.close();
  }
  console.log(JSON.stringify({ outcome, sawAuthenticatedRedirect: sawRedirect, redirectTargetRequests: redirected }));
  process.exitCode = outcome === 'ok' && sawRedirect && redirected === 0 ? 0 : 1;
})().catch((error) => { console.error(error.message); process.exitCode = 1; });
