// Calendar: the selected circle is exactly 26px like today's circle (no outer halo), and five-figure amounts are shortened to "15K".
const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, 'NewCalendar.part.html');
let s = fs.readFileSync(file, 'utf8');
let n = 0, miss = 0;
const rep = (a, b) => { const c = s.split(a).length - 1; if (c !== 1) { console.log('PROBLEM (' + c + ' matches): ' + a.slice(0, 90)); miss++; return; } s = s.replace(a, () => b); n++; };
rep("// Selected: a soft dark halo keeps the white circle crisp on bright cells; selected today also gets a turquoise ring.\n        badgeRing: on ? (isToday ? '0 0 0 2.5px ' + (dark ? t.onAccent : t.accent) : '0 0 0 2px ' + t.onAccent + '59') : 'none',", "// When today is also the selected day, the white circle carries a turquoise rim inside its edge.\n        badgeRing: on && isToday ? 'inset 0 0 0 2.5px ' + t.accent : 'none',");
rep("amt: v >= 10000 ? (v / 1000).toFixed(1) + 'K' : K.fmt(v),", "amt: v >= 10000 ? Math.round(v / 1000) + 'K' : K.fmt(v),");
fs.writeFileSync(file, s);
console.log('replacements applied: ' + n + ', problems: ' + miss);
