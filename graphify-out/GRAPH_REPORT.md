# Graph Report - hidrosense  (2026-09-30)

## Corpus Check
- 181 files · ~107,609 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 55 file(s) not represented in the graph (top: (none) 12, .xcconfig 8, .xml 7)

## Summary
- 1139 nodes · 1541 edges · 105 communities (66 shown, 39 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 23 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `89358af8`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- .agents/skills/caveman-compress/scripts/cli.py
- Win32Window
- AppDelegate
- .agents/skills/caveman-compress/scripts/validate.py
- .codex/skills/caveman-compress/scripts/validate.py
- my_application.cc
- utils.cpp
- Path
- _compress_file_locked
- app.ts
- .codex/skills/caveman-compress/scripts/compress.py
- What You Must Do When Invoked
- write_bytes_atomic
- Mobile App (Flutter)
- manifest.json
- .agents/skills/caveman-explore/package.json
- .agents/skills/caveman-learn/package.json
- backend/package.json
- .codex/skills/caveman-explore/package.json
- .codex/skills/caveman-learn/package.json
- .agents/skills/caveman-compress/scripts/compress.py
- note_viewmodel.dart
- MainActivity.kt
- Database backend HidroSense
- What You Must Do When Invoked
- .agents/skills/caveman-compress/README.md
- .codex/skills/caveman-compress/README.md
- .agents/skills/cavecrew/SKILL.md
- LockTimeoutError
- Caveman Help
- .codex/skills/cavecrew/SKILL.md
- Caveman Help
- Caveman Compress
- .agents/skills/caveman/SKILL.md
- Caveman Compress
- .codex/skills/caveman/SKILL.md
- caveman-commit
- caveman-review
- caveman-commit
- caveman-review
- graphify reference: extra exports and benchmark
- graphify reference: extra exports and benchmark
- Review Caveman evidence
- Manage eval-gated experiments
- .agents/skills/caveman-setup/SKILL.md
- Review Caveman evidence
- Manage eval-gated experiments
- .codex/skills/caveman-setup/SKILL.md
- Evaluate an optimization observation
- caveman-stats
- Evaluate an optimization observation
- caveman-stats
- compilerOptions
- .agents/skills/caveman-discover/SKILL.md
- graphify reference: query, path, explain
- .codex/skills/caveman-discover/SKILL.md
- graphify reference: query, path, explain
- skills/caveman-learn — the Caveman Learn editing skill (MIT, public)
- caveman-learn skill
- skills/caveman-learn — the Caveman Learn editing skill (MIT, public)
- caveman-learn skill
- graphify reference: add a URL and watch a folder
- graphify reference: commit hook and native CLAUDE.md integration
- graphify reference: incremental update and cluster-only
- note_model.dart
- graphify reference: add a URL and watch a folder
- graphify reference: commit hook and native CLAUDE.md integration
- graphify reference: incremental update and cluster-only
- AGENTS.md
- graphify reference: GitHub clone and cross-repo merge
- graphify reference: transcribe video and audio
- hidrosense_mobile
- graphify reference: GitHub clone and cross-repo merge
- graphify reference: transcribe video and audio
- caveman.md
- rules/graphify.md
- .agents/skills/graphify/references/extraction-spec.md
- .agents/skills/investigate-first/SKILL.md
- .agents/skills/lean-build/SKILL.md
- .agents/skills/migration/SKILL.md
- .agents/skills/safe-refactor/SKILL.md
- .agents/skills/surgical-patch/SKILL.md
- .agents/skills/verify-and-stop/SKILL.md
- workflows/graphify.md
- LaunchImage.imageset/README.md
- .codex/skills/graphify/references/extraction-spec.md
- .codex/skills/investigate-first/SKILL.md
- .codex/skills/lean-build/SKILL.md
- .codex/skills/migration/SKILL.md
- .codex/skills/safe-refactor/SKILL.md
- .codex/skills/surgical-patch/SKILL.md
- .codex/skills/verify-and-stop/SKILL.md

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 24 edges
2. `ApiError` - 19 edges
3. `_compress_file_locked()` - 18 edges
4. `_compress_file_locked()` - 18 edges
5. `validate()` - 14 edges
6. `validate()` - 14 edges
7. `buildApp()` - 14 edges
8. `scripts` - 13 edges
9. `compilerOptions` - 12 edges
10. `MessageHandler` - 12 edges

## Surprising Connections (you probably didn't know these)
- `Mobile App (Flutter)` --conceptually_related_to--> `Inventory Management (Benih & Pupuk)`  [INFERRED]
  README.md → docs/A9_PPL IF_WEEK5.docx.md
- `Mobile App (Flutter)` --conceptually_related_to--> `YOLO Pest Detection`  [INFERRED]
  README.md → docs/A9_PPL IF_WEEK5.docx.md
- `Mobile App (Flutter)` --conceptually_related_to--> `Weather Care Recommendation`  [INFERRED]
  README.md → docs/A9_PPL IF_WEEK5.docx.md
- `YOLO Pest Detection` --implements--> `ML Pest Detection Pipeline`  [INFERRED]
  docs/A9_PPL IF_WEEK5.docx.md → README.md
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  apps/mobile/windows/runner/main.cpp → apps/mobile/windows/runner/utils.cpp

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Hidroponik Cultivation Lifecycle** — srs_nursery_management, srs_table_capacity_management, srs_growth_monitoring, srs_harvest_sales_tracking [INFERRED 0.95]

## Communities (105 total, 39 thin omitted)

### Community 0 - ".agents/skills/caveman-compress/scripts/cli.py"
Cohesion: 0.16
Nodes (6): main(), detect_file_type(), _is_code_line(), _is_json_content(), _is_yaml_content(), should_compress()

### Community 1 - "Win32Window"
Cohesion: 0.05
Nodes (38): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), MessageHandler, OnCreate, OnDestroy, project_, EnableFullDpiSupportIfAvailable() (+30 more)

