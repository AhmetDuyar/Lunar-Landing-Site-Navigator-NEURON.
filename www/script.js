/* NEURON Lunar Navigator: full-bleed lunar map + UI glue.
   Frames: Moon ME (x -> 0°E, y -> 90°E, z -> north)  ==>  three.js (X, Y, Z) = (x, z, -y).
   Polar textures use azimuthal-equidistant UVs: u = .5 + r cos(lon), v = .5 + r sin(lon),
   r = colatitude / extent / 2 (same convention as data-raw/build_textures.py and heat_grid()). */

const R_KM = 1737.4, CAP_DEG = 15;

async function startLunarMap() {
  const host = document.querySelector('.map-stage');
  if (!host || host.dataset.initialized) return;
  host.dataset.initialized = 'true';
  const status = host.querySelector('.map-status');
  const labelLayer = host.querySelector('.map-labels');
  const pinLayer = host.querySelector('.map-pins');
  try {
    const THREE = await import('./assets/three.module.js');
    const { OrbitControls } = await import('./assets/OrbitControls.js');
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    host.prepend(renderer.domElement);
    renderer.domElement.setAttribute('aria-label', 'Lunar south-pole map. Drag to rotate, scroll to zoom, click to analyse a point.');

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(30, 1, 0.0005, 100);
    const controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true; controls.dampingFactor = 0.09;
    controls.enablePan = true; controls.screenSpacePanning = true; controls.zoomToCursor = true;
    controls.zoomSpeed = 0.9; controls.rotateSpeed = 0.55; controls.panSpeed = 0.8;
    controls.mouseButtons = { LEFT: THREE.MOUSE.ROTATE, MIDDLE: THREE.MOUSE.DOLLY, RIGHT: THREE.MOUSE.PAN };

    const ambient = new THREE.AmbientLight(0xffffff, 0.9);
    const sunLight = new THREE.DirectionalLight(0xffffff, 3.2);
    scene.add(ambient, sunLight);

    const coords = (lat, lon, r = 1) => {
      const a = lat * Math.PI / 180, b = lon * Math.PI / 180;
      return new THREE.Vector3(r * Math.cos(a) * Math.cos(b), r * Math.sin(a), -r * Math.cos(a) * Math.sin(b));
    };
    const capGeometry = (radius, extent, segR) => {
      const g = new THREE.SphereGeometry(radius, 512, segR, 0, Math.PI * 2, Math.PI - extent * Math.PI / 180, extent * Math.PI / 180);
      const pos = g.attributes.position, uv = g.attributes.uv;
      for (let i = 0; i < pos.count; i++) {
        const x = pos.getX(i), y = -pos.getZ(i), z = pos.getY(i), n = Math.hypot(x, y, z);
        const lat = Math.asin(z / n) * 180 / Math.PI, lon = Math.atan2(y, x);
        const r = (90 + lat) / extent * 0.5;
        uv.setXY(i, 0.5 + r * Math.cos(lon), 0.5 + r * Math.sin(lon));
      }
      return g;
    };

    /* ---- surfaces: global sphere + high-resolution south-polar cap ---- */
    const loader = new THREE.TextureLoader();
    const mats = (tex) => ({ basic: new THREE.MeshBasicMaterial({ color: 0xffffff }), lit: new THREE.MeshLambertMaterial({ color: 0xffffff }) });
    const globeM = mats(), capM = mats();
    // soft edge so the high-resolution polar cap blends into the global mosaic
    const fade = document.createElement('canvas'); fade.width = fade.height = 256;
    const fx = fade.getContext('2d'), gr = fx.createRadialGradient(128, 128, 0, 128, 128, 128);
    gr.addColorStop(0, '#fff'); gr.addColorStop(0.72, '#fff'); gr.addColorStop(0.98, '#000'); gr.addColorStop(1, '#000');
    fx.fillStyle = gr; fx.fillRect(0, 0, 256, 256);
    const fadeTex = new THREE.CanvasTexture(fade);
    for (const m of [capM.basic, capM.lit]) { m.alphaMap = fadeTex; m.transparent = true; m.depthWrite = false; }
    const fade2 = document.createElement('canvas'); fade2.width = fade2.height = 256;
    const f2 = fade2.getContext('2d'), g2 = f2.createRadialGradient(128, 128, 0, 128, 128, 128);
    g2.addColorStop(0, '#fff'); g2.addColorStop(0.9, '#fff'); g2.addColorStop(0.995, '#000'); g2.addColorStop(1, '#000');
    f2.fillStyle = g2; f2.fillRect(0, 0, 256, 256);
    const fadeHill = new THREE.CanvasTexture(fade2);
    const globe = new THREE.Mesh(new THREE.SphereGeometry(1, 256, 160), globeM.basic);
    const cap = new THREE.Mesh(capGeometry(1.0003, CAP_DEG, 96), capM.basic);
    cap.renderOrder = 1;
    scene.add(globe, cap);
    let texGlobe = null, texCap = null, texHill = null, pending = 2;
    // optional LOLA hillshade (80-90 S) produced by data-raw/build_terrain.R
    const hillM = new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, depthWrite: false });
    const hill = new THREE.Mesh(capGeometry(1.00045, 10, 64), hillM);
    hill.renderOrder = 2; hill.visible = false; scene.add(hill);
    loader.load('assets/moon_south_hill.jpg', t => {
      t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = renderer.capabilities.getMaxAnisotropy();
      texHill = t; hillM.map = t; hillM.needsUpdate = true; applyLayers();
    }, undefined, () => { texHill = null; });
    const loaded = () => { if (--pending === 0) status.textContent = ''; applyLayers(); };
    loader.load('assets/moon_global_4k.jpg', t => { t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = renderer.capabilities.getMaxAnisotropy(); texGlobe = t; loaded(); });
    loader.load('assets/moon_south_cap.jpg', t => {
      t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = renderer.capabilities.getMaxAnisotropy();
      t.minFilter = THREE.LinearMipmapLinearFilter; texCap = t; loaded();
    }, undefined, () => { status.textContent = 'Polar imagery unavailable, geometry still valid.'; });

    /* ---- visibility rasters: light tint + isolines every 10 % (bold at 50 %) ----
       polar cap (detailed, 80-90 S) and whole Moon (equirectangular, geometry layers) */
    const heatShader = (mask) => new THREE.ShaderMaterial({
      transparent: true, depthWrite: false,
      uniforms: { data: { value: null }, showLines: { value: 1.0 }, mask: { value: mask }, hole: { value: 0.0 } },
      vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
      fragmentShader: `
        uniform sampler2D data; uniform float showLines; uniform float mask; uniform float hole; varying vec2 vUv;
        void main(){
          if (mask > 0.5 && length(vUv - 0.5) > 0.497) discard;
          if (mask < 0.5 && vUv.y < hole) discard;   // leave the polar cap to the detailed raster
          vec4 d = texture2D(data, vUv);
          float v = d.r * 100.0;
          float t = clamp(v / 100.0, 0.0, 1.0);
          // diverging ramp: orange (low) -> warm neutral (50 %) -> green (high)
          vec3 cLow = vec3(0.91, 0.39, 0.10), cMid = vec3(0.96, 0.94, 0.88), cHigh = vec3(0.12, 0.50, 0.30);
          vec3 fill = t < 0.5 ? mix(cLow, cMid, t * 2.0) : mix(cMid, cHigh, (t - 0.5) * 2.0);
          float aFill = showLines > 0.5 ? 0.20 + 0.36 * abs(t - 0.5) * 2.0 : 0.30 + 0.45 * abs(t - 0.5) * 2.0;
          float w = fwidth(v);
          float l10 = 1.0 - smoothstep(0.0, 1.1, abs(fract(v / 10.0 + 0.5) - 0.5) * 10.0 / max(w, 1e-4));
          float l50 = 1.0 - smoothstep(0.0, 1.8, abs(fract(v / 50.0 + 0.5) - 0.5) * 50.0 / max(w, 1e-4));
          float interior = smoothstep(4.0, 6.0, v) * (1.0 - smoothstep(94.0, 96.0, v));
          float line = max(l10 * 0.35, l50 * 0.8) * interior * showLines;
          vec3 col = mix(fill, vec3(0.08), line);
          gl_FragColor = vec4(col, max(aFill, line * 0.9));
        }`
    });
    const toTex = (values, w, h) => {
      const data = new Uint16Array(w * h * 4), toH = THREE.DataUtils.toHalfFloat, one = toH(1);
      values.forEach((v, i) => {
        const q = toH(Math.max(0, Math.min(1, (v ?? 0) / 100)));
        data[i * 4] = q; data[i * 4 + 1] = q; data[i * 4 + 2] = q; data[i * 4 + 3] = one;
      });
      const t = new THREE.DataTexture(data, w, h, THREE.RGBAFormat, THREE.HalfFloatType);
      t.magFilter = THREE.LinearFilter; t.minFilter = THREE.LinearFilter; t.wrapS = THREE.RepeatWrapping; t.needsUpdate = true;
      return t;
    };
    const heatMat = heatShader(1.0), globalMat = heatShader(0.0);
    const globalHeat = new THREE.Mesh(new THREE.SphereGeometry(1.0005, 256, 128), globalMat);
    globalHeat.renderOrder = 4; globalHeat.visible = false; scene.add(globalHeat);
    let heat = null;
    function onHeat(m) {
      if (m.container !== host.id) return;
      if (heat) { scene.remove(heat); heat.geometry.dispose(); heatMat.uniforms.data.value?.dispose(); heat = null; }
      globalMat.uniforms.data.value?.dispose(); globalMat.uniforms.data.value = null; globalHeat.visible = false;
      if (m.global && m.global.values) {
        globalMat.uniforms.data.value = toTex(m.global.values, m.global.w, m.global.h);
        globalMat.uniforms.showLines.value = 1.0; globalHeat.visible = true;
        globalMat.uniforms.hole.value = m.values ? (m.extent || 10) / 180 : 0.0;
      }
      if (!m.values) return;
      heatMat.uniforms.data.value = toTex(m.values, m.n, m.n);
      heatMat.uniforms.showLines.value = m.lines === false ? 0.0 : 1.0;
      heat = new THREE.Mesh(capGeometry(1.0006, m.extent, 64), heatMat); heat.renderOrder = 5;
      scene.add(heat);
    }

    /* ---- graticule ---- */
    const grid = new THREE.Group(); scene.add(grid);
    const lm = (o) => new THREE.LineBasicMaterial({ color: 0xffffff, transparent: true, opacity: o, depthWrite: false });
    const ring = (lat, mat, step = 0.5) => grid.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(
      Array.from({ length: Math.round(360 / step) + 1 }, (_, i) => coords(lat, i * step, 1.0009))), mat));
    for (let lat = -89; lat <= -80; lat++) ring(lat, lm(lat % 5 === 0 ? 0.55 : 0.32));
    for (let lat = -75; lat <= 75; lat += 15) ring(lat, lm(0.25), 2);
    for (let lon = 0; lon < 360; lon += 30) grid.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(
      Array.from({ length: 181 }, (_, i) => coords(-90 + i, lon, 1.0009))), lm(lon % 90 === 0 ? 0.5 : 0.3)));
    grid.children.forEach(l => { l.renderOrder = 6; });

    /* ---- DOM labels and pins ---- */
    const labels = [];
    const glab = (txt, pos, cls) => { const el = document.createElement('span'); el.className = 'glab ' + cls; el.textContent = txt; labelLayer.append(el); labels.push({ el, pos }); };
    for (let lat = -89; lat <= -81; lat++) glab(`${-lat}° S`, coords(lat, 0, 1.001), 'lat');
    for (let lon = 0; lon < 360; lon += 30) glab(`${lon}° E`, coords(-80.55, lon, 1.001), 'lon');

    let pins = [], siteKey = '', selected = null, layers = { grid: true, labels: true, lighting: false, imagery: true };
    /* ---- NASA Artemis candidate regions (USGS outlines) ---- */
    const regionGroup = new THREE.Group(); scene.add(regionGroup);
    const regionMat = new THREE.LineDashedMaterial({ color: 0xffffff, dashSize: 0.0012, gapSize: 0.0008, transparent: true, opacity: 0.95, depthWrite: false });
    let regionKey = '', regionLabels = [];
    function rebuildRegions(regions) {
      while (regionGroup.children.length) { const l = regionGroup.children.pop(); l.geometry.dispose(); }
      regionLabels.forEach(l => l.el.remove()); regionLabels = [];
      for (const r of regions || []) {
        const pts = r.lon.map((lo, i) => coords(r.lat[i], lo, 1.0012));
        const line = new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), regionMat);
        line.computeLineDistances(); line.renderOrder = 7; regionGroup.add(line);
        const el = document.createElement('span'); el.className = 'glab region'; el.textContent = r.name; labelLayer.append(el);
        regionLabels.push({ el, pos: coords(r.centroid[1], r.centroid[0], 1.001) });
      }
    }
    function rebuildPins(sites) {
      pins.forEach(p => p.el.remove()); pins = [];
      for (const s of sites) {
        const el = document.createElement('div');
        el.className = 'pin' + (s.id === 'USR' ? ' user' : '');
        el.innerHTML = `<div class="dot"></div><div class="tag"></div>`;
        el.querySelector('.tag').textContent = s.name;
        el.title = `${s.name} · ${Math.abs(s.lat).toFixed(4)}° S, ${s.lon.toFixed(4)}° E`;
        el.addEventListener('click', ev => { ev.stopPropagation(); window.Shiny?.setInputValue(host.dataset.pickInput, s.id, { priority: 'event' }); window.openDossier?.(s.id); });
        pinLayer.append(el);
        pins.push({ el, id: s.id, pos: coords(s.lat, s.lon, 1.0006) });
      }
    }
    /* ---- previous lunar landings (NASA NSSDCA table) ---- */
    let lpins = [], landKey = '';
    const OUT = { landed: 'landed', tipped: 'landed, tipped over', crashed: 'crashed', planned: 'planned' };
    function rebuildLandings(list) {
      lpins.forEach(p => p.el.remove()); lpins = [];
      for (const l of list || []) {
        const el = document.createElement('div');
        el.className = `lpin ${l.outcome}${l.polar ? ' polar' : ''}${l.merge ? ' merge' : ''}${l.major ? ' major' : ''}`;
        el.innerHTML = `<div class="mk"></div><div class="lt"></div>`;
        el.querySelector('.lt').textContent = `${l.mission} · ${l.year}`;
        el.title = `${l.mission} (${l.year}, ${OUT[l.outcome]}). Click for the dossier.`;
        el.addEventListener('click', ev => { ev.stopPropagation(); window.openDossier?.(l.id); });
        pinLayer.append(el);
        lpins.push({ el, pos: coords(l.lat, l.lon, 1.0006) });
      }
    }

    function applyLayers() {
      const lit = layers.lighting;
      globeM.basic.map = globeM.lit.map = layers.imagery ? texGlobe : null;
      capM.basic.map = capM.lit.map = layers.imagery ? texCap : null;
      for (const m of [globeM.basic, globeM.lit, capM.basic, capM.lit]) { m.color.set(layers.imagery ? 0xffffff : 0xb9b9b6); m.needsUpdate = true; }
      globe.material = lit ? globeM.lit : globeM.basic;
      cap.material = lit ? capM.lit : capM.basic;
      hillM.alphaMap = fadeHill; hill.visible = !!(layers.hill && texHill && layers.imagery);
      grid.visible = layers.grid; regionGroup.visible = !!layers.regions;
      labelLayer.style.display = layers.grid ? '' : 'none';
      pinLayer.classList.toggle('pins-nolabels', !layers.labels);
    }
    function onSites(m) {
      if (m.container !== host.id) return;
      const key = JSON.stringify(m.sites);
      if (key !== siteKey) { rebuildPins(m.sites); siteKey = key; }
      const rk = JSON.stringify((m.regions || []).map(r => r.name));
      if (rk !== regionKey) { rebuildRegions(m.regions); regionKey = rk; }
      const lk = JSON.stringify((m.landings || []).map(l => l.id));
      if (lk !== landKey) { rebuildLandings(m.landings); landKey = lk; }
      selected = m.selected; layers = m.layers; applyLayers();
    }
    function onTime(m) {
      if (m.container !== host.id) return;
      const sun = new THREE.Vector3(m.sun[0], m.sun[2], -m.sun[1]).normalize();
      sunLight.position.copy(sun).multiplyScalar(10);
    }

    /* ---- cameras; the map centre is shifted to the free area between the side cards ---- */
    function viewOffset() {   // [x, y] shift so the pole sits in the free map area
      const L = document.querySelector('.col-left'), Rc = document.querySelector('.col-right'), D = document.querySelector('.card-details');
      if (!L || !Rc || getComputedStyle(L).position !== 'absolute') return [0, 0];
      return [(Rc.offsetWidth - L.offsetWidth) / 2, D ? (D.offsetHeight + 20 - 70) / 2 : 0];
    }
    // Polar view: orbit axis = local vertical at the south pole (three.js -Y).
    // Drag left/right spins the map around the pole, drag up/down tilts, right-drag pans,
    // wheel zooms towards the cursor. 0°E (Earth-facing side) starts at the top.
    function southPole() {
      host.classList.remove('is-globe');
      camera.up.set(0, -1, 0);
      controls.target.set(0, -1, 0);
      camera.position.set(-0.0005, -1.5, 0);
      controls.minDistance = 0.02; controls.maxDistance = 3;
      controls.minPolarAngle = 0; controls.maxPolarAngle = 1.25;
      controls.update();
    }
    function globeView() {
      host.classList.add('is-globe');
      camera.up.set(0, 1, 0);
      controls.target.set(0, 0, 0);
      camera.position.set(2.5, -2.3, 2.1);
      controls.minDistance = 1.2; controls.maxDistance = 6;
      controls.minPolarAngle = 0; controls.maxPolarAngle = Math.PI;
      controls.update();
    }
    function zoomBy(f) {
      const off = camera.position.clone().sub(controls.target);
      const d = THREE.MathUtils.clamp(off.length() * f, controls.minDistance, controls.maxDistance);
      camera.position.copy(controls.target).add(off.setLength(d)); controls.update();
    }
    document.getElementById('zoom-in')?.addEventListener('click', () => zoomBy(0.7));
    document.getElementById('zoom-out')?.addEventListener('click', () => zoomBy(1.4));
    document.getElementById('reset-camera')?.addEventListener('click', southPole);
    document.getElementById('orbit-camera')?.addEventListener('click', globeView);
    southPole();

    /* ---- surface click -> custom point ---- */
    const ray = new THREE.Raycaster(), mouse = new THREE.Vector2(); let down = null;
    renderer.domElement.addEventListener('pointerdown', e => { down = [e.clientX, e.clientY]; });
    renderer.domElement.addEventListener('pointerup', e => {
      if (!down || Math.hypot(e.clientX - down[0], e.clientY - down[1]) > 4) return;
      const box = renderer.domElement.getBoundingClientRect();
      mouse.set((e.clientX - box.left) / box.width * 2 - 1, -(e.clientY - box.top) / box.height * 2 + 1);
      ray.setFromCamera(mouse, camera);
      const hit = ray.intersectObject(globe)[0];
      if (hit) {
        const P = hit.point.clone().normalize();
        window.Shiny?.setInputValue(host.dataset.groundInput,
          { lat: Math.asin(P.y) * 180 / Math.PI, lon: Math.atan2(-P.z, P.x) * 180 / Math.PI }, { priority: 'event' });
      }
    });

    let W = 1, H = 1;
    const resize = new ResizeObserver(() => {
      W = host.clientWidth; H = host.clientHeight; if (!W || !H) return;
      renderer.setSize(W, H); camera.aspect = W / H;
      const [ox, oy] = viewOffset(); camera.setViewOffset(W, H, ox, oy, W, H); camera.updateProjectionMatrix();
    });
    resize.observe(host);

    /* ---- scale bar ---- */
    const sb = document.getElementById('scale-bar'), sl = document.getElementById('scale-label');
    const nice = [1, 2, 5, 10, 20, 25, 50, 100, 200, 500, 1000];
    let lastScale = '';
    function updateScale() {
      ray.setFromCamera(new THREE.Vector2(0, 0), camera);
      const hit = ray.intersectObject(globe)[0]; if (!hit || !sb) return;
      const kmPerPx = 2 * hit.distance * Math.tan(camera.fov * Math.PI / 360) / H * R_KM;
      let len = nice[0]; for (const n of nice) if (n / kmPerPx <= 110) len = n;
      const key = len + ':' + Math.round(len / kmPerPx);
      if (key === lastScale) return; lastScale = key;
      sb.style.width = `${Math.round(len / kmPerPx)}px`; sl.textContent = `${len} km`;
    }

    const tmp = new THREE.Vector3(), camDir = new THREE.Vector3();
    const place = (el, pos, extraFacing = 0.02) => {
      camDir.copy(camera.position).sub(pos).normalize();
      const facing = tmp.copy(pos).normalize().dot(camDir) > extraFacing;
      tmp.copy(pos).project(camera);
      const off = !facing || Math.abs(tmp.x) > 1.05 || Math.abs(tmp.y) > 1.05 || tmp.z > 1;
      el.hidden = off;
      if (!off) { el.style.left = `${(tmp.x * .5 + .5) * W}px`; el.style.top = `${(-tmp.y * .5 + .5) * H}px`; }
    };
    let frame = 0;
    renderer.setAnimationLoop(() => {
      if (document.querySelector('.sheet.is-active')) return;   // a full-page sheet covers the map: pause rendering
      controls.update();
      if (camera.position.length() < 1.0008) camera.position.setLength(1.0008);
      // keep depth precision: near plane scales with the distance to the surface
      const near = THREE.MathUtils.clamp((camera.position.length() - 1) * 0.25, 0.0002, 0.5);
      if (Math.abs(near - camera.near) / camera.near > 0.05) { camera.near = near; camera.updateProjectionMatrix(); }
      camera.updateMatrixWorld();
      for (const l of labels) place(l.el, l.pos, 0.05);
      for (const l of regionLabels) { place(l.el, l.pos, 0.05); if (!layers.regions) l.el.hidden = true; }
      for (const p of pins) { place(p.el, p.pos); p.el.classList.toggle('selected', p.id === selected); }
      for (const p of lpins) { place(p.el, p.pos); if (!layers.landings) p.el.hidden = true; }
      if (++frame % 6 === 0) updateScale();
      renderer.render(scene, camera);
    });

    (function ready() {
      if (!window.Shiny?.addCustomMessageHandler) { setTimeout(ready, 50); return; }
      window.Shiny.addCustomMessageHandler('lunar:sites', onSites);
      window.Shiny.addCustomMessageHandler('lunar:time', onTime);
      window.Shiny.addCustomMessageHandler('lunar:heat', onHeat);
      const announce = () => window.Shiny.setInputValue(host.dataset.readyInput, true, { priority: 'event' });
      if (window.Shiny.shinyapp?.isConnected()) announce();
      window.jQuery(document).on('shiny:connected.lunar', announce);
    })();
    window.addEventListener('pagehide', () => { renderer.setAnimationLoop(null); resize.disconnect(); controls.dispose(); renderer.dispose(); });
  } catch (err) {
    console.error(err);
    status.textContent = 'Map renderer could not start (WebGL required). All analysis panels remain available.';
  }
}

