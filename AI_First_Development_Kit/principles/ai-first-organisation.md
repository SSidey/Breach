---
doc: principles/ai-first-organisation
status: active
applies_to: all specifications and all source files
---

# AI-First Organisation Principles

## Why this exists

AI agents read source files as linear text blocks. A human developer navigating a
600-line file has an IDE outline, jump-to-definition, and collapsible regions to skip
irrelevant code at near-zero cost. An agent has none of these: every line inside a file
it opens is context it must pay for and can be distracted or misled by. These principles
are not style preferences. They are load-bearing constraints on how reliably an agent
(or a human, under the same constraints) can reason about and modify the codebase.

These principles are **language-agnostic**. Every numeric threshold below is a
**configurable default**, set in `config/thresholds.yaml` (see bottom of this file), not
a hardcoded rule. A project may tighten or loosen any threshold with a recorded Decision
(see `principles/decision-ledger.md`) explaining why.

## The four principles

### 1. One concern per file

Each source file implements exactly one identifiable concern.

**Test:** Can the file's purpose be stated as a single noun phrase, with no
conjunction? "Serialisation" passes. "Serialisation and parsing" fails — split it.
"Order validation" passes. "Order validation and notification dispatch" fails.

This is necessarily a judgement call at the boundary, but the conjunction test resolves
the overwhelming majority of cases without ambiguity.

### 2. Context locality

Code that is read or changed together lives in the same file.

**Test:** Can a single feature change be understood and implemented by opening no more
than `context_locality.max_files` files (default: **2**)? If a routine change to one
feature requires touching many files scattered across the tree, the code is
mis-organised — not necessarily the change.

This principle is about **co-location of a feature's definition, its usage, and its
immediate supporting logic** — not about file count in general. A large, well-factored
codebase legitimately has many files; the test only fires per-feature.

### 3. Grep-discoverable names

Every identifier — function, type, module, constant — is specific enough that searching
for it by name returns fewer than `naming.max_grep_hits` (default: **10**) matches
across the codebase.

Generic names (`process`, `handle`, `util`, `helper`, `common`, `base`, `manager`,
`data`) are prohibited **unless** they are scoped to a single module and genuinely
universal within that scope (e.g. a method literally named `process` inside a class
called `PaymentProcessor`, never referenced by that short name outside the class, may be
acceptable — but the same name as a free function at module or global scope is not).

**Test:** `grep -rn "<identifier>" <source root>` returns fewer than the threshold.

### 4. No cross-cutting helpers

A utility function lives in the same file as its only caller.

**Promotion rule:** If a helper is needed by `helpers.promotion_threshold` (default:
**3**) or more callers in different modules, it is promoted out of any single caller's
file into its own dedicated module, named precisely for what it does (e.g. `retry.*`,
`auth_strip.*`) — **never** into a generic `utils.*`, `helpers.*`, or `common.*` file.

Below the threshold, duplication is preferred over premature extraction. A helper used
in one file, even if a near-identical helper exists in another file, is not yet a
violation — it becomes one only once genuinely shared and promoted incorrectly (i.e.
dumped into a catch-all file instead of a precisely named module).

**DRY is the tie-breaker, not the default.** Where this principle and general
"don't repeat yourself" instinct conflict below the promotion threshold, this principle
wins: a single-caller helper does not need extraction just because something similar
exists elsewhere. DRY applies in full force once the promotion threshold is reached —
at that point, the duplicate implementations must be collapsed into the single promoted
module, not left duplicated.

## Relationship to other principle sets

These four principles are additive to, and independent of:
- File/function **size** budgets — see `principles/solid-mechanical.md` (Single
  Responsibility proxy) for the size-based check.
- **SOLID**-derived mechanical checks — see `principles/solid-mechanical.md`.
- The **decision ledger** — a change to any threshold below is itself a Decision.

A file can be within a size budget and still violate Principle 1 if it mixes two
unrelated concerns in very few lines. Size and concern-purity are different failure
modes and are checked independently.

## Configurable thresholds (defaults)

These live in the project's `config/thresholds.yaml`, not hardcoded in tooling. Example:

```yaml
ai_first_organisation:
  context_locality:
    max_files: 2
  naming:
    max_grep_hits: 10
  helpers:
    promotion_threshold: 3
```

Any change to a value here is a Decision (see `principles/decision-ledger.md`) with a
stated rationale — thresholds are not silently tuned mid-project.
