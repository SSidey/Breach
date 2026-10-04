---
doc: templates/decision-entry
status: active
---

# Decision Entry Template

Copy the relevant block below into the specification's `## Decisions` section. See
`principles/decision-ledger.md` for the full rules — the short version: never edit an
existing Decision, only append.

## New decision

```markdown
### Decision N — <short title>

**Rationale:** <why this choice was made, stated plainly, one paragraph>

**Alternatives:**

| Option | Reason Rejected |
|--------|-----------------|
| <option> | <reason> |
| <option> | <reason> |

**Consequences:** <what this commits future work to; what it forecloses>

**Rules over cases:** general: <the rule> | special case: <the owner's reason, and who gave it>
**Order:** <why no outcome depends on identifiers or creation order; trial numbers if any>
```

The last two lines answer `principles/rules-over-cases.md`; an agent never writes a
special-case reason the owner didn't give.

## Decision that supersedes a prior one

```markdown
### Decision M — <short title>

**Supersedes:** Decision N
**Authorised by:** <human name or identifier — required, not an agent>
**Date:** <date>

**Rationale:** <why the change is being made now>

**Alternatives:**

| Option | Reason Rejected |
|--------|-----------------|
| <option> | <reason> |

**Consequences:** <what changes going forward; what, if anything, survives from Decision N>

**Rules over cases:** general: <the rule> | special case: <the owner's reason, and who gave it>
**Order:** <why no outcome depends on identifiers or creation order; trial numbers if any>
```

## Required edit to the superseded decision's heading

Directly below `### Decision N — <original title>`, add (and only add — do not touch the
rest of the block):

```markdown
> Superseded by Decision M on <date>.
```
