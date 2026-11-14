// Makes the adaptive launcher icon layers from the approved icon in design/icon.
// The foreground keeps the approved look: the visible icon (72 of 108 units) shows the motif at the size the user approved.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { pathToFileURL } = require('url');

const root = path.join(__dirname, '..');
const src = fs.readFileSync(path.join(root, '..', 'design', 'icon', 'app_icon_foreground.svg'), 'utf8');
const open = src.match(/<svg[^>]*>/);
if (!open) throw new Error('no <svg> tag in foreground');
const inner = src.slice(open.index + open[0].length, src.lastIndexOf('</svg>'));
const vb = (open[0].match(/viewBox="([^"]+)"/) || [])[1] || '0 0 108 108';
const w = Number(vb.split(/\s+/)[2]);
const k = 72 / 108;
const off = (w * (1 - k)) / 2;
const fg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="' + vb + '" width="1024" height="1024"><g transform="translate(' + off + ' ' + off + ') scale(' + k + ')">' + inner + '</g></svg>';

const bgTxt = fs.readFileSync(path.join(root, '..', 'design', 'icon', 'app_icon_background.txt'), 'utf8');
const hexes = bgTxt.match(/#[0-9A-Fa-f]{6}/g) || ['#4FD1C5'];
const top = hexes[0];
const bottom = hexes[1] || hexes[0];
const bg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="' + top + '"/><stop offset="1" stop-color="' + bottom + '"/></linearGradient></defs><rect width="1024" height="1024" fill="url(#g)"/></svg>';

const tmp = path.join(root, 'build', 'icon_tmp');
fs.mkdirSync(tmp, { recursive: true });
const chrome = path.join('C:', 'Program Files', 'Google', 'Chrome', 'Application', 'chrome.exe');
for (const [name, svg] of [['icon_foreground', fg], ['icon_background', bg]]) {
  const html = path.join(tmp, name + '.html');
  fs.writeFileSync(html, '<!doctype html><html><head><style>html,body{margin:0;background:transparent}svg{display:block}</style></head><body>' + svg + '</body></html>');
  const out = path.join(root, 'assets', 'icon', name + '.png');
  execFileSync(chrome, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--default-background-color=00000000', '--force-device-scale-factor=1', '--window-size=1024,1024', '--screenshot=' + out, pathToFileURL(html).href], { stdio: 'ignore' });
  console.log(name + '.png ' + fs.statSync(out).size + ' bytes');
}
console.log('background gradient ' + top + ' -> ' + bottom);
