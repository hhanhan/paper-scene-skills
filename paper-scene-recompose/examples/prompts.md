# Trigger Examples

## Should Trigger

- “读懂这张照片，但不要出现照片块，只保留人物之间的距离感重新画。”
- “把这张雨夜街景转译成非摄影的纸上插画，不要照着原构图描。”
- “Use this photo only to understand the gesture, then create a new paper-editorial illustration from text.”
- “先提取语义摘要，生成那一步不能访问照片。”
- “用 `$paper-scene-recompose` 只做语义重画。” Treat the route as selected unless the rest of the request conflicts.
- “用 `$paper-scene-recompose`，但原照片必须原样留在成品里。” The explicit skill and requested output conflict; ask which intent wins.

## Should Trigger Without Generation

- “先评估无照片像素的转译路线，不要生成。”
- “只润色一份 text-only 的纸面重构提示词。”

Make zero `image_gen` calls.

## Structure Expectations

- “一位撑伞的人和远处驶离的电车，只保留告别关系，重新做成无照片像素的纸面插画。” Freeze the person, umbrella posture, departing counterpart, distance, and wet-street pressure in the Evidence Capsule. Do not reduce the result to one silhouette and one line.
- “把两名舞者的重心交换提炼成抽象纸面作品，不要脸部细节。” Preserve subject count, opposed body directions, contact interval, and clothing-value partitions; build relation-led, environment-led, and sequence-led candidates before selecting one.
- “这张空旷沙滩几乎没有东西，但希望重构后仍有层次。” Use wind, horizon pressure, footprints, or light only when visible. Activate quiet space through scale, fade, and counterform rather than inventing icons.
- “参考这几张丝网印刷图的材料语言，但不要带入里面的人物、标志和文字。” Analyze exemplars into a neutral Style Profile and discard their content. The generation call remains text-only with both image selectors omitted.
- “我明确要极端极简，只要两个形体和大量留白。” Honor the explicit override, but require the two forms to preserve the source relationship and require the quiet region to carry directional pressure. Do not add generic symbolism.

## Anti-Collapse Acceptance

Reject a result that can be summarized as one anonymous silhouette, one smooth connector, and unused paper unless the explicit extreme-minimal override applies and the relationship remains specific. A successful result has a focal assembly, relational echo, environmental field, counterform, multiple scales of information, and source-grounded material or color behavior.

## Should Not Trigger

- “把这张照片做成纸感作品。” Let `paper-scene-collage` own the route question.
- “给这个场景做一个 zine 版本。” Let `paper-scene-collage` own the route question.
- “照片本人要保留下来，只在四周加纸张和墨线。” Use `paper-scene-collage`.
- “把背景虚化，再提亮人脸。” This is ordinary image editing.
- “图里的人是谁？” This is image identification.
