// Swipe direction corrected. The user's words: "swiping left means revealing the left side".
// So dragging the finger left-to-right (or top-to-bottom) shows the PREVIOUS one, which comes in from the left (or top);
// dragging right-to-left (or bottom-to-top) shows the NEXT one.
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
patch(path.join(__dirname, 'overlay.js'), [
  ["'  // Swiping. The rule the user set: finger left or up goes back, finger right or down goes forward.',", "'  // Swiping pulls the neighbouring page into view. Dragging the finger left-to-right or top-to-bottom reveals what is',\n  '  // on the left or above (the previous one); dragging right-to-left or bottom-to-top reveals the next one.',"],
  ["'        if (far < 0) back(); else forward();',", "'        if (far > 0) back(); else forward();',"]
]);
patch(path.join(__dirname, 'NewCalendar.part.html'), [
  ['    // Swiping. The rule the user set: finger left or up goes to the month before, finger right or down to the month after.', '    // Swiping pulls the neighbouring month into view. Dragging the finger left-to-right or top-to-bottom reveals the month\n    // on the left or above (the one before); dragging right-to-left or bottom-to-top reveals the month after.'],
  ['      if (far < 0) { if (!v.atStart) v.prev(); } else if (!v.atEnd) v.next();', '      if (far > 0) { if (!v.atStart) v.prev(); } else if (!v.atEnd) v.next();']
]);
console.log(problems ? problems + ' PROBLEM(S)' : 'all good');
