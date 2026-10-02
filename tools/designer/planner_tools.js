// The structure planner's editing rules (spec 24 round 3; Decisions 61, 65, 67): pure
// functions over a plan, used by planner.js. A plan (as exported to Godot):
//   { solid_cells: {"x,y,level": material}, faces: [{x, y, level, side, material, thickness,
//     into_neighbour}], dug: [[x, y, level]], fills: {"x,y,level": material},
//     loads: {"x,y,level": load units} }
// Faces are stored canonically: north, west or floor. A wall sits flush on its edge and
// grows into its own cell, or (into_neighbour) the cell north or west of the edge.
(function (root) {
  'use strict';

  var SIZE = 16, HISTORY = 100;

  function at(x, y, l) { return x + ',' + y + ',' + l; }
  function emptyPlan() { return { solid_cells: {}, faces: [], dug: [], fills: {}, loads: {} }; }
  function normalise(plan) {
    plan.solid_cells = plan.solid_cells || {}; plan.faces = plan.faces || []; plan.dug = plan.dug || [];
    plan.fills = plan.fills || {}; plan.loads = plan.loads || {};
    return plan;
  }

  // A face drawn on a side of cell (x, y) at level l, stored canonically. It grows into the
  // cell it was drawn from: a south or east wall lives on the neighbour and grows back.
  function face(x, y, l, side) {
    if (side === 'south') return { x: x, y: y + 1, level: l, side: 'north', into_neighbour: true };
    if (side === 'east') return { x: x + 1, y: y, level: l, side: 'west', into_neighbour: true };
    return { x: x, y: y, level: l, side: side, into_neighbour: false };
  }
  function faceIndex(plan, f) {
    for (var i = 0; i < plan.faces.length; i++) {
      var g = plan.faces[i];
      if (g.x === f.x && g.y === f.y && g.level === f.level && g.side === f.side) return i;
    }
    return -1;
  }
  function setFace(plan, f, material, thickness) {
    var i = faceIndex(plan, f);
    if (i !== -1) plan.faces.splice(i, 1);
    plan.faces.push({ x: f.x, y: f.y, level: f.level, side: f.side, material: material, thickness: thickness, into_neighbour: !!f.into_neighbour });
  }
  function dugIndex(plan, x, y, l) {
    for (var i = 0; i < plan.dug.length; i++) if (plan.dug[i][0] === x && plan.dug[i][1] === y && plan.dug[i][2] === l) return i;
    return -1;
  }
  function isDug(plan, x, y, l) { return dugIndex(plan, x, y, l) !== -1; }

  // A solid cell fills its cell, so it replaces the thinner pieces in it (Decision 67): the
  // walls on its four edges and its floor at that level.
  function setSolid(plan, x, y, l, material) {
    var inside = [face(x, y, l, 'north'), face(x, y, l, 'south'), face(x, y, l, 'west'), face(x, y, l, 'east'), face(x, y, l, 'floor')];
    plan.faces = plan.faces.filter(function (g) { return !inside.some(function (f) { return f.x === g.x && f.y === g.y && f.level === g.level && f.side === g.side; }); });
    plan.solid_cells[at(x, y, l)] = material;
  }

  // ---------- picking edges ----------
  // The nearest grid line to a point in cell units: {x, y, side} for the cell the point is
  // in and the side of it that line is, plus the line itself ({axis: 'h'|'v', index}).
  function nearestEdge(fx, fy) {
    var x = Math.min(SIZE - 1, Math.max(0, Math.floor(fx))), y = Math.min(SIZE - 1, Math.max(0, Math.floor(fy)));
    var toV = Math.min(fx - x, x + 1 - fx), toH = Math.min(fy - y, y + 1 - fy);
    if (toH <= toV) return fy - y < 0.5 ? { x: x, y: y, side: 'north', axis: 'h', index: y, before: false } : { x: x, y: y, side: 'south', axis: 'h', index: y + 1, before: true };
    return fx - x < 0.5 ? { x: x, y: y, side: 'west', axis: 'v', index: x, before: false } : { x: x, y: y, side: 'east', axis: 'v', index: x + 1, before: true };
  }
  // The edge on a locked line (a stroke keeps its first line and side), nearest the point.
  function edgeOnLine(fx, fy, line) {
    var clamp = function (v) { return Math.min(SIZE - 1, Math.max(0, Math.floor(v))); };
    if (line.axis === 'h') {
      var hx = clamp(fx);
      return line.before ? { x: hx, y: line.index - 1, side: 'south' } : { x: hx, y: line.index, side: 'north' };
    }
    var vy = clamp(fy);
    return line.before ? { x: line.index - 1, y: vy, side: 'east' } : { x: line.index, y: vy, side: 'west' };
  }

  // ---------- digging and filling ----------
  // A cell can be dug if it is below ground, within the dig depth, and open to the surface
  // (level -1) or beside a cell already dug (Decision 67): a dig is a hole, not a pocket.
  function canDig(plan, x, y, l, digDepth) {
    if (l >= 0 || l < -digDepth) return false;
    if (l === -1) return true;
    var around = [[x, y, l + 1], [x, y, l - 1], [x - 1, y, l], [x + 1, y, l], [x, y - 1, l], [x, y + 1, l]];
    return around.some(function (c) { return isDug(plan, c[0], c[1], c[2]); });
  }
  // Fills a dug cell; the material GROUND restores the original ground (undoes the dig).
  function fill(plan, x, y, l, material) {
    var i = dugIndex(plan, x, y, l);
    if (i === -1) return false;
    if (material === 'GROUND') { plan.dug.splice(i, 1); delete plan.fills[at(x, y, l)]; }
    else plan.fills[at(x, y, l)] = material;
    return true;
  }

  // ---------- areas ----------
  function span(rect) {
    return { x0: Math.min(rect.x0, rect.x1), x1: Math.max(rect.x0, rect.x1), y0: Math.min(rect.y0, rect.y1), y1: Math.max(rect.y0, rect.y1) };
  }
  // Walls round rect's edge at level l, flush inside it.
  function perimeterWalls(plan, rect, l, material, thickness) {
    var r = span(rect);
    for (var x = r.x0; x <= r.x1; x++) { setFace(plan, face(x, r.y0, l, 'north'), material, thickness); setFace(plan, face(x, r.y1, l, 'south'), material, thickness); }
    for (var y = r.y0; y <= r.y1; y++) { setFace(plan, face(r.x0, y, l, 'west'), material, thickness); setFace(plan, face(r.x1, y, l, 'east'), material, thickness); }
  }
  // Every cell of rect, front to back (so digs below a dug cell connect as they go).
  function cellsOf(rect) {
    var r = span(rect), out = [];
    for (var y = r.y0; y <= r.y1; y++) for (var x = r.x0; x <= r.x1; x++) out.push([x, y]);
    return out;
  }

  // ---------- rooms ----------
  // A room over rect {x0, y0, x1, y1} from level `level`: perimeter walls on every level of
  // its height, flush inside; a floor at its base and a ceiling over its top, if wanted.
  // opts: {height, wall: {material, thickness}, floor: {on, material, thickness},
  // ceiling: {on, material, thickness}}.
  function addRoom(plan, rect, level, opts) {
    for (var l = level; l < level + opts.height; l++) perimeterWalls(plan, rect, l, opts.wall.material, opts.wall.thickness);
    [[opts.floor, level], [opts.ceiling, level + opts.height]].forEach(function (pair) {
      if (!pair[0] || !pair[0].on) return;
      cellsOf(rect).forEach(function (c) { setFace(plan, face(c[0], c[1], pair[1], 'floor'), pair[0].material, pair[0].thickness); });
    });
  }

  // ---------- clearing ----------
  function clearLevel(plan, l) {
    Object.keys(plan.solid_cells).forEach(function (k) { if (Number(k.split(',')[2]) === l) delete plan.solid_cells[k]; });
    Object.keys(plan.loads).forEach(function (k) { if (Number(k.split(',')[2]) === l) delete plan.loads[k]; });
    Object.keys(plan.fills).forEach(function (k) { if (Number(k.split(',')[2]) === l) delete plan.fills[k]; });
    plan.faces = plan.faces.filter(function (f) { return f.level !== l; });
    plan.dug = plan.dug.filter(function (d) { return d[2] !== l; });
  }
  function clearPlan(plan) { var empty = emptyPlan(); Object.keys(empty).forEach(function (k) { plan[k] = empty[k]; }); }

  // ---------- undo ----------
  // One snapshot per stroke, room or clear; restore() puts a snapshot back into the plan.
  function History() { this.undos = []; this.redos = []; }
  History.prototype.record = function (plan) {
    this.undos.push(JSON.stringify(plan));
    if (this.undos.length > HISTORY) this.undos.shift();
    this.redos = [];
  };
  History.prototype.undo = function (plan) { return this.step(plan, this.undos, this.redos); };
  History.prototype.redo = function (plan) { return this.step(plan, this.redos, this.undos); };
  History.prototype.step = function (plan, from, to) {
    if (!from.length) return false;
    to.push(JSON.stringify(plan));
    var snapshot = JSON.parse(from.pop());
    Object.keys(snapshot).forEach(function (k) { plan[k] = snapshot[k]; });
    normalise(plan);
    return true;
  };

  root.BreachPlannerTools = {
    SIZE: SIZE, at: at, emptyPlan: emptyPlan, normalise: normalise, face: face, faceIndex: faceIndex,
    setFace: setFace, setSolid: setSolid, perimeterWalls: perimeterWalls, cellsOf: cellsOf, dugIndex: dugIndex, isDug: isDug, nearestEdge: nearestEdge, edgeOnLine: edgeOnLine,
    canDig: canDig, fill: fill, addRoom: addRoom, clearLevel: clearLevel, clearPlan: clearPlan, History: History
  };
  if (typeof module !== 'undefined') module.exports = root.BreachPlannerTools;
})(this);
