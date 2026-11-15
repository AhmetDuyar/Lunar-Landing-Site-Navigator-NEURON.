/* NEURON Lunar Navigator: site dossier.
   Opens when a pin (candidate site, custom point or previous landing) is clicked.
   All values arrive from the server (R/dossier.R); this file only draws them. */
(function () {
  'use strict';
  const LO = [232, 100, 26], MID = [245, 240, 224], HI = [31, 128, 77];
  const ramp = t => {
    t = Math.max(0, Math.min(1, t));
    const [a, b, u] = t < 0.5 ? [LO, MID, t * 2] : [MID, HI, (t - 0.5) * 2];
    return [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u];
  };
  const css = c => `rgb(${c.map(Math.round).join(',')})`;
  const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const fmt = (v, u) => (v === null || v === undefined || Number.isNaN(v)) ? 'n/a' : `${(+v).toLocaleString('en-US', { maximumFractionDigits: 1 })}${u === '°' ? '°' : ' ' + u}`;
  const ord = n => n + (['th', 'st', 'nd', 'rd'][(n % 100 > 10 && n % 100 < 14) ? 0 : (n % 10 < 4 ? n % 10 : 0)] || 'th');
  const arr = x => Array.isArray(x) ? x : (x === null || x === undefined || x === '' ? [] : [x]);
  const OUTCOME = { landed: 'Landed', tipped: 'Landed, tipped over', crashed: 'Crashed', planned: 'Planned' };

  let root = null, data = null, layer = 'slope';

  function shell() {
    if (root) return root;
    root = document.createElement('div');
    root.className = 'dossier'; root.id = 'dossier';
    root.innerHTML = `<div class="dz-backdrop"></div>
      <div class="dz-panel" role="dialog" aria-modal="true" aria-labelledby="dz-title">
        <button type="button" class="dz-close" aria-label="Close">&times;</button>
        <div class="dz-body"></div>
      </div>`;
    document.body.append(root);
    root.addEventListener('click', e => {
      if (e.target.closest('.dz-close') || e.target.classList.contains('dz-backdrop')) close();
      const t = e.target.closest('.dz-tab'); if (t) { layer = t.dataset.layer; drawMap(); }
      const n = e.target.closest('[data-open]'); if (n) window.Shiny?.setInputValue('dossier_open', { id: n.dataset.open, t: Date.now() }, { priority: 'event' });
      const r = e.target.closest('.dz-ref'); if (r) { close(); }
    });
    return root;
  }
  function close() { root?.classList.remove('is-open'); }
  document.addEventListener('keydown', e => { if (e.key === 'Escape') close(); });

  /* ---------------- sections ---------------- */
  function header(d) {
    let kicker;
    if (d.kind === 'landing') kicker = `Previous landing · ${esc(d.landing.date.slice(0, 4))} · ${esc(OUTCOME[d.landing.outcome])}`;
    else if (d.kind === 'custom') kicker = 'Custom point';
    else kicker = 'Candidate landing site';
    const lat = d.lat < 0 ? `${Math.abs(d.lat).toFixed(4)}° S` : `${d.lat.toFixed(4)}° N`;
    const lon = d.lon > 180 ? `${(360 - d.lon).toFixed(4)}° W` : `${d.lon.toFixed(4)}° E`;
    return `<header class="dz-head">
      <div class="dz-kicker ${d.kind}">${kicker}</div>
      <h2 id="dz-title">${esc(d.name)}</h2>
      <div class="dz-sub">${lat}, ${lon}${d.status ? ' · ' + esc(d.status) : ''}${d.landing && d.kind === 'landing' ? ' · ' + esc(d.landing.agency) : ''}</div>
    </header>`;
  }

  function verdict(d) {
    const r = d.robust;
    const kScore = d.scorable ? `<div class="dz-kpi"><div class="v">${Math.round(d.score)}<small> / 100</small></div><div class="l">landing score, current weights</div></div>` :
      `<div class="dz-kpi"><div class="v">n/a</div><div class="l">no terrain data at this latitude</div></div>`;
    const kRank = d.rank ? `<div class="dz-kpi"><div class="v">${ord(d.rank)}<small> of ${d.n_sites}</small></div><div class="l">among the published sites</div></div>` :
      (d.scorable ? `<div class="dz-kpi"><div class="v">${Math.round(d.site_range[0])} to ${Math.round(d.site_range[1])}</div><div class="l">scores of the published sites</div></div>` : '');
    const kRob = r ? `<div class="dz-kpi"><div class="v">${Math.round(r.hist[0])} %</div><div class="l">of ${r.scenarios.toLocaleString('en-US')} scenarios at rank 1</div></div>` : '';
    return `<section class="dz-verdict"><p class="dz-lead">${esc(d.verdict)}</p><div class="dz-kpis">${kScore}${kRank}${kRob}</div></section>`;
  }

  function landingBox(d) {
    const L = d.landing; if (!L) return '';
    return `<section class="dz-landing ${L.outcome}">
      <div class="dz-lhead"><span class="dz-lmark ${L.outcome}"></span><strong>${esc(L.mission)}</strong>
        <span>${esc(L.date)} · ${esc(OUTCOME[L.outcome])}${L.crewed ? ' · crewed' : ''}</span></div>
      <p>${esc(L.note)}</p>
      ${arr(L.checks).length ? `<ul>${arr(L.checks).map(c => `<li>${esc(c)}</li>`).join('')}</ul>` : ''}
      <div class="dz-src">Position: NASA NSSDCA lander table, LROC measurements <a href="#" class="ref dz-ref" data-ref="${esc(L.ref)}">[${d.refs.nssdca}]</a></div>
    </section>`;
  }

  /* criteria strips: every compared place on one axis per criterion */
  function strips(d) {
    const W = 470, rowH = 50, L = 0, R = W - 8, top = 8;
    let svg = `<svg class="dz-strips" viewBox="0 0 ${W} ${d.criteria.length * rowH + 6}" width="100%">`;
    d.criteria.forEach((c, i) => {
      const y = top + i * rowH + 26;
      const vals = arr(c.others).map(o => o.value).concat([c.value]);
      let lo = Math.min(...vals), hi = Math.max(...vals);
      if (hi === lo) { lo -= 1; hi += 1; }
      const pad = (hi - lo) * 0.08; lo -= pad; hi += pad;
      // the "better" end is always drawn on the right
      const X = v => c.better === 'high' ? L + (v - lo) / (hi - lo) * (R - L) : R - (v - lo) / (hi - lo) * (R - L);
      svg += `<g><title>${esc(c.why)}</title>
        <text x="0" y="${y - 14}" class="s-lab">${esc(c.label)}</text>
        <text x="${R}" y="${y - 14}" class="s-place" text-anchor="end">${ord(c.place)} of ${c.of} · better →</text>
        <line x1="${L}" x2="${R}" y1="${y}" y2="${y}" class="s-axis"/>`;
      arr(c.others).forEach(o => { svg += `<circle cx="${X(o.value)}" cy="${y}" r="4.2" class="s-oth"><title>${esc(o.name)}: ${fmt(o.value, c.unit)}</title></circle>`; });
      const x = X(c.value);
      svg += `<circle cx="${x}" cy="${y}" r="7" class="s-me"/>
        <text x="${Math.min(Math.max(x, 26), R - 26)}" y="${y + 19}" class="s-val" text-anchor="middle">${fmt(c.value, c.unit)}</text></g>`;
    });
    return svg + '</svg>';
  }

  /* exact score decomposition: score = sum(weight x value) */
  function contrib(d) {
    return `<div class="dz-contrib">${d.criteria.map(c => `
      <div class="c-row" title="${esc(c.why)}">
        <span class="c-lab">${esc(c.label)}</span>
        <span class="c-track"><span class="c-fill" style="width:${c.value}%"></span></span>
        <span class="c-num">${Math.round(100 * c.weight)} % × ${Math.round(c.value)} % = <b>${c.contrib.toFixed(1)}</b></span>
      </div>`).join('')}
      <div class="c-row c-sum"><span class="c-lab">Score</span><span></span><span class="c-num"><b>${d.score.toFixed(1)}</b> / 100</span></div>
      <p class="dz-note">Bar = value of the criterion (0 to 100 %). Points = weight × value; the score is their sum, so it never depends on which other places are compared.</p>
    </div>`;
  }

  function robustChart(d) {
    const r = d.robust; if (!r) return '';
    const W = 300, H = 96, bw = W / r.hist.length;
    const mx = Math.max(...r.hist, 1);
    let s = `<svg viewBox="0 0 ${W} ${H + 20}" width="100%" class="dz-rh">`;
    r.hist.forEach((v, i) => {
      const h = (v / mx) * (H - 16);
      s += `<rect x="${i * bw + 6}" y="${H - h}" width="${bw - 12}" height="${h}" class="${i === 0 ? 'b1' : 'bn'}"><title>Rank ${i + 1}: ${v} %</title></rect>
        <text x="${i * bw + bw / 2}" y="${H - h - 4}" text-anchor="middle" class="t-v">${v >= 0.5 ? Math.round(v) + ' %' : v > 0 ? '<1 %' : ''}</text>
        <text x="${i * bw + bw / 2}" y="${H + 14}" text-anchor="middle" class="t-x">Rank ${i + 1}</text>`;
    });
    return `<h4>How stable is the rank?</h4>${s}</svg>
      <p class="dz-note">Share of ${r.scenarios.toLocaleString('en-US')} scenarios (every weighting of the three criteria × slope limits ${arr(r.limits).join('/')}°) in which this site reaches each rank among the published sites.</p>`;
  }

  /* local terrain window from the original rasters */
  function terrain(d) {
    const c = d.crop;
    if (!c) return `<section class="dz-sec"><h3>Ground truth around the site</h3>
      <p class="dz-note">High-resolution windows from the original LOLA and Mazarico rasters are prepared for the published candidate sites and the south-polar landings (data-raw/build_dossiers.R). ${d.kind === 'custom' ? 'For a custom point the comparison above uses the ~1.5 km analysis grid.' : 'This place lies outside the 80 to 90° S LOLA coverage.'}</p></section>`;
    const a = c.area_2km, p = c.point, b = c.best_nearby;
    const bestTxt = b ? (b.dist_m < 120 ? 'The point itself is the best flat spot within 3 km.' :
      `Best flat spot within 3 km (slope below 5° everywhere within 100 m, highest mean of Sun and Earth visibility): ${(b.dist_m / 1000).toFixed(1)} km away, slope ${b.slope}°, Sun ${b.sun} %, Earth ${b.earth} %. Marked ◇ on the map.`) : 'No spot within 3 km stays below 5° within 100 m.';
    return `<section class="dz-sec dz-terrain">
      <div class="dz-sec-head"><h3>Ground truth around the site</h3>
        <div class="dz-tabs">${[['slope', 'Slope'], ['sun', 'Sun'], ['earth', 'Earth'], ['relief', 'Relief']].map(([k, l]) => `<button type="button" class="dz-tab${k === layer ? ' on' : ''}" data-layer="${k}">${l}</button>`).join('')}</div></div>
      <p class="dz-banner">One pixel is 80 m. That is enough to compare areas, but boulders and craters smaller than about 100 m are invisible here (IM-2 Athena tipped over in one). Final hazard checks need 1 to 5 m data.</p>
      <div class="dz-tgrid">
        <div class="dz-mapwrap">
          <canvas class="dz-map" width="${c.n}" height="${c.n}"></canvas>
          <svg class="dz-over" viewBox="0 0 400 400"></svg>
          <div class="dz-read">Move over the map</div>
          <div class="dz-leg"></div>
        </div>
        <div class="dz-tside">
          <div class="dz-stats">
            <div><b>${fmt(p.slope, '°')}</b><span>slope at the point</span></div>
            <div><b>${fmt(p.slope_max_100m, '°')}</b><span>steepest within 100 m</span></div>
            <div><b>${fmt((p.flat_1km || {})['lt' + d.slope_limit], '%')}</b><span>of the ground within 1 km below ${d.slope_limit}° (used in the score)</span></div>
            <div><b>${fmt(a.psr_pct, '%')}</b><span>permanent shadow within 2 km</span></div>
            <div><b>${fmt(p.sun, '%')}</b><span>long-term Sun at the point</span></div>
            <div><b>${fmt(p.earth, '%')}</b><span>long-term Earth at the point</span></div>
          </div>
          <h4>Slope within 2 km</h4>
          ${slopeHist(a.slope_hist, d.slope_limit)}
          <p class="dz-note">${esc(bestTxt)}</p>
        </div>
      </div>
      <p class="dz-src">12.8 × 12.8 km window. Slope and relief: LOLA 80 m <a href="#" class="ref dz-ref" data-ref="lola_pgda">[${d.refs.lola}]</a>. Sun and Earth: 18.6-year averages with terrain, Mazarico et al. 120 m <a href="#" class="ref dz-ref" data-ref="mazarico2011">[${d.refs.mazarico}]</a>. Circle: 2 km radius.${c.slope.some(v => v < 0) ? ' Grey: outside the 80 to 90° S LOLA coverage.' : ''}</p>
    </section>`;
  }

  function slopeHist(h, limit) {
    const W = 300, H = 90, n = h.length, bw = W / n, mx = Math.max(...h, 1);
    let s = `<svg viewBox="0 0 ${W} ${H + 18}" width="100%" class="dz-sh">`;
    h.forEach((v, i) => {
      const hh = v / mx * (H - 4);
      s += `<rect x="${i * bw + 0.5}" y="${H - hh}" width="${bw - 1}" height="${hh}" fill="${css(ramp(1 - Math.min(1, i / (2 * limit))))}"><title>${i}${i === n - 1 ? '+' : ''}°: ${v} px</title></rect>`;
    });
    const xl = limit * bw;
    s += `<line x1="${xl}" x2="${xl}" y1="0" y2="${H}" class="sh-lim"/><text x="${xl + 3}" y="10" class="t-v">limit ${limit}°</text>`;
    [0, 10, 20, 30].forEach(t => { s += `<text x="${Math.min(t * bw, W - 2)}" y="${H + 14}" class="t-x" text-anchor="${t === 30 ? 'end' : t === 0 ? 'start' : 'middle'}">${t}°+</text>`.replace(/(\d+)°\+/, (m0, a) => +a === 30 ? '30°+' : a + '°'); });
    return s + '</svg>';
  }

  function drawMap() {
    if (!data?.crop || !root) return;
    root.querySelectorAll('.dz-tab').forEach(t => t.classList.toggle('on', t.dataset.layer === layer));
    const c = data.crop, n = c.n, cv = root.querySelector('.dz-map'); if (!cv) return;
    const ctx = cv.getContext('2d'), img = ctx.createImageData(n, n), lim = data.slope_limit || 8;
    for (let i = 0; i < n * n; i++) {
      const rel = c.relief[i] < 0 ? 128 : c.relief[i];
      let col;
      if (layer === 'relief') col = [rel, rel, rel];
      else {
        const raw = c[layer][i];
        if (raw < 0) col = [200, 200, 200];
        else {
          const v = raw / 10;
          const t = layer === 'slope' ? 1 - Math.min(1, v / (2 * lim)) : v / 100;
          const k = 0.62 + 0.38 * rel / 255;
          col = ramp(t).map(x => x * k);
        }
      }
      img.data.set([col[0], col[1], col[2], 255], i * 4);
    }
    ctx.putImageData(img, 0, 0);
    // overlay
    const S = 400, px = S / (2 * c.half_m), cx = S / 2, cy = S / 2;
    let o = `<circle cx="${cx}" cy="${cy}" r="${2000 * px}" class="o-ring"/>`;
    if (c.best_nearby && c.best_nearby.dist_m >= 120) {
      const bx = cx + c.best_nearby.dx_m * px, by = cy - c.best_nearby.dy_m * px;
      o += `<rect x="${bx - 6}" y="${by - 6}" width="12" height="12" transform="rotate(45 ${bx} ${by})" class="o-best"/>`;
    }
    o += `<circle cx="${cx}" cy="${cy}" r="8" class="o-me"/><circle cx="${cx}" cy="${cy}" r="2.5" class="o-dot"/>`;
    const [ux, uy] = c.pole_dir;
    o += `<g transform="translate(${S - 34},34)"><circle r="20" class="o-comp"/><line x1="${-ux * 12}" y1="${uy * 12}" x2="${ux * 12}" y2="${-uy * 12}" class="o-arrow" marker-end="url(#dz-ah)"/><text y="34" text-anchor="middle" class="o-t">pole</text></g>
      <defs><marker id="dz-ah" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="5" markerHeight="5" orient="auto"><path d="M0 0L10 5L0 10z" fill="#141414"/></marker></defs>
      <g transform="translate(14,${S - 18})"><rect x="0" y="-5" width="${2000 * px}" height="5" class="o-sb"/><text x="0" y="-9" class="o-t">2 km</text></g>`;
    root.querySelector('.dz-over').innerHTML = o;
    // legend
    const leg = root.querySelector('.dz-leg');
    const stops = Array.from({ length: 11 }, (_, i) => css(ramp(layer === 'slope' ? 1 - i / 10 : i / 10))).join(',');
    leg.innerHTML = layer === 'relief' ? '<span>LOLA hillshade</span>' :
      `<span>${layer === 'slope' ? '0°' : '0 %'}</span><i style="background:linear-gradient(90deg,${stops})"></i><span>${layer === 'slope' ? (2 * lim) + '°+' : '100 %'}</span>`;
  }

  function bindHover() {
    const wrap = root.querySelector('.dz-mapwrap'); if (!wrap) return;
    const read = root.querySelector('.dz-read'), c = data.crop;
    wrap.addEventListener('mousemove', e => {
      const b = wrap.getBoundingClientRect();
      const fx = (e.clientX - b.left) / b.width, fy = (e.clientY - b.top) / b.height;
      if (fx < 0 || fy < 0 || fx >= 1 || fy >= 1) return;
      const i = Math.floor(fy * c.n) * c.n + Math.floor(fx * c.n);
      const dx = (fx - 0.5) * 2 * c.half_m, dy = (0.5 - fy) * 2 * c.half_m;
      const v = (a, k) => a[i] < 0 ? 'n/a' : (a[i] / k).toFixed(1);
      read.textContent = `${(Math.hypot(dx, dy) / 1000).toFixed(2)} km from the point · slope ${v(c.slope, 10)}° · Sun ${v(c.sun, 10)} % · Earth ${v(c.earth, 10)} %`;
    });
    wrap.addEventListener('mouseleave', () => { read.textContent = 'Move over the map'; });
  }

  function yearChart(d) {
    const y = arr(d.year); if (!y.length) return '';
    const W = 560, H = 130, X0 = 38, gw = (W - X0) / y.length, bw = (gw - 10) / 2;
    let s = `<svg viewBox="0 -10 ${W} ${H + 32}" width="100%" class="dz-yr">`;
    [0, 50, 100].forEach(t => { const yy = H - t / 100 * H; s += `<line x1="${X0}" x2="${W}" y1="${yy}" y2="${yy}" class="g"/><text x="${X0 - 6}" y="${yy + 4}" text-anchor="end" class="t-x">${t} %</text>`; });
    y.forEach((m, i) => {
      const x = X0 + i * gw + 5;
      s += `<rect x="${x}" y="${H - m.sun / 100 * H}" width="${bw}" height="${m.sun / 100 * H}" class="ys"><title>${m.label}: Sun ${m.sun} %, longest night ${m.night} h</title></rect>
        <rect x="${x + bw}" y="${H - m.earth / 100 * H}" width="${bw}" height="${m.earth / 100 * H}" class="ye"><title>${m.label}: Earth ${m.earth} %, longest blackout ${m.blackout} h</title></rect>
        <text x="${x + bw}" y="${H + 15}" text-anchor="middle" class="t-x">${m.label}</text>`;
    });
    return s + '</svg>';
  }

  function strip(d) {
    return `<div class="dz-strip"><canvas class="dz-hours" width="${d.window.strip.length}" height="1"></canvas></div>
      <div class="dz-strip-leg"><span><i class="k3"></i>Sun and Earth</span><span><i class="k1"></i>Sun only</span><span><i class="k2"></i>Earth only</span><span><i class="k0"></i>neither</span>
</div>
      ${d.window.best ? `<p class="dz-note">Longest period with Sun and Earth up together: from ${esc(d.window.best.start)} UTC for ${d.window.best.hours} h. Landing in this period gives light on the terrain and a live link to Earth.</p>` : '<p class="dz-note">No period with Sun and Earth up together in this window.</p>'}`;
  }
  function drawStrip() {
    const cv = root.querySelector('.dz-hours'); if (!cv) return;
    const s = data.window.strip, ctx = cv.getContext('2d'), img = ctx.createImageData(s.length, 1);
    const col = { 0: [20, 20, 20], 1: [249, 192, 154], 2: [150, 150, 150], 3: [242, 106, 27] };
    for (let i = 0; i < s.length; i++) img.data.set([...col[s[i]], 255], i * 4);
    ctx.putImageData(img, 0, 0);
  }

  function words(d) {
    const li = (a, cls) => a.map(t => `<li class="${cls}">${esc(t)}</li>`).join('');
    const near = arr(d.near).map(n => `<li><button type="button" class="dz-link" data-open="${esc(n.id)}"><span class="dz-lmark ${n.outcome}"></span>${esc(n.mission)}</button><span>${n.km < 0.5 ? 'at this point' : n.km.toLocaleString('en-US') + ' km'} · ${esc(n.date.slice(0, 4))} · ${esc(OUTCOME[n.outcome])}</span></li>`).join('');
    return `<section class="dz-sec dz-words">
      <div><h4>Speaks for it</h4><ul class="why-list">${li(arr(d.strengths), 'pro') || '<li class="muted">No criterion stands out in this window.</li>'}</ul></div>
      <div><h4>Speaks against it</h4><ul class="why-list">${li(arr(d.weaknesses), 'con') || '<li class="muted">No weak criterion in this window.</li>'}</ul></div>
      <div><h4>Previous landings nearby</h4><ul class="dz-near">${near}</ul></div>
    </section>`;
  }

  function render(d) {
    data = d; layer = 'slope';
    const body = shell().querySelector('.dz-body');
    body.innerHTML = header(d) + verdict(d) + landingBox(d) + `
      ${d.scorable ? `<section class="dz-sec"><h3>Why it scores what it scores</h3>
        <div class="dz-two">
          <div><h4>Compared with the published sites (hover a dot for its name)</h4>${strips(d)}<p class="dz-note">Terrain values from ${esc(d.terrain_src)}. All three are long-term averages with real terrain.</p></div>
          <div><h4>Where the points come from</h4>${contrib(d)}${robustChart(d)}</div>
        </div>
      </section>` : ''}` + terrain(d) + `
      <section class="dz-sec"><h3>When to land</h3>
        <p class="dz-banner">${d.window.horizon === 'smooth' ? 'Smooth-Moon geometry from JPL DE421 (no terrain model at this latitude).' : 'JPL DE421 with the real skyline from LOLA 80 m terrain (' + (d.window.horizon === 'exact' ? 'exact 360° horizon' : 'ML surrogate horizon') + ').'} These values tell you <b>when</b> Sun and Earth are up; the score above decides <b>where</b>. In this window: Sun ${fmt(d.window.sun, '%')}, Earth ${fmt(d.window.earth, '%')}, longest night ${fmt(d.window.night, 'h')}, longest blackout ${fmt(d.window.blackout, 'h')}.</p>
        <div class="dz-two">
          <div><h4>Next 12 lunar months from the mission start <span class="dz-key"><i class="ys"></i>Sun <i class="ye"></i>Earth</span></h4>${yearChart(d)}</div>
          <div><h4>Selected mission window, hour by hour <span class="dz-key">${esc(d.window.start)} to ${esc(d.window.end)}</span></h4>${strip(d)}</div>
        </div>
        <p class="dz-src">Geometry from JPL DE421 with the LOLA terrain horizon <a href="#" class="ref dz-ref" data-ref="de421">[${d.refs.de421}]</a>; long-term terrain values above.</p>
      </section>` + words(d);
    root.classList.add('is-open');
    body.scrollTop = 0;
    drawMap(); bindHover(); drawStrip();
  }

  (function bind() {
    if (!window.Shiny?.addCustomMessageHandler) { setTimeout(bind, 60); return; }
    window.Shiny.addCustomMessageHandler('lunar:dossier', render);
  })();
  window.openDossier = id => window.Shiny?.setInputValue('dossier_open', { id, t: Date.now() }, { priority: 'event' });
})();
