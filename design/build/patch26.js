// Last small fixes: shorter label on the "new category" tile, and a slimmer Add button so category names get more room.
const fs = require('fs');
const path = require('path');
const proj = path.join(__dirname, '..', 'mockup', 'project');
let problems = 0;
function patch(file, pairs) {
  let s = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
  for (const [a, b] of pairs) {
    const c = s.split(a).length - 1;
    if (c !== 1) { problems++; console.log('PROBLEM (' + c + ' matches) in ' + path.basename(file) + ': ' + a.slice(0, 70)); continue; }
    s = s.split(a).join(b);
  }
  fs.writeFileSync(file, s);
}
patch(path.join(__dirname, 'pop', 'PopQuickCat.pop.html'), [['font-weight: 600">New category</span>', 'font-weight: 600">New</span>']]);
['NewAdd', 'NewAddQuick', 'NewEdit', 'NewAddQuickNew', 'NewAddCalc'].forEach((n) => patch(path.join(proj, n + '.dc.html'), [
  ['<a href="{{qv.addHref}}" style="height: 40px; flex-shrink: 0; padding: 0 18px;', '<a href="{{qv.addHref}}" style="height: 40px; flex-shrink: 0; padding: 0 14px;']
]));
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
