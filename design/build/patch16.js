// Settings: no currency anywhere in the app, so the Currency row goes and the group is just "Numbers".
const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, 'NewSettings.part.html');
let s = fs.readFileSync(file, 'utf8');
let n = 0, miss = 0;
const re = /\n\s*<button type="button" style="[^"]*">\s*<span style="[^"]*">Currency<\/span>[\s\S]*?<\/button>/;
if (re.test(s)) { s = s.replace(re, ''); n++; } else { console.log('PROBLEM: currency row not found'); miss++; }
const rep = (a, b) => { const c = s.split(a).length - 1; if (c !== 1) { console.log('PROBLEM (' + c + ' matches): ' + a.slice(0, 90)); miss++; return; } s = s.replace(a, () => b); n++; };
rep('<section aria-label="Currency and numbers"', '<section aria-label="Numbers"');
rep('font-weight: 800">Currency and numbers</h2>', 'font-weight: 800">Numbers</h2>');
rep('width: 360px; height: 1796px;', 'width: 360px; height: 1740px;');
rep('"height":1796}', '"height":1740}');
fs.writeFileSync(file, s);
console.log('replacements applied: ' + n + ', problems: ' + miss + ', "Currency" left: ' + (s.split('Currency').length - 1));
