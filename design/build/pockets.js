// Builds the pocket boards that are variants of existing boards (Home, Add expense, Edit expense, Settings),
// and the two boards that are another opening state of a pocket screen.
// Run after build.js (PocketList, PocketEdit) and before overlay.js (PocketSwitch, PocketPick, PocketMove).
const fs = require('fs');
const path = require('path');
const proj = path.join(__dirname, '..', 'mockup', 'project');
let problems = 0;
const read = (n) => fs.readFileSync(path.join(proj, n + '.dc.html'), 'utf8').replace(/\r\n/g, '\n');
const write = (n, s) => { fs.writeFileSync(path.join(proj, n + '.dc.html'), s); console.log('built ' + n + '.dc.html'); };
function swap(s, name, pairs) {
  for (const [a, b] of pairs) {
    if (a instanceof RegExp) {
      const c = (s.match(new RegExp(a.source, 'g')) || []).length;
      if (c !== 1) { problems++; console.log('PROBLEM (' + c + ' matches) in ' + name + ': ' + a.source.slice(0, 70)); continue; }
      s = s.replace(a, () => b);
      continue;
    }
    const c = s.split(a).length - 1;
    if (c !== 1) { problems++; console.log('PROBLEM (' + c + ' matches) in ' + name + ': ' + a.slice(0, 70)); continue; }
    s = s.split(a).join(b);
  }
  return s;
}
const icons = (s, extra) => s.replace(/icon_names=([a-z0-9_,]*)&amp;display=block/, (all, list) => 'icon_names=' + Array.from(new Set(list.split(',').concat(extra.split(',')).filter(Boolean))).sort().join(',') + '&amp;display=block');
const title = (s, t) => s.replace(/<title>[^<]*<\/title>/, '<title>' + t + '</title>');

// 1. Home: the app title at the top-left becomes the pocket switch (the spot where Money Tracker has its cashbook menu).
//    It is as tall as the two round buttons beside it, tinted so it reads as "where you are", and its name is the screen's title.
write('PocketHome', title(swap(read('MoodAqua'), 'PocketHome', [
  ['<h1 style="margin: 0; font-size: 21px; line-height: 28px; font-weight: 800; letter-spacing: -0.3px">Expense Tracker</h1>', [
    '<a href="PocketSwitch.dc.html" aria-label="You are in the pocket Personal. Tap to switch pocket" style="min-width: 0; margin-right: 12px; height: 40px; padding: 0 6px 0 4px; border-radius: 20px; background: {{t.accentSoft}}; color: {{t.text}}; text-decoration: none; display: flex; align-items: center; gap: 8px">',
    '        <span style="width: 32px; height: 32px; flex-shrink: 0; border-radius: 16px; background: {{t.bg}}; display: flex; align-items: center; justify-content: center">',
    '          <span class="em" aria-hidden="true" style="font-size: 17px">👛</span>',
    '        </span>',
    '        <span style="min-width: 0; font-size: 19px; line-height: 24px; font-weight: 800; letter-spacing: -0.3px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">Personal</span>',
    '        <span class="ms" aria-hidden="true" style="font-size: 24px; width: 24px; height: 24px; flex-shrink: 0; margin-left: -4px; color: {{t.accent}}">expand_more</span>',
    '      </a>'
  ].join('\n')]
]), 'Home, with the pocket switch'));

// 2. Add expense and Edit expense: the empty slot at the top-right holds a small pocket pill, the same tinted pill as on Home.
//    Nothing else on these screens moves. (Only shown when there are two or more pockets.)
const pocketPill = (href, aria) => [
  '    <a href="' + href + '" aria-label="' + aria + '" style="justify-self: end; max-width: 100px; height: 36px; box-sizing: border-box; padding: 0 10px 0 8px; border-radius: 18px; background: {{t.accentSoft}}; color: {{t.text}}; text-decoration: none; font-size: 12px; line-height: 20px; font-weight: 700; white-space: nowrap; display: flex; align-items: center; gap: 5px">',
  '      <span class="em" aria-hidden="true" style="font-size: 15px">👛</span>',
  '      <span style="min-width: 0; overflow: hidden; text-overflow: ellipsis">Personal</span>',
  '    </a>',
  '  </header>'
].join('\n');
const COLS = ['grid-template-columns: 88px minmax(0, 1fr) 88px; align-items: center">\n    <a href=', 'grid-template-columns: 100px minmax(0, 1fr) 100px; align-items: center">\n    <a href='];
const SLOT = '    <span aria-hidden="true"></span>\n  </header>';
write('PocketAddExpense', title(swap(read('NewAdd'), 'PocketAddExpense', [
  COLS,
  [SLOT, pocketPill('PocketPick.dc.html', 'This expense will be saved in the pocket Personal. Tap to choose another pocket')]
]), 'Add expense, which pocket'));
write('PocketEditExpense', title(swap(read('NewEdit'), 'PocketEditExpense', [
  COLS,
  [SLOT, pocketPill('PocketMove.dc.html', 'This expense is in the pocket Personal. Tap to move it to another pocket')]
]), 'Edit expense, which pocket'));

