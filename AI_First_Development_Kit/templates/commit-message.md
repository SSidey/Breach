---
doc: templates/commit-message
status: active
reference: https://www.conventionalcommits.org/en/v1.0.0/#specification
---

# Commit Message Template

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Type must match the actual diff, not the intent

Before writing the type, check the diff itself against this table — the run-baseline
rubric (`commit-message-conforms`) checks classification correctness against the diff,
not just message formatting.

| Type | Use when the diff... | Common misclassification to avoid |
|---|---|---|
| `feat` | Adds a new capability visible to a consumer of the code | Don't use for internal refactors with no new behaviour |
| `fix` | Corrects incorrect behaviour | Don't use `fix` if the diff also adds a new public API — that's `feat`, or split the commit |
| `refactor` | Changes internal structure with no behaviour change | Must have zero test-behaviour changes; if tests changed to assert new behaviour, it isn't a pure refactor |
| `test` | Adds or corrects tests only | No production code change |
| `docs` | Documentation only | — |
| `chore` | Tooling, build config, dependency bumps | No source behaviour change |
| `perf` | Performance improvement with no behaviour change | If behaviour also changed, split the commit |

## Breaking changes

Append `!` after the type/scope, and include a `BREAKING CHANGE:` footer describing the
change. This is what CI's release pipeline reads to determine a major version bump — see
`principles/tdd-bdd-workflow.md` and CI documentation for how versioning is fully
delegated to the pipeline, not decided by the agent beyond correct classification here.

## Example

```
feat(inventory): add stock threshold alert

Adds a configurable low-stock threshold per item. Emits an event when
stock drops below the threshold rather than requiring a poll.

Closes #142
```
