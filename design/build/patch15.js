// Calendar: when today is the selected day, a 22px white circle with a 2px turquoise ring outside it (26px in all),
// so the number is never pinched; amounts a touch larger and optically centred in their band.
const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, 'NewCalendar.part.html');
let s = fs.readFileSync(file, 'utf8');
let n = 0, miss = 0;
const rep = (a, b) => { const c = s.split(a).length - 1; if (c !== 1) { console.log('PROBLEM (' + c + ' matches): ' + a.slice(0, 90)); miss++; return; } s = s.replace(a, () => b); n++; };
rep('<span style="width: 26px; height: 26px; flex-shrink: 0; border-radius: 13px; background: {{c.badgeBg}}; box-shadow: {{c.badgeRing}}; color: {{c.badgeFg}}; font-size: 15px; line-height: 26px;', '<span style="width: {{c.badgeSize}}; height: {{c.badgeSize}}; margin: {{c.badgeMargin}}; flex-shrink: 0; border-radius: 13px; background: {{c.badgeBg}}; box-shadow: {{c.badgeRing}}; color: {{c.badgeFg}}; font-size: 15px; line-height: {{c.badgeSize}};');
rep("// When today is also the selected day, the white circle carries a turquoise rim inside its edge.\n        badgeRing: on && isToday ? 'inset 0 0 0 2.5px ' + t.accent : 'none',", "// When today is also the selected day, the white circle is 22px with a 2px turquoise ring around it (26px in all).\n        badgeRing: on && isToday ? '0 0 0 2px ' + (dark ? t.heat[1] : t.accent) : 'none',\n        badgeSize: on && isToday ? '22px' : '26px',\n        badgeMargin: on && isToday ? '2px' : '0',");
rep('font-size: 13px; line-height: 22px; font-weight: 700; letter-spacing: 0.1px; text-align: center;', 'font-size: 13.5px; line-height: 20px; font-weight: 700; letter-spacing: 0.1px; text-align: center;');
fs.writeFileSync(file, s);
console.log('replacements applied: ' + n + ', problems: ' + miss);
