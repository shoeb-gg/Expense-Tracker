// Tap a column to pin its amount (Charts "Over time" and Category), and say in words what the dashed line is.
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
const slotsTpl = (h, indent) => indent + '<sc-for list="{{slots}}" as="s" hint-placeholder-count="18">\n' + indent + '  <button type="button" aria-label="{{s.aria}}" aria-pressed="{{s.on}}" onClick="{{s.pick}}" style="position: absolute; left: {{s.left}}; top: 0; width: {{s.w}}; height: ' + h + 'px; border: 0; padding: 0; background: transparent; cursor: pointer"></button>\n' + indent + '</sc-for>';
const slotsJs = (setter) => "    // Tapping a column pins its amount; tapping it again clears it.\n    const slots = [];\n    pts.forEach((p, i) => {\n      if (p.v === null) return;\n      slots.push({ left: (X(i) - pitch / 2).toFixed(1) + 'px', w: pitch.toFixed(1) + 'px', on: i === hover, aria: p.long + ': ' + K.fmt(p.v), pick: () => " + setter + "({ hover: i === hover ? null : i }) });\n    });";
const SCRUB_FN = /    const scrub = \(ev\) => \{[\s\S]*?\n    \};/;

patch(path.join(__dirname, '..', 'mockup', 'project', 'NewCharts.dc.html'), [
  // Title with a plain-words line under it instead of a dash key.
  [/<div style="align-self: stretch; height: 20px; display: flex; align-items: baseline; justify-content: space-between">[\s\S]*?\{\{avgLegend\}\}\s*<\/span>\s*<\/div>/, '<div style="align-self: stretch; display: flex; flex-direction: column; gap: 2px">\n          <h3 style="margin: 0; font-size: 14px; line-height: 20px; font-weight: 800">{{trendTitle}}</h3>\n          <span style="font-size: 12px; line-height: 16px; font-weight: 500; color: {{t.text3}}; font-variant-numeric: tabular-nums">{{avgLegend}}</span>\n        </div>'],
  ["avgLegend: 'Average ' + K.fmt(avgV),", "avgLegend: 'Dashed line = average ' + K.fmt(avgV),"],
  // The plot gives up the height the extra line takes, so this card stays as tall as the ring card.
  ['<div role="img" aria-label="{{trendAria}}" style="position: relative; width: 296px; height: 240px; flex-shrink: 0">', '<div role="group" aria-label="{{trendAria}}" style="position: relative; width: 296px; height: 222px; flex-shrink: 0">'],
  ['<svg viewBox="0 0 296 240" width="296" height="240" aria-hidden="true"', '<svg viewBox="0 0 296 222" width="296" height="222" aria-hidden="true"'],
  ['top: 220px; width: 40px;', 'top: 202px; width: 40px;'],
  ['const W = 296, padL = 34, padT = 24, ph = 188;', 'const W = 296, padL = 34, padT = 24, ph = 170;'],
  // One tap target per column.
  ['          <div onPointerMove="{{scrub}}" onPointerDown="{{scrub}}" onPointerLeave="{{unscrub}}" style="position: absolute; left: 38px; top: 0; width: 254px; height: 216px; cursor: crosshair; touch-action: pan-y"></div>', slotsTpl(198, '          ')],
  [SCRUB_FN, slotsJs('set')],
  ['      scrub,\n      unscrub: () => set({ hover: null }),', '      slots,'],
  ["'Touch and drag across the chart to see each ' + unitWord + '.'", "'Tap a column to see that ' + unitWord + '.'"]
]);

patch(path.join(__dirname, 'NewCategory.part.html'), [
  [/<div style="height: 20px; display: flex; align-items: baseline; justify-content: space-between">[\s\S]*?\{\{avgLegend\}\}\s*<\/span>\s*<\/div>/, '<div style="display: flex; flex-direction: column; gap: 2px">\n        <h2 style="margin: 0; font-size: 14px; line-height: 20px; font-weight: 800">Daily spending</h2>\n        <span style="font-size: 12px; line-height: 16px; font-weight: 500; color: {{t.text3}}; font-variant-numeric: tabular-nums">{{avgLegend}}</span>\n      </div>'],
  ["avgLegend: 'Average ' + K.fmt(avgV),", "avgLegend: 'Dashed line = average ' + K.fmt(avgV),"],
  ['<div role="img" aria-label="{{trendAria}}" style="position: relative; width: 296px; height: 188px; flex-shrink: 0">', '<div role="group" aria-label="{{trendAria}}" style="position: relative; width: 296px; height: 188px; flex-shrink: 0">'],
  ['        <div onPointerMove="{{scrub}}" onPointerDown="{{scrub}}" onPointerLeave="{{unscrub}}" style="position: absolute; left: 38px; top: 0; width: 254px; height: 164px; cursor: crosshair; touch-action: pan-y"></div>', slotsTpl(164, '        ')],
  [SCRUB_FN, slotsJs('this.setState')],
  ['      scrub,\n      unscrub: () => this.setState({ hover: null }),', '      slots,'],
  ['      </div>\n    </section>\n\n    <section aria-label="Expenses in this category"', '      </div>\n      <p style="margin: 0; font-size: 12px; line-height: 16px; font-weight: 500; color: {{t.text3}}; text-align: center">Tap a column to see that day.</p>\n    </section>\n\n    <section aria-label="Expenses in this category"'],
  ['width: 360px; height: 788px;', 'width: 360px; height: 834px;'],
  ['"height":788}', '"height":834}']
]);

patch(path.join(__dirname, 'NewReports.part.html'), [
  [/<div style="height: 16px; display: flex; align-items: center; gap: 16px; font-size: 12px; line-height: 16px; font-weight: 500; color: \{\{t\.text3\}\}">[\s\S]*?\{\{avgText\}\}\s*<\/span>\s*<\/div>/, '<div style="min-height: 36px; display: flex; flex-direction: column; gap: 4px; font-size: 12px; line-height: 16px; font-weight: 500; color: {{t.text3}}">\n          <span style="font-variant-numeric: tabular-nums">{{avgText}}</span>\n          <sc-if value="{{hasPartial}}" hint-placeholder-val="{{ true }}">\n            <span>Hollow column = month in progress</span>\n          </sc-if>\n        </div>'],
  ["avgText: year + ' monthly average ' + K.fmt(avgV),", "avgText: 'Dashed line = ' + year + ' monthly average ' + K.fmt(avgV),"],
  ['width: 360px; height: 1454px;', 'width: 360px; height: 1474px;'],
  ['"height":1454}', '"height":1474}']
]);
console.log('replacements applied: ' + n + ', problems: ' + miss);
