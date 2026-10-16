---
name: frontend-design
description: Create distinctive, intentional frontend design rather than generic templates. Use when building or reshaping web UI, landing pages, portfolios, showcases, catalogs or sites; includes proactive art direction, storytelling, item-specific experiences and visual validation.
---

# Frontend Design

Act as a design lead, not a template assembler. Do not wait for the user to say
"premium", "be creative" or "make it less generic". The default is a coherent,
subject-specific identity with a memorable point of view and finished details.
Build an experience of the subject, not merely a pretty page describing it.

The brief, existing design system, audience and requested scope take priority.
A small UI fix does not authorize a redesign. For dashboards and task-oriented
applications, express identity through clarity, typography and precise feedback;
do not impose cinematic storytelling on workflows that need speed and familiarity.
For new presentation sites, landing pages, portfolios, showcases and concept
catalogs, use the authored-experience approach below by default.

## 1. Choose a concept before choosing a layout

Identify the subject, audience and primary action. When creative direction is
open, choose and briefly state a concrete direction instead of asking the user
to supply every aesthetic decision. Ask when missing facts materially affect
accuracy or scope. Invent freely for explicitly fictional concepts; do not
invent business facts, testimonials, achievements or product claims for real sites.

Draw the visual vocabulary from the subject's materials, instruments, rituals,
places, artifacts and language. Decide what the visitor should feel, understand
and do. Turn this into a concise concept that connects content, composition,
typography and interaction. "Modern, clean and premium" is not a concept.

Consider two genuinely different directions briefly, choose one, and build a
compact design brief:
- **Concept:** subject, audience, purpose and the distinctive experiential idea.
- **Color:** a small palette of named hex tokens, with readable text contrast.
- **Type:** deliberate display, body and utility roles as needed; these need not
  all use separate font families. Define scale, weights and spacing.
- **Sequence:** the page's narrative or task progression, not a default section list.
- **Signature:** one memorable visual or interactive idea grounded in the subject.

Use short descriptions or a wireframe where useful. Keep planning proportional;
do not turn creative exploration into a long approval ceremony unless requested.

## 2. Build an authored experience

### Hero as an opening scene

Make the hero establish the concept immediately. Choose the most characteristic
expression of the subject: striking editorial typography, an illustration, an
object, a demonstration, photography, a composition or a meaningful interaction.
A headline, subtitle and button can work, but must not be the unexamined default.
Give the visitor enough clarity to understand the offer and the next action.
Do not bury the purpose beneath atmosphere or force an introductory animation.

### Storytelling through progression

Each section must add information or change the visitor's understanding. Shape
a progression appropriate to the brief: discovery, evidence, exploration,
comparison, resolution or action. Do not automatically produce hero → three
feature cards → statistics → testimonials → CTA. Use those sections only when
real content and the page's purpose justify them.

Vary scale, density and rhythm deliberately while retaining a coherent system.
A grid of interchangeable cards is not a substitute for art direction. Structure
and decoration must encode something meaningful: numbering for a true sequence
or catalog identity, captions for evidence, dividers for relationships.

### Items with their own character

For products, projects or exhibits, develop their individual stories and details
instead of only swapping titles in identical cards or modals. Where useful,
give each an appropriate composition, illustration, demonstration, reveal or
interaction tied to what makes it different. A record might expose provenance;
a tool might demonstrate its operation; a project might show its transformation.
These are possibilities, not a mandatory aesthetic or component recipe.

Keep navigation and controls consistent. Shared components are welcome; the
content and meaningful details should provide individuality. Do not create a
unique widget for every item merely to increase complexity, and do not hide
essential information behind hover-only effects.

### Motion with meaning

Use motion to reveal, explain, guide attention or create subject-specific
atmosphere. One orchestrated moment usually lands harder than many scattered
effects. Add interactions incrementally and check each one. Do not accumulate
parallax, cursor spotlights, grain, marquees and text scrambling as a "premium"
checklist. Keep text legible, actions responsive and content reachable throughout.
Respect reduced motion in both CSS and JavaScript; keep a usable static state.

### Respond to the person, not just the clock

Proactively consider a signature interaction driven by the visitor's touch,
pointer or deliberate gesture. Do not wait for the user to request this, and do
not equate creative frontend work with entry animations, hover states or an
ambient loop. Ask: **What could this surface do in response to the person?**
A simple layout with one beautifully responsive surface can be more distinctive
than a long narrative page. Storytelling and bespoke item views are options,
not requirements for every creative design.

Explore subject-appropriate responses: a textured field displaced by a finger,
light or depth following movement, particles yielding to contact, an object
revealing its material as it rotates under a drag, or a comparison scrubbed by
the visitor. These illustrate a category, not a recipe: do not put particles,
liquid backgrounds or cursor followers on every project. Choose a response that
expresses the concept; when justified, implement it rather than merely proposing
it. Omit it when it would undermine the task, audience or requested scope.

