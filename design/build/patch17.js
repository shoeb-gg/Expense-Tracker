// Details: a "this month in this category" row fills the gap above the buttons. Categories: slimmer row buttons so no name clips.
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
patch(path.join(__dirname, 'NewExpense.part.html'), [
  ['<!--@HELMET arrow_back,calendar_month,delete,edit,notes,photo_camera-->', '<!--@HELMET arrow_back,calendar_month,chevron_right,delete,donut_small,edit,notes,photo_camera-->'],
  ['    <div style="margin-top: auto; flex-shrink: 0; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px">',
   '    <a href="NewCategory.dc.html" aria-label="{{monthAria}}" style="flex-shrink: 0; border-radius: 20px; background: {{t.surface}}; color: {{t.text}}; text-decoration: none; display: flex; align-items: center; gap: 12px; padding-left: 16px">\n      <span style="width: 44px; height: 44px; flex-shrink: 0; border-radius: 14px; background: {{t.tile}}; color: {{t.accent}}; display: flex; align-items: center; justify-content: center">\n        <span class="ms" aria-hidden="true" style="font-size: 22px; width: 22px; height: 22px">donut_small</span>\n      </span>\n      <span style="flex: 1; min-width: 0; height: 76px; margin-right: 16px; display: flex; align-items: center; gap: 12px">\n        <span style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px">\n          <span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}">{{monthLabel}}</span>\n          <span style="font-size: 15px; line-height: 20px; font-weight: 600">{{monthText}}</span>\n        </span>\n        <span class="ms" aria-hidden="true" style="font-size: 20px; width: 20px; height: 20px; margin-right: -6px; color: {{t.text3}}">chevron_right</span>\n      </span>\n    </a>\n\n    <div style="margin-top: auto; flex-shrink: 0; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px">'],
  ["      confirm: !!st.confirm,", "      monthLabel: c.name + ' in ' + K.ML[d.getUTCMonth()],\n      monthText: K.fmt(monthSum) + (monthCount === 1 ? ' in 1 expense' : ' across ' + monthCount + ' expenses'),\n      monthAria: 'See all ' + c.name + ' expenses this month',\n      confirm: !!st.confirm,"],
  ["    const amount = K.fmt(x.amount);\n", "    const amount = K.fmt(x.amount);\n    // This category's spending in the same month, for context.\n    let monthSum = 0, monthCount = 0;\n    for (let n = K.dn(d.getUTCFullYear(), d.getUTCMonth(), 1); n <= K.TODAY; n++) (K.byDay[n] || []).forEach((y) => { if (y.catId === c.id) { monthSum += y.amount; monthCount++; } });\n"]
]);
patch(path.join(__dirname, 'NewCategories.part.html'), [
  ['style="width: 36px; height: 36px; flex-shrink: 0; border: 0; border-radius: 18px; padding: 0; background: transparent; color: {{t.text3}}; opacity: {{r.delOp}};', 'style="width: 32px; height: 36px; flex-shrink: 0; border: 0; border-radius: 16px; padding: 0; background: transparent; color: {{t.text3}}; opacity: {{r.delOp}};'],
  ['style="width: 36px; height: 36px; flex-shrink: 0; border-radius: 18px; color: {{t.text3}}; display: flex; align-items: center; justify-content: center; text-decoration: none">', 'style="width: 32px; height: 36px; flex-shrink: 0; border-radius: 16px; color: {{t.text3}}; display: flex; align-items: center; justify-content: center; text-decoration: none">'],
  ['style="width: 36px; height: 36px; flex-shrink: 0; margin-right: -12px; color: {{t.text3}};', 'style="width: 32px; height: 36px; flex-shrink: 0; margin-right: -11px; color: {{t.text3}};'],
  ['width: 360px; height: 1104px; position: relative;', 'width: 360px; height: 1114px; position: relative;'],
  ['left: 0; top: 0; width: 360px; height: 1104px; background: rgba(4, 10, 11, 0.68)', 'left: 0; top: 0; width: 360px; height: 1114px; background: rgba(4, 10, 11, 0.68)'],
  ['"height":1104}', '"height":1114}']
]);
patch(path.join(__dirname, 'NewCategoryEdit.part.html'), [
  ['width: 360px; height: 920px;', 'width: 360px; height: 900px;'],
  ['"height":920}', '"height":900}']
]);
console.log('replacements applied: ' + n + ', problems: ' + miss);
