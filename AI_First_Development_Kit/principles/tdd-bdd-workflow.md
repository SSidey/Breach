---
doc: principles/tdd-bdd-workflow
status: active
applies_to: all specifications that introduce or change executable behaviour
---

# BDD/TDD Workflow

## Why this exists

Writing tests after code tends to test what the code happens to do, not what it was
supposed to do. This document mandates the reverse order for anything with actual
behaviour, while explicitly carving out the specifications that have no behaviour to
test — so the rule stays honest rather than forcing invented tests onto documentation or
policy changes.

## Spec-type taxonomy (decides whether this document applies at all)

Every specification is classified as exactly one of:

- **`code`** — introduces or changes executable behaviour (a function, a class, an
  interaction, a bugfix). This document's workflow is **mandatory**.
- **`policy`** — changes documentation, rubric definitions, or process convention with no
  executable behaviour (e.g. the specification that produced this very file). This
  document's workflow **does not apply**; there is nothing to write a failing test for.
- **`hybrid`** — a policy change that also requires tooling to enforce it (e.g. "add a
  new rubric criterion" plus "write the script that checks it"). The tooling portion
  follows this workflow; the policy/documentation portion does not.

A specification declares its type in frontmatter (`spec_type: code | policy | hybrid`).
A `code` or `hybrid` specification without a corresponding test plan in its Steps fails
the spec-baseline rubric outright — see `rubrics/spec-baseline.rubrics.md`.

## The workflow (for `code` and the tooling half of `hybrid`)

1. **Identify the behaviour.** Before any implementation code is written, state the
   required behaviour as one or more Given/When/Then scenarios (BDD form). This is the
   specification's acceptance criteria, not prose description of the implementation.
2. **Write the test(s) first.** Translate each scenario into an automated test. Run it.
3. **Assert red.** The test must fail before any implementation exists, and must fail
   for the *right* reason (missing behaviour, not a typo or setup error). A test that
   passes before implementation exists is not testing anything and must be fixed before
   proceeding.
4. **Implement to green.** Write the minimum code required to make the test pass. Do not
   implement behaviour with no corresponding test.
5. **Refactor with the safety net in place.** Once green, apply the AI-first and
   SOLID-mechanical checks (see the other `principles/` documents) with the test suite
   as the guard against regression.

## Contract tests (Liskov tie-in)

Where a specification introduces a second implementation of an existing base
type/interface/contract, the shared contract-test suite required by
`principles/solid-mechanical.md` (criterion L) **is** the BDD specification for that
abstraction. It is written once, against the base contract, and re-run unmodified
against every implementation — it is not rewritten per implementation.

## Coverage requirement

- **≥90% line coverage overall**, and **≥90% coverage on changed/new lines**, measured
  by whichever coverage tool is bootstrapped for the project's stack (see the relevant
  `ci/<stack>/` directory — the tool is stack-specific; the threshold is not).
- Coverage is checked as part of Gate 1 in `principles/progress-tracking.md` — a drop
  below threshold is a hard fail requiring more tests before the pass is considered
  complete.
- Coverage is a **floor, not a target to game.** A test that executes a line without
  asserting anything meaningful about its behaviour satisfies the coverage tool but not
  this workflow's intent. Spec-baseline review should treat suspiciously assertion-free
  tests as a smell, not a pass.

## What this does not claim

Passing tests and hitting the coverage threshold demonstrate that specified behaviour
works as specified — they do not prove the specification captured the right behaviour in
the first place. That judgement sits with whoever reviews the Given/When/Then scenarios
in step 1, before any test is written.
