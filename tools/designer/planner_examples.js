// Example structure plans for the planner (spec 24 round 4, spec 25; Decision 68): a
// farmer's house, a watch tower, a palisade fort and a castle, each on one 64 x 64 tile and
// built with the same editing rules as hand edits (BreachPlannerTools). Each names the
// ground it is meant for (bearing) and must stand there under the game's load paths; the
// planner's Examples menu loads one into a plan. Cells: one grem, about 1.7 m (6 ft).
(function (root) {
  'use strict';

  var T = root.BreachPlannerTools || (typeof require !== 'undefined' ? require('./planner_tools.js') : null);

  function room(plan, x0, y0, x1, y1, level, height, wall, floor, ceiling) {
    T.addRoom(plan, { x0: x0, y0: y0, x1: x1, y1: y1 }, level, {
      height: height, wall: wall,
      floor: floor ? { on: true, material: floor[0], thickness: floor[1] } : { on: false },
      ceiling: ceiling ? { on: true, material: ceiling[0], thickness: ceiling[1] } : { on: false }
    });
  }
  // Removes the walls on a straight run of edges: a door or gate.
  function opening(plan, cells, side, levels) {
    levels.forEach(function (l) {
      cells.forEach(function (c) { var i = T.faceIndex(plan, T.face(c[0], c[1], l, side)); if (i !== -1) plan.faces.splice(i, 1); });
    });
  }
  // Floors at every level between the base and the top of a tower.
  function floors(plan, x0, y0, x1, y1, from, to, thickness) {
    for (var l = from; l <= to; l++) T.cellsOf({ x0: x0, y0: y0, x1: x1, y1: y1 }).forEach(function (c) { T.setFace(plan, T.face(c[0], c[1], l, 'floor'), 'TIMBER', thickness); });
  }
  // A tower with one wall spec per level (bottom up), timber floors between and a roof.
  function tower(plan, x0, y0, x1, y1, walls, floorThickness) {
    walls.forEach(function (wall, l) { room(plan, x0, y0, x1, y1, l, 1, wall); });
    floors(plan, x0, y0, x1, y1, 1, walls.length - 1, floorThickness);
    floors(plan, x0, y0, x1, y1, walls.length, walls.length, 2);
  }
  // A ring of dug cells `width` wide round a rect, filled with water, except a causeway
  // across its south side at the given columns.
  function moat(plan, x0, y0, x1, y1, width, causeway) {
    for (var x = x0; x <= x1; x++) for (var y = y0; y <= y1; y++) {
      var ring = x < x0 + width || x > x1 - width || y < y0 + width || y > y1 - width;
      if (!ring || (causeway.indexOf(x) !== -1 && y > y1 - width)) continue;
      plan.dug.push([x, y, -1]); plan.fills[T.at(x, y, -1)] = 'WATER';
    }
  }

  var TIMBER_1 = { material: 'TIMBER', thickness: 1 }, TIMBER_2 = { material: 'TIMBER', thickness: 2 };
  var TIMBER_3 = { material: 'TIMBER', thickness: 3 };
  var ROCK_3 = { material: 'ROCK', thickness: 3 }, ROCK_4 = { material: 'ROCK', thickness: 4 };

  // A one-storey timber house (about 9 x 7 m) with a roof, a shed and a fenced yard.
  function farmhouse() {
    var plan = T.emptyPlan();
    room(plan, 27, 27, 31, 30, 0, 1, TIMBER_1, null, ['TIMBER', 2]);
    opening(plan, [[29, 30]], 'south', [0]);
    room(plan, 33, 27, 34, 28, 0, 1, TIMBER_1, null, ['TIMBER', 1]);
    room(plan, 22, 22, 41, 37, 0, 1, TIMBER_1);
    opening(plan, [[31, 37], [32, 37]], 'south', [0]);
    return plan;
  }
  // The user's watch tower: 24 x 24 x 30 ft, so 4 x 4 cells and 5 levels, with 3 ft (4/8)
  // walls: rock for three levels, timber above. Too heavy for fields; it stands on rock.
  function watchTower() {
    var plan = T.emptyPlan();
    tower(plan, 30, 30, 33, 33, [ROCK_4, ROCK_4, ROCK_4, TIMBER_2, TIMBER_2], 1);
    opening(plan, [[31, 33]], 'south', [0]);
    return plan;
  }
  // A 32 x 32 timber palisade two levels high, with a gate between two gate towers, corner
  // towers and a barracks.
  function fort() {
    var plan = T.emptyPlan();
    room(plan, 16, 16, 47, 47, 0, 2, TIMBER_2);
    opening(plan, [[31, 47], [32, 47]], 'south', [0, 1]);
    [[26, 44, 3], [34, 44, 3], [17, 17, 2], [43, 17, 2], [17, 43, 2], [43, 43, 2]].forEach(function (c) {
      room(plan, c[0], c[1], c[0] + c[2], c[1] + c[2], 0, 3, { material: 'TIMBER', thickness: 3 }, null, ['TIMBER', 2]);
      floors(plan, c[0], c[1], c[0] + c[2], c[1] + c[2], 1, 2, 1);
    });
    room(plan, 24, 22, 39, 26, 0, 1, TIMBER_2, null, ['TIMBER', 2]);
    opening(plan, [[31, 26]], 'south', [0]);
    return plan;
  }
  // A castle of about 48 x 48 cells on rocky ground: a water-filled moat with a causeway,
  // a rock curtain wall three levels high, two 8 x 8 towers flanking the gate (the user's
  // watch tower doubled), an 8 x 8 keep, and a timber hall.
  function castle() {
    var plan = T.emptyPlan();
    moat(plan, 5, 5, 58, 58, 2, [31, 32]);
    room(plan, 8, 8, 55, 55, 0, 3, { material: 'ROCK', thickness: 3 });
    opening(plan, [[31, 55], [32, 55]], 'south', [0]);
    [22, 34].forEach(function (x) { tower(plan, x, 48, x + 7, 55, [ROCK_4, ROCK_4, ROCK_3, TIMBER_3, TIMBER_2], 1); });
    tower(plan, 13, 13, 20, 20, [ROCK_3, ROCK_3, TIMBER_3, TIMBER_2], 1);
    opening(plan, [[16, 20]], 'south', [0]);
    room(plan, 34, 12, 45, 17, 0, 1, TIMBER_2, null, ['TIMBER', 2]);
    opening(plan, [[39, 17]], 'south', [0]);
    return plan;
  }

  root.BreachPlannerExamples = [
    { id: 'farmhouse', label: "Farmer's house (fields)", bearing: 4, build: farmhouse },
    { id: 'tower', label: 'Watch tower (rocky ground)', bearing: 8, build: watchTower },
    { id: 'fort', label: 'Palisade fort (fields)', bearing: 4, build: fort },
    { id: 'castle', label: 'Castle (rocky ground)', bearing: 8, build: castle }
  ];
  if (typeof module !== 'undefined') module.exports = root.BreachPlannerExamples;
})(this);
