// Calendar day cells: larger date, amount in its own chip, and a lifted light tile for the selected day instead of a ring.
const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, 'NewCalendar.part.html');
let s = fs.readFileSync(file, 'utf8');
let n = 0, miss = 0;
const rep = (a, b) => { const c = s.split(a).length - 1; if (c !== 1) { console.log('PROBLEM (' + c + ' matches): ' + a.slice(0, 90)); miss++; return; } s = s.replace(a, () => b); n++; };

rep('<span aria-hidden="true" style="height: 58px"></span>', '<span aria-hidden="true" style="height: 64px"></span>');
rep('style="height: 58px; border: 0; border-radius: 12px; padding: 5px; background: {{c.bg}}; box-shadow: {{c.ring}}; color: {{c.fg}}; display: flex; flex-direction: column; justify-content: space-between; align-items: flex-start; text-align: left; cursor: {{c.cursor}}; transition: box-shadow 0.15s">',
    'style="position: relative; z-index: {{c.z}}; height: 64px; border: 0; border-radius: 12px; padding: 5px 3px 4px; background: {{c.bg}}; box-shadow: {{c.ring}}; transform: {{c.lift}}; color: {{c.fg}}; display: flex; flex-direction: column; justify-content: space-between; align-items: center; cursor: {{c.cursor}}; transition: background 0.15s, box-shadow 0.15s, transform 0.15s">');
// Date: 15px bold, centred at the top; today's date sits on a round badge.
rep('<span style="height: 20px; margin-left: -1px; padding: 0 4px; border-radius: 7px; background: {{c.badgeBg}}; color: {{c.badgeFg}}; font-size: 12.5px; line-height: 20px; font-weight: {{c.fw}}; font-variant-numeric: tabular-nums">{{c.day}}</span>',
    '<span style="min-width: 24px; height: 24px; box-sizing: border-box; padding: 0 4px; border-radius: 12px; background: {{c.badgeBg}}; color: {{c.badgeFg}}; font-size: 15px; line-height: 24px; font-weight: 800; text-align: center; font-variant-numeric: tabular-nums">{{c.day}}</span>');
// Amount: white figures in a dark chip across the bottom of the cell, so it can never be mistaken for the date.
rep('<span style="align-self: stretch; padding-right: 3px; text-align: right; font-size: 10.5px; line-height: 12px; font-weight: 700; font-variant-numeric: tabular-nums; color: {{c.amtFg}}">{{c.amt}}</span>',
    '<span style="align-self: stretch; height: 20px; border-radius: 8px; background: {{c.chipBg}}; color: {{c.amtFg}}; font-size: 11.5px; line-height: 20px; font-weight: 700; text-align: center; font-variant-numeric: tabular-nums">{{c.amt}}</span>');
rep('const fg = future ? t.dim : (dark ? t.onAccent : t.text);', 'const fg = future ? t.dim : (on || dark ? t.onAccent : t.text);');
rep('bg: future ? t.mix(t.surface, t.bg, 0.45) : HEAT[b],', 'bg: on ? t.text : (future ? t.mix(t.surface, t.bg, 0.45) : HEAT[b]),');
rep('amtFg: dark ? t.onAccent : t.text,', "amtFg: '#FFFFFF',\n        chipBg: on ? t.onAccent : t.onAccent + '8C',");
rep("badgeBg: isToday ? (dark ? t.onAccent : t.accent) : 'transparent',", "badgeBg: isToday ? (dark && !on ? t.onAccent : t.accent) : 'transparent',");
rep('badgeFg: isToday ? (dark ? t.accent : t.onAccent) : fg,', 'badgeFg: isToday ? (dark && !on ? t.accent : t.onAccent) : fg,');
// The selected day is a light tile that lifts off the grid.
rep("ring: on ? '0 0 0 2px ' + t.text + ', inset 0 0 0 1px ' + t.bg : 'none',", "ring: on ? '0 8px 18px rgba(0, 0, 0, 0.45)' : 'none',\n        lift: on ? 'scale(1.08)' : 'none',\n        z: on ? 1 : 0,");

fs.writeFileSync(file, s);
console.log('replacements applied: ' + n + ', problems: ' + miss);