### Community 2 - "AppDelegate"
Cohesion: 0.07
Nodes (11): AppDelegate, SceneDelegate, RunnerTests, AppDelegate, MainFlutterWindow, RunnerTests, Cocoa, Flutter (+3 more)

### Community 3 - ".agents/skills/caveman-compress/scripts/validate.py"
Cohesion: 0.10
Nodes (21): benchmark_pair(), count_tokens(), main(), print_table(), count_bullets(), extract_code_blocks(), extract_fenced_spans(), extract_headings() (+13 more)

### Community 4 - ".codex/skills/caveman-compress/scripts/validate.py"
Cohesion: 0.09
Nodes (21): benchmark_pair(), count_tokens(), main(), print_table(), count_bullets(), extract_code_blocks(), extract_fenced_spans(), extract_headings() (+13 more)

### Community 5 - "my_application.cc"
Cohesion: 0.10
Nodes (13): main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line(), my_application_new() (+5 more)

### Community 6 - "utils.cpp"
Cohesion: 0.13
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 7 - "Path"
Cohesion: 0.21
Nodes (7): backup_dir_for(), compress_file(), file_lock(), is_sensitive_path(), lock_path_for(), _state_base_dir(), _unlock()

### Community 8 - "_compress_file_locked"
Cohesion: 0.12
Nodes (9): build_compress_prompt(), build_fix_prompt(), _compress_file_locked(), first_nonblank_line(), _is_smaller_than_body(), mask_code_blocks(), read_source(), restore_code_blocks() (+1 more)

### Community 9 - "app.ts"
Cohesion: 0.06
Nodes (62): md, skillFile, skill, extensions, largest, root, AppOptions, buildApp() (+54 more)

### Community 10 - ".codex/skills/caveman-compress/scripts/compress.py"
Cohesion: 0.06
Nodes (29): main(), backup_dir_for(), build_compress_prompt(), build_fix_prompt(), call_claude(), compress_file(), _compress_file_locked(), file_lock() (+21 more)

### Community 11 - "What You Must Do When Invoked"
Cohesion: 0.08
Nodes (24): For /graphify add and --watch, For /graphify query, For the commit hook and native CLAUDE.md integration, For --update and --cluster-only, /graphify, Honesty Rules, Interpreter guard for subcommands, Part A - Structural extraction for code files (+16 more)

### Community 12 - "write_bytes_atomic"
Cohesion: 0.40
Nodes (3): write_bytes_atomic(), _write_target(), write_text_atomic()

### Community 13 - "Mobile App (Flutter)"
Cohesion: 0.18
Nodes (12): Mobile App (Flutter), ML Pest Detection Pipeline, HidroSense System, BMKG Weather API Integration, Growth Monitoring (HSS / Umur Tanaman), Harvest & Sales Tracking (Pencatatan Panen), Inventory Management (Benih & Pupuk), NFT Hydroponics Cultivation (+4 more)

### Community 14 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 15 - ".agents/skills/caveman-explore/package.json"
Cohesion: 0.20
Nodes (9): description, files, license, name, private, scripts, test, type (+1 more)

