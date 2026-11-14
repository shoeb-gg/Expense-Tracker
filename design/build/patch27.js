// Swipe to change the month or year: date pop-up, month pop-up (months and years), Calendar screen.
// The user's rule: finger left or up = previous, finger right or down = next. The arrows stay.
const fs = require('fs');
const path = require('path');
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
const pop = (n) => path.join(__dirname, 'pop', n + '.pop.html');
const PANEL = 'box-shadow: 0 16px 40px rgba(0, 0, 0, 0.5); display: flex; flex-direction: column">';
const PANEL_SW = 'box-shadow: 0 16px 40px rgba(0, 0, 0, 0.5); display: flex; flex-direction: column; touch-action: none; user-select: none">';

patch(pop('PopDate'), [
  ['<div role="dialog" aria-label="Date of this expense" style="', '<div role="dialog" aria-label="Date of this expense" onPointerDown="{{pop.swDown}}" onPointerUp="{{pop.swUp}}" style="'],
  [PANEL, PANEL_SW],
  ['        pick: () => this.setState({ popSel: n, popYM: d.getUTCFullYear() * 12 + d.getUTCMonth() })', '        pick: this.popTap(() => this.setState({ popSel: n, popYM: d.getUTCFullYear() * 12 + d.getUTCMonth() }))'],
  ['    const lead = k.dt(first).getUTCDay();\n', '    const lead = k.dt(first).getUTCDay();\n    const prev = () => this.setState({ popYM: ym - 1 });\n    const next = () => this.setState({ popYM: ym + 1 });\n    // Swiping across the pop-up changes the month, the same as the two arrows.\n    const sw = this.popSwipe(prev, next);\n'],
  ['      prev: () => this.setState({ popYM: ym - 1 }),\n      next: () => this.setState({ popYM: ym + 1 })', '      prev,\n      next,\n      swDown: sw.down,\n      swUp: sw.up']
]);
patch(pop('PopMonth'), [
  ['<div role="dialog" aria-label="Month to show" style="', '<div role="dialog" aria-label="Month to show" onPointerDown="{{pop.swDown}}" onPointerUp="{{pop.swUp}}" style="'],
  [PANEL, PANEL_SW],
  ["fw: on || isNow ? '800' : '600', pick });", "fw: on || isNow ? '800' : '600', pick: this.popTap(pick) });"],
  ['    const cells = [];\n', '    const prev = () => this.setState(years ? { popPage: page - 12 } : { popY: y - 1 });\n    const next = () => this.setState(years ? { popPage: page + 12 } : { popY: y + 1 });\n    // Swiping across the pop-up steps one year (twelve years in the year view), the same as the two arrows.\n    const sw = this.popSwipe(prev, next);\n    const cells = [];\n'],
  ["      prev: () => this.setState(years ? { popPage: page - 12 } : { popY: y - 1 }),\n      next: () => this.setState(years ? { popPage: page + 12 } : { popY: y + 1 })", '      prev,\n      next,\n      swDown: sw.down,\n      swUp: sw.up']
]);

// Calendar screen: swiping across the month grid changes the month, within the same limits as the arrows.
patch(path.join(__dirname, 'NewCalendar.part.html'), [
  ['<div style="margin-top: 8px; display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 4px">', '<div onPointerDown="{{swDown}}" onPointerUp="{{swUp}}" style="margin-top: 8px; display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 4px; touch-action: none; user-select: none">'],
  ['\n  renderVals() {\n', [
    '',
    '  renderVals() {',
    '    const v = this.calVals();',
    '    // Swiping. The rule the user set: finger left or up goes to the month before, finger right or down to the month after.',
    '    v.swDown = (e) => { this._sw = { x: e.clientX, y: e.clientY }; };',
    '    v.swUp = (e) => {',
    '      const s = this._sw;',
    '      this._sw = null;',
    '      if (!s) return;',
    '      const dx = e.clientX - s.x;',
    '      const dy = e.clientY - s.y;',
    '      const far = Math.abs(dx) > Math.abs(dy) ? dx : dy;',
    '      if (Math.abs(far) < 24) return;',
    '      this._swiped = Date.now();',
    '      if (far < 0) { if (!v.atStart) v.prev(); } else if (!v.atEnd) v.next();',
    '    };',
    '    // A tap that ends a swipe does not also pick a day.',
    '    v.cells.forEach((c) => {',
    '      if (!c.pick) return;',
    '      const pick = c.pick;',
    '      c.pick = () => { if (Date.now() - (this._swiped || 0) > 350) pick(); };',
    '    });',
    '    return v;',
    '  }',
    '',
    '  calVals() {',
    ''
  ].join('\n')]
]);
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
