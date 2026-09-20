---
doc: principles/decision-ledger
status: active
applies_to: all specifications
---

# Decision Ledger

## Why this exists

A decision recorded in prose ("we chose X because Y") is only as durable as every future
agent's willingness to read and respect it. Nothing stops a later pass from quietly
rewriting or deleting that rationale under pressure to "just fix" something. This
document defines an **append-only** convention: decisions are never edited in place. To
change one, a new entry is appended that supersedes the old one, and the old entry is
never deleted or rewritten. This is enforceable by a mechanical diff check even though
there is no file-system lock — see "Mechanical enforcement" below.

## Rules

1. **Every Decision is numbered sequentially** within its specification file
   (`Decision 1`, `Decision 2`, ...), never renumbered.
2. **A Decision, once recorded, is never edited.** Not to fix a typo, not to "clarify" —
   if the substance needs to change, a new Decision is appended.
3. **To change a prior decision**, append a new Decision entry containing:
   - `supersedes: Decision N`
   - `authorised_by: <human name or identifier>` — a Decision may only be superseded by
     a human-authorised entry. An agent cannot supersede a Decision unilaterally.
   - `date:`
   - The rationale for the change, in the same Rationale/Alternatives/Consequences shape
     as the original.
4. **A superseded Decision is marked, not removed.** Add a one-line
   `> Superseded by Decision M on <date>.` note immediately under its original heading.
   The original Rationale/Alternatives/Consequences text stays exactly as written.
5. **No Decision may be deleted.** The ledger only grows.

## Template for a new Decision

See `templates/decision-entry.md` for the exact block to copy. Structure:

```markdown
### Decision N — <short title>

**Rationale:** <why this choice, stated plainly>

**Alternatives:**

| Option | Reason Rejected |
|--------|-----------------|
| ... | ... |

**Consequences:** <what this commits future work to>
```

And for a superseding entry:

```markdown
### Decision M — <short title>

**Supersedes:** Decision N
**Authorised by:** <human name>
**Date:** <date>

**Rationale:** <why the change>

**Alternatives:**

| Option | Reason Rejected |
|--------|-----------------|
| ... | ... |

**Consequences:** <what this changes going forward, and what remains from Decision N (if anything)>
```

## Mechanical enforcement

A reviewing agent or CI step can check compliance without any special tooling beyond a
diff:

- **Check:** does this diff modify any text inside an existing `### Decision N` block
  (other than appending a `> Superseded by ...` note under rule 4)?
- **Pass condition:** no. Any change to a Decision's original Rationale, Alternatives, or
  Consequences text — for any reason — fails this check and must be reverted in favour of
  a new superseding Decision.
- **This check runs as part of the spec-baseline rubric** — see
  `rubrics/spec-baseline.rubrics.md`, criterion `decision-ledger-append-only`.

This does not require locking the file or any special permissions — it is a straight
text-diff rule, checkable by any agent or script with access to `git diff` against the
prior version of the specification.
