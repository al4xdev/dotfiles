---
name: publish-portfolio-cv
description: Route verified résumé content from the private career/CV archive into the isolated public portfolio CV editor. Use when asked from any repository to publish, sync, export, or update Alexsandro's CV, résumé, portfolio CV, bilingual CV, or A4 CV PDF in the separate local portfolio checkout.
---

# Publish the portfolio CV

Use the private career archive as the evidence source and the public portfolio
checkout only as a constrained rendering destination.

## Route to the destination editor

1. Set the destination to `/home/alex/git/my/porf_page`.
2. Read its `AGENTS.md` and obey the required plan/instruction sequence.
3. Read `/home/alex/git/my/porf_page/.agents/skills/cv-editor/SKILL.md`
   completely and follow it as the authoritative editing/export workflow.
4. Read only the additional CV files that skill requires. Do not explore or
   analyze unrelated portfolio source code.
5. If the checkout, downstream skill or required CV contract is missing, stop
   and report the missing path instead of creating a replacement site flow.

## Preserve the evidence boundary

- Resolve facts, disclosure limits and wording approval in the career archive
  before transferring content.
- Never convert private/restricted evidence, pending metrics or fabricated
  experience into public copy.
- Keep explicit mock/pending markers for unverified contact, education,
  certification, language-proficiency or confidential-project fields.
- Keep English and `pt-BR` shapes aligned as required by the destination
  editor. Translate meaning without strengthening a claim.

## Isolate the portfolio mutation

- For ordinary publication, edit only
  `/home/alex/git/my/porf_page/cv/content.js`.
- Do not modify the portfolio layout, renderer, iframe protocol, application
  code, tests, plans or build tooling unless the user explicitly expands the
  scope.
- Expect a dirty worktree owned by another agent. Preserve every unrelated
  tracked and untracked change.
- Stage and commit only the content file changed by this workflow. Inspect the
  staged filename list before committing.
- Push only when the user explicitly asks. Before pushing, fetch the remote and
  verify that the outgoing commit contains only the intended content change.

## Validate and publish

Run the downstream skill's required sequence:

1. `npm run test:unit`
2. Export both changed languages with `npm run cv:export -- --lang en` and
   `npm run cv:export -- --lang pt-BR`.
3. Inspect both reported `/tmp/*-preview.png` files. Require one readable,
   unclipped A4 page per language.
4. Run `npm test`.
5. Commit only `cv/content.js`.
6. If explicitly authorized, push the single content commit and report its
   hash, remote branch, export paths and unresolved fields.
