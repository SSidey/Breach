// Example structure plans for the planner (spec 24 round 4): a farmer's house, a watch
// tower, a palisade fort and a small castle, each on one 16 x 16 tile, built with the same
// editing rules as hand edits (BreachPlannerTools). They show the scale of a tile and
// must stand on fields (bearing 4); the planner's Examples menu loads one into a plan.
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
  // Timber floors at every level between the base and the top of a tower.
  function floors(plan, x0, y0, x1, y1, from, to, thickness) {
    for (var l = from; l <= to; l++) T.cellsOf({ x0: x0, y0: y0, x1: x1, y1: y1 }).forEach(function (c) { T.setFace(plan, T.face(c[0], c[1], l, 'floor'), 'TIMBER', thickness); });
  }

  var TIMBER_1 = { material: 'TIMBER', thickness: 1 }, TIMBER_2 = { material: 'TIMBER', thickness: 2 };
  var ROCK_2 = { material: 'ROCK', thickness: 2 }, ROCK_3 = { material: 'ROCK', thickness: 3 };

  // A one-storey timber house with a pitched-roof stand-in, a shed, and a fenced yard.
  function farmhouse() {
    var plan = T.emptyPlan();
    room(plan, 5, 5, 9, 8, 0, 1, TIMBER_1, null, ['TIMBER', 2]);
    opening(plan, [[7, 8]], 'south', [0]);
    room(plan, 11, 5, 12, 6, 0, 1, TIMBER_1, null, ['TIMBER', 1]);
    room(plan, 3, 3, 13, 12, 0, 1, TIMBER_1);
    opening(plan, [[7, 12], [8, 12]], 'south', [0]);
    return plan;
  }
  // A four-storey watch tower: two storeys of rock walls under two of timber (rock all the
  // way up is too heavy for fields; on rocky ground it could be), timber floors and roof.
  function tower() {
    var plan = T.emptyPlan();
    room(plan, 6, 6, 9, 9, 0, 2, ROCK_2);
    room(plan, 6, 6, 9, 9, 2, 2, TIMBER_2, null, ['TIMBER', 2]);
    floors(plan, 6, 6, 9, 9, 1, 3, 1);
    opening(plan, [[7, 9]], 'south', [0]);
    return plan;
  }
  // A timber palisade with a two-wide gate, four corner towers and a barracks.
  function fort() {
    var plan = T.emptyPlan();
    room(plan, 1, 1, 14, 14, 0, 2, TIMBER_2);
    opening(plan, [[7, 14], [8, 14]], 'south', [0, 1]);
    [[2, 2], [12, 2], [2, 12], [12, 12]].forEach(function (c) {
      room(plan, c[0], c[1], c[0] + 1, c[1] + 1, 0, 3, TIMBER_2, null, ['TIMBER', 2]);
      floors(plan, c[0], c[1], c[0] + 1, c[1] + 1, 1, 2, 2);
    });
    room(plan, 5, 4, 10, 6, 0, 1, TIMBER_1, null, ['TIMBER', 2]);
    return plan;
  }
  // A small castle: a water-filled moat round the tile's edge with a causeway, a rock
  // curtain wall and gate towers, a three-storey keep, and a timber hall.
  function castle() {
    var plan = T.emptyPlan();
    for (var i = 0; i < 16; i++) {
      [[i, 0], [i, 15], [0, i], [15, i]].forEach(function (c) {
        if (c[1] === 15 && (c[0] === 7 || c[0] === 8)) return;  // the causeway
        if (T.isDug(plan, c[0], c[1], -1)) return;
        plan.dug.push([c[0], c[1], -1]); plan.fills[T.at(c[0], c[1], -1)] = 'WATER';
      });
    }
    room(plan, 1, 1, 14, 14, 0, 2, ROCK_3);
    opening(plan, [[7, 14], [8, 14]], 'south', [0]);
    [[5, 12], [9, 12]].forEach(function (c) {
      room(plan, c[0], c[1], c[0] + 1, c[1] + 1, 0, 2, ROCK_2);
      room(plan, c[0], c[1], c[0] + 1, c[1] + 1, 2, 1, TIMBER_2, null, ['TIMBER', 2]);
      floors(plan, c[0], c[1], c[0] + 1, c[1] + 1, 1, 2, 2);
    });
    room(plan, 2, 2, 6, 6, 0, 2, ROCK_2);
    room(plan, 2, 2, 6, 6, 2, 1, TIMBER_2, null, ['TIMBER', 2]);
    floors(plan, 2, 2, 6, 6, 1, 2, 2);
    opening(plan, [[4, 6]], 'south', [0]);
    room(plan, 9, 3, 13, 6, 0, 1, TIMBER_2, null, ['TIMBER', 2]);
    opening(plan, [[11, 6]], 'south', [0]);
    return plan;
  }

  root.BreachPlannerExamples = [
    { id: 'farmhouse', label: "Farmer's house", build: farmhouse },
    { id: 'tower', label: 'Watch tower', build: tower },
    { id: 'fort', label: 'Palisade fort', build: fort },
    { id: 'castle', label: 'Small castle', build: castle }
  ];
  if (typeof module !== 'undefined') module.exports = root.BreachPlannerExamples;
})(this);
