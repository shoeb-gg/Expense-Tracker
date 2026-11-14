// Second-round fixes: clearer reorder hint, calmer dialogs, visible secondary buttons, matching form header controls.
const fs = require('fs');
const path = require('path');
let n = 0, miss = 0;
function patch(file, pairs) {
  let s = fs.readFileSync(file, 'utf8');
  for (const [a, b, count] of pairs) {
    const c = s.split(a).length - 1;
    if (c !== (count || 1)) { console.log('PROBLEM (' + c + ' matches, wanted ' + (count || 1) + ') in ' + path.basename(file) + ': ' + a.slice(0, 80)); miss++; continue; }
    s = s.split(a).join(b); n++;
  }
  fs.writeFileSync(file, s);
}

patch(path.join(__dirname, 'NewCategories.part.html'), [
  // The hint shows the handle itself, so it cannot be confused with the colour dots.
  ['<span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}; white-space: nowrap">Drag the dots to reorder</span>', '<span style="display: inline-flex; align-items: center; gap: 2px; font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}; white-space: nowrap">Hold<span class="ms" aria-hidden="true" style="font-size: 16px; width: 16px; height: 16px">drag_indicator</span>and drag to reorder</span>'],
  // Dialog: darker backdrop so the list behind it stays out of the way; one bold line, one quiet line.
  ['height: 1114px; background: rgba(4, 10, 11, 0.78)', 'height: 1114px; background: rgba(4, 10, 11, 0.88)'],
  ["target.name + '\\u2019s ' + (n === 1 ? '1 expense moves' : K.fmt(n) + ' expenses move') + ' to Miscellaneous.'", "(n === 1 ? '1 expense moves' : K.fmt(n) + ' expenses move') + ' to Miscellaneous.'"],
  ['<button type="button" onClick="{{cancelDelete}}" style="height: 48px; border: 0; border-radius: 16px; padding: 0; background: {{t.surface}}; color: {{t.text}};', '<button type="button" onClick="{{cancelDelete}}" style="height: 48px; border: 0; border-radius: 16px; padding: 0; background: {{t.tile}}; color: {{t.text}};']
]);

patch(path.join(__dirname, 'NewExpense.part.html'), [
  ['width: 360px; height: 780px; background: rgba(4, 10, 11, 0.78); display: flex;', 'width: 360px; height: 780px; background: rgba(4, 10, 11, 0.88); display: flex;'],
  ['<button type="button" onClick="{{cancelDelete}}" style="height: 48px; border: 0; border-radius: 16px; padding: 0; background: {{t.surface}}; color: {{t.text}};', '<button type="button" onClick="{{cancelDelete}}" style="height: 48px; border: 0; border-radius: 16px; padding: 0; background: {{t.tile}}; color: {{t.text}};'],
  // The Delete button has a surface that shows against the docked bar.
  ['<button type="button" onClick="{{askDelete}}" style="height: 52px; border: 0; border-radius: 18px; padding: 0; background: {{t.surface}}; color: {{t.bad}};', '<button type="button" onClick="{{askDelete}}" style="height: 52px; border: 0; border-radius: 18px; padding: 0; background: {{t.surface2}}; color: {{t.bad}};'],
  ["monthText: monthCount === 1 ? '1 expense this month' : monthCount + ' expenses this month',", "monthText: monthCount === 1 ? '1 expense so far' : monthCount + ' expenses so far',"]
]);

patch(path.join(__dirname, 'NewCategoryEdit.part.html'), [
  // Header controls match the Add expense screen (36px tall); a disabled Save is plain grey.
  ['style="justify-self: start; width: 80px; height: 40px; border-radius: 20px; background: {{t.surface}};', 'style="justify-self: start; width: 80px; height: 36px; border-radius: 18px; background: {{t.surface}};'],
  ['style="justify-self: end; width: 80px; height: 40px; border-radius: 20px; background: {{t.accent}}; color: {{t.onAccent}}; opacity: {{saveOp}}; pointer-events: {{savePe}};', 'style="justify-self: end; width: 80px; height: 36px; border-radius: 18px; background: {{saveBg}}; color: {{saveFg}}; pointer-events: {{savePe}};'],
  ["      saveOp: name.trim() ? 1 : 0.4,", "      saveBg: name.trim() ? t.accent : t.surface2,\n      saveFg: name.trim() ? t.onAccent : t.text3,"]
]);
console.log('replacements applied: ' + n + ', problems: ' + miss);
