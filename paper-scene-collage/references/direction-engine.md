# Direction Engine

## Evidence Ledger

Before proposing art directions, keep a compact ledger. Every design move must point to one of these sources:

- an observed source cue;
- a protected user requirement;
- a stable property in the neutral Style Profile;
- a general production constraint such as legibility or flat reproduction.

Mark each entry as observation, interpretation, or user direction. Record confidence and exclusions. Do not promote an uncertain interpretation into a factual image invariant.

## Three Structurally Different Candidates

Create one candidate from each axis. Every pair must differ in at least two of these properties: page topology, value and quiet-space distribution, or the mechanism that carries the source into paper. Palette, texture, or medium changes alone do not constitute a different candidate.

### Surface-Led

Treat a large source depth band as the printed page field. Keep the most important photographic core intact while another band converts into an ink or wash system that continues through the page.

### Boundary-Led

Let source contours, depth breaks, or material changes determine how photography, paper, and print interlock. Use varied transitions such as dissolve, overlap, pierce, continuation, or abrasion in different local regions.

### Rhythm-Led

Carry a repeated source interval, gesture, crowd, window, branch, ripple, roof, or shadow across the photographic boundary. Use scale and density changes to bind photo and paper without turning the page into a sequence of frames.

## Candidate Fingerprint

Write each candidate with the same fields:

- `basis`: observed cues and Style Profile properties supporting the direction;
- `protected_core`: subjects, relationships, and photographic zones that must remain legible;
- `photo_role`: core, band, field, islands, or another source-specific topology;
- `boundary_graph`: local region, transition action, source cue, and layer order;
- `bridge_motifs`: source-derived forms that connect photography and print;
- `mass_map`: focal mass, counterform, quiet field, and dominant axis;
- `value_join`: how photographic contrast and print values become one hierarchy;
- `material_stack`: stock, dominant process, subordinate process, photo layer, and overprint;
- `color_jobs`: job of each non-neutral color;
- `detail_curve`: placement of broad, middle, and fine information;
- `anti_template`: the most likely generic failure and how this direction prevents it;
- `attribution_guard`: every existing source signature, credit, or watermark, its footprint and required legibility, plus whether the user explicitly authorized any crop or removal;
- `retry_trigger`: the single visible failure that would justify correction.
- `explicit_override`: exact user-requested framed, contact-sheet, or other structural exception; record which gate it waives and which content, hierarchy, material, and attribution gates remain. Use `none` when absent.

## Selection Order

Apply hard gates first:

1. protected content and source relationship can survive;
2. every existing source signature, credit, or watermark remains present and legible, unless the user explicitly authorized its crop or removal and that authorization is recorded in `attribution_guard`;
3. photography participates as a material layer rather than a floating card, unless a recorded explicit framed/contact-sheet override waives only this gate;
4. at least one meaningful boundary action and one middle-scale counterform exist;
5. added forms have source evidence;
6. the direction can be described without copying an exemplar's subject or exact layout.

Rank survivors for source fit, structural completeness, anti-template strength, material coherence, and generation risk. Prefer the lower-risk candidate when aesthetic quality is otherwise comparable. At least two candidates must pass the gates. If fewer survive, build a genuinely different replacement candidate and test it; if two survivors still cannot be established, stop before generation. Freeze the winner and retain the runner-up.

## Failure Routing

- **surface failure**: texture, edge breakup, color balance, or local mark density is wrong while the structure works. Use the one correction pass on the existing draft and source.
- **structure failure**: pasted-card effect, weak hierarchy, unsupported motifs, or dead space dominates. Do not add decoration to the failed draft. Use the one correction allowance as a fresh edit from the complete original generation target set under the runner-up direction.
- **content failure**: protected subject or relationship drifts. Restore the original source and complete locks; if one correction cannot verify them, mark `FAILED`.

A core structure failure cannot be downgraded to `LIMITED` merely because the image looks polished.
