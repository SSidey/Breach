---
doc: templates/ci-tool-mapping
status: active
---

# Stack-Specific `ci/<stack>/README.md` Template

Every stack-specific implementation layer (`ci/<stack>/`, e.g. `ci/godot/`, `ci/node/`)
should document itself in this shape, so anyone reading it — human or agent — can tell at
a glance which rubric rows are genuinely mechanical, which are heuristics with known
blind spots, and which are procedural because no tool covers them yet. Presenting all
three the same way (a script that silently always passes, say) is worse than stating the
gap plainly.

```markdown
# <Stack> Tooling Layer

One paragraph: what this directory wires the stack-agnostic rubrics into, for this stack.

## Rubric → tool mapping

| Rubric row | Tool | Where |
|---|---|---|
| `<rubric-row-name>` | `<tool/script>` | `<config file or path, and where it runs — pre-commit / CI / both>` |
...one row per rubric criterion this stack has *some* answer for, mechanical or not...

## Heuristic limits (stated plainly, not hidden)

For each check that's mechanical but not a proof - a real script that runs and can fail,
but whose "pass" doesn't fully establish the property it's named after - name the gap:

- `<script>` — <what shape of violation it actually catches, and what it structurally
  cannot see (e.g. "no call-graph, so it can't tell a real duplicate from a coincidence")>

## Procedural, not scripted

For each rubric row with no mechanical check at all yet, name the concrete alternative
enforcement (e.g. a codified procedure per `principles/agent-workflow.md`, or an
explicit manual-review question) — never leave a row silently unenforced without saying
so here:

- `<rubric-row-name>` — <how it's actually enforced today, and what would need to exist
  for it to become mechanical>

## Running the checks locally

<the exact commands a contributor or agent runs before pushing, matching what pre-commit
and CI actually run>
```

## Why three sections, not one

A single "here's our tooling" list invites treating every row the same way. Splitting
mechanical / heuristic / procedural forces an honest answer for each rubric row instead
of a blanket "it's covered." This mirrors `principles/solid-mechanical.md`'s own
per-letter commitment to either a real mechanical check or an honestly labeled
manual-review question — this template is that same discipline applied to a stack's
actual tool wiring instead of to SOLID specifically.
