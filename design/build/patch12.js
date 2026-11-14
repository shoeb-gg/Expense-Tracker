// Calendar cells, third pass: bigger amount in a full-width footer band, and the selected day marked by a white circle
// on its date (no tile, ring, shadow or scaling). Charts: the yearly average matches Reports; tapping dims the other columns.
const fs = require('fs');
const path = require('path');
let n = 0, miss = 0;
function patch(file, pairs) {
  let s = fs.readFileSync(file, 'utf8');
  for (const [a, b] of pairs) {
    if (a instanceof RegExp) { const m = s.match(a); if (!m || s.split(m[0]).length - 1 !== 1) { console.log('PROBLEM (regex) in ' + path.basename(file) + ': ' + String(a).slice(0, 90)); miss++; continue; } s = s.replace(a, () => b); n++; continue; }
    const c = s.split(a).length - 1;
    if (c !== 1) { console.log('PROBLEM (' + c + ' matches) in ' + path.basename(file) + ': ' + a.slice(0, 80)); miss++; continue; }
    s = s.replace(a, () => b); n++;
  }
  fs.writeFileSync(file, s);
}

patch(path.join(__dirname, 'NewCalendar.part.html'), [
  ['style="position: relative; z-index: {{c.z}}; height: 64px; border: 0; border-radius: 12px; padding: 5px 3px 4px; background: {{c.bg}}; box-shadow: {{c.ring}}; transform: {{c.lift}}; color: {{c.fg}}; display: flex; flex-direction: column; justify-content: space-between; align-items: center; cursor: {{c.cursor}}; transition: background 0.15s, box-shadow 0.15s, transform 0.15s">',
   'style="height: 64px; border: 0; border-radius: 12px; padding: 4px 0 0; overflow: hidden; background: {{c.bg}}; color: {{c.fg}}; display: flex; flex-direction: column; justify-content: space-between; align-items: center; cursor: {{c.cursor}}">'],
  // Date: a true 26px circle. White when the day is selected, turquoise when it is today.
  ['<span style="min-width: 24px; height: 24px; box-sizing: border-box; padding: 0 4px; border-radius: 12px; background: {{c.badgeBg}}; color: {{c.badgeFg}}; font-size: 15px; line-height: 24px; font-weight: 800; text-align: center; font-variant-numeric: tabular-nums">{{c.day}}</span>',
   '<span style="width: 26px; height: 26px; flex-shrink: 0; border-radius: 13px; background: {{c.badgeBg}}; box-shadow: {{c.badgeRing}}; color: {{c.badgeFg}}; font-size: 15px; line-height: 26px; font-weight: 800; text-align: center; font-variant-numeric: tabular-nums; transition: background 0.15s, box-shadow 0.15s">{{c.day}}</span>'],
  // Amount: 13px white figures in a darker band across the foot of the cell.
  ['<span style="align-self: stretch; height: 20px; border-radius: 8px; background: {{c.chipBg}}; color: {{c.amtFg}}; font-size: 11.5px; line-height: 20px; font-weight: 700; text-align: center; font-variant-numeric: tabular-nums">{{c.amt}}</span>',
   '<span style="align-self: stretch; height: 22px; flex-shrink: 0; background: {{c.chipBg}}; color: {{c.amtFg}}; font-size: 13px; line-height: 22px; font-weight: 700; letter-spacing: -0.2px; text-align: center; font-variant-numeric: tabular-nums">{{c.amt}}</span>'],
  ['const fg = future ? t.dim : (on || dark ? t.onAccent : t.text);', 'const fg = future ? t.dim : (dark ? t.onAccent : t.text);'],
  ['bg: on ? t.text : (future ? t.mix(t.surface, t.bg, 0.45) : HEAT[b]),', 'bg: future ? t.mix(t.surface, t.bg, 0.45) : HEAT[b],'],
  ["chipBg: on ? t.onAccent : t.onAccent + '8C',", "chipBg: t.onAccent + '8C',"],
  ["badgeBg: isToday ? (dark && !on ? t.onAccent : t.accent) : 'transparent',", "badgeBg: on ? '#FFFFFF' : (isToday ? (dark ? t.onAccent : t.accent) : 'transparent'),"],
  ['badgeFg: isToday ? (dark && !on ? t.accent : t.onAccent) : fg,', 'badgeFg: on ? t.onAccent : (isToday ? (dark ? t.accent : t.onAccent) : fg),'],
  ["ring: on ? '0 8px 18px rgba(0, 0, 0, 0.45)' : 'none',\n        lift: on ? 'scale(1.08)' : 'none',\n        z: on ? 1 : 0,", "// Selected: a soft dark halo keeps the white circle crisp on bright cells; selected today also gets a turquoise ring.\n        badgeRing: on ? (isToday ? '0 0 0 2.5px ' + (dark ? t.onAccent : t.accent) : '0 0 0 2px ' + t.onAccent + '59') : 'none',"]
]);

patch(path.join(__dirname, '..', 'mockup', 'project', 'NewCharts.dc.html'), [
  [/    let units = eEff - cur\.s \+ 1;[\s\S]*?const avg = units > 0 \? total \/ units : 0;/, "    // Average: per day, or per full month in a year view (a month in progress is left out, exactly as on Reports).\n    let avg = total / Math.max(1, eEff - cur.s + 1);\n    if (byMonth) {\n      const fullMonths = eEff < cur.e ? K.dt(eEff).getUTCMonth() : 12;\n      const fullEnd = eEff < cur.e ? K.dn(cur.y, fullMonths, 0) : eEff;\n      avg = fullMonths > 0 ? K.sum(cur.s, fullEnd) / fullMonths : total;\n    }"],
  ['    t.barSoft = mix(t.accent, t.surface, 0.6);', '    t.barSoft = mix(t.accent, t.surface, 0.6);\n    t.barDim = mix(t.accent, t.surface, 0.36);'],
  ['const tone = i === hi ? t.accent : t.barSoft;', 'const tone = i === hi ? t.accent : (hover !== null ? t.barDim : t.barSoft);']
]);
console.log('replacements applied: ' + n + ', problems: ' + miss);