/* ---------- UI glue: views, references, timeline cursor ---------- */
function showView(name) {
  document.querySelectorAll('.sheet').forEach(sh => sh.classList.toggle('is-active', sh.dataset.view === name));
  document.body.classList.toggle('sheet-open', name !== 'analysis');
  if (name === 'story') setTimeout(() => window.initStory?.(), 30);
  document.querySelectorAll('.view-btn').forEach(b => b.classList.toggle('is-active', b.dataset.view === name));
}
document.addEventListener('click', e => {
  const go = e.target.closest('[data-go]');
  if (go) { e.preventDefault(); showView(go.dataset.go); const sh = document.querySelector(`.sheet[data-view="${go.dataset.go}"]`); if (sh) sh.scrollTop = 0; return; }
  const btn = e.target.closest('.view-btn');
  if (btn) { showView(btn.dataset.view); return; }
  const ref = e.target.closest('.ref');
  if (e.target.closest('.goto-methods')) { e.preventDefault(); showView('methods'); document.querySelector('.sheet[data-view="methods"]')?.scrollTo({ top: 0 }); return; }
  if (ref) {
    e.preventDefault(); e.stopPropagation(); showView('methods');
    const row = document.getElementById('ref-' + ref.dataset.ref);
    if (row) { row.scrollIntoView({ behavior: 'smooth', block: 'center' }); row.classList.add('flash'); setTimeout(() => row.classList.remove('flash'), 1600); }
  }
});
/* ---------- guide ---------- */
const help = () => document.getElementById('help');
function openHelp() { help()?.classList.add('is-open'); }
function closeHelp() {
  help()?.classList.remove('is-open');
  try { localStorage.setItem('neuron-help-seen', '1'); } catch (e) { /* storage unavailable */ }
}
document.addEventListener('click', e => {
  if (e.target.closest('#help-btn')) { openHelp(); return; }
  if (e.target.closest('.help-close') || e.target.closest('.help-ok') || e.target.classList?.contains('help-backdrop')) closeHelp();
});
document.addEventListener('keydown', e => { if (e.key === 'Escape') { closeHelp(); showView('analysis'); } });
(function firstVisit() {
  let seen = false; try { seen = localStorage.getItem('neuron-help-seen') === '1'; } catch (e) { seen = false; }
  /* the Start view now introduces the tool; the guide opens only from the ? button */
})();