### Community 16 - ".agents/skills/caveman-learn/package.json"
Cohesion: 0.20
Nodes (9): description, files, license, name, private, scripts, test, type (+1 more)

### Community 17 - "backend/package.json"
Cohesion: 0.05
Nodes (39): author, dependencies, fastify, @fastify/cors, @fastify/helmet, @libsql/client, zod, description (+31 more)

### Community 18 - ".codex/skills/caveman-explore/package.json"
Cohesion: 0.20
Nodes (9): description, files, license, name, private, scripts, test, type (+1 more)

### Community 19 - ".codex/skills/caveman-learn/package.json"
Cohesion: 0.20
Nodes (9): description, files, license, name, private, scripts, test, type (+1 more)

### Community 20 - ".agents/skills/caveman-compress/scripts/compress.py"
Cohesion: 0.11
Nodes (3): call_claude(), strip_llm_wrapper(), _try_lock_nonblocking()

### Community 21 - "note_viewmodel.dart"
Cohesion: 0.09
Nodes (11): build, main, MyApp, addNote, build, noteProvider, NoteViewModel, removeNote (+3 more)

### Community 23 - "Database backend HidroSense"
Cohesion: 0.05
Nodes (39): Backup dan pemulihan, Bukti pengujian dan batas pekerjaan, Database backend HidroSense, Disiplin migrasi, Menjalankan API dan autentikasi, Menjalankan lokal, Pemetaan DBML ke SQLite, Target Turso/libSQL (+31 more)

### Community 33 - "What You Must Do When Invoked"
Cohesion: 0.08
Nodes (24): For /graphify add and --watch, For /graphify query, For the commit hook and native CLAUDE.md integration, For --update and --cluster-only, /graphify, Honesty Rules, Interpreter guard for subcommands, Part A - Structural extraction for code files (+16 more)

### Community 34 - ".agents/skills/caveman-compress/README.md"
Cohesion: 0.09
Nodes (20): Before / After, Benchmarks, How It Work, <img src="../../docs/assets/dancing-rock.svg" width="20" height="20" alt="rock"/> Caveman (285 tokens), Install, Original (706 tokens), Part of Caveman, Security (+12 more)

### Community 35 - ".codex/skills/caveman-compress/README.md"
Cohesion: 0.09
Nodes (20): Before / After, Benchmarks, How It Work, <img src="../../docs/assets/dancing-rock.svg" width="20" height="20" alt="rock"/> Caveman (285 tokens), Install, Original (706 tokens), Part of Caveman, Security (+12 more)

### Community 36 - ".agents/skills/cavecrew/SKILL.md"
Cohesion: 0.14
Nodes (12): cavecrew, Example chaining, How to invoke, Model overrides, See also, What it does, Auto-clarity (inherited), Chaining patterns (+4 more)

### Community 38 - "Caveman Help"
Cohesion: 0.14
Nodes (12): caveman-help, Example output, How to invoke, See also, What it does, Caveman Help, Configure Default Mode, Deactivate (+4 more)

### Community 39 - ".codex/skills/cavecrew/SKILL.md"
Cohesion: 0.14
Nodes (12): cavecrew, Example chaining, How to invoke, Model overrides, See also, What it does, Auto-clarity (inherited), Chaining patterns (+4 more)

### Community 40 - "Caveman Help"
Cohesion: 0.14
Nodes (12): caveman-help, Example output, How to invoke, See also, What it does, Caveman Help, Configure Default Mode, Deactivate (+4 more)

### Community 41 - "Caveman Compress"
Cohesion: 0.17
Nodes (11): Boundaries, Caveman Compress, Compress, Compression Rules, Pattern, Preserve EXACTLY (never modify), Preserve Structure, Process (+3 more)

### Community 42 - ".agents/skills/caveman/SKILL.md"
Cohesion: 0.17
Nodes (10): caveman, Example output, How to invoke, See also, What it does, Auto-Clarity, Boundaries, Intensity (+2 more)

### Community 43 - "Caveman Compress"
Cohesion: 0.17
Nodes (11): Boundaries, Caveman Compress, Compress, Compression Rules, Pattern, Preserve EXACTLY (never modify), Preserve Structure, Process (+3 more)

### Community 44 - ".codex/skills/caveman/SKILL.md"
Cohesion: 0.17
Nodes (10): caveman, Example output, How to invoke, See also, What it does, Auto-Clarity, Boundaries, Intensity (+2 more)

### Community 45 - "caveman-commit"
Cohesion: 0.18
Nodes (9): caveman-commit, Example output, How to invoke, See also, What it does, Auto-Clarity, Boundaries, Examples (+1 more)

