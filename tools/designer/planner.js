// The structure planner panel (spec 24 rounds 2-3; Decisions 52, 61, 65, 67): a node's
// plan drawn level by level on its tile's 16 x 16 cells, beside an isometric view, both
// coloured by material or by load against capacity (BreachLoadPaths, the game's rule).
// Editing rules live in planner_tools.js and drawing in planner_draw.js; this file is the
// panel: tools, levels, strokes, undo, clearing and the Room tool.
(function (root) {
  'use strict';

  var T = root.BreachPlannerTools, D = root.BreachPlannerDraw, SIZE = T.SIZE;
  var TOOLS = [['solid', 'Solid cell'], ['wall', 'Face wall'], ['floor', 'Floor / roof'], ['room', 'Room'],
    ['dig', 'Dig'], ['fill', 'Fill'], ['load', 'Load'], ['erase', 'Erase']];
  var MODES = [['material', 'Material'], ['load', 'Load v capacity']];
  var SHAPES = [['free', 'Freehand'], ['area', 'Area']];
  var ui = {
    level: 0, tool: 'wall', shape: 'free', example: 'farmhouse', material: 'TIMBER', fillMaterial: 'GROUND', thickness: 1, load: 20, mode: 'material',
    hover: null, room: null, pendingRoom: null, confirm: null,
    roomOpts: { height: 1, wall: { material: 'TIMBER', thickness: 1 }, floor: { on: true, material: 'TIMBER', thickness: 2 }, ceiling: { on: true, material: 'TIMBER', thickness: 2 } }
  };
  var histories = {}, painting = null, listening = false, current = null;

  function esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
  function historyOf(node) { return histories[node.id] || (histories[node.id] = new T.History()); }
  function solve(plan, ctx) { return BreachLoadPaths.solve(plan, ctx.materialMap(), ctx.bearing); }

  // ---------- applying a tool ----------
  function digLevel() { return ui.level < 0 ? ui.level : -1; }
  function apply(plan, ctx, spot, adding) {
    var l = ui.level, key = T.at(spot.x, spot.y, l);
    if (ui.tool === 'solid') { if (adding) T.setSolid(plan, spot.x, spot.y, l, ui.material); else delete plan.solid_cells[key]; }
    else if (ui.tool === 'wall' || ui.tool === 'floor') {
      var f = T.face(spot.x, spot.y, l, ui.tool === 'floor' ? 'floor' : spot.side), i = T.faceIndex(plan, f);
      if (adding) T.setFace(plan, f, ui.material, ui.thickness); else if (i !== -1) plan.faces.splice(i, 1);
    } else if (ui.tool === 'dig') {
      var dl = digLevel(), di = T.dugIndex(plan, spot.x, spot.y, dl);
      if (adding && di === -1 && T.canDig(plan, spot.x, spot.y, dl, ctx.digDepth)) plan.dug.push([spot.x, spot.y, dl]);
    } else if (ui.tool === 'fill') T.fill(plan, spot.x, spot.y, digLevel(), ui.fillMaterial);
    else if (ui.tool === 'load') { if (adding) plan.loads[key] = ui.load; else delete plan.loads[key]; }
    else if (ui.tool === 'erase') erase(plan, spot, l);
  }
  function erase(plan, spot, l) {
    delete plan.solid_cells[T.at(spot.x, spot.y, l)]; delete plan.loads[T.at(spot.x, spot.y, l)];
    var edge = spot.side ? T.face(spot.x, spot.y, l, spot.side) : null;
    plan.faces = plan.faces.filter(function (g) {
      if (g.level !== l) return true;
      var floor = g.side === 'floor' && g.x === spot.x && g.y === spot.y;
      return !(floor || (edge && g.side === edge.side && g.x === edge.x && g.y === edge.y));
    });
    T.fill(plan, spot.x, spot.y, digLevel(), 'GROUND');
  }
  // The tool over a whole dragged rectangle: walls round its edge (flush inside), anything
  // else in every cell; Erase clears every cell and the walls on its edges.
  function applyArea(plan, ctx, rect) {
    if (ui.tool === 'wall') { T.perimeterWalls(plan, rect, ui.level, ui.material, ui.thickness); return; }
    T.cellsOf(rect).forEach(function (c) {
      if (ui.tool === 'erase') ['north', 'south', 'west', 'east'].forEach(function (side) { erase(plan, { x: c[0], y: c[1], side: side }, ui.level); });
      else apply(plan, ctx, { x: c[0], y: c[1] }, true);
    });
  }
  // True if the tool would add at this spot (it isn't there yet).
  function wouldAdd(plan, spot) {
    var key = T.at(spot.x, spot.y, ui.level);
    if (ui.tool === 'solid') return plan.solid_cells[key] !== ui.material;
    if (ui.tool === 'wall' || ui.tool === 'floor') return T.faceIndex(plan, T.face(spot.x, spot.y, ui.level, ui.tool === 'floor' ? 'floor' : spot.side)) === -1;
    if (ui.tool === 'load') return plan.loads[key] == null;
    return true;
  }
  // The spot under the pointer: an edge for the wall tools (locked to the stroke's line),
  // otherwise a cell. Null outside the grid.
  function spotAt(canvas, ev) {
    var r = canvas.getBoundingClientRect(), fx = (ev.clientX - r.left) / D.CELL, fy = (ev.clientY - r.top) / D.CELL;
    if (fx < 0 || fy < 0 || fx >= SIZE || fy >= SIZE) return null;
    if (ui.tool === 'wall' || ui.tool === 'erase') return painting && painting.line ? T.edgeOnLine(fx, fy, painting.line) : T.nearestEdge(fx, fy);
    return { x: Math.floor(fx), y: Math.floor(fy) };
  }

  // ---------- the panel ----------
  function chips(list, current, attr) {
    return list.map(function (t) { return '<button type="button" class="chip" data-' + attr + '="' + t[0] + '" data-active="' + (t[0] === current) + '">' + esc(t[1]) + '</button>'; }).join('');
  }
  function options(list, selected) {
    return list.map(function (o) { return '<option value="' + esc(o[0]) + '"' + (o[0] === selected ? ' selected' : '') + '>' + esc(o[1]) + '</option>'; }).join('');
  }
  function levelName(l) { return l < 0 ? 'below ' + (-l) : l === 0 ? 'ground' : 'level ' + l; }
  function toolBar(ctx) {
    var building = ctx.materials.filter(function (m) { return !(m.traits || {}).flows; }).map(function (m) { return [m.id, m.label]; });
    var fills = [['GROUND', 'Ground (undo the dig)']].concat(ctx.materials.map(function (m) { return [m.id, m.label]; }));
    var thick = [1, 2, 3, 4, 6, 8].map(function (t) { return [t, t + '/8']; });
    var extra = ui.tool === 'fill' ? '<select id="pl_fill" aria-label="Fill with">' + options(fills, ui.fillMaterial) + '</select>'
      : ui.tool === 'load' ? '<input type="number" id="pl_load" min="1" value="' + ui.load + '" aria-label="Load units" style="width:64px;" />'
        : ui.tool === 'dig' || ui.tool === 'erase' || ui.tool === 'room' ? ''
          : '<select id="pl_mat" aria-label="Material">' + options(building, ui.material) + '</select>' +
            (ui.tool === 'wall' || ui.tool === 'floor' ? '<select id="pl_thick" aria-label="Thickness in eighths">' + options(thick, ui.thickness) + '</select>' : '');
    return '<div class="planner-bar"><span class="row-label">Level</span>' +
      '<button type="button" class="chip" id="pl_down" title="Down a level (PageDown)">▼</button>' +
      '<input type="number" id="pl_level" min="' + (-ctx.digDepth) + '" max="' + ctx.maxLevel + '" value="' + ui.level + '" style="width:58px;" aria-label="Level" />' +
      '<button type="button" class="chip" id="pl_up" title="Up a level (PageUp)">▲</button><span class="hint" style="margin:0;">' + esc(levelName(ui.level)) + '</span>' +
      chips(TOOLS, ui.tool, 'tool') + extra + (ui.tool === 'room' ? '' : '<span class="row-label">Draw</span>' + chips(SHAPES, ui.shape, 'shape')) + '</div>';
  }
  function editBar(node) {
    var h = historyOf(node);
    function clearButton(which, label) {
      return '<button type="button" class="chip" data-clear="' + which + '">' + (ui.confirm === which ? 'Click again to clear ' + which : label) + '</button>';
    }
    return '<button type="button" class="chip" id="pl_undo"' + (h.undos.length ? '' : ' disabled') + ' title="Ctrl+Z">Undo</button>' +
      '<button type="button" class="chip" id="pl_redo"' + (h.redos.length ? '' : ' disabled') + ' title="Ctrl+Shift+Z / Ctrl+Y">Redo</button>' +
      clearButton('level', 'Clear level') + clearButton('plan', 'Clear plan') +
      '<span class="row-label">Examples</span><select id="pl_example" aria-label="Example structure">' +
      options((root.BreachPlannerExamples || []).map(function (e) { return [e.id, e.label]; }), ui.example) + '</select>' +
      '<button type="button" class="chip" data-clear="example">' + (ui.confirm === 'example' ? 'Click again to replace the plan' : 'Load example') + '</button>';
  }
  function roomForm(ctx) {
    var r = ui.pendingRoom, o = ui.roomOpts;
    if (!r) return '';
    var building = ctx.materials.filter(function (m) { return !(m.traits || {}).flows; }).map(function (m) { return [m.id, m.label]; });
    var thick = [1, 2, 3, 4, 6, 8].map(function (t) { return [t, t + '/8']; });
    function part(id, label, p, toggle) {
      return '<span class="row-label">' + label + '</span>' + (toggle ? '<input type="checkbox" id="rm_' + id + '_on"' + (p.on ? ' checked' : '') + ' aria-label="' + label + '" />' : '') +
        '<select id="rm_' + id + '_mat" aria-label="' + label + ' material">' + options(building, p.material) + '</select>' +
        '<select id="rm_' + id + '_thick" aria-label="' + label + ' thickness">' + options(thick, p.thickness) + '</select>';
    }
    return '<div class="planner-bar" id="pl_room_form"><span class="row-label">Room ' + (Math.abs(r.x1 - r.x0) + 1) + ' × ' + (Math.abs(r.y1 - r.y0) + 1) + ', ' + esc(levelName(ui.level)) + '</span>' +
      '<span class="row-label">Height</span><input type="number" id="rm_height" min="1" max="8" value="' + o.height + '" style="width:48px;" aria-label="Height in levels" />' +
      part('wall', 'Walls', o.wall, false) + part('floor', 'Floor', o.floor, true) + part('ceiling', 'Ceiling', o.ceiling, true) +
      '<button type="button" class="chip" id="rm_apply">Apply</button><button type="button" class="chip" id="rm_cancel">Cancel</button></div>';
  }
  function render(host, node, ctx) {
    node.plan = T.normalise(node.plan || T.emptyPlan());
    current = { host: host, node: node, ctx: ctx };
    var plan = node.plan, result = solve(plan, ctx);
    ui.level = Math.max(-ctx.digDepth, Math.min(ctx.maxLevel, ui.level));
    var failedText = result.failed.length ? result.failed.length + ' failing' : 'all standing';
    var hint = ui.mode === 'load' ? 'green < 50% of capacity, yellow < 80%, red to full, black failing'
      : ui.shape === 'area' && ui.tool !== 'room' ? 'drag out a rectangle: walls go round its edge, everything else fills it'
      : ui.tool === 'wall' ? 'walls snap to the nearest grid line and keep to it while you drag; Alt-click flips which side a wall grows into'
        : ui.tool === 'room' ? 'drag out a rectangle, then set the room up and Apply'
          : ui.tool === 'dig' ? 'dig down from the surface or beside a dug cell' : 'drag to paint';
    host.innerHTML = toolBar(ctx) + roomForm(ctx) +
      '<div class="planner-bar"><span class="row-label">View</span>' + chips(MODES, ui.mode, 'mode') + editBar(node) +
      '<span class="hint" style="margin:0;">' + esc(failedText) + ' · ground bears ' + ctx.bearing * 8 + ' per column · ' + esc(hint) + '</span></div>' +
      '<div class="planner-panes"><canvas id="pl_grid" width="' + SIZE * D.CELL + '" height="' + SIZE * D.CELL + '"></canvas>' +
      '<canvas id="pl_iso" width="640" height="460" aria-label="Isometric view of the plan"></canvas></div>';
    host.tabIndex = 0;
    redraw(true);
    bindBars(host, node, ctx);
    bindGrid(host.querySelector('#pl_grid'), node, ctx);
    if (!listening) { listening = true; window.addEventListener('mouseup', endStroke); host.addEventListener('keydown', onKey); }
  }
  function redraw(withIso) {
    var plan = current.node.plan, ctx = current.ctx, result = solve(plan, ctx);
    var view = { level: ui.level, mode: ui.mode, hover: ui.hover, room: ui.room || ui.pendingRoom };
    D.drawGrid(current.host.querySelector('#pl_grid'), plan, ctx, result, view);
    if (withIso) D.drawIso(current.host.querySelector('#pl_iso'), plan, ctx, result, view);
  }
  function rerender() { ui.hover = null; current.ctx.save(); render(current.host, current.node, current.ctx); }
  function setLevel(l) { ui.level = Math.max(-current.ctx.digDepth, Math.min(current.ctx.maxLevel, l)); ui.pendingRoom = null; render(current.host, current.node, current.ctx); }

  function bindBars(host, node, ctx) {
    function on(id, event, fn) { var el = host.querySelector(id); if (el) el.addEventListener(event, fn); }
    host.querySelectorAll('[data-tool]').forEach(function (b) { b.addEventListener('click', function () { ui.tool = b.getAttribute('data-tool'); ui.confirm = null; ui.pendingRoom = null; render(host, node, ctx); }); });
    host.querySelectorAll('[data-shape]').forEach(function (b) { b.addEventListener('click', function () { ui.shape = b.getAttribute('data-shape'); render(host, node, ctx); }); });
    on('#pl_example', 'change', function () { ui.example = this.value; ui.confirm = null; });
    host.querySelectorAll('[data-mode]').forEach(function (b) { b.addEventListener('click', function () { ui.mode = b.getAttribute('data-mode'); render(host, node, ctx); }); });
    on('#pl_level', 'change', function () { setLevel(Number(this.value) || 0); });
    on('#pl_down', 'click', function () { setLevel(ui.level - 1); });
    on('#pl_up', 'click', function () { setLevel(ui.level + 1); });
    on('#pl_mat', 'change', function () { ui.material = this.value; });
    on('#pl_fill', 'change', function () { ui.fillMaterial = this.value; });
    on('#pl_thick', 'change', function () { ui.thickness = Number(this.value); });
    on('#pl_load', 'change', function () { ui.load = Math.max(1, Number(this.value) || 1); });
    on('#pl_undo', 'click', function () { if (historyOf(node).undo(node.plan)) rerender(); });
    on('#pl_redo', 'click', function () { if (historyOf(node).redo(node.plan)) rerender(); });
    host.querySelectorAll('[data-clear]').forEach(function (b) {
      b.addEventListener('click', function () {
        var which = b.getAttribute('data-clear');
        if (ui.confirm !== which) { ui.confirm = which; render(host, node, ctx); return; }
        ui.confirm = null; historyOf(node).record(node.plan);
        if (which === 'level') T.clearLevel(node.plan, ui.level);
        else T.clearPlan(node.plan);
        if (which === 'example') loadExample(node.plan);
        rerender();
      });
    });
    bindRoomForm(host, node);
  }
  function loadExample(plan) {
    var example = (root.BreachPlannerExamples || []).find(function (e) { return e.id === ui.example; });
    if (!example) return;
    var built = example.build();
    Object.keys(built).forEach(function (k) { plan[k] = built[k]; });
    ui.level = 0;
  }
  function bindRoomForm(host, node) {
    var form = host.querySelector('#pl_room_form');
    if (!form) return;
    var o = ui.roomOpts;
    form.querySelector('#rm_height').addEventListener('change', function () { o.height = Math.max(1, Math.min(8, Number(this.value) || 1)); });
    ['wall', 'floor', 'ceiling'].forEach(function (part) {
      form.querySelector('#rm_' + part + '_mat').addEventListener('change', function () { o[part].material = this.value; });
      form.querySelector('#rm_' + part + '_thick').addEventListener('change', function () { o[part].thickness = Number(this.value); });
      var toggle = form.querySelector('#rm_' + part + '_on');
      if (toggle) toggle.addEventListener('change', function () { o[part].on = this.checked; });
    });
    form.querySelector('#rm_apply').addEventListener('click', function () {
      historyOf(node).record(node.plan);
      T.addRoom(node.plan, ui.pendingRoom, ui.level, o);
      ui.pendingRoom = null; rerender();
    });
    form.querySelector('#rm_cancel').addEventListener('click', function () { ui.pendingRoom = null; rerender(); });
  }

  // ---------- strokes ----------
  function bindGrid(grid, node, ctx) {
    grid.addEventListener('mousedown', function (ev) {
      if (ev.button !== 0) return;
      current.host.focus({ preventScroll: true });
      var spot = spotAt(grid, ev);
      if (!spot) return;
      ui.confirm = null;
      if (ui.tool === 'room' || ui.shape === 'area') {
        ui.pendingRoom = null; ui.room = { x0: spot.x, y0: spot.y, x1: spot.x, y1: spot.y };
        painting = { room: true, before: JSON.stringify(node.plan) }; redraw(false); return;
      }
      var flip = ev.altKey && ui.tool === 'wall' ? T.faceIndex(node.plan, T.face(spot.x, spot.y, ui.level, spot.side)) : -1;
      painting = { before: JSON.stringify(node.plan), line: ui.tool === 'wall' ? spot : null, last: '' };
      if (flip !== -1) { node.plan.faces[flip].into_neighbour = !node.plan.faces[flip].into_neighbour; endStroke(); return; }
      painting.adding = wouldAdd(node.plan, spot);
      stroke(node, ctx, spot);
    });
    grid.addEventListener('mousemove', function (ev) {
      if (painting && !(ev.buttons & 1)) { endStroke(); return; }  // released outside the window
      var spot = spotAt(grid, ev);
      if (painting && painting.room) { if (spot) { ui.room.x1 = spot.x; ui.room.y1 = spot.y; redraw(false); } return; }
      if (painting) { if (spot && ui.tool !== 'load') stroke(node, ctx, spot); return; }
      ui.hover = spot; redraw(false);
    });
    grid.addEventListener('mouseleave', function () { if (!painting) { ui.hover = null; redraw(false); } });
  }
  function stroke(node, ctx, spot) {
    var id = spot.x + ',' + spot.y + ',' + (spot.side || '');
    if (id === painting.last) return;
    painting.last = id;
    apply(node.plan, ctx, spot, painting.adding);
    ui.hover = spot; redraw(false);
  }
  function endStroke() {
    if (!painting || !current) return;
    var done = painting; painting = null;
    if (done.room && ui.tool === 'room') { ui.pendingRoom = ui.room; ui.room = null; render(current.host, current.node, current.ctx); return; }
    if (done.room) { applyArea(current.node.plan, current.ctx, ui.room); ui.room = null; }
    if (JSON.stringify(current.node.plan) !== done.before) {
      var h = historyOf(current.node);
      h.undos.push(done.before); h.redos = [];
    }
    rerender();
  }
  function onKey(ev) {
    if (!current) return;
    var mod = ev.ctrlKey || ev.metaKey, key = ev.key.toLowerCase(), h = historyOf(current.node);
    if (mod && key === 'z' && !ev.shiftKey) { ev.preventDefault(); if (h.undo(current.node.plan)) rerender(); }
    else if (mod && (key === 'y' || (key === 'z' && ev.shiftKey))) { ev.preventDefault(); if (h.redo(current.node.plan)) rerender(); }
    else if (ev.key === 'PageUp') { ev.preventDefault(); setLevel(ui.level + 1); }
    else if (ev.key === 'PageDown') { ev.preventDefault(); setLevel(ui.level - 1); }
  }

  // The worst load ratio across a plan (for the map's load diagnostic): 2 if anything fails.
  function worstRatio(plan, materials, bearing) {
    if (!plan) return null;
    var r = BreachLoadPaths.solve(plan, materials, bearing), worst = 0;
    if (r.failed.length) return 2;
    Object.keys(r.capacities).forEach(function (k) { if (r.capacities[k]) worst = Math.max(worst, (r.loads[k] || 0) / r.capacities[k]); });
    return worst;
  }

  root.BreachPlanner = { render: render, emptyPlan: T.emptyPlan, worstRatio: worstRatio, ui: ui };
})(this);
