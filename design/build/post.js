// After build.js: derives the "Add category" board, points links at the new boards, and orders the press-and-hold menu
// as in the original app (Edit, Delete, Details). Safe to run more than once.
const fs = require('fs');
const path = require('path');
const proj = path.join(__dirname, '..', 'mockup', 'project');
const rd = (f) => fs.readFileSync(path.join(proj, f), 'utf8');
const wr = (f, s) => fs.writeFileSync(path.join(proj, f), s);
const log = [];

// 1. "Add category" is the edit form opened empty.
{
  let s = rd('NewCategoryEdit.dc.html');
  const before = s;
  s = s.replace('<title>Edit category</title>', '<title>Add category</title>').replace('"default":"edit"', '"default":"add"').replace("this.props.mode ?? 'edit'", "this.props.mode ?? 'add'");
  if (s === before || s.includes("?? 'edit'")) log.push('PROBLEM: add variant not derived');
  wr('NewCategoryAdd.dc.html', s);
  log.push('NewCategoryAdd.dc.html written');
}

// 2. The Edit tile on the Add screens opens Categories directly.
for (const f of ['NewAdd.dc.html', 'NewAddQuick.dc.html', 'NewEdit.dc.html']) {
  let s = rd(f);
  const c = s.split('href="NewSettings.dc.html"').length - 1;
  if (c) { s = s.split('href="NewSettings.dc.html"').join('href="NewCategories.dc.html"'); wr(f, s); }
  log.push(f + ': ' + c + ' link(s) repointed, now ' + (s.split('href="NewCategories.dc.html"').length - 1));
}

// 3. Press-and-hold menu order: Edit, Delete, Details.
{
  let s = rd('NewQuickMenu.dc.html');
  const items = s.match(/    <a role="menuitem"[\s\S]*?<\/a>\n/g) || [];
  if (items.length !== 3) log.push('PROBLEM: expected 3 menu items, found ' + items.length);
  else {
    const find = (word) => items.find((x) => new RegExp('\\n\\s+' + word + '\\n').test(x));
    const want = [find('Edit'), find('Delete'), find('Details')];
    if (want.some((x) => !x)) log.push('PROBLEM: menu items not recognised');
    else { const joined = items.join(''); if (s.includes(joined)) { s = s.replace(joined, () => want.join('')); wr('NewQuickMenu.dc.html', s); log.push('quick menu order: Edit, Delete, Details'); } else log.push('PROBLEM: menu block not contiguous'); }
  }
}
console.log(log.join('\n'));
