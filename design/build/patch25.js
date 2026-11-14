// Second-pass fixes for Export and Import.
const fs = require('fs');
const path = require('path');
let problems = 0;
function patch(file, pairs) {
  let s = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
  for (const [a, b, n] of pairs) {
    const c = s.split(a).length - 1;
    if (c !== (n || 1)) { problems++; console.log('PROBLEM (' + c + ' matches) in ' + path.basename(file) + ': ' + a.slice(0, 70)); continue; }
    s = s.split(a).join(b);
  }
  fs.writeFileSync(file, s);
}
const part = (n) => path.join(__dirname, n + '.part.html');
patch(part('NewExport'), [['>One row per expense. Receipt photos are not included.</span>', '>One row per expense. Photos are left out.</span>']]);
patch(part('NewImport'), [["sub: 'Blank category = Miscellaneous'", "sub: 'Blank ones go to Miscellaneous'"]]);
patch(part('NewImportMatch'), [['<h2 style="margin: 0; font-size: 15px; line-height: 20px; font-weight: 800">Match the columns</h2>', '<h2 style="margin: 0; font-size: 15px; line-height: 20px; font-weight: 800">Your columns</h2>']]);
patch(part('NewImportReview'), [
  // 900 tall, so the taller rows still show in full.
  ['<div style="width: 360px; height: 880px; position: relative;', '<div style="width: 360px; height: 900px; position: relative;'],
  ['"$preview":{"width":360,"height":880}', '"$preview":{"width":360,"height":900}'],
  ['>Added to your current expenses. Nothing is replaced.</span>', '>Adds to your expenses. Nothing is replaced.</span>'],
  // A very long count pushes the total onto its own line instead of running into it.
  ['<div style="margin-top: 2px; display: flex; align-items: flex-end; justify-content: space-between; gap: 12px">', '<div style="margin-top: 2px; display: flex; flex-wrap: wrap; align-items: flex-end; justify-content: space-between; column-gap: 12px">'],
  ['font-weight: 800; letter-spacing: -0.6px; font-variant-numeric: tabular-nums">298 expenses</span>', 'font-weight: 800; letter-spacing: -0.6px; font-variant-numeric: tabular-nums; white-space: nowrap">298 expenses</span>'],
  ['<div style="margin: 0 16px; height: 64px; display: flex; align-items: center; gap: 12px">', '<div style="margin: 0 16px; height: 68px; display: flex; align-items: center; gap: 12px">'],
  ['<span style="display: flex; align-items: center; gap: 6px; font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}; white-space: nowrap">', '<span style="display: flex; align-items: center; gap: 4px; font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}; white-space: nowrap">']
]);
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
