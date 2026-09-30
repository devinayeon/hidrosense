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
