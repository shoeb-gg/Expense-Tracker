// Builds new-look boards from "part" files, so every board shares one helmet, theme, sample-data kit and bottom bar.
// Usage: node build.js Name [Name ...]   (reads build/Name.part.html, writes mockup/project/Name.dc.html)
// Markers in a part file:
//   <!--@HELMET icon,names,sorted-->   the <helmet> block with the fonts and base CSS
//   <!--@NAV home|charts|reports|settings-->   the bottom bar with that tab active
//   /*@THEME*/ and /*@KIT*/   the shared theme() and kit() methods, taken from NewCharts.dc.html
const fs = require('fs');
const path = require('path');
const proj = path.join(__dirname, '..', 'mockup', 'project');
const charts = fs.readFileSync(path.join(proj, 'NewCharts.dc.html'), 'utf8');
const cut = (src, from, to) => { const a = src.indexOf(from); const b = src.indexOf(to, a); if (a < 0 || b < 0) throw new Error('marker not found: ' + from.slice(0, 40) + ' / ' + to.slice(0, 40)); return src.slice(a, b); };
const THEME = cut(charts, '  theme(mood) {', '\n  kit() {').trimEnd();
const KIT = cut(charts, '  kit() {', '\n  // The period tabs under each time range.').trimEnd();

const helmet = (icons) => {
  const names = icons.split(',').map((s) => s.trim()).filter(Boolean).sort();
  return '<helmet>\n'
    + '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700;800&amp;display=swap">\n'
    + '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@24,500,0..1,0&amp;icon_names=' + Array.from(new Set(names)).join(',') + '&amp;display=block">\n'
    + '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Color+Emoji&amp;display=swap">\n'
    + '<style>\n'
    + 'html,body{margin:0;overflow:hidden}\n'
    + ".em{font-family:'Noto Color Emoji','Apple Color Emoji','Segoe UI Emoji',sans-serif;line-height:1;display:inline-block;flex-shrink:0}\n"
    + 'button,input{font-family:inherit}\n'
    + 'a{color:inherit}\n'
    + 'main::-webkit-scrollbar{display:none}\n'
    + ".ms{font-family:'Material Symbols Rounded';font-weight:normal;font-style:normal;line-height:1;display:inline-block;flex-shrink:0;overflow:hidden;white-space:nowrap;letter-spacing:normal;text-transform:none;direction:ltr;font-feature-settings:'liga';-webkit-font-smoothing:antialiased}\n"
    + '</style>\n'
    + '</helmet>';
};

const TABS = [['home', 'MoodAqua.dc.html', 'home', 'Home'], ['charts', 'NewCharts.dc.html', 'donut_small', 'Charts'], ['add'], ['reports', 'NewReports.dc.html', 'bar_chart', 'Reports'], ['settings', 'NewSettings.dc.html', 'tune', 'Settings']];
const nav = (active) => {
  const item = ([key, href, icon, label]) => {
    if (key === 'add') {
      return '    <a href="NewAdd.dc.html" aria-label="Add expense" style="height: 72px; display: flex; align-items: flex-start; justify-content: center; text-decoration: none">\n'
        + '      <span style="margin-top: -16px; width: 58px; height: 58px; border-radius: 29px; background: {{t.accent}}; color: {{t.onAccent}}; display: flex; align-items: center; justify-content: center; box-shadow: 0 8px 22px -2px {{t.accentGlow}}, 0 2px 6px rgba(0, 0, 0, 0.35)">\n'
        + '        <span class="ms" aria-hidden="true" style="font-size: 30px; width: 30px; height: 30px">add</span>\n'
        + '      </span>\n'
        + '    </a>\n';
    }
    const on = key === active;
    return '    <a href="' + href + '"' + (on ? ' aria-current="page"' : '') + ' style="height: 72px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; color: ' + (on ? '{{t.accent}}' : '{{t.text2}}') + '; text-decoration: none; font-size: 11.5px; line-height: 14px; font-weight: ' + (on ? '700' : '600') + '">\n'
      + '      <span style="width: 48px; height: 28px; ' + (on ? 'border-radius: 14px; background: {{t.accentSoft}}; ' : '') + 'display: flex; align-items: center; justify-content: center">\n'
      + '        <span class="ms" aria-hidden="true" style="font-size: 24px; width: 24px; height: 24px' + (on ? "; font-variation-settings: 'FILL' 1" : '') + '">' + icon + '</span>\n'
      + '      </span>\n'
      + '      ' + label + '\n'
      + '    </a>\n';
  };
  return '<nav aria-label="Main" style="height: 72px; flex-shrink: 0; position: relative; background: {{t.nav}}; box-shadow: inset 0 1px 0 {{t.line}}; display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); align-items: center">\n' + TABS.map(item).join('') + '  </nav>';
};

for (const name of process.argv.slice(2)) {
  let s = fs.readFileSync(path.join(__dirname, name + '.part.html'), 'utf8');
  let navIcons = '';
  s = s.replace(/<!--@NAV (\w+)-->/, (m, a) => { navIcons = 'add,bar_chart,donut_small,home,tune'; return nav(a); });
  s = s.replace(/<!--@HELMET ([^>]*?)-->/, (m, icons) => helmet(icons + (navIcons ? ',' + navIcons : '')));
  s = s.replace('/*@THEME*/', () => THEME.replace(/^ {2}/, ''));
  s = s.replace('/*@KIT*/', () => KIT.replace(/^ {2}/, ''));
  const left = s.match(/@(HELMET|NAV|THEME|KIT)/g);
  if (left) throw new Error(name + ': unresolved markers ' + left.join(','));
  fs.writeFileSync(path.join(proj, name + '.dc.html'), s);
  console.log('built ' + name + '.dc.html  ' + s.length + ' bytes');
}
