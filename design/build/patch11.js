// Columns also show their amount on mouse-over (Charts "Over time" and Category); Settings caption centred.
const fs = require('fs');
const path = require('path');
let n = 0, miss = 0;
function patch(file, pairs) {
  let s = fs.readFileSync(file, 'utf8');
  for (const [a, b] of pairs) {
    const c = s.split(a).length - 1;
    if (c !== 1) { console.log('PROBLEM (' + c + ' matches) in ' + path.basename(file) + ': ' + a.slice(0, 80)); miss++; continue; }
    s = s.replace(a, () => b); n++;
  }
  fs.writeFileSync(file, s);
}
const HOVER_OLD = 'const hover = st.hover != null && st.hover <= lastIdx && pts[st.hover] && pts[st.hover].v !== null ? st.hover : null;';
const HOVER_NEW = '// A column can be pinned by a tap (st.hover) or peeked at with the mouse (st.peek); the mouse wins while it is over the chart.\n    const usable = (v) => (v != null && v <= lastIdx && pts[v] && pts[v].v !== null ? v : null);\n    const pinned = usable(st.hover);\n    const hover = usable(st.peek) !== null ? usable(st.peek) : pinned;';
const slotOld = (setter) => "slots.push({ left: (X(i) - pitch / 2).toFixed(1) + 'px', w: pitch.toFixed(1) + 'px', on: i === hover, aria: p.long + ': ' + K.fmt(p.v), pick: () => " + setter + "({ hover: i === hover ? null : i }) });";
const slotNew = "slots.push({ left: (X(i) - pitch / 2).toFixed(1) + 'px', w: pitch.toFixed(1) + 'px', on: i === hover, aria: p.long + ': ' + K.fmt(p.v), pick: () => this.setState({ hover: i === pinned ? null : i, peek: null }), enter: () => { if ((this.state || {}).peek !== i) this.setState({ peek: i }); } });";
const BTN_OLD = 'aria-pressed="{{s.on}}" onClick="{{s.pick}}" style="position: absolute; left: {{s.left}}; top: 0;';
const BTN_NEW = 'aria-pressed="{{s.on}}" onClick="{{s.pick}}" onMouseEnter="{{s.enter}}" style="position: absolute; left: {{s.left}}; top: 0;';
const UNPEEK = "      slots,\n      unpeek: () => { if ((this.state || {}).peek != null) this.setState({ peek: null }); },";

patch(path.join(__dirname, '..', 'mockup', 'project', 'NewCharts.dc.html'), [
  [HOVER_OLD, HOVER_NEW],
  [slotOld('set'), slotNew],
  [BTN_OLD, BTN_NEW],
  ['<div role="group" aria-label="{{trendAria}}" style="position: relative; width: 296px; height: 222px; flex-shrink: 0">', '<div role="group" aria-label="{{trendAria}}" onMouseLeave="{{unpeek}}" style="position: relative; width: 296px; height: 222px; flex-shrink: 0">'],
  ['      slots,', UNPEEK]
]);
patch(path.join(__dirname, 'NewCategory.part.html'), [
  [HOVER_OLD, HOVER_NEW],
  [slotOld('this.setState'), slotNew],
  [BTN_OLD, BTN_NEW],
  ['<div role="group" aria-label="{{trendAria}}" style="position: relative; width: 296px; height: 188px; flex-shrink: 0">', '<div role="group" aria-label="{{trendAria}}" onMouseLeave="{{unpeek}}" style="position: relative; width: 296px; height: 188px; flex-shrink: 0">'],
  ['      slots,', UNPEEK]
]);
patch(path.join(__dirname, 'NewSettings.part.html'), [
  ['<span style="font-size: 12px; line-height: 16px; font-weight: 500; color: {{t.text3}}">Preview. The whole app uses this size.</span>', '<span style="text-align: center; font-size: 12px; line-height: 16px; font-weight: 500; color: {{t.text3}}">Preview. The whole app uses this size.</span>']
]);
console.log('replacements applied: ' + n + ', problems: ' + miss);
