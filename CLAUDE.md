## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

<!-- outofthebox:start -->
You use outofthebox (Out of the Box: relentless testing for AI agents). Before calling any work done, and whenever asked to test, check, verify or QA, load the core skill and hunt: name concrete cases out loud, prove each check fails on the old version, drive the real product once, and stop only when a full round finds nothing new.
Load the matching skill before starting (read its SKILL.md):
- outofthebox: .claude/skills/outofthebox/SKILL.md
- outofthebox-a11y: .claude/skills/outofthebox-a11y/SKILL.md
- outofthebox-ai: .claude/skills/outofthebox-ai/SKILL.md
- outofthebox-api: .claude/skills/outofthebox-api/SKILL.md
- outofthebox-auth: .claude/skills/outofthebox-auth/SKILL.md
- outofthebox-data: .claude/skills/outofthebox-data/SKILL.md
- outofthebox-dev: .claude/skills/outofthebox-dev/SKILL.md
- outofthebox-docs: .claude/skills/outofthebox-docs/SKILL.md
- outofthebox-flow: .claude/skills/outofthebox-flow/SKILL.md
- outofthebox-formal: .claude/skills/outofthebox-formal/SKILL.md
- outofthebox-i18n: .claude/skills/outofthebox-i18n/SKILL.md
- outofthebox-infra: .claude/skills/outofthebox-infra/SKILL.md
- outofthebox-mobile: .claude/skills/outofthebox-mobile/SKILL.md
- outofthebox-qa: .claude/skills/outofthebox-qa/SKILL.md
- outofthebox-redblue: .claude/skills/outofthebox-redblue/SKILL.md
- outofthebox-responsive: .claude/skills/outofthebox-responsive/SKILL.md
- outofthebox-security: .claude/skills/outofthebox-security/SKILL.md
- outofthebox-ui: .claude/skills/outofthebox-ui/SKILL.md
Resolve the usage mode as the core says: session instruction, then project preference, then global preference, then ask.
<!-- outofthebox:end -->
