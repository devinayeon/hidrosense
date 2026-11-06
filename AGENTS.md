## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

## caveman

This project has Caveman installed locally in `.agents/skills/caveman` and `.codex/skills/caveman`.

When the user types `/caveman`, "caveman mode", "talk like caveman", "be brief", or asks to reduce output tokens:
- Follow instructions in `.agents/skills/caveman/SKILL.md`.
- Default style level is `full`:
  - `/caveman lite`: Remove filler and pleasantries; keep articles and complete sentences.
  - `/caveman full`: Classic caveman mode. Drop articles, fragments OK, short synonyms, no preamble or tool narration.
  - `/caveman ultra`: Maximum terseness, keyword-focused, strip conjunctions where meaning is unambiguous.
  - `stop caveman` or `normal mode`: Revert to standard conversational style.
- Sub-skills available:
  - `/caveman-commit`: Conventional Commits message compressed to intent only (`.agents/skills/caveman-commit/SKILL.md`).
  - `/caveman-review`: Compressed code review, one line per finding (`.agents/skills/caveman-review/SKILL.md`).
  - `/caveman-compress`: Compress documentation / memory files while preserving technical commands and headings (`.agents/skills/caveman-compress/SKILL.md`).
  - `/caveman-explore`: Read-only repository exploration with path:line citations (`.agents/skills/caveman-explore/SKILL.md`).
- Core boundaries:
  - NEVER distort or alter code, commands, file paths, exact error messages, numbers, or units.
  - NEVER remove security warnings or confirmations for destructive operations.
  - Maintain the user's language (e.g. Indonesian or English) while eliminating conversational fluff.

<!-- antislop:start -->
## antislop
For UI, copy, people, mobile layout, or code comments work, read `.agents/skills/antislop/SKILL.md` (core) and then the skill for the task:
- UI / visual: `.agents/skills/antislop-ui/SKILL.md`
- Copy & text: `.agents/skills/antislop-copywriting/SKILL.md`
- People: `.agents/skills/antislop-human/SKILL.md`
- Mobile / responsive: `.agents/skills/antislop-layoutmobile/SKILL.md`
- Code comments: `.agents/skills/antislop-code/SKILL.md`
Before starting, follow the core's "Two Usage Modes" section in strict order: explicit session instruction first, then global preference, then ask. A session instruction always wins. For a resolved mode, say `antislop active: <mode> (session override).` or `antislop active: <mode> (global preference).` once before presenting findings or making edits, using the actual mode and source. Acknowledging the user's request without naming the source does not replace this notice.
Only an explicit choice of antislop during or after selects a session mode. A request to review, audit, or avoid file edits does not select a mode; read the global preference in that case. Another skill's mode does not select antislop's mode.
If the mode is unresolved, ask during/after and end the response; wait for the answer before any UI review, planning, or concept. For read-only tasks, put the active-mode notice only at the start of the final answer, never in progress messages. For editing tasks, announce before the first edit and omit it from the final answer.
To update antislop later: run `npx skills update` or `npx antislop-ai --update`.
<!-- antislop:end -->


<!-- outofthebox:start -->
You use outofthebox (Out of the Box: relentless testing for AI agents). Before calling any work done, and whenever asked to test, check, verify or QA, load the core skill and hunt: name concrete cases out loud, prove each check fails on the old version, drive the real product once, and stop only when a full round finds nothing new.
Load the matching skill before starting (read its SKILL.md):
- outofthebox: .agents/skills/outofthebox/SKILL.md
- outofthebox-a11y: .agents/skills/outofthebox-a11y/SKILL.md
- outofthebox-ai: .agents/skills/outofthebox-ai/SKILL.md
- outofthebox-api: .agents/skills/outofthebox-api/SKILL.md
- outofthebox-auth: .agents/skills/outofthebox-auth/SKILL.md
- outofthebox-data: .agents/skills/outofthebox-data/SKILL.md
- outofthebox-dev: .agents/skills/outofthebox-dev/SKILL.md
- outofthebox-docs: .agents/skills/outofthebox-docs/SKILL.md
- outofthebox-flow: .agents/skills/outofthebox-flow/SKILL.md
- outofthebox-formal: .agents/skills/outofthebox-formal/SKILL.md
- outofthebox-i18n: .agents/skills/outofthebox-i18n/SKILL.md
- outofthebox-infra: .agents/skills/outofthebox-infra/SKILL.md
- outofthebox-mobile: .agents/skills/outofthebox-mobile/SKILL.md
- outofthebox-qa: .agents/skills/outofthebox-qa/SKILL.md
- outofthebox-redblue: .agents/skills/outofthebox-redblue/SKILL.md
- outofthebox-responsive: .agents/skills/outofthebox-responsive/SKILL.md
- outofthebox-security: .agents/skills/outofthebox-security/SKILL.md
- outofthebox-ui: .agents/skills/outofthebox-ui/SKILL.md
Resolve the usage mode as the core says: session instruction, then project preference, then global preference, then ask.
<!-- outofthebox:end -->
