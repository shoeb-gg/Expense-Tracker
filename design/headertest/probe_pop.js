// Pop-up probe: for a board with a [data-pop] element (data-pop="dialog" or "sheet"), measures the panel
// (first element child of [data-pop]): its box, every text run inside it, every control, the direct blocks
// (rows), the gaps to the panel edges, and flags the usual layout faults.
// Used through render.js like probe_generic.js (see measure_pop.js).
(function () {
  const r2 = (v) => Math.round(v * 2) / 2;           // round to 0.5px
  const f1 = (v) => +v.toFixed(1);
  const rect = (el) => { const b = el.getBoundingClientRect(); return { l: b.left, r: b.right, t: b.top, b: b.bottom, w: b.width, h: b.height }; };
  const rr = (b) => ({ l: r2(b.l), r: r2(b.r), t: r2(b.t), b: r2(b.b), w: r2(b.w), h: r2(b.h) });
  const CTRL = 'button, a, input, select, textarea, [role="button"], [role="tab"], [role="switch"], [role="checkbox"], [role="radio"], [role="menuitem"], [tabindex]:not([tabindex="-1"])';

  function run() {
    const o = { flags: [], notes: [] };
    const root = document.querySelector('#mount > div');
    const rb = rect(root);
    o.board = { w: r2(rb.w), h: r2(rb.h) };
    const pop = root.querySelector('[data-pop]');
    o.fonts = { jakarta: document.fonts.check('800 20px "Plus Jakarta Sans"'), symbols: document.fonts.check('24px "Material Symbols Rounded"'), emoji: document.fonts.check('22px "Noto Color Emoji"') };
    if (!pop) { o.nopop = true; document.getElementById('out').textContent = JSON.stringify(o); return; }
    const panel = pop.firstElementChild;
    const kind = pop.getAttribute('data-pop');
    const pb = rect(panel);
    const pcs = getComputedStyle(panel);
    const padL = parseFloat(pcs.paddingLeft) + parseFloat(pcs.borderLeftWidth), padR = parseFloat(pcs.paddingRight) + parseFloat(pcs.borderRightWidth);
    const inL = pb.l + padL, inR = pb.r - padR;
    o.pop = { kind, wrapper: rr(rect(pop)), panel: rr(pb), padL: r2(padL), padR: r2(padR), contentL: r2(inL), contentR: r2(inR), scrimAbove: r2(pb.t), scrimBelow: r2(rb.b - pb.b), centre: { dx: f1((pb.l + pb.r) / 2 - (rb.l + rb.r) / 2), dy: f1((pb.t + pb.b) / 2 - (rb.t + rb.b) / 2) }, label: panel.getAttribute('aria-label') || '' };

    const vis = (el) => { for (let p = el; p && p !== root.parentElement; p = p.parentElement) { const s = getComputedStyle(p); if (s.display === 'none' || s.visibility === 'hidden' || s.opacity === '0') return false; } return true; };
    const srOnly = (el) => { const b = el.getBoundingClientRect(); const s = getComputedStyle(el); return (b.width <= 1.5 && b.height <= 1.5) || s.clip === 'rect(0px, 0px, 0px, 0px)'; };
    const short = (s, n) => (s || '').replace(/\s+/g, ' ').trim().slice(0, n || 30);
    const labelOf = (el) => short(el.getAttribute('aria-label') || el.textContent || el.getAttribute('placeholder') || el.tagName.toLowerCase(), 28);

    // Panel vs board.
    if (pb.l < rb.l - 0.5 || pb.r > rb.r + 0.5 || pb.t < rb.t - 0.5 || pb.b > rb.b + 0.5) o.flags.push('PANEL OUTSIDE BOARD panel x' + r2(pb.l) + '-' + r2(pb.r) + ' y' + r2(pb.t) + '-' + r2(pb.b) + ' board ' + o.board.w + 'x' + o.board.h);
    if (kind === 'dialog') {
      if (Math.abs(o.pop.centre.dx) > 0.5 || Math.abs(o.pop.centre.dy) > 0.5) o.flags.push('NOT CENTRED dx ' + o.pop.centre.dx + ' dy ' + o.pop.centre.dy);
    } else if (kind === 'sheet') {
      if (Math.abs(pb.b - rb.b) > 0.5 || Math.abs(pb.l - rb.l) > 0.5 || Math.abs(pb.r - rb.r) > 0.5) o.flags.push('NOT DOCKED panel x' + r2(pb.l) + '-' + r2(pb.r) + ' bottom ' + r2(pb.b) + ' vs board bottom ' + r2(rb.b));
    }
    const pw = rect(pop);
    if (Math.abs(pw.w - rb.w) > 0.5 || Math.abs(pw.h - rb.h) > 0.5 || Math.abs(pw.l - rb.l) > 0.5 || Math.abs(pw.t - rb.t) > 0.5) o.flags.push('SCRIM DOES NOT COVER BOARD scrim ' + rr(pw).w + 'x' + rr(pw).h + ' at ' + rr(pw).l + ',' + rr(pw).t);
    if (panel.scrollHeight > panel.clientHeight + 1 || panel.scrollWidth > panel.clientWidth + 1) o.flags.push('PANEL CONTENT LARGER THAN PANEL scroll ' + panel.scrollWidth + 'x' + panel.scrollHeight + ' client ' + panel.clientWidth + 'x' + panel.clientHeight);

    // All visible elements in the panel.
    const all = Array.from(panel.querySelectorAll('*')).filter((el) => vis(el) && !srOnly(el) && !(el.closest('svg') && el.tagName.toLowerCase() !== 'svg'));

    // Text runs.
    const items = [];
    const walker = document.createTreeWalker(panel, NodeFilter.SHOW_TEXT);
    const probeCanvas = document.createElement('canvas'); probeCanvas.width = 64; probeCanvas.height = 64;
    const emojiColoured = (ch, fontPx) => { const c = probeCanvas.getContext('2d', { willReadFrequently: true }); c.clearRect(0, 0, 64, 64); c.font = fontPx + 'px "Noto Color Emoji"'; c.textBaseline = 'middle'; c.fillStyle = '#000'; c.fillText(ch, 4, 32); const d = c.getImageData(0, 0, 64, 64).data; let col = 0, ink = 0; for (let i = 0; i < d.length; i += 4) { if (d[i + 3] > 40) { ink++; if (Math.abs(d[i] - d[i + 1]) > 25 || Math.abs(d[i + 1] - d[i + 2]) > 25) col++; } } return { ink, col }; };
    while (walker.nextNode()) {
      const n = walker.currentNode; const s = n.nodeValue.replace(/\s+/g, ' ').trim(); if (!s) continue;
      const el = n.parentElement; if (!vis(el) || srOnly(el)) continue;
      const cs = getComputedStyle(el);
      const rg = document.createRange(); rg.selectNodeContents(n);
      const rects = Array.from(rg.getClientRects()).filter((q) => q.width > 0);
      if (!rects.length) continue;
      const u = { l: Math.min(...rects.map((q) => q.left)), r: Math.max(...rects.map((q) => q.right)), t: Math.min(...rects.map((q) => q.top)), b: Math.max(...rects.map((q) => q.bottom)) };
      const tops = []; rects.forEach((q) => { if (!tops.some((t) => Math.abs(t - q.top) < 3)) tops.push(q.top); });
      const kindOf = el.classList.contains('ms') ? 'icon' : (el.classList.contains('em') ? 'emoji' : 'text');
      items.push({ s: short(s, 40), full: s, kind: kindOf, fs: parseFloat(cs.fontSize), fw: cs.fontWeight, l: u.l, r: u.r, t: u.t, b: u.b, lines: tops.length, el });
    }
    o.items = items.map((i) => ({ text: i.s, kind: i.kind, fs: i.fs, fw: i.fw, l: r2(i.l), r: r2(i.r), t: r2(i.t), b: r2(i.b), lines: i.lines }));

    // Icons and emoji that did not render.
    items.forEach((i) => {
      if (i.kind === 'icon' && (i.r - i.l) > i.fs * 1.6) o.flags.push('ICON SHOWN AS NAME "' + i.s + '" width ' + f1(i.r - i.l) + ' for ' + i.fs + 'px icon');
      if (i.kind === 'emoji') { const e = emojiColoured(i.full.replace(/\s/g, '').slice(0, 4), Math.round(i.fs)); if (e.ink < 60 || e.col < 40) o.flags.push('EMOJI MAYBE EMPTY BOX "' + i.s + '" ink ' + e.ink + ' coloured ' + e.col); }
    });

    // Controls.
    const ctrls = Array.from(panel.querySelectorAll(CTRL)).filter((el) => vis(el) && !srOnly(el) && !(el.tagName === 'INPUT' && el.type === 'hidden'));
    // A control nested inside another control is reported once, as the outer one.
    const ctrlRows = ctrls.map((el) => { const b = rect(el); return { el, l: b.l, r: b.r, t: b.t, b: b.b, w: b.w, h: b.h, label: labelOf(el), tag: el.tagName.toLowerCase() }; });
    o.controls = ctrlRows.map((c) => ({ tag: c.tag, label: c.label, l: r2(c.l), r: r2(c.r), t: r2(c.t), b: r2(c.b), w: r2(c.w), h: r2(c.h) }));
    ctrlRows.forEach((c) => { if (c.w < 36 || c.h < 36) o.flags.push('TAP TARGET ' + c.w.toFixed(1) + 'x' + c.h.toFixed(1) + ' "' + c.label + '" (' + c.tag + ' x' + r2(c.l) + '-' + r2(c.r) + ' y' + r2(c.t) + '-' + r2(c.b) + ')'); });

    // Gaps to the panel's left and right edges (text ink and control boxes).
    const edgeItems = items.map((i) => ({ name: '"' + i.s + '"', l: i.l, r: i.r })).concat(ctrlRows.map((c) => ({ name: '[' + c.label + ']', l: c.l, r: c.r })));
    const minBy = (arr, fn) => arr.reduce((m, x) => (m === null || fn(x) < fn(m) ? x : m), null);
    const mL = minBy(edgeItems, (x) => x.l - pb.l), mR = minBy(edgeItems, (x) => pb.r - x.r);
    o.gaps = { toPanelEdgeL: r2(mL.l - pb.l), byL: mL.name, toPanelEdgeR: r2(pb.r - mR.r), byR: mR.name, toContentEdgeL: r2(mL.l - inL), toContentEdgeR: r2(inR - mR.r) };
    // Same, split for text only and controls only.
    const tL = minBy(items, (x) => x.l - pb.l), tR = minBy(items, (x) => pb.r - x.r);
    if (tL) { o.gaps.textMinL = r2(tL.l - pb.l); o.gaps.textMinR = r2(pb.r - tR.r); }
    if (ctrlRows.length) { const cL = minBy(ctrlRows, (x) => x.l - pb.l), cR = minBy(ctrlRows, (x) => pb.r - x.r); o.gaps.ctrlMinL = r2(cL.l - pb.l); o.gaps.ctrlMinR = r2(pb.r - cR.r); }

    // Direct blocks (rows) of the panel.
    const blocks = Array.from(panel.children).filter((c) => vis(c) && !srOnly(c) && rect(c).h > 0);
    const rows = blocks.map((c) => {
      const b = rect(c);
      const cs2 = ctrlRows.filter((x) => c === x.el || c.contains(x.el));
      const ts = items.filter((x) => c.contains(x.el));
      const decor = !cs2.length && !ts.length;
      const lab = c.getAttribute('aria-label') || (ts[0] ? ts[0].s : '') || (decor ? 'decor' : c.tagName.toLowerCase());
      return { el: c, label: short(lab, 24), tag: c.tagName.toLowerCase(), l: b.l, r: b.r, t: b.t, b: b.b, h: b.h, hasCtrl: cs2.length > 0, decor, ctrlL: cs2.length ? Math.min(...cs2.map((x) => x.l)) : null, ctrlR: cs2.length ? Math.max(...cs2.map((x) => x.r)) : null, inkL: ts.length ? Math.min(...ts.map((x) => x.l)) : null, inkR: ts.length ? Math.max(...ts.map((x) => x.r)) : null, nCtrl: cs2.length };
    });
    const mode = (vals) => { const m = {}; vals.forEach((v) => { const k = r2(v); m[k] = (m[k] || 0) + 1; }); let best = null; Object.keys(m).forEach((k) => { if (best === null || m[k] > m[best]) best = k; }); return best === null ? null : Number(best); };
    const real = rows.filter((x) => !x.decor);
    const mBoxL = mode(real.map((x) => x.l)), mBoxR = mode(real.map((x) => x.r));
    const crow = rows.filter((x) => x.hasCtrl);
    const mCL = mode(crow.map((x) => x.ctrlL)), mCR = mode(crow.map((x) => x.ctrlR));
    o.rows = rows.map((x) => ({ label: x.label, tag: x.tag, l: r2(x.l), r: r2(x.r), t: r2(x.t), b: r2(x.b), h: r2(x.h), nCtrl: x.nCtrl, ctrlL: x.ctrlL === null ? null : r2(x.ctrlL), ctrlR: x.ctrlR === null ? null : r2(x.ctrlR), inkL: x.inkL === null ? null : r2(x.inkL), inkR: x.inkR === null ? null : r2(x.inkR), decor: x.decor }));
    o.rowModes = { boxL: mBoxL, boxR: mBoxR, ctrlL: mCL, ctrlR: mCR };
    real.forEach((x) => { if (Math.abs(r2(x.l) - mBoxL) > 0.5 || Math.abs(r2(x.r) - mBoxR) > 0.5) o.flags.push('ROW EDGES "' + x.label + '" box x' + r2(x.l) + '-' + r2(x.r) + ' vs most rows x' + mBoxL + '-' + mBoxR); });
    crow.forEach((x) => { if (Math.abs(r2(x.ctrlL) - mCL) > 0.5 || Math.abs(r2(x.ctrlR) - mCR) > 0.5) o.flags.push('CONTROL ROW EDGES "' + x.label + '" controls x' + r2(x.ctrlL) + '-' + r2(x.ctrlR) + ' vs most control rows x' + mCL + '-' + mCR); });

    // Clipped / ellipsised text (scrollWidth > clientWidth), also vertical clipping.
    all.forEach((el) => {
      const cs = getComputedStyle(el);
      const hasText = Array.from(el.childNodes).some((n) => n.nodeType === 3 && n.nodeValue.trim()) || el.tagName === 'INPUT';
      if (el.clientWidth > 0 && el.scrollWidth > el.clientWidth + 1 && hasText) {
        const how = cs.textOverflow === 'ellipsis' ? 'ELLIPSISED' : (cs.overflowX !== 'visible' ? 'CLIPPED' : 'OVERFLOWS ITS BOX');
        o.flags.push(how + ' "' + labelOf(el) + '" needs ' + el.scrollWidth + ' has ' + el.clientWidth + (el.classList.contains('ms') ? ' (icon name not turned into a glyph)' : ''));
      }
      if (el.clientHeight > 0 && !el.classList.contains('ms') && cs.overflowY !== 'visible' && el.scrollHeight > el.clientHeight + 1 && hasText) o.flags.push('CLIPPED VERTICALLY "' + labelOf(el) + '" needs ' + el.scrollHeight + ' has ' + el.clientHeight);
    });

    // Wrapping: a run on two lines or more where its peers are one line.
    const sig = (i) => i.fs + '/' + i.fw + '/' + i.el.tagName + '/' + (i.el.className || '');
    items.filter((i) => i.kind === 'text' && i.lines > 1).forEach((i) => {
      const gp = i.el.parentElement && i.el.parentElement.parentElement;
      const peers = items.filter((q) => q !== i && q.kind === 'text' && sig(q) === sig(i) && (q.el.parentElement === i.el.parentElement || (gp && q.el.parentElement && q.el.parentElement.parentElement === gp)));
      const one = peers.filter((q) => q.lines === 1);
      if (one.length) o.flags.push('WRAPS "' + i.s + '" on ' + i.lines + ' lines, ' + one.length + ' of ' + peers.length + ' peers on one line');
      else o.notes.push('wraps "' + i.s + '" ' + i.lines + ' lines' + (peers.length ? ' (all ' + peers.length + ' peers wrap too)' : ' (no peers)'));
    });

    // Overlaps: text vs text, text vs control, control vs control.
    const ov = (a, b) => ({ x: Math.min(a.r, b.r) - Math.max(a.l, b.l), y: Math.min(a.b, b.b) - Math.max(a.t, b.t) });
    for (let a = 0; a < items.length; a++) for (let c = a + 1; c < items.length; c++) {
      const p = items[a], q = items[c]; if (p.el === q.el || p.el.contains(q.el) || q.el.contains(p.el)) continue;
      const d = ov(p, q); if (d.x > 1 && d.y > 2) o.flags.push('OVERLAP text "' + p.s + '" x "' + q.s + '" by ' + f1(d.x) + 'x' + f1(d.y));
    }
    items.forEach((t) => ctrlRows.forEach((c) => {
      if (c.el.contains(t.el)) return;
      const d = ov(t, c); if (d.x > 1 && d.y > 2) o.flags.push('OVERLAP text "' + t.s + '" x control [' + c.label + '] by ' + f1(d.x) + 'x' + f1(d.y));
    }));
    for (let a = 0; a < ctrlRows.length; a++) for (let c = a + 1; c < ctrlRows.length; c++) {
      const p = ctrlRows[a], q = ctrlRows[c]; if (p.el.contains(q.el) || q.el.contains(p.el)) continue;
      const d = ov(p, q); if (d.x > 1 && d.y > 1) o.flags.push('OVERLAP control [' + p.label + '] x [' + q.label + '] by ' + f1(d.x) + 'x' + f1(d.y));
    }
    // Text sticking out of the control that holds it, and tight text inside a control.
    items.forEach((t) => {
      const c = ctrlRows.filter((x) => x.el.contains(t.el)).sort((a, b) => (a.w * a.h) - (b.w * b.h))[0];
      if (!c) return;
      if (t.l < c.l - 0.5 || t.r > c.r + 0.5 || t.t < c.t - 1 || t.b > c.b + 1) o.flags.push('TEXT OUTSIDE ITS CONTROL "' + t.s + '" x' + r2(t.l) + '-' + r2(t.r) + ' y' + r2(t.t) + '-' + r2(t.b) + ' control [' + c.label + '] x' + r2(c.l) + '-' + r2(c.r) + ' y' + r2(c.t) + '-' + r2(c.b));
      else if (t.kind === 'text' && (t.l - c.l < 3 || c.r - t.r < 3) && c.w > 60 && !/rgba?\(\d+, \d+, \d+, 0\)|transparent/.test(getComputedStyle(c.el).backgroundColor)) o.notes.push('tight "' + t.s + '" ' + r2(t.l - c.l) + 'px left / ' + r2(c.r - t.r) + 'px right inside [' + c.label + ']');
    });

    // Anything sticking out of the panel (topmost offender only).
    const out = [];
    all.forEach((el) => {
      const b = rect(el); if (b.w === 0 && b.h === 0) return;
      const sides = [];
      if (b.l < pb.l - 0.5) sides.push('left by ' + f1(pb.l - b.l)); if (b.r > pb.r + 0.5) sides.push('right by ' + f1(b.r - pb.r)); if (b.t < pb.t - 0.5) sides.push('top by ' + f1(pb.t - b.t)); if (b.b > pb.b + 0.5) sides.push('bottom by ' + f1(b.b - pb.b));
      if (sides.length) out.push({ el, sides });
    });
    out.filter((x) => !out.some((y) => y !== x && y.el.contains(x.el))).forEach((x) => o.flags.push('STICKS OUT OF PANEL ' + x.el.tagName.toLowerCase() + ' "' + labelOf(x.el) + '" ' + x.sides.join(', ')));
    items.forEach((i) => { if (i.l < pb.l - 0.5 || i.r > pb.r + 0.5 || i.t < pb.t - 0.5 || i.b > pb.b + 0.5) { if (!out.some((y) => y.el.contains(i.el))) o.flags.push('TEXT STICKS OUT OF PANEL "' + i.s + '"'); } });

    o.flags = o.flags.slice(0, 60); o.notes = o.notes.slice(0, 30);
    document.getElementById('out').textContent = JSON.stringify(o);
  }
  const loads = [document.fonts.load('800 20px "Plus Jakarta Sans"', 'Expense 0123'), document.fonts.load('500 12px "Plus Jakarta Sans"', 'Total'), document.fonts.load('600 12px "Plus Jakarta Sans"', 'Total'), document.fonts.load('700 12px "Plus Jakarta Sans"', 'Total'), document.fonts.load('24px "Material Symbols Rounded"', 'home'), document.fonts.load('22px "Noto Color Emoji"', '🏠')];
  Promise.all(loads.map((p) => p.catch(() => null))).then(() => document.fonts.ready).then(() => setTimeout(() => { try { run(); } catch (e) { document.getElementById('out').textContent = JSON.stringify({ error: String((e && e.stack) || e) }); } }, 700));
})();