// 3. Settings: a Pockets card above Categories. Shown 780 tall, scrolled so the new card is in view.
write('PocketSettings', title(icons(swap(read('NewSettings'), 'PocketSettings', [
  ['    <section aria-label="Categories" style="flex-shrink: 0;', [
    '    <section aria-label="Pockets" style="flex-shrink: 0; border-radius: 20px; background: {{t.surface}}; overflow: hidden; display: flex; flex-direction: column">',
    '      <div style="height: 48px; flex-shrink: 0; padding: 0 16px; background: {{t.surface2}}; display: flex; align-items: center; gap: 8px">',
    '        <span class="ms" aria-hidden="true" style="font-size: 20px; width: 20px; height: 20px; color: {{t.accent}}">account_balance_wallet</span>',
    '        <h2 style="margin: 0; font-size: 15px; line-height: 20px; font-weight: 800">Pockets</h2>',
    '      </div>',
    '      <a href="PocketList.dc.html" style="margin: 0 16px; height: 68px; border: 0; padding: 0; background: transparent; color: {{t.text}}; display: flex; align-items: center; justify-content: space-between; gap: 12px; text-align: left; cursor: pointer; text-decoration: none">',
    '        <span style="min-width: 0; display: flex; flex-direction: column; gap: 2px">',
    '          <span style="font-size: 15px; line-height: 20px; font-weight: 600">Manage pockets</span>',
    '          <span style="font-size: 12.5px; line-height: 16px; font-weight: 500; color: {{t.text3}}">Add, edit, delete</span>',
    '        </span>',
    '        <span style="flex-shrink: 0; display: flex; align-items: center; gap: 6px">',
    '          <span aria-hidden="true" style="display: flex; align-items: center; gap: 4px">',
    '            <span style="width: 28px; height: 28px; border-radius: 9px; background: {{t.tile}}; display: flex; align-items: center; justify-content: center"><span class="em" style="font-size: 15px">👛</span></span>',
    '            <span style="width: 28px; height: 28px; border-radius: 9px; background: {{t.tile}}; display: flex; align-items: center; justify-content: center"><span class="em" style="font-size: 15px">💼</span></span>',
    '            <span style="width: 28px; height: 28px; border-radius: 9px; background: {{t.tile}}; display: flex; align-items: center; justify-content: center"><span class="em" style="font-size: 15px">🏖️</span></span>',
    '          </span>',
    '          <span class="ms" aria-hidden="true" style="font-size: 20px; width: 20px; height: 20px; margin-right: -6px; color: {{t.text3}}">chevron_right</span>',
    '        </span>',
    '      </a>',
    '    </section>',
    '',
    '    <section aria-label="Categories" style="flex-shrink: 0;'
  ].join('\n')],
  [/height: \d+px; position: relative; overflow: hidden/, 'height: 780px; position: relative; overflow: hidden'],
  [/"\$preview":\{"width":360,"height":\d+\}/, '"$preview":{"width":360,"height":780}'],
  ['</style>\n</helmet>', 'main>:first-child{margin-top:-652px}\n</style>\n</helmet>']
]), 'account_balance_wallet'), 'Settings, the Pockets row'));

// 4. The same screens opened another way.
if (fs.existsSync(path.join(proj, 'PocketList.dc.html'))) {
  write('PocketDelete', title(swap(read('PocketList'), 'PocketDelete', [
    ['"options":["list","delete"],"default":"list"', '"options":["list","delete"],"default":"delete"'],
    ["this.props.show ?? 'list'", "this.props.show ?? 'delete'"]
  ]), 'Pockets, delete a pocket'));
}
if (fs.existsSync(path.join(proj, 'PocketEdit.dc.html'))) {
  write('PocketAdd', title(swap(read('PocketEdit'), 'PocketAdd', [
    ['"options":["edit","add"],"default":"edit"', '"options":["edit","add"],"default":"add"'],
    ["this.props.mode ?? 'edit'", "this.props.mode ?? 'add'"]
  ]), 'Add pocket'));
}

// 5. The sheet the pocket pill opens on Add expense is the Move sheet with other words.
{
  const f = path.join(__dirname, 'pop', 'PocketMove.pop.html');
  const s = swap(fs.readFileSync(f, 'utf8').replace(/\r\n/g, '\n'), 'PocketPick', [
    ['"host":"PocketEditExpense","title":"Edit expense, move to another pocket"', '"host":"PocketAddExpense","title":"Add expense, choose the pocket"'],
    ['<div role="dialog" aria-label="Move to another pocket"', '<div role="dialog" aria-label="Save in another pocket"'],
    ['font-weight: 800; letter-spacing: -0.2px">Move to another pocket</span>', 'font-weight: 800; letter-spacing: -0.2px">Save in another pocket</span>'],
    ['>Tap the pocket this expense should go to.</span>', '>Tap the pocket this expense should go in.</span>'],
    ['white-space: nowrap">Now in this pocket</span>', 'white-space: nowrap">It will be saved here</span>']
  ]);
  fs.writeFileSync(path.join(__dirname, 'pop', 'PocketPick.pop.html'), s);
  console.log('wrote PocketPick.pop.html');
}
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