let cursorI = 0;
function placeCursor() {
  const svg = document.querySelector('.elev-chart'); if (!svg) return;
  const pl = +svg.dataset.pl, pw = +svg.dataset.pw, n = +svg.dataset.n;
  svg.querySelector('#tl-cursor')?.setAttribute('transform', `translate(${pl + (Math.min(cursorI, n - 1) / Math.max(1, n - 1)) * pw},0)`);
}
(function bindTimeline() {
  if (!window.Shiny?.addCustomMessageHandler) { setTimeout(bindTimeline, 50); return; }
  window.Shiny.addCustomMessageHandler('timeline:cursor', m => { cursorI = m.i; placeCursor(); });
  window.jQuery(document).on('shiny:value', ev => { if (ev.name === 'timeline-chart') setTimeout(placeCursor, 0); });
})();

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', startLunarMap); else startLunarMap();

document.body.classList.toggle('sheet-open', !!document.querySelector('.sheet.is-active'));

/* Start view: in-page link to the requirement table */
document.addEventListener('click', e => {
  const a = e.target.closest('a[href="#ov-req"]');
  if (!a) return;
  e.preventDefault();
  const t = document.getElementById('ov-req');
  if (t) t.scrollIntoView({ behavior: 'smooth', block: 'start' });
});
