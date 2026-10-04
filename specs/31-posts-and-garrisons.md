# Spec 31: Posts and garrisons

Decision 104. It builds on Decisions 42 and 45 (painted waves, the domain reserve), 51
(lanes depart and share), 72 (subnodes and capture), 75 (player routes), 87
(coordination), 90 (merges at nodes), 95 (objectives and fallbacks), 99 and 103
(withdrawals and their end).

## Purpose

Today a wave starts at the player's domain and ends wherever its route does; a retreat
that reaches home just holds there. The user wants a formation's terminus to mean
something: home returns its units to the reserve, and any node the player holds keeps
them as its garrison, from which new waves can be painted out of each of its egresses -
a fort with two gates runs two lanes.

## Status

**Agreed (Decision 104); not started.** Its own feature, specced for later: after spec
30 (continuous positioning), and once the field has real nodes.

## Agreed

- **Home is a node:** the player's domain is the first node held, the one with builders.
  Every rule below applies to it and to every other held node alike.
- **A formation at the end of its route joins the node it ends at:**
  - **home** - its units go back to the domain reserve (as routers reaching home do);
  - **a held node** - its units join that node's garrison: when an order stops it at the
    next node, when its objective was to take the node and it has, or when a retreat
    falls back to it;
  - **a node not held** - an objective, not a stop: it fights for it, and holds and
    garrisons it once taken (Decision 72).
- **Units are persistent and somewhere:** once out of the domain, units stay on the map.
  At a node they staff its structures' places - posts, quarters, defence points - as the
  kingdom's garrisons do; any beyond those stand on the node's tiles in the open, idle
  and exposed. A node's capacity is how many it can house, not how many may be there.
- **A garrison defends its node,** and the node changes hands only by the normal capture
  rules (Decision 72). The player can leave a standing garrison by choosing how many stay
  when painting waves out.
- **Lanes from any held node:** each egress of a held node can start a lane. Its waves are
  painted as at home and fill from that node's garrison, shared between its lanes by the
  domain's rule (priority or round robin, Decision 45). Only nodes with builders make
  units; others are filled by formations arriving.
- **Units move between nodes only by marching:** a reinforcement is a lane whose objective
  is "garrison node X". It can be intercepted, and suffers whatever hazards lie on its
  way. No transfers.

## Agenda for round 1

1. **Staffing:** what places a structure offers (posts, quarters, defence points), what a
   unit in each does, and what units in the open are exposed to.
2. **Choosing who stays:** how the player sets a node's standing garrison when painting
   waves out of it, and what an AI garrison keeps.
3. **The wave painter per node:** picking a node and an egress, and seeing its garrison as
   the stock a wave fills from.
4. **Orders:** "stop at next node", "take and hold", "garrison node X", and fallbacks
   naming a node (Decision 95), as orders on a lane.
5. **Upkeep:** whether garrisons cost anything over time (spec 29's workers and
   logistics) - not decided.
6. **The field:** a feel-test scene with a capturable fort with two egresses.
