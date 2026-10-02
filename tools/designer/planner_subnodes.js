// A node's subnodes (Decision 72, spec 26): its objectives, each with a capture area
// inside a zone of influence, painted in the node's local cells (columns, all levels).
// Zones stay on the node's tiles and never overlap; a capture cell is always in its zone.
// These are the editing rules; planner.js drives them and planner_draw.js draws them.
(function (root) {
  'use strict';

  // Default areas (squares, in cells) when a subnode is placed; both can be repainted.
  var TYPES = {
    WELL: { label: 'Well', colour: '#3f8fd1', capture: 3, zone: 11 },
    ORE_VEIN: { label: 'Ore vein', colour: '#b06a2c', capture: 4, zone: 12 },
    KEEP: { label: 'Keep', colour: '#8a4fbf', capture: 6, zone: 20 },
    OBJECTIVE: { label: 'Objective (painted)', colour: '#d1a21f', capture: 4, zone: 16 }
  };

  function has(cells, x, y) { return indexOf(cells, x, y) !== -1; }
  function indexOf(cells, x, y) {
    for (var i = 0; i < cells.length; i++) if (cells[i][0] === x && cells[i][1] === y) return i;
    return -1;
  }
  function find(subnodes, id) { return subnodes.filter(function (s) { return s.id === id; })[0] || null; }
  // The subnode whose zone holds the cell, or null.
  function owner(subnodes, x, y) { return subnodes.filter(function (s) { return has(s.zone, x, y); })[0] || null; }
  function onNode(ctx, x, y) { return !ctx || !ctx.inFootprint || ctx.inFootprint(x, y); }
  function nextId(subnodes, type) {
    var stem = type.toLowerCase(), n = 1;
    while (find(subnodes, stem + '_' + n)) n++;
    return stem + '_' + n;
  }
  // A size x size square of cells centred on (x, y).
  function square(x, y, size) {
    var out = [], lo = -Math.floor((size - 1) / 2);
    for (var dx = lo; dx < lo + size; dx++) for (var dy = lo; dy < lo + size; dy++) out.push([x + dx, y + dy]);
    return out;
  }

  // Places a subnode of `type` at (x, y) with its default areas, clipped to the node's
  // tiles and to cells no other zone holds. Returns its id, or null where refused (off the
  // node, or inside another subnode's zone).
  function place(subnodes, type, x, y, ctx) {
    var spec = TYPES[type];
    if (!spec || !onNode(ctx, x, y) || owner(subnodes, x, y)) return null;
    function free(c) { return onNode(ctx, c[0], c[1]) && !owner(subnodes, c[0], c[1]); }
    var zone = square(x, y, spec.zone).filter(free);
    var subnode = { id: nextId(subnodes, type), type: type, at: [x, y],
      capture: square(x, y, spec.capture).filter(free), zone: zone };
    subnodes.push(subnode);
    return subnode.id;
  }
  // Adds or removes one cell of a subnode's capture area or zone. A capture cell joins
  // the zone too; a zone cell leaving takes its capture cell with it. Refuses cells off
  // the node or in another subnode's zone, and never removes the marker's zone cell.
  function paint(subnodes, id, which, x, y, adding, ctx) {
    var s = find(subnodes, id);
    if (!s) return false;
    var other = owner(subnodes, x, y);
    if (adding) {
      if (!onNode(ctx, x, y) || (other && other !== s)) return false;
      if (!has(s.zone, x, y)) s.zone.push([x, y]);
      if (which === 'capture' && !has(s.capture, x, y)) s.capture.push([x, y]);
      return true;
    }
    var ci = indexOf(s.capture, x, y);
    if (ci !== -1) s.capture.splice(ci, 1);
    if (which === 'zone' && !(s.at[0] === x && s.at[1] === y)) {
      var zi = indexOf(s.zone, x, y);
      if (zi !== -1) s.zone.splice(zi, 1);
    }
    return true;
  }
  function remove(subnodes, id) {
    var i = subnodes.indexOf(find(subnodes, id));
    if (i !== -1) subnodes.splice(i, 1);
    return i !== -1;
  }
  // What would stop a node's subnodes validating in the game, as messages.
  function problems(subnodes) {
    var out = [];
    subnodes.forEach(function (s) {
      if (!s.capture.length) out.push("subnode '" + s.id + "': its capture area is empty");
    });
    return out;
  }

  root.BreachPlannerSubnodes = {
    TYPES: TYPES, place: place, paint: paint, remove: remove, owner: owner, find: find, has: has, problems: problems
  };
  if (typeof module !== 'undefined') module.exports = root.BreachPlannerSubnodes;
})(this);
