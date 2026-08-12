# Quality Check

## Isolation Audit

Before evaluating aesthetics, confirm:

- the generation call used a text prompt only;
- neither image selector was included;
- the source, style exemplars, benchmark results, and earlier drafts were not passed as edit, style, composition, or supporting references;
- any regeneration follows the same isolation rule and resends the complete frozen specification.

## Hard Checks

Reject or correct the result when any applicable check fails:

- photographic raster, photorealistic reconstruction, or a source-like photo block appears;
- the work directly traces the source framing or copies incidental layout;
- the requested relationship, subject count, directional event, or necessary counterpart is no longer readable;
- personal identity is more specific than the brief requires;
- the requested orientation or aspect relationship is wrong;
- supplied wording is incorrect or unverified;
- an invented sensitive fact, logo, signature, or watermark appears.

## Specificity Checks

Unless the user explicitly requested extreme minimalism and that override is recorded in the winning fingerprint, reject a superficially tasteful result when any failure dominates:

- one anonymous silhouette and one smooth line sit on a mostly inactive background;
- the focal figure is one undifferentiated dark mass despite source-supported color or shape partitions;
- a distinctive counterpart, gesture, posture, environmental structure, or material cue has been replaced by a generic symbol;
- quiet space has no directional pressure, interval, fade, echo, or counterweight;
- paper texture is a uniform overlay rather than a visible construction process;
- every motif is the same scale or every edge uses the same distressed treatment;
- the result could plausibly answer an unrelated source photograph without changes.

## Aesthetic Checks

Inspect at thumbnail, normal, and close scale. When deterministic local tooling is available, also inspect a grayscale thumbnail and a coarse mass view; these are diagnostics, not replacements for human judgment.

- thumbnail: the central relationship and directional force read immediately;
- normal: focal assembly, relational echo, environmental field, and counterform form a coherent score; under a recorded explicit override, every non-waived role remains visible and the reduced set still carries the source relationship and active-void logic;
- close: paper fibers, ink breakup, wash, grain, or registration vary selectively and credibly;
- body or object partitions preserve source-specific posture, material, or color relationships without facial copying;
- the chosen composition engine is visible without explanatory text;
- the dominant and subordinate processes have distinct jobs;
- every non-neutral color has a spatial or semantic function;
- active quiet space balances density without making the page feel unfinished.
- grayscale preserves broad, middle, and fine hierarchy without relying on a single accent color;
- the coarse mass view contains more than one scale of structure and shows pressure on the quiet regions.

## One Targeted Regeneration

Make no more than one prompt-only regeneration. Classify the failure first. For a surface failure, resend the complete winning Generation Blueprint and emphasize one local property. For a structure failure, compile a separate runner-up Generation Blueprint and Illustration Score from the immutable Evidence Capsule, Style Profile, and runner-up fingerprint; do not include winning-direction fields. For a meaning failure, restore the full per-subject pose ledger and semantic locks. Never include image selectors. Examples:

- output looks photographic: enforce flat non-photographic paper shapes and visible print processes;
- layout follows the source too literally: rebuild with the selected composition engine while preserving the relationship;
- meaning was lost: restore the specified subject count, counterpart, posture, interval, or directional event;
- result is generic: switch to the runner-up structure while restoring source-derived color partitions, environmental trace, and relational echo;
- result is too empty: add a grounded middle-scale counterform or environmental field, not unrelated decoration;
- result is crowded: consolidate minor motifs while preserving the focal assembly and relational echo;
- connector looks diagrammatic: vary its material, density, and contact with the related forms;
- color is decorative: assign each color a structural job or remove it;
- text failed: correct only the supplied wording and placement;
- identity is too specific: generalize face and identifying detail while preserving posture and event.

Never add any image selector to a regeneration call.

## Final State

- `PASS`: the isolation audit and hard checks pass, no specificity failure dominates, and the aesthetic checks are materially satisfied.
- `LIMITED`: isolation, hard, and specificity checks pass, but one non-critical surface property remains uncertain. Deliver only with a specific disclosure.
- `FAILED`: isolation fails, a hard or meaning check remains, or a dominant specificity/structure failure survives the single regeneration. Do not present the image as a successful final artifact.