### Community 46 - "caveman-review"
Cohesion: 0.18
Nodes (9): caveman-review, Example output, How to invoke, See also, What it does, Auto-Clarity, Boundaries, Examples (+1 more)

### Community 47 - "caveman-commit"
Cohesion: 0.18
Nodes (9): caveman-commit, Example output, How to invoke, See also, What it does, Auto-Clarity, Boundaries, Examples (+1 more)

### Community 48 - "caveman-review"
Cohesion: 0.18
Nodes (9): caveman-review, Example output, How to invoke, See also, What it does, Auto-Clarity, Boundaries, Examples (+1 more)

### Community 49 - "graphify reference: extra exports and benchmark"
Cohesion: 0.22
Nodes (8): graphify reference: extra exports and benchmark, Step 6b - Wiki (only if --wiki flag), Step 7 - Neo4j export (only if --neo4j or --neo4j-push flag), Step 7a - FalkorDB export (only if --falkordb or --falkordb-push flag), Step 7b - SVG export (only if --svg flag), Step 7c - GraphML export (only if --graphml flag), Step 7d - MCP server (only if --mcp flag), Step 8 - Token reduction benchmark (only if total_words > 5000)

### Community 50 - "graphify reference: extra exports and benchmark"
Cohesion: 0.22
Nodes (8): graphify reference: extra exports and benchmark, Step 6b - Wiki (only if --wiki flag), Step 7 - Neo4j export (only if --neo4j or --neo4j-push flag), Step 7a - FalkorDB export (only if --falkordb or --falkordb-push flag), Step 7b - SVG export (only if --svg flag), Step 7c - GraphML export (only if --graphml flag), Step 7d - MCP server (only if --mcp flag), Step 8 - Token reduction benchmark (only if total_words > 5000)

### Community 51 - "Review Caveman evidence"
Cohesion: 0.25
Nodes (7): Hard rules, Review Caveman evidence, Step 1 — Load context, Step 2 — Establish baseline, Step 3 — Test the leading explanation with traces, Step 4 — Inspect representative traces, Step 5 — Report

### Community 52 - "Manage eval-gated experiments"
Cohesion: 0.25
Nodes (7): Manage eval-gated experiments, Non-negotiable gates, Step 1 — Load project and experiment, Step 2 — Evaluate evidence, Step 3 — Propose one action, Step 4 — Block unsafe execution, Step 5 — Re-read after external operator action

### Community 53 - ".agents/skills/caveman-setup/SKILL.md"
Cohesion: 0.25
Nodes (7): Failure templates (use verbatim, filled in — never soften), Rules (non-negotiable), Step 1 — Find every live LLM callsite, Step 2 — Pick the app slug, Step 3 — Wire each callsite, Step 4 — Verify with one real request, Step 5 — Report

### Community 54 - "Review Caveman evidence"
Cohesion: 0.25
Nodes (7): Hard rules, Review Caveman evidence, Step 1 — Load context, Step 2 — Establish baseline, Step 3 — Test the leading explanation with traces, Step 4 — Inspect representative traces, Step 5 — Report

### Community 55 - "Manage eval-gated experiments"
Cohesion: 0.25
Nodes (7): Manage eval-gated experiments, Non-negotiable gates, Step 1 — Load project and experiment, Step 2 — Evaluate evidence, Step 3 — Propose one action, Step 4 — Block unsafe execution, Step 5 — Re-read after external operator action

### Community 56 - ".codex/skills/caveman-setup/SKILL.md"
Cohesion: 0.25
Nodes (7): Failure templates (use verbatim, filled in — never soften), Rules (non-negotiable), Step 1 — Find every live LLM callsite, Step 2 — Pick the app slug, Step 3 — Wire each callsite, Step 4 — Verify with one real request, Step 5 — Report

### Community 57 - "Evaluate an optimization observation"
Cohesion: 0.29
Nodes (6): 1. Read the exact observations, 2. Ask the operator to choose, 3. Design a candidate and paired eval, 4. Apply only the approved candidate, 5. Report observations, not savings, Evaluate an optimization observation

### Community 58 - "caveman-stats"
Cohesion: 0.29
Nodes (5): caveman-stats, Example output, How to invoke, See also, What it does

### Community 59 - "Evaluate an optimization observation"
Cohesion: 0.29
Nodes (6): 1. Read the exact observations, 2. Ask the operator to choose, 3. Design a candidate and paired eval, 4. Apply only the approved candidate, 5. Report observations, not savings, Evaluate an optimization observation

