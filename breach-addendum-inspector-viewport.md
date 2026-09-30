# Breach — Design Addendum: The Inspector Viewport Pattern

> **Read with Decision 36 (2026-09-30):** the main scene is 3D, but structures are 2D sprites
> like the units (not low-poly geometry); the Inspector Viewport shows a structure's detailed
> side-on sprite. The main camera does not zoom into cutaways. Base terrain starts flat; 3D
> terrain is a stretch goal.

*Addendum to the base spec and "Unit AI and Tactical Space" (which references this pattern for dual-viewport ranged engagements). Consolidates a pattern discussed across the art/camera conversation but never previously written down on its own.*

## Origin: an alternative to arcing the main camera into a cutaway

The main camera was originally going to do double duty: read well as a gameplay iso view *and* arc from a steep angle down into a legible side-on structure cutaway. That created a real tension (a workable gameplay angle and a legible cutaway angle aren't the same angle) and a real cost (a cutaway interior painted for one angle looks wrong at every other angle along that arc).

**The fix: decouple them.** Let the player select a structure and show its cutaway in a separate popout — a panel to the side of the screen — rendered by its own dedicated camera that never moves. The main world camera goes back to whatever angle reads best for gameplay, with zero compromise for cutaway duty, since it no longer has to do that job at all.

## Implementation: SubViewport + isolated camera layer

In Godot, this is a standard, low-risk pattern — the same mechanism used for minimaps, portraits, and inventory previews:

- A `SubViewport` with its own independent `Camera3D`, rendered to a texture, displayed inside a `Panel`/`Control` on screen.
- Use `VisualInstance3D.layers` + `Camera3D.cull_mask` so the inspector camera sees a structure's model on a dedicated render layer with its own isolated lighting, separate from the main scene's camera and lighting setup.

**Why the layer trick specifically matters, not just the SubViewport:** the main-world camera and the inspector camera become two different eyes looking at the *same underlying model*, rather than two separately-authored pieces of content. This is what makes the pattern non-throwaway — if a live in-world arcing cutaway is ever wanted later, that's "point the main camera at it too and animate the transition," not a content rebuild. This only holds if the structure is real 3D geometry; a flat painted interior card doesn't carry over the same way, which is why real (even minimal, low-poly) geometry was the recommended default for structures generally.

**Because this camera is fixed forever, it also fully resolves the earlier 2D-sprite-pair caveat.** A hand-painted interior illustration (or a tiny separate diorama scene) only needing to be correct from one angle is exactly satisfied by construction once the viewing camera never moves — no compromise needed if a fully 2D interior is preferred over 3D for a given structure.

## Generalizes beyond structures: one piece of infrastructure, several UI uses

The same SubViewport + isolated-layer setup, pointed at whatever's currently selected:

- **A structure** → the cutaway interior.
- **A single unit** → its current animation state (idle / firing / melee / routing), effectively free since it's just pointing a camera at state that already exists from the combat spec, not a new system.
- **A scouted Hero Party** → its composition, reusing the exact "only reveal what's been scouted" gating already specced for the Scout unit.

One Inspector Viewport concept, three call sites.

## Caveat for unit-focus specifically: sprite angle vs. inspector angle

Units are planned as flat, side-on sprites regardless of camera angle (the main camera has no yaw, so a fixed facing is sufficient — no per-frame billboard rotation needed). That sprite is only fully legible at the angle it was painted for. Two consequences:

- If the Inspector Viewport's camera angle doesn't match what the sprite was authored for, "focus this unit" will look wrong rather than dramatic.
- For rank-and-file units, keep the inspector camera matched to the sprite's authored angle — cheap, consistent.
- For units worth a genuine close-up (heroes, named commanders), consider giving them an actual 3D model on the same isolated-layer trick as structures, so their Inspector Viewport can use a more flattering angle than the main-camera-matched one — same "reserve the expensive treatment for what's worth it" scoping call used elsewhere in this spec.

## Extension: dual viewports for spatially-separated ranged Encounters

Per the grid-range correction in "Unit AI and Tactical Space," a ranged Encounter can have a source location and a target location that aren't the same place (a turret firing across the grid at an approaching force). This pattern is what handles the presentation of that directly, with no new mechanism:

- Two Inspector Viewports live at once — one on the firing Structure, one on the advancing force.
- As the target's position converges with the Structure's (true adjacency reached), the two locations become one, and the two viewports collapse into the single shared one already used for ordinary melee — no explicit "merge" logic required, since at that point there's genuinely only one location left to look at.

## Note for implementation

This is one reusable component — a SubViewport-backed camera on an isolated render layer, pointed at a selection — not a family of separate features. Structure cutaways, unit focus, Hero Party scouting, and dual-viewport ranged engagements are all the same component with a different target; build it once accordingly.
