// The structure planner (spec 24 round 2; Decisions 52, 61, 65): a node's plan drawn level
// by level on its tile's 16 x 16 cells, beside an isometric view of the whole plan, both
// coloured by material or by load against capacity (BreachLoadPaths, the same rule as the
// game). Plan format (as exported to Godot):
//   { solid_cells: {"x,y,level": material}, faces: [{x, y, level, side, material, thickness}],
//     dug: [[x, y, level]], loads: {"x,y,level": load units} }
// Faces are stored canonically: north, west or floor (south/east become the neighbour's).
(function (root) {
  'use strict';

  var SIZE = 16, CELL = 24, LEVELS = [-3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7];
  var TOOLS = [['solid', 'Solid cell'], ['wall', 'Face wall'], ['floor', 'Floor / roof'], ['dig', 'Dig'], ['load', 'Load'], ['erase', 'Erase']];
  var MODES = [['material', 'Material'], ['load', 'Load v capacity']];
  var ui = { level: 0, tool: 'wall', material: 'TIMBER', thickness: 1, load: 20, mode: 'material' };

  function esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
  function emptyPlan() { return { solid_cells: {}, faces: [], dug: [], loads: {} }; }
  function at(x, y, l) { return x + ',' + y + ',' + l; }

  function canonical(x, y, level, side) {
    if (side === 'south') return { x: x, y: y + 1, level: level, side: 'north' };
    if (side === 'east') return { x: x + 1, y: y, level: level, side: 'west' };
    return { x: x, y: y, level: level, side: side };
  }
  function faceIndex(plan, f) {
    for (var i = 0; i < plan.faces.length; i++) {
      var g = plan.faces[i];
      if (g.x === f.x && g.y === f.y && g.level === f.level && g.side === f.side) return i;
    }
    return -1;
  }
  function dugIndex(plan, x, y, l) {
    for (var i = 0; i < plan.dug.length; i++) if (plan.dug[i][0] === x && plan.dug[i][1] === y && plan.dug[i][2] === l) return i;
    return -1;
  }

  // ---------- editing ----------
  // Applies the current tool at a cell (and edge, for walls); adding decides add vs remove.
  function apply(plan, x, y, edge, adding) {
    var l = ui.level, key = at(x, y, l);
    if (ui.tool === 'solid') { if (adding) plan.solid_cells[key] = ui.material; else delete plan.solid_cells[key]; }
    else if (ui.tool === 'wall' || ui.tool === 'floor') {
      var f = canonical(x, y, l, ui.tool === 'floor' ? 'floor' : edge);
      var i = faceIndex(plan, f);
      if (i !== -1) plan.faces.splice(i, 1);
      if (adding) { f.material = ui.material; f.thickness = ui.thickness; plan.faces.push(f); }
    } else if (ui.tool === 'dig') {
      var dl = Math.min(l, -1), di = dugIndex(plan, x, y, dl);
      if (adding && di === -1) plan.dug.push([x, y, dl]);
      if (!adding && di !== -1) plan.dug.splice(di, 1);
    } else if (ui.tool === 'load') { if (adding) plan.loads[key] = ui.load; else delete plan.loads[key]; }
    else if (ui.tool === 'erase') {
      delete plan.solid_cells[key]; delete plan.loads[key];
      plan.faces = plan.faces.filter(function (g) {
        if (g.level !== l) return true;
        var c = canonical(x, y, l, edge);
        return !((g.side === 'floor' && g.x === x && g.y === y) || (g.side === c.side && g.x === c.x && g.y === c.y));
      });
    }
  }
  // True if the tool would add at this spot (it isn't there yet).
  function wouldAdd(plan, x, y, edge) {
    var key = at(x, y, ui.level);
    if (ui.tool === 'solid') return plan.solid_cells[key] !== ui.material;
    if (ui.tool === 'wall' || ui.tool === 'floor') return faceIndex(plan, canonical(x, y, ui.level, ui.tool === 'floor' ? 'floor' : edge)) === -1;
    if (ui.tool === 'dig') return dugIndex(plan, x, y, Math.min(ui.level, -1)) === -1;
    if (ui.tool === 'load') return plan.loads[key] == null;
    return false;
  }

  // ---------- colours ----------
  function shade(hex, f) {
    var n = parseInt(String(hex || '#888888').slice(1), 16);
    var r = Math.min(255, Math.round(((n >> 16) & 255) * f)), g = Math.min(255, Math.round(((n >> 8) & 255) * f)), b = Math.min(255, Math.round((n & 255) * f));
    return 'rgb(' + r + ',' + g + ',' + b + ')';
  }
  // Load against capacity: green, yellow, red, and black for failed (Decision 57's overlay).
  function loadColour(result, key) {
    if (result.failed.indexOf(key) !== -1) return '#111111';
    var cap = result.capacities[key] || 0, ratio = cap ? (result.loads[key] || 0) / cap : 1;
    return ratio > 0.8 ? '#d0453a' : ratio > 0.5 ? '#e0b43a' : '#4f9a52';
  }
  function colourOf(ctx, result, key, material) {
    if (ui.mode === 'load') return loadColour(result, key);
    var m = ctx.material(material);
    return m ? m.color : '#888888';
  }
  function faceKey(f) { return 'face:' + f.x + ',' + f.y + ',' + f.level + ',' + f.side; }

  // ---------- plan grid (top-down, one level) ----------
  function drawGrid(canvas, plan, ctx, result) {
    var g = canvas.getContext('2d'), l = ui.level;
    g.clearRect(0, 0, canvas.width, canvas.height);
    for (var y = 0; y < SIZE; y++) for (var x = 0; x < SIZE; x++) {
      var px = x * CELL, py = y * CELL, below = l <= 0 ? dugIndex(plan, x, y, -1) !== -1 : false;
      g.fillStyle = l < 0 ? (dugIndex(plan, x, y, l) !== -1 ? '#2b2621' : ctx.groundColour) : (l === 0 && below ? '#2b2621' : '#efe9dc');
      g.fillRect(px, py, CELL, CELL);
      if (plan.solid_cells[at(x, y, l - 1)] && l > 0) { g.fillStyle = 'rgba(0,0,0,0.08)'; g.fillRect(px, py, CELL, CELL); }
      g.strokeStyle = 'rgba(0,0,0,0.08)'; g.strokeRect(px + 0.5, py + 0.5, CELL, CELL);
    }
    plan.faces.forEach(function (f) {
      if (f.level !== l || f.side !== 'floor') return;
      g.fillStyle = colourOf(ctx, result, faceKey(f), f.material); g.globalAlpha = 0.45;
      g.fillRect(f.x * CELL + 2, f.y * CELL + 2, CELL - 4, CELL - 4); g.globalAlpha = 1;
    });
    Object.keys(plan.solid_cells).forEach(function (k) {
      var p = k.split(',').map(Number);
      if (p[2] !== l) return;
      g.fillStyle = colourOf(ctx, result, 'cell:' + k, plan.solid_cells[k]);
      g.fillRect(p[0] * CELL + 1, p[1] * CELL + 1, CELL - 2, CELL - 2);
    });
    plan.faces.forEach(function (f) {
      if (f.level !== l || f.side === 'floor') return;
      var w = Math.max(3, f.thickness * 2.5);
      g.fillStyle = colourOf(ctx, result, faceKey(f), f.material);
      if (f.side === 'north') g.fillRect(f.x * CELL - 1, f.y * CELL - w / 2, CELL + 2, w);
      else g.fillRect(f.x * CELL - w / 2, f.y * CELL - 1, w, CELL + 2);
    });
    Object.keys(plan.loads).forEach(function (k) {
      var p = k.split(',').map(Number);
      if (p[2] !== l) return;
      g.fillStyle = '#c96a1b'; g.beginPath(); g.arc(p[0] * CELL + CELL / 2, p[1] * CELL + CELL / 2, 7, 0, Math.PI * 2); g.fill();
      g.fillStyle = '#fff'; g.font = '9px sans-serif'; g.textAlign = 'center'; g.fillText(plan.loads[k], p[0] * CELL + CELL / 2, p[1] * CELL + CELL / 2 + 3);
    });
  }
  function hit(canvas, ev) {
    var r = canvas.getBoundingClientRect();
    var fx = (ev.clientX - r.left) / CELL, fy = (ev.clientY - r.top) / CELL;
    var x = Math.floor(fx), y = Math.floor(fy);
    if (x < 0 || y < 0 || x >= SIZE || y >= SIZE) return null;
    var dx = fx - x, dy = fy - y, edges = [['north', dy], ['south', 1 - dy], ['west', dx], ['east', 1 - dx]];
    edges.sort(function (a, b) { return a[1] - b[1]; });
    return { x: x, y: y, edge: edges[0][0] };
  }

  // ---------- isometric view ----------
  // Boxes in cell units, drawn back to front with three shaded faces (top, south, east).
  function drawIso(canvas, plan, ctx, result) {
    var g = canvas.getContext('2d');
    // Fit the view to what is built (plus a margin of ground), at most a whole tile.
    var b0 = bounds(plan), s = 1, h = 1.15, ox = 0, oy = 0;
    var spanXY = (b0.x1 - b0.x0) + (b0.y1 - b0.y0), spanZ = b0.z1;
    s = Math.max(8, Math.min(34, Math.min((canvas.width - 40) / spanXY, (canvas.height - 40) / (spanXY / 2 + spanZ * 1.15))));
    h = s * 1.15;
    ox = canvas.width / 2 - ((b0.x0 + b0.x1) / 2 - (b0.y0 + b0.y1) / 2) * s;
    oy = canvas.height / 2 - ((b0.x0 + b0.x1) / 2 + (b0.y0 + b0.y1) / 2) * s / 2 + spanZ * h / 2;
    function p(x, y, z) { return [ox + (x - y) * s, oy + (x + y) * s / 2 - z * h]; }
    function poly(pts, fill) { g.beginPath(); g.moveTo(pts[0][0], pts[0][1]); for (var i = 1; i < pts.length; i++) g.lineTo(pts[i][0], pts[i][1]); g.closePath(); g.fillStyle = fill; g.fill(); g.strokeStyle = 'rgba(0,0,0,0.18)'; g.stroke(); }
    function box(b) {
      var x0 = b.x, y0 = b.y, z0 = b.z, x1 = x0 + b.dx, y1 = y0 + b.dy, z1 = z0 + b.dz;
      poly([p(x0, y1, z0), p(x1, y1, z0), p(x1, y1, z1), p(x0, y1, z1)], shade(b.colour, 0.78));
      poly([p(x1, y0, z0), p(x1, y1, z0), p(x1, y1, z1), p(x1, y0, z1)], shade(b.colour, 0.6));
      poly([p(x0, y0, z1), p(x1, y0, z1), p(x1, y1, z1), p(x0, y1, z1)], shade(b.colour, 1.08));
    }
    g.clearRect(0, 0, canvas.width, canvas.height);
    // The ground: the tile's surface, with dug pits.
    poly([p(b0.x0, b0.y0, 0), p(b0.x1, b0.y0, 0), p(b0.x1, b0.y1, 0), p(b0.x0, b0.y1, 0)], ctx.groundColour);
    plan.dug.forEach(function (d) { if (d[2] === -1) poly([p(d[0], d[1], 0), p(d[0] + 1, d[1], 0), p(d[0] + 1, d[1] + 1, 0), p(d[0], d[1] + 1, 0)], '#2b2621'); });
    var boxes = [];
    Object.keys(plan.solid_cells).forEach(function (k) {
      var q = k.split(',').map(Number);
      if (q[2] > ui.level || q[2] < 0) return;
      boxes.push({ x: q[0], y: q[1], z: q[2], dx: 1, dy: 1, dz: 1, colour: colourOf(ctx, result, 'cell:' + k, plan.solid_cells[k]) });
    });
    plan.faces.forEach(function (f) {
      if (f.level > ui.level || f.level < 0) return;
      var t = f.thickness / 8, c = colourOf(ctx, result, faceKey(f), f.material);
      if (f.side === 'floor') boxes.push({ x: f.x, y: f.y, z: f.level, dx: 1, dy: 1, dz: t, colour: c });
      else if (f.side === 'north') boxes.push({ x: f.x, y: f.y - t / 2, z: f.level, dx: 1, dy: t, dz: 1, colour: c });
      else boxes.push({ x: f.x - t / 2, y: f.y, z: f.level, dx: t, dy: 1, dz: 1, colour: c });
    });
    Object.keys(plan.loads).forEach(function (k) {
      var q = k.split(',').map(Number);
      if (q[2] > ui.level) return;
      boxes.push({ x: q[0] + 0.3, y: q[1] + 0.3, z: q[2] + 0.12, dx: 0.4, dy: 0.4, dz: 0.4, colour: '#c96a1b' });
    });
    boxes.sort(function (a, b) { return (a.x + a.dx / 2 + a.y + a.dy / 2) - (b.x + b.dx / 2 + b.y + b.dy / 2) || a.z - b.z; });
    boxes.forEach(box);
  }

  // The cells a plan uses, with two cells of ground around them, within the tile; the whole
  // tile when the plan is empty. z1 is the top level drawn.
  function bounds(plan) {
    var xs = [], ys = [], zs = [0];
    Object.keys(plan.solid_cells).forEach(function (k) { var q = k.split(',').map(Number); xs.push(q[0]); ys.push(q[1]); zs.push(q[2] + 1); });
    plan.faces.forEach(function (f) { xs.push(f.x); ys.push(f.y); zs.push(f.level + 1); });
    plan.dug.forEach(function (d) { xs.push(d[0]); ys.push(d[1]); });
    if (!xs.length) return { x0: 0, y0: 0, x1: SIZE, y1: SIZE, z1: 1 };
    return {
      x0: Math.max(0, Math.min.apply(null, xs) - 2), y0: Math.max(0, Math.min.apply(null, ys) - 2),
      x1: Math.min(SIZE, Math.max.apply(null, xs) + 3), y1: Math.min(SIZE, Math.max.apply(null, ys) + 3),
      z1: Math.min(ui.level + 1, Math.max.apply(null, zs))
    };
  }

  // ---------- panel ----------
  function render(host, node, ctx) {
    if (!node.plan) node.plan = emptyPlan();
    var plan = node.plan;
    if (!ctx.material(ui.material) && ctx.materials.length) ui.material = ctx.materials[0].id;
    var result = BreachLoadPaths.solve(plan, ctx.materialMap(), ctx.bearing);
    function chips(list, current, attr) {
      return list.map(function (t) { return '<button type="button" class="chip" data-' + attr + '="' + t[0] + '" data-active="' + (t[0] === current) + '">' + esc(t[1]) + '</button>'; }).join('');
    }
    var mats = ctx.materials.filter(function (m) { return !(m.traits || {}).flows; }).map(function (m) { return '<option value="' + esc(m.id) + '"' + (m.id === ui.material ? ' selected' : '') + '>' + esc(m.label) + '</option>'; }).join('');
    var thick = [1, 2, 3, 4, 6, 8].map(function (t) { return '<option value="' + t + '"' + (t === ui.thickness ? ' selected' : '') + '>' + t + '/8</option>'; }).join('');
    var levels = LEVELS.map(function (l) { return '<option value="' + l + '"' + (l === ui.level ? ' selected' : '') + '>' + (l < 0 ? 'below ' + (-l) : l === 0 ? 'ground (0)' : 'level ' + l) + '</option>'; }).join('');
    var failedText = result.failed.length ? result.failed.length + ' failing' : 'all standing';
    host.innerHTML =
      '<div class="planner-bar"><span class="row-label">Level</span><select id="pl_level">' + levels + '</select>' + chips(TOOLS, ui.tool, 'tool') +
      '<select id="pl_mat" aria-label="Material">' + mats + '</select>' +
      (ui.tool === 'wall' || ui.tool === 'floor' ? '<select id="pl_thick" aria-label="Thickness in eighths">' + thick + '</select>' : '') +
      (ui.tool === 'load' ? '<input type="number" id="pl_load" min="1" value="' + ui.load + '" aria-label="Load units" style="width:64px;" />' : '') +
      '</div><div class="planner-bar"><span class="row-label">View</span>' + chips(MODES, ui.mode, 'mode') +
      '<span class="hint" style="margin:0;">' + esc(failedText) + ' · ground bears ' + ctx.bearing * 8 + ' per column · ' +
      (ui.mode === 'load' ? 'green < 50% of capacity, yellow < 80%, red to full, black failing' : 'walls snap to the nearest edge; drag to paint') + '</span></div>' +
      '<div class="planner-panes"><canvas id="pl_grid" width="' + SIZE * CELL + '" height="' + SIZE * CELL + '"></canvas>' +
      '<canvas id="pl_iso" width="640" height="460" aria-label="Isometric view of the plan up to the current level"></canvas></div>';
    var grid = host.querySelector('#pl_grid'), iso = host.querySelector('#pl_iso');
    drawGrid(grid, plan, ctx, result);
    drawIso(iso, plan, ctx, result);
    function rerender() { ctx.save(); render(host, node, ctx); }
    host.querySelectorAll('[data-tool]').forEach(function (b) { b.addEventListener('click', function () { ui.tool = b.getAttribute('data-tool'); render(host, node, ctx); }); });
    host.querySelectorAll('[data-mode]').forEach(function (b) { b.addEventListener('click', function () { ui.mode = b.getAttribute('data-mode'); render(host, node, ctx); }); });
    host.querySelector('#pl_level').addEventListener('change', function () { ui.level = Number(this.value); render(host, node, ctx); });
    host.querySelector('#pl_mat').addEventListener('change', function () { ui.material = this.value; });
    var th = host.querySelector('#pl_thick'); if (th) th.addEventListener('change', function () { ui.thickness = Number(this.value); });
    var ld = host.querySelector('#pl_load'); if (ld) ld.addEventListener('change', function () { ui.load = Math.max(1, Number(this.value) || 1); });
    var painting = null;
    grid.addEventListener('mousedown', function (ev) {
      var h = hit(grid, ev); if (!h) return;
      painting = { adding: wouldAdd(plan, h.x, h.y, h.edge), last: '' };
      apply(plan, h.x, h.y, h.edge, painting.adding); painting.last = h.x + ',' + h.y + ',' + h.edge;
      drawGrid(grid, plan, ctx, BreachLoadPaths.solve(plan, ctx.materialMap(), ctx.bearing));
    });
    grid.addEventListener('mousemove', function (ev) {
      if (!painting || ui.tool === 'load') return;
      var h = hit(grid, ev); if (!h) return;
      var spot = h.x + ',' + h.y + ',' + h.edge;
      if (spot === painting.last) return;
      painting.last = spot;
      apply(plan, h.x, h.y, h.edge, painting.adding);
      drawGrid(grid, plan, ctx, BreachLoadPaths.solve(plan, ctx.materialMap(), ctx.bearing));
    });
    window.addEventListener('mouseup', function up() { if (painting) { painting = null; rerender(); } window.removeEventListener('mouseup', up); });
  }

  // The worst load ratio across a plan (for the map's load diagnostic): 2 if anything fails.
  function worstRatio(plan, materials, bearing) {
    if (!plan) return null;
    var r = BreachLoadPaths.solve(plan, materials, bearing), worst = 0;
    if (r.failed.length) return 2;
    Object.keys(r.capacities).forEach(function (k) { if (r.capacities[k]) worst = Math.max(worst, (r.loads[k] || 0) / r.capacities[k]); });
    return worst;
  }

  root.BreachPlanner = { render: render, emptyPlan: emptyPlan, worstRatio: worstRatio, ui: ui };
})(this);
