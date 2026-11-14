// Calendar: short amounts in the day cells (1,665 -> 1.7K) so no number fills its cell edge to edge, plus a "K = thousand" note.
const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, 'NewCalendar.part.html');
let s = fs.readFileSync(file, 'utf8');
let n = 0, miss = 0;
const rep = (a, b) => { const c = s.split(a).length - 1; if (c !== 1) { console.log('PROBLEM (' + c + ' matches): ' + a.slice(0, 90)); miss++; return; } s = s.replace(a, () => b); n++; };
rep("amt: v >= 10000 ? Math.round(v / 1000) + 'K' : K.fmt(v),", 'amt: short(v),');
rep('    const cells = [];\n', "    // Amounts in the cells are shortened so they always have room: 835 stays, 1,665 becomes 1.7K, 15,090 becomes 15K.\n    const short = (v) => (v < 1000 ? K.fmt(v) : (v < 9950 ? (v / 1000).toFixed(1).replace(/\.0$/, '') : Math.round(v / 1000)) + 'K');\n    const cells = [];\n");
rep('font-size: 13px; line-height: 22px; font-weight: 700; letter-spacing: -0.2px; text-align: center;', 'font-size: 13px; line-height: 22px; font-weight: 700; letter-spacing: 0.1px; text-align: center;');
rep('      <span style="margin-right: 4px">Less</span>', '      <span style="margin-right: auto">K = thousand</span>\n      <span style="margin-right: 4px">Less</span>');
fs.writeFileSync(file, s);
console.log('replacements applied: ' + n + ', problems: ' + miss);
