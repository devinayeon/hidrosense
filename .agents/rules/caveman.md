---
trigger: always_on
description: Caveman ultra-compressed communication skill and commands (/caveman, /caveman-commit, /caveman-review, /caveman-compress).
---

## caveman

This project has Caveman installed locally in `.agents/skills/caveman` and `.codex/skills/caveman`.

When the user types `/caveman`, "caveman mode", "talk like caveman", "be brief", or asks to reduce output tokens:
- Consult and apply `.agents/skills/caveman/SKILL.md`.
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
