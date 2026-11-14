// Review fixes for Calendar and Category, plus chart-axis and segmented-control consistency across boards.
const fs = require('fs');
const path = require('path');
let n = 0, miss = 0;
function patch(file, pairs) {
  let s = fs.readFileSync(file, 'utf8');
  for (const [a, b, count] of pairs) {
    if (a instanceof RegExp) { if (!a.test(s)) { console.log('PROBLEM (no regex match) in ' + path.basename(file) + ': ' + a); miss++; continue; } s = s.replace(a, b); n++; continue; }
    const c = s.split(a).length - 1;
    if (c !== (count || 1)) { console.log('PROBLEM (' + c + ' matches, wanted ' + (count || 1) + ') in ' + path.basename(file) + ': ' + a.slice(0, 80)); miss++; continue; }
    s = s.split(a).join(b); n++;
  }
  fs.writeFileSync(file, s);
}
const YL = 'width: 28px; text-align: left; white-space: nowrap;';
const YR = 'width: 28px; text-align: right; white-space: nowrap;';

// Charts: axis numbers right-aligned against the plot, like the other two charts.
patch(path.join(__dirname, '..', 'mockup', 'project', 'NewCharts.dc.html'), [[YL, YR]]);

patch(path.join(__dirname, 'NewCalendar.part.html'), [
  // Header controls share one height.
  ['style="justify-self: end; height: 36px; padding: 0 14px; border: 0; border-radius: 18px; background: {{t.surface}}; color: {{t.text}}; font-size: 14px; line-height: 20px; font-weight: 700; cursor: pointer">Today</button>', 'style="justify-self: end; height: 40px; padding: 0 16px; border: 0; border-radius: 20px; background: {{t.surface}}; color: {{t.text}}; font-size: 14px; line-height: 20px; font-weight: 700; cursor: pointer">Today</button>'],
  // Every day number starts on the same edge (8px in); today's badge wraps its number without moving it.
  ['<span style="min-width: 20px; height: 20px; box-sizing: border-box; padding: 0 3px; border-radius: 7px; background: {{c.badgeBg}}; color: {{c.badgeFg}}; font-size: 12.5px; line-height: 20px; font-weight: {{c.fw}}; text-align: center; font-variant-numeric: tabular-nums">{{c.day}}</span>', '<span style="height: 20px; margin-left: -1px; padding: 0 4px; border-radius: 7px; background: {{c.badgeBg}}; color: {{c.badgeFg}}; font-size: 12.5px; line-height: 20px; font-weight: {{c.fw}}; font-variant-numeric: tabular-nums">{{c.day}}</span>'],
  // Amounts sit 8px in from the right, matching the numbers on the left.
  ['<span style="align-self: stretch; padding-right: 1px; text-align: right;', '<span style="align-self: stretch; padding-right: 3px; text-align: right;'],
  // Amounts are white on the two darker levels, so they stay easy to read.
  ['amtFg: dark ? t.onAccent : t.text2,', 'amtFg: dark ? t.onAccent : t.text,'],
  // The selected day has a white ring with a dark gap inside it, visible on every cell colour.
  ["ring: on ? 'inset 0 0 0 2px ' + (dark ? t.onAccent : t.text) : (future ? 'inset 0 0 0 1px ' + t.line : 'none'),", "ring: on ? 'inset 0 0 0 2px ' + t.text + ', inset 0 0 0 4px ' + t.bg : 'none',"],
  // Days still to come are faint solid tiles, not outlines.
  ["bg: future ? 'transparent' : HEAT[b],", "bg: future ? t.mix(t.surface, t.bg, 0.45) : HEAT[b],"]
]);

patch(path.join(__dirname, 'NewCategory.part.html'), [
  // Header: the title is centred in the space between the back button and the month button, with equal clearance.
  ['<header style="height: 60px; flex-shrink: 0; padding: 0 16px; display: grid; grid-template-columns: 96px minmax(0, 1fr) 96px; align-items: center">', '<header style="height: 60px; flex-shrink: 0; padding: 0 16px; display: flex; align-items: center; gap: 12px">'],
  ['aria-label="Back to charts" style="justify-self: start; width: 40px; height: 40px; border-radius: 20px;', 'aria-label="Back to charts" style="flex-shrink: 0; width: 40px; height: 40px; border-radius: 20px;'],
  ['<h1 style="margin: 0; min-width: 0; display: flex;', '<h1 style="margin: 0; flex: 1; min-width: 0; display: flex;'],
  ['style="justify-self: end; height: 36px; padding: 0 6px 0 12px; border: 0; border-radius: 18px;', 'style="flex-shrink: 0; height: 40px; padding: 0 8px 0 14px; border: 0; border-radius: 20px;'],
  // Chart: axis numbers right-aligned, less empty space above the plot, livelier columns.
  [YL, YR],
  ['const W = 296, padL = 34, padT = 24, ph = 148, inset = 4;', 'const W = 296, padL = 34, padT = 12, ph = 148, inset = 4;'],
  ['style="position: relative; width: 296px; height: 200px; flex-shrink: 0">', 'style="position: relative; width: 296px; height: 188px; flex-shrink: 0">'],
  ['<svg viewBox="0 0 296 200" width="296" height="200" aria-hidden="true"', '<svg viewBox="0 0 296 188" width="296" height="188" aria-hidden="true"'],
  ['top: 180px; width: 40px;', 'top: 168px; width: 40px;'],
  ['top: 151px; width: {{laterW}};', 'top: 139px; width: {{laterW}};'],
  ['left: 38px; top: 0; width: 254px; height: 176px;', 'left: 38px; top: 0; width: 254px; height: 164px;'],
  ['const soft = t.mix(c.color, t.surface, 0.65);', 'const soft = t.mix(c.color, t.surface, 0.8);'],
  // The sort switch sits in a lighter groove on the header band.
  ['border-radius: 12px; background: {{t.bg}}; display: grid; grid-template-columns: repeat(2, 84px); gap: 2px', 'border-radius: 12px; background: {{t.surface}}; display: grid; grid-template-columns: repeat(2, 84px); gap: 2px'],
  ['width: 360px; height: 810px;', 'width: 360px; height: 798px;'],
  ['"height":810}', '"height":798}']
]);

patch(path.join(__dirname, 'NewReports.part.html'), [
  [YL, YR],
  ['border-radius: 12px; background: {{t.bg}}; display: grid; grid-template-columns: repeat(2, 60px); gap: 2px', 'border-radius: 12px; background: {{t.surface}}; display: grid; grid-template-columns: repeat(2, 60px); gap: 2px'],
  [/mCmpText: mCmp \? mCmp\.abs \+ '%' : '(\\u2014|—)',/, "mCmpText: mCmp ? (mCmp.flat ? 'Same' : mCmp.abs + '% ' + (mCmp.less ? 'less' : 'more')) : '\\u2014',"]
]);

patch(path.join(__dirname, 'NewSettings.part.html'), [
  ['width: 360px; height: 1746px;', 'width: 360px; height: 1796px;'],
  ['"height":1746}', '"height":1796}']
]);
console.log('replacements applied: ' + n + ', problems: ' + miss);
