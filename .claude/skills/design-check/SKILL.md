---
name: design-check
description: "Check a Breach design decision or simulation change against the project's two standing principles before it is proposed, recorded or committed: a general rule over special cases (a special case needs the user's own reason), and identity or spawn order never deciding outcomes. Use whenever proposing or recording a Decision, answering feel-test feedback with a rule change, or changing anything under sim/ that affects outcomes (targeting, ordering, tie-breaks, contests, movement, morale), and when invoked as /design-check."
---

# Checking a design against the standing principles

Two principles in `AI_First_Development_Kit/principles/rules-over-cases.md` (Breach
Decisions 96 and 97) are checked on **every** design decision and simulation change.
Both have cost this project repeated rework: special-cased manoeuvres that missed the
next situation, and spawn ids or spawn-ordered lists that quietly favoured one side.
Run this before you propose a design, before you record a Decision, and before you
commit a change under `sim/`.

## 1. A general rule, not a special case (Decision 96)

For each new branch on a situation in the design or the diff:

1. State it as a rule. Does it decide situations nobody has listed? ("The most urgent
   manoeuvre wins, checked every tick" does; "if halted after a turn, re-form" doesn't.)
2. If it only covers the named case, find the general rule it's an instance of, and
   propose that instead.
3. If you still believe a special case is needed, **ask the user**; never decide it
   yourself. Record their reason, in their words where possible, in the Decision that
   introduces it, with who gave it.

Write the answer to the spec's `general-over-special` row (spec-baseline rubric), or a
**Rules over cases** line in the Decision: "general: <the rule>" or "special case:
<the user's reason>".

## 2. Identity and order never decide outcomes (Decision 97)

An id names a unit or squad. It never ranks one. Ids are handed out in spawn order, and
`squads`/`units` lists are in spawn order too.

1. **Static check:** `python3 ci/godot/scripts/check_id_order.py` (also a pre-commit
   hook on `sim/`). It catches ids compared, sorted, used in a key or in arithmetic. An
   id may salt a seeded draw (`hash([seed, ..., unit.id])`, `BattleRolls`,
   `ScrumContest.draw`).
2. **Read your diff for what grep can't see:**
   - `if key < best_key` keeping the **first of equals** over a spawn-ordered list.
   - A sequential pass where one squad's update changes what the next one sees. Decide
     from a snapshot, then apply ("orders given together act together").
   - Ties should go to what things are and where they stand (front first, nearest, rank
     and column in the squad's own frame), then to a seeded draw.
3. **Trial both ways round** whenever a change can move outcomes:

   ```
   godot --headless --path . --script res://tools/formation_trials.gd -- \
       scenario=mirror_headon runs=100 first_seed=1
   godot --headless --path . --script res://tools/formation_trials.gd -- \
       scenario=mirror_headon runs=100 first_seed=1 swap
   ```

   Use at least 300 seeds per order (`first_seed=1`, `101`, `201`), and do the same
   for `mirror_flank` if flanks are touched. Compare the first-spawned side's wins
   across both orders. A gap beyond about 2 standard deviations (sd ≈ √n / 2 over n
   decided battles) is a bias: find it before committing. Report the numbers in the PR.
4. **Reverse the lists:** a list-order tie can hide inside the trial's noise. The
   reversed-lists tests (`test_formation_list_order.gd`, `test_formation_rout_order.gd`)
   step a battle twice, the second with every squad and unit list reversed (same ids,
   same seed), and require the same state each tick. Add a case there for any new
   situation your change decides.

Write the answer to the spec's `order-independent` row, or an **Order** line in the
Decision.

## 3. Then

- Put both answers in the PR body under the rubric checklist.
- If either check turned up something you didn't fix, say so plainly in the PR and to
  the user. Don't leave it for a reviewer to find.
