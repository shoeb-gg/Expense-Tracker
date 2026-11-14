// Generic probe for new-look boards: lists every block and every piece of text with its ink box,
// and flags overlaps, clipped text, text outside its card, and elements outside the board.
(function () {
  const f = (v) => +v.toFixed(1);
  const R = (el) => { const b = el.getBoundingClientRect(); return { l: f(b.left), r: f(b.right), t: f(b.top), b: f(b.bottom), w: f(b.width), h: f(b.height) }; };
  const box = (el) => { const b = R(el); return 'x' + b.l + '-' + b.r + ' y' + b.t + '-' + b.b + ' h' + b.h; };
  function run() {
    const o = {};
    const root = document.querySelector('#mount > div');
    const main = root.querySelector('main') || root; // boards without <main>: measure the whole board
    o.root = R(root).w + 'x' + R(root).h;
    o.main = { box: box(main), scrollH: main.scrollHeight, clientH: main.clientHeight };
    o.top = Array.from(root.children).map((c) => c.tagName.toLowerCase() + ' ' + box(c));
    const kids = Array.from(main.children).filter((c) => R(c).h > 0);
    o.blocks = kids.map((c) => (c.getAttribute('aria-label') || c.tagName.toLowerCase()).slice(0, 26) + ' ' + box(c));
    o.gaps = kids.slice(1).map((c, i) => f(R(c).t - R(kids[i]).b));
    const hdr = root.querySelector('header');
    if (hdr) o.firstGap = f(R(kids[0]).t - R(hdr).b);
    const nav = root.querySelector('nav');
    const lastKid = kids[kids.length - 1];
    if (nav) { const fab = nav.children[2].children[0]; o.nav = { box: box(nav), lastToNav: f(R(nav).t - R(lastKid).b), lastToFab: f(R(fab).t - R(lastKid).b), active: (nav.querySelector('[aria-current]') || {}).textContent ? nav.querySelector('[aria-current]').textContent.replace(/\s+/g, ' ').trim() : 'none' }; }
    else o.bottom = { lastToBoard: f(R(root).b - R(lastKid).b) };
    // Every visible text run.
    const items = [];
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const n = walker.currentNode; const s = n.nodeValue.replace(/\s+/g, ' ').trim(); if (!s) continue;
      const el = n.parentElement; const cs = getComputedStyle(el);
      let hidden = false; for (let p = el; p && p !== root.parentElement; p = p.parentElement) { const ps = getComputedStyle(p); if (ps.visibility === 'hidden' || ps.display === 'none' || ps.opacity === '0') { hidden = true; break; } }
      if (hidden) continue;
      const rg = document.createRange(); rg.selectNodeContents(n); const b = rg.getBoundingClientRect(); if (!b.width) continue;
      const kind = el.classList.contains('ms') ? 'icon' : (el.classList.contains('em') ? 'emoji' : 'text');
      items.push({ s: s.slice(0, 30), l: f(b.left), r: f(b.right), t: f(b.top), b: f(b.bottom), fs: parseFloat(cs.fontSize), kind, el });
    }
    o.items = items.map((i) => (i.kind === 'text' ? '' : i.kind + ' ') + '"' + i.s + '" x' + i.l + '-' + i.r + ' y' + i.t + '-' + i.b + ' ' + i.fs + 'px');
    const inMain = items.filter((i) => main.contains(i.el) && i.kind === 'text');
    const tally = (arr) => { const m = {}; arr.forEach((v) => { m[v] = (m[v] || 0) + 1; }); return Object.keys(m).map(Number).sort((a, b) => a - b).map((k) => k + '(' + m[k] + ')').join(' '); };
    o.textLefts = tally(inMain.map((i) => Math.round(i.l * 2) / 2));
    o.textRights = tally(inMain.map((i) => Math.round(i.r * 2) / 2));
    // Flags.
    const flags = [];
    for (let a = 0; a < items.length; a++) for (let c = a + 1; c < items.length; c++) {
      const p = items[a], q = items[c]; if (p.el === q.el || p.el.contains(q.el) || q.el.contains(p.el)) continue;
      const ox = Math.min(p.r, q.r) - Math.max(p.l, q.l), oy = Math.min(p.b, q.b) - Math.max(p.t, q.t);
      if (ox > 1 && oy > 2) flags.push('OVERLAP "' + p.s + '" x "' + q.s + '" by ' + f(ox) + 'x' + f(oy));
    }
    Array.from(root.querySelectorAll('*')).forEach((el) => {
      const cs = getComputedStyle(el); const b = el.getBoundingClientRect();
      if (cs.overflow !== 'visible' && el.scrollWidth > el.clientWidth + 1 && el !== main && el.children.length === 0 && el.textContent.trim()) flags.push('CLIPPED "' + el.textContent.trim().slice(0, 30) + '" needs ' + el.scrollWidth + ' has ' + el.clientWidth);
      if (b.width && (b.right > R(root).r + 0.5 || b.left < R(root).l - 0.5)) flags.push('OUTSIDE BOARD ' + el.tagName + ' x' + f(b.left) + '-' + f(b.right));
    });
    inMain.forEach((i) => { const card = i.el.closest('section'); if (!card) return; const c = R(card); if (i.l < c.l + 15.5 || i.r > c.r - 15.5) { if (!i.el.closest('[data-bleed]')) flags.push('NEAR CARD EDGE "' + i.s + '" x' + i.l + '-' + i.r + ' card ' + c.l + '-' + c.r); } });
    o.flags = flags.slice(0, 40);
    o.fonts = { jakarta: document.fonts.check('800 20px "Plus Jakarta Sans"'), symbols: document.fonts.check('24px "Material Symbols Rounded"'), emoji: document.fonts.check('22px "Noto Color Emoji"') };
    document.getElementById('out').textContent = JSON.stringify(o);
  }
  const loads = [document.fonts.load('800 20px "Plus Jakarta Sans"', 'Expense 0123'), document.fonts.load('500 12px "Plus Jakarta Sans"', 'Total'), document.fonts.load('600 12px "Plus Jakarta Sans"', 'Total'), document.fonts.load('700 12px "Plus Jakarta Sans"', 'Total'), document.fonts.load('24px "Material Symbols Rounded"', 'home'), document.fonts.load('22px "Noto Color Emoji"', '🏠')];
  Promise.all(loads.map((p) => p.catch(() => null))).then(() => document.fonts.ready).then(() => setTimeout(() => { try { run(); } catch (e) { document.getElementById('out').textContent = JSON.stringify({ error: String((e && e.stack) || e) }); } }, 700));
})();