### Community 60 - "caveman-stats"
Cohesion: 0.29
Nodes (5): caveman-stats, Example output, How to invoke, See also, What it does

### Community 61 - "compilerOptions"
Cohesion: 0.14
Nodes (13): compilerOptions, allowJs, checkJs, esModuleInterop, module, moduleResolution, outDir, rootDir (+5 more)

### Community 62 - ".agents/skills/caveman-discover/SKILL.md"
Cohesion: 0.33
Nodes (5): Step 1 — Inventory the workflows, Step 2 — Name them, Step 3 — Propose, then apply, Step 4 — Verify, Step 5 — Report

### Community 63 - "graphify reference: query, path, explain"
Cohesion: 0.33
Nodes (5): For /graphify explain, For /graphify path, graphify reference: query, path, explain, Step 0 — Constrained query expansion (REQUIRED before traversal), Step 1 — Traversal

### Community 64 - ".codex/skills/caveman-discover/SKILL.md"
Cohesion: 0.33
Nodes (5): Step 1 — Inventory the workflows, Step 2 — Name them, Step 3 — Propose, then apply, Step 4 — Verify, Step 5 — Report

### Community 65 - "graphify reference: query, path, explain"
Cohesion: 0.33
Nodes (5): For /graphify explain, For /graphify path, graphify reference: query, path, explain, Step 0 — Constrained query expansion (REQUIRED before traversal), Step 1 — Traversal

### Community 66 - "skills/caveman-learn — the Caveman Learn editing skill (MIT, public)"
Cohesion: 0.40
Nodes (4): Boundary (binding), Install path, Layout, skills/caveman-learn — the Caveman Learn editing skill (MIT, public)

### Community 67 - "caveman-learn skill"
Cohesion: 0.40
Nodes (4): caveman-learn skill, Honesty, Install, What it does

### Community 68 - "skills/caveman-learn — the Caveman Learn editing skill (MIT, public)"
Cohesion: 0.40
Nodes (4): Boundary (binding), Install path, Layout, skills/caveman-learn — the Caveman Learn editing skill (MIT, public)

### Community 69 - "caveman-learn skill"
Cohesion: 0.40
Nodes (4): caveman-learn skill, Honesty, Install, What it does

### Community 71 - "graphify reference: add a URL and watch a folder"
Cohesion: 0.50
Nodes (3): For /graphify add, For --watch, graphify reference: add a URL and watch a folder

### Community 72 - "graphify reference: commit hook and native CLAUDE.md integration"
Cohesion: 0.50
Nodes (3): For git commit hook, For native CLAUDE.md integration, graphify reference: commit hook and native CLAUDE.md integration

### Community 73 - "graphify reference: incremental update and cluster-only"
Cohesion: 0.50
Nodes (3): For --cluster-only, For --update (incremental re-extraction), graphify reference: incremental update and cluster-only

### Community 74 - "note_model.dart"
Cohesion: 0.50
Nodes (3): id, Note, title

### Community 76 - "graphify reference: add a URL and watch a folder"
Cohesion: 0.50
Nodes (3): For /graphify add, For --watch, graphify reference: add a URL and watch a folder

### Community 77 - "graphify reference: commit hook and native CLAUDE.md integration"
Cohesion: 0.50
Nodes (3): For git commit hook, For native CLAUDE.md integration, graphify reference: commit hook and native CLAUDE.md integration

### Community 78 - "graphify reference: incremental update and cluster-only"
Cohesion: 0.50
Nodes (3): For --cluster-only, For --update (incremental re-extraction), graphify reference: incremental update and cluster-only

## Knowledge Gaps
- **489 isolated node(s):** `name`, `version`, `license`, `private`, `type` (+484 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 695 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **39 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Win32Window` to `utils.cpp`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `@libsql/client` connect `app.ts` to `backend/package.json`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `name`, `version`, `license` to the rest of the system?**
  _489 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.05407925407925408 - nodes in this community are weakly interconnected._
- **Should `AppDelegate` be split into smaller, more focused modules?**
  _Cohesion score 0.07058823529411765 - nodes in this community are weakly interconnected._
- **Should `.agents/skills/caveman-compress/scripts/validate.py` be split into smaller, more focused modules?**
  _Cohesion score 0.0957983193277311 - nodes in this community are weakly interconnected._
- **Should `.codex/skills/caveman-compress/scripts/validate.py` be split into smaller, more focused modules?**
  _Cohesion score 0.09206349206349207 - nodes in this community are weakly interconnected._