Design the relationship explicitly: input → affected property → immediate
feedback → settling or release behavior. Make the cause and effect perceptible;
a prerecorded loop is not a gesture-responsive experience. Keep essential text
and controls stable when the surrounding atmosphere reacts. Tune amplitude,
latency, inertia and recovery deliberately instead of moving everything equally.

Treat touch as a first-class input, not a desktop hover afterthought. Use pointer
events where appropriate, handle release/cancellation, and avoid stuck states.
Decorative surfaces must not intercept taps, hijack native scrolling, disable
page-wide touch gestures or block selection. Scope drag capture and touch-action
to intentional interactive regions. Essential actions need accessible controls
and keyboard alternatives; purely decorative responses must not be required to
understand content or navigate. Provide a quiet reduced-motion/static fallback.

Keep the interaction affordable: coalesce rendering with requestAnimationFrame,
avoid layout work per input event, stop unnecessary loops when inactive or hidden,
and release listeners/resources on teardown. Use CSS, SVG, canvas or WebGL only
as the effect warrants; a shader is not inherently more creative than a precise
CSS response. Reduce complexity if it cannot remain responsive on mobile.

Validate causality, not just appearance: move, pause, reverse and release the
pointer or finger; verify the intended response and recovery, then check that
scrolling and controls still work. Test touch and pointer where supported. A
screenshot or an animation playing alone does not demonstrate gesture response.
When tools permit, inspect a short interaction recording; disclose any input mode
or performance behavior that remains untested.

## 3. Reject interchangeable aesthetics

Before implementation, ask: **If I replaced the logo and nouns, could this be
almost any other site?** If yes, revise the concept, composition or signature,
not merely the accent color. This is a heuristic, not proof of originality.

Common defaults include cream with serif and terracotta, dark backgrounds with
neon accents, editorial hairline grids, and black/gold "luxury". None is banned;
use one when it expresses the brief, not because it is an easy premium costume.
Do not copy the palette or motifs of the last successful project into every site.
Premium means intentional hierarchy, composition, material detail, coherent copy
and reliable interactions, not a specific color scheme or maximum animation.

Spend boldness on a clear signature and let the rest support it. Restraint is not
an excuse for a generic result; originality is not an excuse for visual noise.
Minimal work needs precision; maximal work needs orchestration. Use real assets
when available, or deliberate illustrations and honest placeholders appropriate
to the brief. Do not imply missing assets have been delivered.

## 4. Treat words as design material

Write content specific enough to carry the concept. Narrative copy can evoke a
world on a presentation site; functional copy must still explain actions plainly.
Avoid interchangeable marketing filler and fabricated social proof.

Use the user's vocabulary rather than implementation terminology. Label actions
by their result: "Save changes", not "Submit". Keep the same action name through
buttons and feedback. Match tone to the audience and brand; clarity takes priority
over cleverness in navigation, forms and errors.

Empty and error states should tell people what happened and what they can do.
Do not replace useful feedback with atmospheric but ambiguous language.

## 5. Implement and inspect, not just describe

Derive implementation from the chosen design tokens and composition. Respect the
project's stack; do not add dependencies solely for decorative effects. Keep CSS
specificity understandable and inspect breakpoint overrides, intrinsic sizes and
overflow rather than hiding broken layouts with overflow-x:hidden.

Preserve a working core while adding visual polish. Use semantic controls,
visible keyboard focus, accessible labels, adequate contrast and touch targets.
Dialogs need appropriate focus handling, dismissal and a truly inactive closed
state. Animation must not be required to read content or complete an action.

When browser tools are available, render and inspect the actual result before
calling it finished. Load applicable browser skills and use supported operations.
At minimum:
- Inspect desktop and a narrow mobile viewport, including below-the-fold sections
  and item details, not just the hero. Check clipping, overlap, wrapping and reachability.
- Exercise primary links/actions and any added open/close, previous/next or scrolling
  interactions. Check keyboard behavior and reduced-motion behavior where supported.
- Inspect console/runtime errors; no errors does not prove a correct layout.
- Look at actual screenshots, not only DOM snapshots or successful capture receipts.
- Fix observed defects and repeat the relevant check before claiming it is resolved.

If rendering or a probe is unavailable, state what remains unverified. Do not
claim "responsive", "accessible" or "fully tested" solely from reading the code.
User feedback is part of iteration, not a substitute for checks you can perform.

Finish with a brief design critique: does the signature express this subject,
does the sequence serve the visitor, and are the details as reliable as the hero
is attractive? Remove decoration that weakens the idea. Report the implemented
result, checks performed and remaining limitations without promising that this
process guarantees originality or quality.
