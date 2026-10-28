// Starts the exported browser game in headless Chrome and checks that it comes up:
//   node tools/web_smoke.js <folder with index.html> [screenshot.png]
// The loading screen (#status) must go away, the canvas must have been drawn on, and no script
// error may be logged on the way. Used by .github/workflows/web.yml, which builds the engine the
// game runs on in the browser; this is what proves that build starts.
// Chrome: the one on the machine (channel "chrome"), or the file named by PW_EXECUTABLE.
const http = require('http');
const fs = require('fs');
const path = require('path');

let chromium;
try {
	({ chromium } = require('playwright-core'));
} catch (e) {
	({ chromium } = require('playwright'));
}

const root = path.resolve(process.argv[2] || 'build/web');
const shot = process.argv[3] || '';
const types = {
	'.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json',
	'.png': 'image/png', '.pck': 'application/octet-stream',
};

const server = http.createServer((req, res) => {
	const url = decodeURIComponent(req.url.split('?')[0]);
	const file = path.join(root, url === '/' ? 'index.html' : url);
	if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
		res.writeHead(404);
		res.end();
		return;
	}
	res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
	fs.createReadStream(file).pipe(res);
});

async function main() {
	await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
	const port = server.address().port;
	const options = process.env.PW_EXECUTABLE
		? { executablePath: process.env.PW_EXECUTABLE }
		: { channel: 'chrome' };
	const browser = await chromium.launch({
		...options,
		args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
	});
	const page = await (await browser.newContext({ viewport: { width: 390, height: 844 } })).newPage();
	const problems = [];
	page.on('pageerror', (e) => problems.push('page error: ' + e.message));
	page.on('console', (m) => {
		const text = m.text();
		if (/SCRIPT ERROR|Parse Error|USER ERROR|Failed to load/.test(text)) {
			problems.push('console: ' + text);
		}
	});

	const started = Date.now();
	await page.goto(`http://127.0.0.1:${port}/`);
	await page.waitForSelector('#status', { state: 'detached', timeout: 120000 });
	console.log(`The loading screen went away after ${((Date.now() - started) / 1000).toFixed(1)} s`);
	await page.waitForTimeout(3000);

	const png = await page.locator('#canvas').screenshot();
	if (shot) {
		fs.writeFileSync(shot, png);
	}
	console.log(`The canvas screenshot is ${png.length} bytes`);
	// A page that was never drawn is one flat colour, which a PNG squeezes to a few hundred bytes
	if (png.length < 15000) {
		problems.push(`the canvas looks empty (${png.length} bytes as a PNG)`);
	}

	await browser.close();
	server.close();
	if (problems.length > 0) {
		console.error('FAILED:\n  ' + problems.join('\n  '));
		process.exit(1);
	}
	console.log('OK: the game started in the browser');
}

main().catch((e) => {
	console.error(e);
	process.exit(1);
});
