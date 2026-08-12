# Quality Check

## Hard Checks

Reject or correct the result when any applicable check fails:

- no recognizably photographic source core remains visible;
- a protected subject, object count, orientation, or key relationship has drifted;
- a face, hand, landmark, or other protected region is unintentionally obscured;
- the requested orientation or aspect relationship is wrong;
- supplied wording is incorrect or unverified;
- a new or unrelated person, object, logo, signature, or watermark appears;
- an existing source signature, credit, or watermark is absent, cropped, obscured, or illegible without the user's explicit authorization;
- a local source was sent without verified metadata sanitation.

Compare the result directly with the source attribution footprint recorded in the Source Morphology Map. Treat attribution preservation as its own hard check; overall polish, composition, or beauty cannot make it pass. Do not treat an existing source signature, credit, or watermark as visual debris. Preserve it unless the user explicitly requests and is entitled to authorize a crop or removal. Absence of decorative type is not a defect when the user supplied no wording.

## Interlock Checks

Unless the user explicitly requested a framed or contact-sheet layout and that override is recorded in the winning fingerprint, reject a superficially polished result when any of these failures dominates:

- the source is a clean rectangular photo card floating on paper with decoration kept outside it;
- the only interaction is a border, tape strip, isolated cloud, arrow, or squiggle;
- all source detail receives one uniform vintage, halftone, or color filter;
- paper texture is merely an overlay and does not participate in the composition;
- every photo edge receives the same treatment, producing a template rather than a scene-specific transition;
- added motifs cannot be traced back to source shape, rhythm, material, light, or user direction.

## Aesthetic Checks

Inspect at thumbnail, normal, and close scale. When deterministic local tooling is available, also inspect a grayscale thumbnail and a coarse edge or mass view; these are diagnostic views, not replacements for human judgment.

- thumbnail: the focal relationship and page direction are immediately legible;
- normal: a protected photo core, middle-scale counterform, and source-derived continuation form one system;
- close: material evidence is selective and credible rather than noisy or synthetic;
- the detail gradient moves intentionally from photographic specificity to print simplification and quiet stock;
- one dominant process and one subordinate process have distinct jobs;
- color forms a hierarchy and every non-neutral color performs a structural role;
- negative space counterbalances the composition rather than signaling unfinished work;
- the result feels source-specific and would not fit an unrelated photograph unchanged.
- grayscale values bind photography and print into one hierarchy instead of revealing a pasted rectangular block;
- the coarse mass or edge view still shows a meaningful crossing, continuation, or overlap between the photo core and the rest of the page.

## One Targeted Correction

Make no more than one correction pass. Classify the failure first. For a surface failure, resend the complete winning specification and every protected invariant, then emphasize one local property. For a structure failure, discard the draft as a generation input and make one fresh edit from the original source under the frozen runner-up direction. For a content failure, restore the original source and full locks. Examples:

- photo became generated: restore the supplied photographic core as visibly real;
- identity drifted: preserve the supplied face and protected features without reinterpretation;
- relationship was lost: restore the specified position, gaze, gesture, or overlap;
- pasted-card effect: use the runner-up structure rather than decorating the same card;
- result is decorative: remove unsupported motifs and replace them with harvested source shapes;
- hierarchy is weak: establish a focal core, middle-scale counterform, and one quiet opposing field;
- page is crowded: simplify secondary marks while keeping the interlock plan intact;
- color floats: assign each non-neutral color a spatial job or remove it;
- text failed: correct only the supplied wording and placement;
- paper looks three-dimensional: flatten the piece and remove mockup shadows or curls.

## Honesty Check

Do not describe the photograph as unchanged, pixel-identical, or exactly preserved unless a deterministic comparison has established that claim.

## Final State

- `PASS`: every applicable hard check passes, no interlock failure dominates, and the aesthetic checks are materially satisfied.
- `LIMITED`: hard and interlock checks pass, but one non-critical surface property remains uncertain. Deliver only with a specific disclosure.
- `FAILED`: a hard check, content failure, or dominant interlock/structure failure remains after the single correction, or the required target set cannot be supplied unambiguously. Do not present the image as a successful final artifact.
