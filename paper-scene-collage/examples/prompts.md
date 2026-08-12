# Trigger Examples

## Should Trigger

- “保留这张街景照片，把它做成克制的纸刊拼贴海报。”
- “人物和山的关系不要变，用一块红色和干墨线扩展到照片外。”
- “Keep the original photo visible, but give it a tactile independent-magazine layout.”
- “用两张照片做同一张纸面编辑作品，两张都要看得出是真实照片。”
- “同时给我保留照片版和只保留含义的重画版。” Coordinate both routes and isolate the second call.
- “用 `$paper-scene-collage` 处理这张图。” Treat the route as selected unless the rest of the request conflicts.

## Ask One Route Question

- “把这张照片做成纸感作品。”
- “给这个场景做一个 zine 版本。”
- “用 `$paper-scene-collage` 处理，但成品绝对不能出现照片。” The explicit skill and requested output conflict; ask which intent wins.

Ask whether the real photograph should remain visible or only its meaning should be reinterpreted.

## Should Trigger Without Generation

- “先分析这种做法是否适合这张照片，不要生成。”
- “只帮我润色一份保留照片的生成提示词。”

Make zero `image_gen` calls.

## Mixed Image Coverage

For one local file plus one conversation attachment, inspect the local file immediately before generation and use one recent-image selector only if its window covers both targets. Otherwise request a unified target set; never silently omit either image.

## Structure Expectations

- “把这张雨夜公交站照片做成纸面编辑拼贴，人物和站牌仍然是照片，路面反光延伸成印刷层。” Keep the people and sign in a protected photo core; let reflection geometry carry photography into wash or screenprint. Reject a framed photo with decorative rain outside it.
- “这张海边全景保留真实船只，礁石、浪线和天空可以逐层转成纸和墨。” Compare surface-led, boundary-led, and rhythm-led directions. Select by source fit; do not produce three palette variants.
- “两张厨房照片合成一个纸面版式，两张中的动作关系都要保留。” Treat both as edit targets, build interlocking photographic islands, and ensure each crop adds distinct relationship information.
- “参考这三张版画的材料做法，但不要复制里面的主体和版式。” Analyze exemplars into a neutral Style Profile; never pass them to `image_gen`, and block subject, wording, logo, and exact-layout leakage.
- “我就是要一张照片完整放在规整纸框里。” This is an explicit framed-layout override. Keep the requested frame, but still apply source-conditioned value, paper, and color decisions; do not silently force the interlock gate.

## Anti-Collapse Acceptance

A generated result is not complete merely because it has paper texture. Reject a floating rectangular photo card, a uniform vintage filter, decoration unsupported by the source, or empty stock without a structural counterweight. A successful result contains a protected photo core, a source-derived boundary action, a middle-scale counterform, and a coherent material stack.

## Should Not Trigger

- “不要出现照片本身，只提取它的情绪重新画。” Use `paper-scene-recompose`.
- “把天空调蓝一点，去掉电线。” This is ordinary image editing.
- “这是哪里拍的？” This is image identification.
