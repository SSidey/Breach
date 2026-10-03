// Drawing for the structure planner (spec 24 rounds 2-4, spec 25; Decisions 61, 65, 67,
// 68): the plan grid for one level and the isometric view, coloured by material or by
// load against capacity (BreachLoadPaths). The grid covers the node's footprint (cells
// measured from its own tile; cells off the footprint shaded) at the current zoom. Walls
// are drawn flush on their edge, thickness into the cell they grow into. Below ground,
// the isometric view shows the strata as blocks with digs carved out and fills.
(function (root) {
  'use strict';

  var T = root.BreachPlannerTools, UNDER = 3;

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
  function colourOf(ctx, view, result, key, material) {
    if (view.mode === 'load') return loadColour(result, key);
    var m = ctx.material(material);
    return m ? m.color : '#888888';
  }
  function isLiquid(ctx, id) { var m = ctx.material(id); return !!(m && (m.traits || {}).flows); }
  function faceKey(f) { return 'face:' + f.x + ',' + f.y + ',' + f.level + ',' + f.side; }
  // A wall's footprint in cell units: on its edge, thickness t into the cell it grows into.
  function wallRect(f, t) {
    if (f.side === 'north') return { x: f.x, y: f.into_neighbour ? f.y - t : f.y, w: 1, h: t };
    return { x: f.into_neighbour ? f.x - t : f.x, y: f.y, w: t, h: 1 };
  }
  function boundsOf(ctx) { return ctx.bounds || T.TILE; }
  // The grid canvas size for a context at a zoom (cell pixels).
  function gridSize(ctx, cell) { var b = boundsOf(ctx); return { w: (b.x1 - b.x0 + 1) * cell, h: (b.y1 - b.y0 + 1) * cell }; }

  // ---------- plan grid (top-down, one level) ----------
  function cellGround(ctx, plan, x, y, l) {
    var below = l < 0 ? l : -1, fill = plan.fills[T.at(x, y, below)], dug = T.isDug(plan, x, y, below);
    if (l > 0) return '#efe9dc';
    if (dug && fill) return ctx.material(fill) ? ctx.material(fill).color : '#3a6ea5';
    if (dug) return '#2b2621';
    return l < 0 ? shade(ctx.stratumColour(l, x, y), 0.9) : '#efe9dc';
  }
  function drawGrid(canvas, plan, ctx, result, view) {
    var g = canvas.getContext('2d'), l = view.level, c = view.cell, b = boundsOf(ctx);
    var inside = ctx.inFootprint || function () { return true; };
    function px(x) { return (x - b.x0) * c; }
    function py(y) { return (y - b.y0) * c; }
    g.clearRect(0, 0, canvas.width, canvas.height);
    for (var y = b.y0; y <= b.y1; y++) for (var x = b.x0; x <= b.x1; x++) {
      g.fillStyle = inside(x, y) ? cellGround(ctx, plan, x, y, l) : '#b9b2a4';
      g.fillRect(px(x), py(y), c, c);
      if (l > 0 && plan.solid_cells[T.at(x, y, l - 1)]) { g.fillStyle = 'rgba(0,0,0,0.08)'; g.fillRect(px(x), py(y), c, c); }
      if (c >= 8) { g.strokeStyle = 'rgba(0,0,0,0.08)'; g.strokeRect(px(x) + 0.5, py(y) + 0.5, c, c); }
    }
    drawTileEdges(g, b, c, px, py);
    plan.faces.forEach(function (f) {
      if (f.level !== l || f.side !== 'floor') return;
      g.fillStyle = colourOf(ctx, view, result, faceKey(f), f.material); g.globalAlpha = 0.45;
      g.fillRect(px(f.x) + c * 0.08, py(f.y) + c * 0.08, c * 0.84, c * 0.84); g.globalAlpha = 1;
    });
    Object.keys(plan.solid_cells).forEach(function (k) {
      var p = k.split(',').map(Number);
      if (p[2] !== l) return;
      g.fillStyle = colourOf(ctx, view, result, 'cell:' + k, plan.solid_cells[k]);
      g.fillRect(px(p[0]) + 0.5, py(p[1]) + 0.5, c - 1, c - 1);
    });
    plan.faces.forEach(function (f) {
      if (f.level !== l || f.side === 'floor') return;
      var r = wallRect(f, Math.max(1.5 / c, f.thickness / 8));
      g.fillStyle = colourOf(ctx, view, result, faceKey(f), f.material);
      g.fillRect(px(r.x), py(r.y), r.w * c, r.h * c);
    });
    Object.keys(plan.loads).forEach(function (k) {
      var p = k.split(',').map(Number);
      if (p[2] !== l) return;
      g.fillStyle = '#c96a1b'; g.beginPath(); g.arc(px(p[0]) + c / 2, py(p[1]) + c / 2, Math.max(2, c * 0.3), 0, Math.PI * 2); g.fill();
      if (c >= 16) { g.fillStyle = '#fff'; g.font = '9px sans-serif'; g.textAlign = 'center'; g.fillText(plan.loads[k], px(p[0]) + c / 2, py(p[1]) + c / 2 + 3); }
    });
    drawSubnodes(g, view, c, px, py);
    drawHover(g, view.hover, c, px, py);
    drawRoom(g, view.room, c, px, py);
  }
  // A node's subnodes (spec 26) on every level: zones tinted in their type's colour,
  // capture areas stronger, the marker with its id, and the active one outlined. Fainter
  // unless the Subnodes tool is in use.
  function drawSubnodes(g, view, c, px, py) {
    var S = root.BreachPlannerSubnodes;
    if (!S || !view.subnodes) return;
    var strength = view.editingSubnodes ? 1 : 0.5;
    view.subnodes.forEach(function (s) {
      var colour = (S.TYPES[s.type] || S.TYPES.OBJECTIVE).colour;
      g.fillStyle = colour;
      g.globalAlpha = 0.18 * strength; s.zone.forEach(function (z) { g.fillRect(px(z[0]), py(z[1]), c, c); });
      g.globalAlpha = 0.45 * strength; s.capture.forEach(function (z) { g.fillRect(px(z[0]), py(z[1]), c, c); });
      g.globalAlpha = 1;
      if (s.id === view.activeSubnode) outline(g, s.zone, colour, c, px, py);
      g.fillStyle = colour; g.beginPath(); g.arc(px(s.at[0]) + c / 2, py(s.at[1]) + c / 2, Math.max(3, c * 0.4), 0, Math.PI * 2); g.fill();
      g.fillStyle = '#1d1a14'; g.font = 'bold 11px sans-serif'; g.textAlign = 'left';
      g.fillText(s.id, px(s.at[0]) + c + 2, py(s.at[1]) + c / 2 + 4);
    });
  }
  // The outer edges of a set of cells.
  function outline(g, cells, colour, c, px, py) {
    var S = root.BreachPlannerSubnodes;
    g.strokeStyle = colour; g.lineWidth = 2; g.beginPath();
    cells.forEach(function (z) {
      var x = px(z[0]), y = py(z[1]);
      if (!S.has(cells, z[0], z[1] - 1)) { g.moveTo(x, y); g.lineTo(x + c, y); }
      if (!S.has(cells, z[0], z[1] + 1)) { g.moveTo(x, y + c); g.lineTo(x + c, y + c); }
      if (!S.has(cells, z[0] - 1, z[1])) { g.moveTo(x, y); g.lineTo(x, y + c); }
      if (!S.has(cells, z[0] + 1, z[1])) { g.moveTo(x + c, y); g.lineTo(x + c, y + c); }
    });
    g.stroke(); g.lineWidth = 1;
  }
  // Tile edges, so a footprint's tiles read as tiles.
  function drawTileEdges(g, b, c, px, py) {
    var N = T.CELLS_PER_TILE;
    g.strokeStyle = 'rgba(60,40,20,0.35)'; g.lineWidth = 1.5;
    for (var x = Math.ceil(b.x0 / N) * N; x <= b.x1 + 1; x += N) { g.beginPath(); g.moveTo(px(x), 0); g.lineTo(px(x), py(b.y1 + 1)); g.stroke(); }
    for (var y = Math.ceil(b.y0 / N) * N; y <= b.y1 + 1; y += N) { g.beginPath(); g.moveTo(0, py(y)); g.lineTo(px(b.x1 + 1), py(y)); g.stroke(); }
    g.lineWidth = 1;
  }
  // The edge or cell the tool would act on.
  function drawHover(g, hover, c, px, py) {
    if (!hover) return;
    g.strokeStyle = '#d0453a'; g.lineWidth = 3;
    if (hover.side && hover.side !== 'floor') {
      var f = T.face(hover.x, hover.y, 0, hover.side);
      g.beginPath();
      if (f.side === 'north') { g.moveTo(px(f.x), py(f.y)); g.lineTo(px(f.x) + c, py(f.y)); } else { g.moveTo(px(f.x), py(f.y)); g.lineTo(px(f.x), py(f.y) + c); }
      g.stroke();
    } else {
      g.lineWidth = 2; g.strokeRect(px(hover.x) + 1, py(hover.y) + 1, c - 2, c - 2);
    }
    g.lineWidth = 1;
  }
  function drawRoom(g, room, c, px, py) {
    if (!room) return;
    var x0 = Math.min(room.x0, room.x1), y0 = Math.min(room.y0, room.y1);
    var w = Math.abs(room.x1 - room.x0) + 1, h = Math.abs(room.y1 - room.y0) + 1;
    g.setLineDash([5, 4]); g.strokeStyle = '#1f6fb2'; g.lineWidth = 2;
    g.strokeRect(px(x0) + 1, py(y0) + 1, w * c - 2, h * c - 2);
    g.setLineDash([]); g.lineWidth = 1;
  }

  // ---------- isometric view ----------
  // The cells a plan uses, with two cells of ground around them, within the footprint's
  // bounds (all of them when the plan is empty).
  function bounds(plan, level, b) {
    var xs = [], ys = [], zs = [0];
    Object.keys(plan.solid_cells).forEach(function (k) { var q = k.split(',').map(Number); xs.push(q[0]); ys.push(q[1]); zs.push(q[2] + 1); });
    plan.faces.forEach(function (f) { xs.push(f.x); ys.push(f.y); zs.push(f.level + 1); });
    plan.dug.forEach(function (d) { xs.push(d[0]); ys.push(d[1]); });
    if (!xs.length) return { x0: b.x0, y0: b.y0, x1: b.x1 + 1, y1: b.y1 + 1, z1: 1 };
    return {
      x0: Math.max(b.x0, Math.min.apply(null, xs) - 2), y0: Math.max(b.y0, Math.min.apply(null, ys) - 2),
      x1: Math.min(b.x1 + 1, Math.max.apply(null, xs) + 3), y1: Math.min(b.y1 + 1, Math.max.apply(null, ys) + 3),
      z1: Math.min(level + 1, Math.max.apply(null, zs))
    };
  }
  function drawIso(canvas, plan, ctx, result, view) {
    var g = canvas.getContext('2d'), b0 = bounds(plan, view.level, boundsOf(ctx)), below = view.level < 0;
    var spanXY = (b0.x1 - b0.x0) + (b0.y1 - b0.y0), spanZ = below ? UNDER : b0.z1;
    var s = Math.max(2, Math.min(34, Math.min((canvas.width - 40) / spanXY, (canvas.height - 40) / (spanXY / 2 + spanZ * 1.15))));
    var h = s * 1.15, zTop = below ? view.level + 1 : 0;
    var ox = canvas.width / 2 - ((b0.x0 + b0.x1) / 2 - (b0.y0 + b0.y1) / 2) * s;
    var oy = canvas.height / 2 - ((b0.x0 + b0.x1) / 2 + (b0.y0 + b0.y1) / 2) * s / 2 + spanZ * h / 2 + zTop * h;
    function p(x, y, z) { return [ox + (x - y) * s, oy + (x + y) * s / 2 - z * h]; }
    function poly(pts, fill) { g.beginPath(); g.moveTo(pts[0][0], pts[0][1]); for (var i = 1; i < pts.length; i++) g.lineTo(pts[i][0], pts[i][1]); g.closePath(); g.fillStyle = fill; g.fill(); if (s >= 6) { g.strokeStyle = 'rgba(0,0,0,0.18)'; g.stroke(); } }
    function box(bx) {
      var x0 = bx.x, y0 = bx.y, z0 = bx.z, x1 = x0 + bx.dx, y1 = y0 + bx.dy, z1 = z0 + bx.dz;
      g.globalAlpha = bx.alpha || 1;
      poly([p(x0, y1, z0), p(x1, y1, z0), p(x1, y1, z1), p(x0, y1, z1)], shade(bx.colour, 0.78));
      poly([p(x1, y0, z0), p(x1, y1, z0), p(x1, y1, z1), p(x1, y0, z1)], shade(bx.colour, 0.6));
      poly([p(x0, y0, z1), p(x1, y0, z1), p(x1, y1, z1), p(x0, y1, z1)], shade(bx.colour, 1.08));
      g.globalAlpha = 1;
    }
    g.clearRect(0, 0, canvas.width, canvas.height);
    var boxes = below ? groundBoxes(plan, ctx, b0, view.level) : buildBoxes(plan, ctx, result, view, b0, poly, p);
    boxes.sort(function (a, c) { return (a.x + a.dx / 2 + a.y + a.dy / 2) - (c.x + c.dx / 2 + c.y + c.dy / 2) || a.z - c.z; });
    boxes.forEach(box);
  }
  // Below ground: UNDER levels of strata blocks down from the current level, digs carved
  // out, fills in their material (liquids see-through).
  function groundBoxes(plan, ctx, b0, level) {
    var boxes = [], inside = ctx.inFootprint || function () { return true; };
    for (var l = level - UNDER + 1; l <= level; l++) {
      if (l < -ctx.digDepth) continue;
      for (var x = b0.x0; x < b0.x1; x++) for (var y = b0.y0; y < b0.y1; y++) {
        if (!inside(x, y)) continue;
        var fill = plan.fills[T.at(x, y, l)];
        if (T.isDug(plan, x, y, l) && !fill) continue;
        var colour = fill ? (ctx.material(fill) || {}).color || '#3a6ea5' : ctx.stratumColour(l, x, y);
        boxes.push({ x: x, y: y, z: l, dx: 1, dy: 1, dz: 1, colour: colour, alpha: fill && isLiquid(ctx, fill) ? 0.6 : 1 });
      }
    }
    return boxes;
  }
  // Above ground: the surface with its pits, then every element up to the current level.
  function buildBoxes(plan, ctx, result, view, b0, poly, p) {
    poly([p(b0.x0, b0.y0, 0), p(b0.x1, b0.y0, 0), p(b0.x1, b0.y1, 0), p(b0.x0, b0.y1, 0)], ctx.groundColour);
    plan.dug.forEach(function (d) {
      if (d[2] !== -1) return;
      var fill = plan.fills[T.at(d[0], d[1], -1)];
      poly([p(d[0], d[1], 0), p(d[0] + 1, d[1], 0), p(d[0] + 1, d[1] + 1, 0), p(d[0], d[1] + 1, 0)], fill ? (ctx.material(fill) || {}).color || '#3a6ea5' : '#2b2621');
    });
    var boxes = [];
    Object.keys(plan.solid_cells).forEach(function (k) {
      var q = k.split(',').map(Number);
      if (q[2] > view.level || q[2] < 0) return;
      boxes.push({ x: q[0], y: q[1], z: q[2], dx: 1, dy: 1, dz: 1, colour: colourOf(ctx, view, result, 'cell:' + k, plan.solid_cells[k]) });
    });
    plan.faces.forEach(function (f) {
      if (f.level > view.level || f.level < 0) return;
      var t = f.thickness / 8, c = colourOf(ctx, view, result, faceKey(f), f.material);
      if (f.side === 'floor') { boxes.push({ x: f.x, y: f.y, z: f.level, dx: 1, dy: 1, dz: t, colour: c }); return; }
      var r = wallRect(f, t);
      boxes.push({ x: r.x, y: r.y, z: f.level, dx: r.w, dy: r.h, dz: 1, colour: c });
    });
    Object.keys(plan.loads).forEach(function (k) {
      var q = k.split(',').map(Number);
      if (q[2] > view.level) return;
      boxes.push({ x: q[0] + 0.3, y: q[1] + 0.3, z: q[2] + 0.12, dx: 0.4, dy: 0.4, dz: 0.4, colour: '#c96a1b' });
    });
    return boxes;
  }

  root.BreachPlannerDraw = { drawGrid: drawGrid, drawIso: drawIso, gridSize: gridSize };
})(this);
