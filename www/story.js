/* NEURON Lunar Navigator: validation story.
   Reads the JSON block written by R/story.R and draws every chart as plain SVG.
   Charts animate once, when they scroll into view. */
(function () {
  'use strict';
  const NS = 'http://www.w3.org/2000/svg';
  const OR = '#f26a1b', INK = '#141414', MUT = '#7b7b7b', LINE = '#e3e3e0';
  const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const arr = x => Array.isArray(x) ? x : (x == null ? [] : [x]);
  const lin = (d0, d1, r0, r1) => v => r0 + (v - d0) / (d1 - d0) * (r1 - r0);
  const svg = (w, h, inner, cls = '') => `<svg class="st-svg ${cls}" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" style="max-width:100%;height:auto" role="img">${inner}</svg>`;
  const ticks = (a, b, n) => { const s = (b - a) / n; return Array.from({ length: n + 1 }, (_, i) => +(a + i * s).toFixed(6)); };
  let D = null;

  /* ------------ axes helper for scatter plots ------------ */
  function frame(W, H, m, xd, yd, xl, yl, nt = 4) {
    const X = lin(xd[0], xd[1], m.l, W - m.r), Y = lin(yd[0], yd[1], H - m.b, m.t);
    let g = '';
    ticks(yd[0], yd[1], nt).forEach(t => { g += `<line x1="${m.l}" x2="${W - m.r}" y1="${Y(t)}" y2="${Y(t)}" class="gl"/><text x="${m.l - 8}" y="${Y(t) + 4}" class="tk" text-anchor="end">${t.toLocaleString('en-US')}</text>`; });
    ticks(xd[0], xd[1], nt).forEach(t => { g += `<text x="${X(t)}" y="${H - m.b + 18}" class="tk" text-anchor="middle">${t.toLocaleString('en-US')}</text>`; });
    g += `<text x="${(m.l + W - m.r) / 2}" y="${H - 4}" class="ax" text-anchor="middle">${esc(xl)}</text>
      <text transform="translate(14 ${(m.t + H - m.b) / 2}) rotate(-90)" class="ax" text-anchor="middle">${esc(yl)}</text>`;
    return { X, Y, g };
  }

  /* ------------ charts ------------ */
  const charts = {
    pipeline() {
      const W = 1100, H = 380, cols = [30, 300, 590, 880], nw = 200, nh = 34;
      const N = {
        s: ['JPL DE421 ephemeris', 'LOLA 80 m slope + relief', 'Mazarico 2011 Sun + Earth', 'USGS Artemis regions 2024', 'NASA NSSDCA landings', 'Published site studies'],
        p: ['build_ephemeris.py', 'build_terrain.R', 'build_dossiers.R', 'analysis_regions.R', 'analysis_robustness.R', 'build_validation.R'],
        o: ['Hourly geometry 2026 to 2030', 'Terrain + light grids', 'Site windows, 12.8 km', 'Region statistics', 'Robustness, 40,000 runs', 'Validation checks'],
        a: ['Map layers', 'Score + ranking', 'Site dossier', 'Evidence + this page']
      };
      const y = (col, i) => { const n = N[col].length; return 30 + i * ((H - 60 - nh) / (n - 1)); };
      const pos = { s: 0, p: 1, o: 2, a: 3 };
      const L = [['s0', 'p0'], ['s1', 'p1'], ['s2', 'p1'], ['s1', 'p2'], ['s2', 'p2'], ['s4', 'p2'], ['s1', 'p3'], ['s2', 'p3'], ['s3', 'p3'], ['s5', 'p3'],
        ['s3', 'p5'], ['p0', 'o0'], ['p1', 'o1'], ['p2', 'o2'], ['p3', 'o3'], ['p4', 'o4'], ['p5', 'o5'], ['o3', 'p4'],
        ['o0', 'a0'], ['o1', 'a0'], ['o1', 'a1'], ['o2', 'a1'], ['o2', 'a2'], ['o0', 'a2'], ['o4', 'a3'], ['o5', 'a3'], ['o3', 'a3']];
      const at = k => ({ c: k[0], i: +k.slice(1) });
      let g = '';
      L.forEach(([a, b], k) => {
        const A = at(a), B = at(b);
        const x1 = cols[pos[A.c]] + nw, y1 = y(A.c, A.i) + nh / 2, x2 = cols[pos[B.c]], y2 = y(B.c, B.i) + nh / 2;
        const back = x2 < x1;
        const d = back ? `M${x1 - nw / 2} ${y1 + nh / 2} C${x1 - nw / 2} ${y1 + 40} ${x2 + nw / 2} ${y2 - 40} ${x2 + nw / 2} ${y2 - nh / 2}` :
          `M${x1} ${y1} C${x1 + 60} ${y1} ${x2 - 60} ${y2} ${x2} ${y2}`;
        g += `<path d="${d}" class="pl draw" pathLength="1" style="--i:${k}"/>`;
      });
      const head = ['Sources', 'Scripts', 'Outputs', 'App'];
      Object.keys(N).forEach((c, ci) => {
        g += `<text x="${cols[ci]}" y="16" class="ph">${head[ci]}</text>`;
        N[c].forEach((t, i) => {
          g += `<g class="pop" style="--i:${ci * 6 + i}"><rect x="${cols[ci]}" y="${y(c, i)}" width="${nw}" height="${nh}" rx="8" class="pn ${c}"/>
            <text x="${cols[ci] + 12}" y="${y(c, i) + nh / 2 + 4}" class="pt ${c}">${esc(t)}</text></g>`;
        });
      });
      return svg(W, H, g, 'pipe');
    },

    eph() {
      const e = D.eph, x = e.expected;
      const rows = [
        ['Sub-solar latitude', e.subsolar_latitude_range_deg, [-x.subsolar_latitude_abs_max_deg, x.subsolar_latitude_abs_max_deg], '°'],
        ['Libration in latitude', e.subearth_latitude_range_deg, [-x.optical_libration_lat_abs_max_deg, x.optical_libration_lat_abs_max_deg], '°'],
        ['Libration in longitude', e.subearth_longitude_range_deg, [-x.optical_libration_lon_abs_max_deg, x.optical_libration_lon_abs_max_deg], '°'],
        ['Earth-Moon distance', e.earth_moon_distance_range_km.map(v => v / 1000), x.earth_moon_centre_distance_km.map(v => v / 1000), ' Mm']];
      const W = 520, rh = 52;
      let g = '';
      rows.forEach(([lab, obs, exp, u], i) => {
        const pad = (exp[1] - exp[0]) * 0.12, X = lin(exp[0] - pad, exp[1] + pad, 170, W - 20), y = 26 + i * rh;
        g += `<text x="0" y="${y + 4}" class="rl">${lab}</text>
          <rect x="${X(exp[0])}" y="${y - 9}" width="${X(exp[1]) - X(exp[0])}" height="18" rx="9" class="env"/>
          <rect x="${X(obs[0])}" y="${y - 4}" width="${X(obs[1]) - X(obs[0])}" height="8" rx="4" class="obs grow" style="--i:${i}"/>
          <text x="${X(obs[0])}" y="${y + 24}" class="tk" text-anchor="middle">${(+obs[0]).toFixed(u === '°' ? 2 : 1)}${u}</text>
          <text x="${X(obs[1])}" y="${y + 24}" class="tk" text-anchor="middle">${(+obs[1]).toFixed(u === '°' ? 2 : 1)}${u}</text>`;
      });
      const err = Math.max(e.de421_vs_iau2015_sun_direction_max_deg, e.de421_vs_iau2015_earth_direction_max_deg), tol = x.de421_vs_iau_tolerance_deg;
      const GX = lin(0, tol, 170, W - 20), gy = 26 + rows.length * rh + 6;
      g += `<text x="0" y="${gy + 4}" class="rl">DE421 vs IAU 2015</text>
        <rect x="170" y="${gy - 9}" width="${W - 190}" height="18" rx="9" class="env"/>
        <rect x="170" y="${gy - 4}" width="${GX(err) - 170}" height="8" rx="4" class="obs grow" style="--i:5"/>
        <text x="${GX(err) + 6}" y="${gy + 4}" class="tk b">${err.toFixed(4)}°</text>
        <text x="${W - 20}" y="${gy + 24}" class="tk" text-anchor="end">tolerance ${tol}°</text>`;
      const leg = `<g transform="translate(170 ${gy + 40})"><rect width="22" height="10" rx="5" class="env"/><text x="28" y="9" class="tk">expected physical range</text>
        <rect x="190" y="1" width="22" height="8" rx="4" class="obs"/><text x="218" y="9" class="tk">computed 2026 to 2030</text></g>`;
      return svg(W, gy + 60, g + leg);
    },

    'earth-scatter'() {
      const P = arr(D.nr2.points), W = 420, H = 330, m = { l: 50, r: 16, t: 14, b: 44 };
      const { X, Y, g } = frame(W, H, m, [0, 60], [0, 60], 'Earth visibility, published (%)', 'Earth visibility, ours (%)', 6);
      let s = g + `<line x1="${X(0)}" y1="${Y(0)}" x2="${X(60)}" y2="${Y(60)}" class="one draw" pathLength="1"/>
        <text x="${X(57)}" y="${Y(57) - 8}" class="tk" text-anchor="end">1 : 1</text>`;
      P.forEach((p, i) => { s += `<circle cx="${X(p.pena_earth_pct)}" cy="${Y(p.earth_pct_ours_120m)}" r="6" class="pt-or pop" style="--i:${i}"><title>ID ${p.id}: published ${p.pena_earth_pct} %, ours ${(+p.earth_pct_ours_120m).toFixed(1)} %</title></circle>`; });
      const z = P.find(p => +p.pena_earth_pct === 0);
      if (z) s += `<text x="${X(0) + 12}" y="${Y(0) - 10}" class="tk">ID ${z.id}: 0 % in both</text>`;
      s += `<text x="${m.l + 10}" y="${m.t + 16}" class="big-t">r = ${(+D.nr2.stats.earth.pearson_r).toFixed(3)}</text>`;
      // C3 rank agreement
      const W2 = 300, m2 = { l: 56, r: 14, t: 14, b: 44 };
      const c3 = P.map(p => [+p.pena_c3 / 1000, +p.c3_ours / 1000]), mx = Math.ceil(Math.max(...c3.flat()) / 20) * 20;
      const f2 = frame(W2, H, m2, [60, mx], [60, mx], 'Published (×1000)', 'Ours (×1000)', 4);
      let s2 = f2.g + `<line x1="${f2.X(60)}" y1="${f2.Y(60)}" x2="${f2.X(mx)}" y2="${f2.Y(mx)}" class="one draw" pathLength="1"/>`;
      c3.forEach(([a, b], i) => { s2 += `<circle cx="${f2.X(a)}" cy="${f2.Y(b)}" r="5" class="pt-ink pop" style="--i:${i}"/>`; });
      s2 += `<text x="${m2.l + 8}" y="${m2.t + 16}" class="big-t">ρ = ${(+D.nr2.stats.c3.spearman_rho).toFixed(2)}</text>`;
      return `<div class="st-pair"><figure>${svg(W, H, s)}<figcaption>Earth visibility at the 12 published Nobile Rim 2 points</figcaption></figure>
        <figure>${svg(W2, H, s2)}<figcaption>Illumination × shadow criterion: same order, ours ~10 to 15 % higher (finer shadow map)</figcaption></figure></div>`;
    },

    consistency() {
      const R = arr(D.checks.consistency.rows), W = 520, rh = 34, top = 40;
      const XS = lin(-1, 1, 150, 320), XF = lin(-6, 6, 350, W - 10);
      let g = `<text x="150" y="16" class="ph">Δ mean slope (°)</text><text x="350" y="16" class="ph">Δ flat ground (pp)</text>
        <rect x="${XS(-0.5)}" y="24" width="${XS(0.5) - XS(-0.5)}" height="${R.length * rh + 6}" class="band"/>
        <rect x="${XF(-5)}" y="24" width="${XF(5) - XF(-5)}" height="${R.length * rh + 6}" class="band"/>
        <line x1="${XS(0)}" x2="${XS(0)}" y1="24" y2="${top + R.length * rh - 10}" class="zero"/><line x1="${XF(0)}" x2="${XF(0)}" y1="24" y2="${top + R.length * rh - 10}" class="zero"/>`;
      R.forEach((r, i) => {
        const y = top + i * rh;
        g += `<text x="0" y="${y + 4}" class="rl">${esc(r.name)}</text>
          <circle cx="${XS(r.d_slope)}" cy="${y}" r="6" class="pt-or pop" style="--i:${i}"><title>${r.slope_mean_terrain}° vs ${r.slope_mean_dossier}°</title></circle>
          <circle cx="${XF(r.d_flat8)}" cy="${y}" r="6" class="pt-ink pop" style="--i:${i + 5}"><title>${r.flat8_terrain} % vs ${r.flat8_dossier} %</title></circle>`;
      });
      [-1, 0, 1].forEach(t => { g += `<text x="${XS(t)}" y="${top + R.length * rh + 8}" class="tk" text-anchor="middle">${t > 0 ? '+' : ''}${t}</text>`; });
      [-5, 0, 5].forEach(t => { g += `<text x="${XF(t)}" y="${top + R.length * rh + 8}" class="tk" text-anchor="middle">${t > 0 ? '+' : ''}${t}</text>`; });
      // raw vs grid, nine regions
      const Rg = arr(D.regions), mets = [['raw_slope_median', 'grid_slope_median', 'Median slope (°)'], ['raw_flat_lt8', 'grid_flat_lt8', 'Flat below 8° (%)'],
        ['raw_sun_mean', 'grid_sun_mean', 'Sunlight (%)'], ['raw_earth_mean', 'grid_earth_mean', 'Earth in view (%)']];
      const minis = mets.map(([a, b, lab], k) => {
        const v = Rg.flatMap(r => [+r[a], +r[b]]), lo = Math.floor(Math.min(...v) / 5) * 5, hi = Math.ceil(Math.max(...v) / 5) * 5;
        const S = 130, mm = 18, X = lin(lo, hi, mm, S - 6), Y = lin(lo, hi, S - mm, 6);
        let s = `<rect x="${mm}" y="6" width="${S - mm - 6}" height="${S - mm - 6}" class="mini-bg"/><line x1="${X(lo)}" y1="${Y(lo)}" x2="${X(hi)}" y2="${Y(hi)}" class="one draw" pathLength="1"/>`;
        Rg.forEach((r, i) => { s += `<circle cx="${X(+r[a])}" cy="${Y(+r[b])}" r="3.6" class="pt-or pop" style="--i:${i + k * 3}"><title>${esc(r.region)}: ${(+r[a]).toFixed(1)} vs ${(+r[b]).toFixed(1)}</title></circle>`; });
        s += `<text x="${mm}" y="${S - 2}" class="tk">${lo}</text><text x="${S - 6}" y="${S - 2}" class="tk" text-anchor="end">${hi}</text>`;
        return `<figure class="mini">${svg(S, S, s)}<figcaption>${lab}</figcaption></figure>`;
      }).join('');
      return `<div class="st-pair"><figure>${svg(W, top + R.length * rh + 14, g)}<figcaption>Terrain pipeline vs dossier pipeline, 1 km around each site. Shaded: ±0.5° and ±5 pp.</figcaption></figure>
        <figure><div class="minis">${minis}</div><figcaption>Nine NASA regions: original pixels (x) vs the app's 1.5 km grid (y)</figcaption></figure></div>`;
    },

    illum() {
      const R = arr(D.illum.rows), W = 620, X = lin(0, 100, 150, W - 20);
      let g = '';
      [0, 25, 50, 75, 100].forEach(t => { g += `<line x1="${X(t)}" x2="${X(t)}" y1="10" y2="${30 + R.length * 50}" class="gl"/><text x="${X(t)}" y="${46 + R.length * 50}" class="tk" text-anchor="middle">${t} %</text>`; });
      R.forEach((r, i) => {
        const y = 34 + i * 50, a = r.mazarico_point_pct, b = r.mazarico_max_1km_pct, l = r.literature_pct;
        g += `<text x="0" y="${y + 4}" class="rl">${esc(r.name)}</text>
          <line x1="${X(Math.min(a, b, l))}" x2="${X(Math.max(a, b, l))}" y1="${y}" y2="${y}" class="dumb draw" pathLength="1"/>
          <circle cx="${X(a)}" cy="${y}" r="6" class="pt-hollow pop" style="--i:${i * 3}"><title>ours at the point ${a} %</title></circle>
          <circle cx="${X(b)}" cy="${y}" r="6" class="pt-or pop" style="--i:${i * 3 + 1}"><title>ours, best within 1 km ${b} %</title></circle>
          <rect x="${X(l) - 6}" y="${y - 6}" width="12" height="12" transform="rotate(45 ${X(l)} ${y})" class="pt-ink pop" style="--i:${i * 3 + 2}"><title>published ${l} %</title></rect>
          <text x="${X(l)}" y="${y - 14}" class="tk" text-anchor="middle">${l} %</text>`;
      });
      const ly = 70 + R.length * 50;
      g += `<g transform="translate(150 ${ly})"><circle cx="6" cy="0" r="5" class="pt-hollow"/><text x="16" y="4" class="tk">ours, at the point</text>
        <circle cx="150" cy="0" r="5" class="pt-or"/><text x="160" y="4" class="tk">ours, best within 1 km</text>
        <rect x="310" y="-5" width="10" height="10" transform="rotate(45 315 0)" class="pt-ink"/><text x="326" y="4" class="tk">published</text></g>`;
      return svg(W, ly + 14, g);
    },

    nasa() {
      const n = D.checks.nasa_regions, bins = arr(n.bins), hi = arr(n.hist_inside), ho = arr(n.hist_outside);
      const W = 560, H = 270, m = { l: 46, r: 12, t: 16, b: 44 };
      const mx = Math.ceil(Math.max(...hi, ...ho) / 5) * 5;
      const { X, Y, g } = frame(W, H, m, [0, 100], [0, mx], 'Landing score (equal weights, 8°)', 'Share of cells (%)', 5);
      const bw = X(5) - X(0);
      let s = g;
      hi.forEach((v, i) => { s += `<rect x="${X(bins[i]) + 1}" y="${Y(v)}" width="${bw - 2}" height="${Y(0) - Y(v)}" class="bar-or growy" style="--i:${i}"/>`; });
      let d = `M${X(0)} ${Y(0)}`; ho.forEach((v, i) => { d += ` L${X(bins[i])} ${Y(v)} L${X(bins[i + 1])} ${Y(v)}`; }); d += ` L${X(100)} ${Y(0)}`;
      s += `<path d="${d}" class="step draw" pathLength="1"/>`;
      s += `<line x1="${X(n.median_inside)}" x2="${X(n.median_inside)}" y1="${m.t}" y2="${Y(0)}" class="med-or"/><text x="${X(n.median_inside) + 5}" y="${m.t + 10}" class="tk b or">inside ${n.median_inside}</text>
        <line x1="${X(n.median_outside)}" x2="${X(n.median_outside)}" y1="${m.t}" y2="${Y(0)}" class="med-ink"/><text x="${X(n.median_outside) - 5}" y="${m.t + 10}" class="tk b" text-anchor="end">outside ${n.median_outside}</text>`;
      // per criterion medians
      const pc = n.per_criterion, keys = [['flat_lt8', 'Flat ground'], ['sun', 'Sunlight'], ['earth', 'Earth in view']];
      const W2 = 300, X2 = lin(0, 100, 100, W2 - 30);
      let s2 = '';
      keys.forEach(([k, lab], i) => {
        const y = 30 + i * 62, a = pc[k].inside, b = pc[k].outside;
        s2 += `<text x="0" y="${y + 10}" class="rl">${lab}</text>
          <rect x="100" y="${y}" width="${X2(a) - 100}" height="12" rx="3" class="bar-or grow" style="--i:${i}"/><text x="${X2(a) + 6}" y="${y + 10}" class="tk b or">${a} %</text>
          <rect x="100" y="${y + 16}" width="${X2(b) - 100}" height="12" rx="3" class="bar-ink grow" style="--i:${i + 3}"/><text x="${X2(b) + 6}" y="${y + 26}" class="tk b">${b} %</text>`;
      });
      return `<div class="st-pair"><figure>${svg(W, H, s)}<figcaption><span class="sw or"></span>inside NASA's nine regions (${n.n_inside.toLocaleString('en-US')} cells) · <span class="sw ink"></span>rest of ${Math.abs(n.lat_band[1]).toFixed(1)} to ${Math.abs(n.lat_band[0]).toFixed(1)}° S (${n.n_outside.toLocaleString('en-US')} cells) · AUC ${n.auc}</figcaption></figure>
        <figure>${svg(W2, 210, s2)}<figcaption>Median per criterion: NASA trades flat ground for light and Earth view</figcaption></figure></div>`;
    },

    landings() {
      const L = arr(D.landings), W = 600, X = lin(0, 15, 140, W - 30);
      let g = '';
      [0, 5, 10, 15].forEach(t => { g += `<line x1="${X(t)}" x2="${X(t)}" y1="10" y2="${36 + L.length * 64}" class="gl"/><text x="${X(t)}" y="${52 + L.length * 64}" class="tk" text-anchor="middle">${t}°</text>`; });
      g += `<line x1="${X(8)}" x2="${X(8)}" y1="6" y2="${36 + L.length * 64}" class="lim"/><text x="${X(8) + 5}" y="16" class="tk b">slope limit 8°</text>`;
      L.forEach((l, i) => {
        const y = 34 + i * 64;
        g += `<text x="0" y="${y + 6}" class="rl">${esc(l.name)}</text>
          <rect x="140" y="${y - 9}" width="${X(l.slope) - 140}" height="18" rx="4" class="${l.slope > 8 ? 'bar-or' : 'bar-ink'} grow" style="--i:${i}"/>
          ${X(l.slope) - 140 > 130 ? `<text x="${X(l.slope) - 6}" y="${y + 4}" class="tk b ${l.slope > 8 ? 'on-or' : 'on-ink'}" text-anchor="end">${l.slope}° at the point</text>`
            : `<text x="${X(l.slope) + 6}" y="${y + 4}" class="tk b">${l.slope}° at the point</text>`}
          <text x="140" y="${y + 24}" class="tk">steepest within 100 m ${l.slope_max_100m}° · mean within 1 km ${(+l.slope_mean_1km).toFixed(1)}°</text>`;
        if (l.id === 'im1') g += `<rect x="${X(12) - 6}" y="${y - 6}" width="12" height="12" transform="rotate(45 ${X(12)} ${y})" class="pt-hollow pop" style="--i:4"/><text x="${X(12)}" y="${y - 14}" class="tk" text-anchor="middle">~12° reported</text>`;
      });
      return svg(W, 66 + L.length * 64, g);
    },

    'horizon-scatter'() {
      const h = D.horizon, s = h.sample, W = 520, H = 330, m = { l: 52, r: 16, t: 14, b: 44 };
      const f = frame(W, H, m, [0, 80], [0, 80], 'Sunlight, Mazarico et al. (NASA), %', 'Sunlight, this work, %', 4);
      let g = f.g + `<line x1="${f.X(0)}" y1="${f.Y(0)}" x2="${f.X(80)}" y2="${f.Y(80)}" class="gl" style="stroke-dasharray:4 4"/>`;
      arr(s.maz_sun).forEach((x, i) => { g += `<circle cx="${f.X(x)}" cy="${f.Y(s.sun_smooth[i])}" r="2.3" class="pop" style="--i:${i % 40};fill:#c8c8c4"/>`; });
      arr(s.maz_sun).forEach((x, i) => { g += `<circle cx="${f.X(x)}" cy="${f.Y(s.sun_limb[i])}" r="2.6" class="pop" style="--i:${i % 40};fill:${OR};opacity:.8"/>`; });
      g += `<text x="${m.l + 10}" y="${m.t + 14}" class="rl" style="fill:${OR}">● with terrain: r = ${h.sun_limb_vs_mazarico.r.toFixed(3)}</text>
        <text x="${m.l + 10}" y="${m.t + 32}" class="rl" style="fill:${MUT}">● smooth Moon, no terrain: r = ${h.smooth_sun_vs_mazarico.r.toFixed(2)}</text>`;
      return svg(W, H, g);
    },
    'ml-bars'() {
      const c = D.hzml.cv, dn = D.hzml.downstream_300_heldout_points, W = 640, rows = [
        ['No terrain (smooth Moon)', c.zero_horizon.mae_deg, dn.smooth.sun_mae_pp, MUT],
        ['Coarse 1.28 km terrain only', c.baseline.mae_deg, dn.baseline.sun_mae_pp, '#9a9a9a'],
        ['Neural network (1.28 km input)', c.mlp.mae_deg, dn.mlp.sun_mae_pp, OR]];
      const X1 = lin(0, 6, 220, 380), X2 = lin(0, 30, 430, W - 50);
      let g = `<text x="220" y="14" class="ph">Skyline error (°)</text><text x="430" y="14" class="ph">Sunlight error (pp)</text>`;
      rows.forEach(([lab, a, b, col], i) => {
        const y = 30 + i * 38;
        g += `<text x="0" y="${y + 14}" class="rl">${esc(lab)}</text>
          <rect x="220" y="${y}" width="${X1(Math.min(a, 6)) - 220}" height="20" rx="4" class="grow" style="--i:${i};fill:${col}"/>
          <text x="${X1(Math.min(a, 6)) + 5}" y="${y + 14}" class="tk">${a.toFixed(2)}</text>
          <rect x="430" y="${y}" width="${X2(Math.min(b, 30)) - 430}" height="20" rx="4" class="grow" style="--i:${i + 3};fill:${col}"/>
          <text x="${X2(Math.min(b, 30)) + 5}" y="${y + 14}" class="tk">${b.toFixed(1)}</text>`;
      });
      return svg(W, 30 + rows.length * 38 + 16, g + `<text x="0" y="${30 + rows.length * 38 + 10}" class="tk">Tested on 30 km blocks the model never saw (5-fold spatial cross-validation).</text>`);
    },

    'matrix-regions'() { return matrix(arr(D.robust.regions.rank_hist), 'region', arr(D.robust.regions.table).map(r => r.region)); },
    'matrix-sites'() {
      const t = arr(D.robust.sites.table), names = Object.fromEntries(t.map(r => [r.id, r.name]));
      return matrix(arr(D.robust.sites.rank_hist).map(r => ({ ...r, name: names[r.id] })), 'name', t.map(r => r.name));
    }
  };

  function matrix(rows, key, order) {
    rows = order.map(o => rows.find(r => r[key] === o)).filter(Boolean);
    const k = Object.keys(rows[0]).filter(c => /^r\d+$/.test(c)).length, cw = 40, ch = 30, L = 150, W = L + k * cw + 4, H = 30 + rows.length * ch;
    let g = '';
    for (let j = 0; j < k; j++) g += `<text x="${L + j * cw + cw / 2}" y="16" class="tk" text-anchor="middle">${j + 1}</text>`;
    rows.forEach((r, i) => {
      const y = 24 + i * ch;
      g += `<text x="${L - 10}" y="${y + ch / 2 + 4}" class="rl" text-anchor="end">${esc(r[key])}</text>`;
      for (let j = 0; j < k; j++) {
        const v = +r['r' + (j + 1)];
        g += `<rect x="${L + j * cw + 1}" y="${y + 1}" width="${cw - 2}" height="${ch - 2}" rx="4" class="cell pop" style="--i:${i + j};fill:${v > 0 ? `rgba(242,106,27,${0.12 + 0.88 * Math.min(1, v / 80)})` : '#f4f4f2'}"><title>${esc(r[key])}: rank ${j + 1} in ${v} % of scenarios</title></rect>`;
        if (v >= 5) g += `<text x="${L + j * cw + cw / 2}" y="${y + ch / 2 + 4}" class="cv ${v > 45 ? 'light' : ''}" text-anchor="middle">${Math.round(v)}</text>`;
      }
    });
    return svg(W, H + 20, g + `<text x="${L}" y="${H + 14}" class="tk">rank →  · numbers: % of scenarios</text>`);
  }

  /* ------------ scroll behaviour ------------ */
  function countUp(el) {
    const to = +el.dataset.to, dec = +el.dataset.dec || 0, t0 = performance.now(), dur = 1400;
    const step = t => { const p = Math.min(1, (t - t0) / dur), e = 1 - Math.pow(1 - p, 3); el.textContent = (to * e).toFixed(dec); if (p < 1) requestAnimationFrame(step); };
    requestAnimationFrame(step);
  }
  function init() {
    const host = document.querySelector('.story'); if (!host || host.dataset.ready) return;
    host.dataset.ready = '1';
    D = JSON.parse(document.getElementById('story-data').textContent);
    const root = host.closest('.sheet');
    const io = new IntersectionObserver(es => es.forEach(e => {
      if (!e.isIntersecting) return;
      const el = e.target; io.unobserve(el);
      if (el.dataset.chart && charts[el.dataset.chart]) { try { el.innerHTML = charts[el.dataset.chart](); } catch (err) { console.error(err); el.textContent = 'Chart unavailable.'; } requestAnimationFrame(() => requestAnimationFrame(() => el.classList.add('in'))); }
      else el.classList.add('in');
      el.querySelectorAll?.('.count').forEach(countUp);
    }), { root, threshold: 0.18 });
    host.querySelectorAll('.reveal, .st-chart').forEach(el => io.observe(el));
    // progress rail
    const links = [...host.querySelectorAll('.st-rail a')];
    const spy = new IntersectionObserver(es => es.forEach(e => {
      if (!e.isIntersecting) return;
      links.forEach(a => a.classList.toggle('on', a.dataset.ch === e.target.dataset.ch));
    }), { root, rootMargin: '-45% 0px -50% 0px' });
    host.querySelectorAll('.st-ch').forEach(s => spy.observe(s));
    links.forEach(a => a.addEventListener('click', ev => { ev.preventDefault(); host.querySelector(a.getAttribute('href'))?.scrollIntoView({ behavior: 'smooth', block: 'start' }); }));
    host.querySelector('.st-scroll')?.addEventListener('click', () => host.querySelector('#ch-00')?.scrollIntoView({ behavior: 'smooth' }));
  }
  // build when the view is first opened
  document.addEventListener('click', e => { if (e.target.closest('.view-btn[data-view="story"]')) setTimeout(init, 30); });
  window.initStory = init;
})();
