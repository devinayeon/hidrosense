# Graph Report - hidrosense  (2026-10-02)

## Corpus Check
- 272 files · ~158,575 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 56 file(s) not represented in the graph (top: (none) 13, .xcconfig 8, .xml 7)

## Summary
- 1790 nodes · 2536 edges · 159 communities (110 shown, 49 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 29 edges (avg confidence: 0.88)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `df599ba8`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- .agents/skills/caveman-compress/scripts/detect.py
- win32_window.cpp
- AppDelegate
- .agents/skills/caveman-compress/scripts/validate.py
- .agents/skills/caveman-compress/scripts/cli.py
- my_application.cc
- utils.cpp
- .codex/skills/caveman-compress/scripts/cli.py
- Review dan perbaikan B003
- fixture.js
- _compress_file_locked
- What You Must Do When Invoked
- dashboard_page.dart
- Mobile App (Flutter)
- manifest.json
- .agents/skills/caveman-explore/package.json
- .agents/skills/caveman-learn/package.json
- backend/package.json
- .codex/skills/caveman-explore/package.json
- .codex/skills/caveman-learn/package.json
- col_info_card_sm.dart
- main.dart
- MainActivity.kt
- Database backend HidroSense
- What You Must Do When Invoked
- .agents/skills/caveman-compress/README.md
- .codex/skills/caveman-compress/README.md
- .agents/skills/cavecrew/SKILL.md
- info_card_md.dart
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
- dashboard_body.dart
- graphify reference: add a URL and watch a folder
- graphify reference: commit hook and native CLAUDE.md integration
- graphify reference: incremental update and cluster-only
- dashboard_header.dart
- ApiError
- graphify reference: add a URL and watch a folder
- graphify reference: commit hook and native CLAUDE.md integration
- graphify reference: incremental update and cluster-only
- AGENTS.md
- package:flutter/material.dart
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
- StatelessWidget
- nodejs-backend-patterns — detailed patterns and worked examples
- Backend Development Patterns
- .agents/skills/caveman-compress/scripts/compress.py
- Win32Window
- _compress_file_locked
- MessageHandler
- MessageHandler
- Urutan Pengerjaan Backend HidroSense
- Validation Patterns - Input Validation with Zod
- Node.js Backend Patterns
- Kontrak API Backend HidroSense
- B001 dan B002: fondasi API dan autentikasi
- B003 — Akun pegawai dan profil
- crud-development/SKILL.md
- Acuan Pengembangan HidroSense
- API akun pegawai dan profil — B003
- Point
- Size
- Review B001/B002
- Backend Development Guidelines
- Architecture Overview - Backend Services
- Routing and Controllers - Best Practices
- Services and Repositories - Business Logic Layer
- Configuration Management - UnifiedConfig Pattern
- Database Patterns - Prisma Best Practices
- Async Patterns and Error Handling
- Sentry Integration and Monitoring
- Testing Guide - Backend Testing Strategies
- Complete Examples - Full Working Code
- Middleware Guide - Express Middleware Patterns
- TypeScript Best Practices
- B004 — Fondasi sinkronisasi server
- Rules
- What You Must Do When Invoked
- graphify reference: extra exports and benchmark
- graphify reference: query, path, explain
- API inventaris B005
- graphify reference: add a URL and watch a folder
- graphify reference: commit hook and native CLAUDE.md integration
- graphify reference: incremental update and cluster-only
- graphify reference: GitHub clone and cross-repo merge
- graphify reference: transcribe video and audio
- CLAUDE.md
- .claude/CLAUDE.md
- .claude/skills/graphify/references/extraction-spec.md
- .agents/skills/caveman-compress/scripts/benchmark.py
- Q: Review B000 sampai B004 untuk development B005

## God Nodes (most connected - your core abstractions)
1. `ApiError` - 45 edges
2. `@libsql/client` - 29 edges
3. `requirePermission()` - 26 edges
4. `Win32Window` - 24 edges
5. `fastify` - 23 edges
6. `parseInput()` - 22 edges
7. `_compress_file_locked()` - 18 edges
8. `_compress_file_locked()` - 18 edges
9. `authenticatedWrite()` - 16 edges
10. `Backend Development Guidelines` - 16 edges

## Surprising Connections (you probably didn't know these)
- `Perubahan untuk B003` --references--> `authenticate()`  [INFERRED]
  docs/review-backend-b001-b002.md → apps/backend/src/common/sessions.ts
- `Temuan yang telah diperbaiki` --references--> `createSession()`  [INFERRED]
  docs/review-backend-b003.md → apps/backend/src/common/sessions.ts
- `Mobile App (Flutter)` --conceptually_related_to--> `Inventory Management (Benih & Pupuk)`  [INFERRED]
  README.md → docs/A9_PPL IF_WEEK5.docx.md
- `Mobile App (Flutter)` --conceptually_related_to--> `YOLO Pest Detection`  [INFERRED]
  README.md → docs/A9_PPL IF_WEEK5.docx.md
- `Mobile App (Flutter)` --conceptually_related_to--> `Weather Care Recommendation`  [INFERRED]
  README.md → docs/A9_PPL IF_WEEK5.docx.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Hidroponik Cultivation Lifecycle** — srs_nursery_management, srs_table_capacity_management, srs_growth_monitoring, srs_harvest_sales_tracking [INFERRED 0.95]

## Communities (159 total, 49 thin omitted)

### Community 0 - ".agents/skills/caveman-compress/scripts/detect.py"
Cohesion: 0.18
Nodes (5): detect_file_type(), _is_code_line(), _is_json_content(), _is_yaml_content(), should_compress()

### Community 1 - "win32_window.cpp"
Cohesion: 0.16
Nodes (12): Scale(), Create, Destroy, SetQuitOnClose, Show, UpdateTheme, Win32Window::Win32Window(), WindowClassRegistrar (+4 more)

### Community 2 - "AppDelegate"
Cohesion: 0.07
Nodes (11): AppDelegate, SceneDelegate, RunnerTests, AppDelegate, MainFlutterWindow, RunnerTests, Cocoa, Flutter (+3 more)

### Community 3 - ".agents/skills/caveman-compress/scripts/validate.py"
Cohesion: 0.06
Nodes (34): count_bullets(), extract_code_blocks(), extract_fenced_spans(), extract_headings(), extract_indented_code_blocks(), extract_inline_codes(), extract_paths(), extract_urls() (+26 more)

### Community 4 - ".agents/skills/caveman-compress/scripts/cli.py"
Cohesion: 0.12
Nodes (10): main(), backup_dir_for(), compress_file(), file_lock(), is_sensitive_path(), lock_path_for(), LockTimeoutError, _state_base_dir() (+2 more)

### Community 5 - "my_application.cc"
Cohesion: 0.10
Nodes (13): main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line(), my_application_new() (+5 more)

### Community 6 - "utils.cpp"
Cohesion: 0.18
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 7 - ".codex/skills/caveman-compress/scripts/cli.py"
Cohesion: 0.18
Nodes (6): main(), detect_file_type(), _is_code_line(), _is_json_content(), _is_yaml_content(), should_compress()

### Community 8 - "Review dan perbaikan B003"
Cohesion: 0.40
Nodes (4): Penerapan guideline, Review dan perbaikan B003, Temuan yang telah diperbaiki, Validasi

### Community 9 - "fixture.js"
Cohesion: 0.08
Nodes (33): md, skillFile, skill, extensions, largest, root, environmentSchema, readConfig() (+25 more)

### Community 10 - "_compress_file_locked"
Cohesion: 0.08
Nodes (18): backup_dir_for(), build_compress_prompt(), build_fix_prompt(), compress_file(), _compress_file_locked(), file_lock(), is_sensitive_path(), _is_smaller_than_body() (+10 more)

### Community 11 - "What You Must Do When Invoked"
Cohesion: 0.08
Nodes (24): For /graphify add and --watch, For /graphify query, For the commit hook and native CLAUDE.md integration, For --update and --cluster-only, /graphify, Honesty Rules, Interpreter guard for subcommands, Part A - Structural extraction for code files (+16 more)

### Community 12 - "dashboard_page.dart"
Cohesion: 0.17
Nodes (7): build, createState, DashboardPage, _DashboardPageState, _onItemTapped, _pages, _selectedIndex

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
Nodes (38): author, dependencies, fastify, @fastify/cors, @fastify/helmet, @libsql/client, zod, description (+30 more)

### Community 18 - ".codex/skills/caveman-explore/package.json"
Cohesion: 0.20
Nodes (9): description, files, license, name, private, scripts, test, type (+1 more)

### Community 19 - ".codex/skills/caveman-learn/package.json"
Cohesion: 0.20
Nodes (9): description, files, license, name, private, scripts, test, type (+1 more)

### Community 20 - "col_info_card_sm.dart"
Cohesion: 0.18
Nodes (8): backgroundColor, borderColor, build, child, backgroundColor, borderColor, build, child

### Community 21 - "main.dart"
Cohesion: 0.33
Nodes (3): build, main, MyApp

### Community 23 - "Database backend HidroSense"
Cohesion: 0.25
Nodes (8): Backup dan pemulihan, Bukti pengujian dan batas pekerjaan, Database backend HidroSense, Disiplin migrasi, Menjalankan API dan autentikasi, Menjalankan lokal, Pemetaan DBML ke SQLite, Target Turso/libSQL

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

### Community 37 - "info_card_md.dart"
Cohesion: 0.29
Nodes (6): backgroundColor, bottomText, build, middleText, textColor, topText

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

### Community 74 - "dashboard_header.dart"
Cohesion: 0.33
Nodes (3): build, DashboardHeader, preferredSize

### Community 75 - "ApiError"
Cohesion: 0.06
Nodes (100): AppOptions, buildApp(), requestPath(), authenticatedWrite(), fastify, FastifyRequest, requirePermission(), ApiError (+92 more)

### Community 76 - "graphify reference: add a URL and watch a folder"
Cohesion: 0.50
Nodes (3): For /graphify add, For --watch, graphify reference: add a URL and watch a folder

### Community 77 - "graphify reference: commit hook and native CLAUDE.md integration"
Cohesion: 0.50
Nodes (3): For git commit hook, For native CLAUDE.md integration, graphify reference: commit hook and native CLAUDE.md integration

### Community 78 - "graphify reference: incremental update and cluster-only"
Cohesion: 0.50
Nodes (3): For --cluster-only, For --update (incremental re-extraction), graphify reference: incremental update and cluster-only

### Community 108 - "StatelessWidget"
Cohesion: 0.50
Nodes (3): ColInfoCardSm, InfoCardMd, RowInfoCardMd

### Community 109 - "nodejs-backend-patterns — detailed patterns and worked examples"
Cohesion: 0.06
Nodes (30): API Response Format, Authentication & Authorization, Caching Strategies, Database Patterns, Dependency Injection, DI Container, JWT Authentication, MongoDB with Mongoose (+22 more)

### Community 110 - "Backend Development Patterns"
Cohesion: 0.08
Nodes (25): API Design Patterns, Authentication & Authorization, Backend Development Patterns, Background Jobs & Queues, Cache-Aside Pattern, Caching Strategies, Centralized Error Handler, Database Patterns (+17 more)

### Community 111 - ".agents/skills/caveman-compress/scripts/compress.py"
Cohesion: 0.09
Nodes (7): call_claude(), strip_llm_wrapper(), call_claude(), first_nonblank_line(), LockTimeoutError, split_frontmatter(), strip_llm_wrapper()

### Community 112 - "Win32Window"
Cohesion: 0.16
Nodes (13): FlutterWindow, flutter_controller_, OnCreate, OnDestroy, project_, Win32Window, child_content_, GetClientArea (+5 more)

### Community 114 - "_compress_file_locked"
Cohesion: 0.10
Nodes (12): build_compress_prompt(), build_fix_prompt(), _compress_file_locked(), first_nonblank_line(), _is_smaller_than_body(), mask_code_blocks(), read_source(), restore_code_blocks() (+4 more)

### Community 116 - "MessageHandler"
Cohesion: 0.36
Nodes (5): EnableFullDpiSupportIfAvailable(), GetHandle, GetThisFromHandle, MessageHandler, WndProc

### Community 120 - "Urutan Pengerjaan Backend HidroSense"
Cohesion: 0.15
Nodes (13): B01–B04: akses dan kontrak pencatatan, B05–B10: inventaris sampai tanaman aktif, B11–B14: hasil deteksi, rekomendasi, dan tindakan aktual, B15–B18: hasil usaha dan kesiapan integrasi, B19: semua pekerjaan terkait BMKG paling akhir, Cakupan lengkap terhadap backlog dan serahan tim, Hubungan dengan sprint dan Definition of Done, Keputusan yang harus ditutup pada tahap terkait (+5 more)

### Community 121 - "Validation Patterns - Input Validation with Zod"
Cohesion: 0.06
Nodes (32): Advanced Patterns, Arrays, Basic Zod Patterns, Benefits Over Joi/Other Libraries, Conditional Validation, Controller Validation, Custom Error Messages, DTO Pattern (+24 more)

### Community 122 - "Node.js Backend Patterns"
Cohesion: 0.33
Nodes (5): Best Practices, Detailed patterns and worked examples, Node.js Backend Patterns, Testing Patterns, When to Use This Skill

### Community 123 - "Kontrak API Backend HidroSense"
Cohesion: 0.33
Nodes (6): Endpoint yang tersedia, Kontrak API Backend HidroSense, Kontrak data untuk slice berikutnya, Matriks hak akses, Penggunaan dan integrasi, Request dan respons

### Community 124 - "B001 dan B002: fondasi API dan autentikasi"
Cohesion: 0.33
Nodes (6): Aturan sesi luring, B001 dan B002: fondasi API dan autentikasi, Breakdown dan hasil, Keputusan akses yang sudah disepakati, Langkah berikutnya, Pilihan implementasi

### Community 125 - "B003 — Akun pegawai dan profil"
Cohesion: 0.29
Nodes (7): B003 — Akun pegawai dan profil, Breakdown implementasi, Keputusan dan batas pekerjaan, Pengujian, Perbaikan review B003, Pola implementasi, Review B001/B002

### Community 126 - "crud-development/SKILL.md"
Cohesion: 0.05
Nodes (35): Actions, Actions & Controllers, Controllers (Thin Dashboard Controllers), Livewire Integration for Forms & Validation, Advanced Formatting, CRUD Schema Renderers & Livewire Integration, CRUD Schemas, Implementation (+27 more)

### Community 127 - "Acuan Pengembangan HidroSense"
Cohesion: 0.33
Nodes (6): Acuan Pengembangan HidroSense, Aturan dan gerbang kualitas yang perlu diingat, Kondisi repo saat acuan pertama dibuat (30 September 2026), Konteks produk, Timeline resmi dan hasil tiap tahap, Urutan pelaksanaan pada baseline awal

### Community 128 - "API akun pegawai dan profil — B003"
Cohesion: 0.40
Nodes (5): API akun pegawai dan profil — B003, Contoh, Endpoint, Error tambahan, Field input

### Community 129 - "Point"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 130 - "Size"
Cohesion: 0.50
Nodes (3): Size, height, width

### Community 131 - "Review B001/B002"
Cohesion: 0.40
Nodes (4): Hasil dan perbaikan, Penggunaan skill, Perubahan untuk B003, Review B001/B002

### Community 132 - "Backend Development Guidelines"
Cohesion: 0.06
Nodes (30): 10. Anti-Patterns (Immediate Rejection), 11. Integration With Other Skills, 12. Operator Validation Checklist, 13. Skill Status, 1. Backend Feasibility & Risk Index (BFRI), 1. Layered Architecture Is Mandatory, 2. Core Architecture Doctrine (Non-Negotiable), 2. Routes Only Route (+22 more)

### Community 133 - "Architecture Overview - Backend Services"
Cohesion: 0.08
Nodes (25): Architecture Overview - Backend Services, Complete Flow Example, Config Directory, Controllers Directory, Directory Structure Rationale, Email Service (Mature Pattern ✅), Example: User Creation, Feature-Based Organization (+17 more)

### Community 134 - "Routing and Controllers - Best Practices"
Cohesion: 0.08
Nodes (25): Anti-Pattern 1: Business Logic in Routes (Bad ❌), Anti-Patterns, BaseController Pattern, BaseController Pattern (Template), Clean Route Pattern, Controller Error Handling, Custom Error Status Codes, Error Handling (+17 more)

### Community 135 - "Services and Repositories - Business Logic Layer"
Cohesion: 0.08
Nodes (24): 1. In-Memory Caching, 1. Single Responsibility, 2. Cache Invalidation, 2. Clear Method Names, 3. Return Types, 4. Error Handling, 5. Avoid God Services, Caching Strategies (+16 more)

### Community 136 - "Configuration Management - UnifiedConfig Pattern"
Cohesion: 0.10
Nodes (19): config.ini Structure, Configuration Management - UnifiedConfig Pattern, Configuration Structure, DO NOT Commit Secrets, Environment Overrides, Environment-Specific Configs, Find All process.env Usage, Implementation Pattern (+11 more)

### Community 137 - "Database Patterns - Prisma Best Practices"
Cohesion: 0.11
Nodes (19): Basic Pattern, Check Availability, Database Patterns - Prisma Best Practices, Error Handling, Interactive Transaction, N+1 Query Prevention, Prisma Error Types, PrismaService Usage (+11 more)

### Community 138 - "Async Patterns and Error Handling"
Cohesion: 0.11
Nodes (18): Always Use Try-Catch, Async/Await Best Practices, Async Patterns and Error Handling, asyncErrorWrapper Utility, Avoid .then() Chains, Common Async Pitfalls, Custom Error Types, Define Custom Errors (+10 more)

### Community 139 - "Sentry Integration and Monitoring"
Cohesion: 0.12
Nodes (17): 1. BaseController Pattern, 2. Workflow Error Handling, 3. Service Layer Error Handling, API Endpoint Spans, Common Mistakes, Core Principles, Cron Job Monitoring, Database Performance Tracking (+9 more)

### Community 140 - "Testing Guide - Backend Testing Strategies"
Cohesion: 0.12
Nodes (17): Coverage Targets, Integration Testing, Mock Authentication in Tests, Mock PrismaService, Mock Services, Mocking Strategies, Recommended Coverage, Run Coverage (+9 more)

### Community 141 - "Complete Examples - Full Working Code"
Cohesion: 0.13
Nodes (15): AFTER: Clean Separation ✅, BEFORE: Business Logic in Routes ❌, Complete Controller Example, Complete Examples - Full Working Code, Complete Repository, Complete Route File, Complete Service with DI, Complete User Management Feature (+7 more)

### Community 142 - "Middleware Guide - Express Middleware Patterns"
Cohesion: 0.15
Nodes (12): Audit Middleware with AsyncLocalStorage, Authentication Middleware, Composable Middleware, Comprehensive Error Handler, Critical Order (Must Follow), Error Boundary Middleware, Excellent Pattern from Blog API, Middleware Guide - Express Middleware Patterns (+4 more)

### Community 144 - "TypeScript Best Practices"
Cohesion: 0.33
Nodes (5): Make Illegal States Unrepresentable, Optional: type-fest, Pair with React Best Practices, Runtime Validation with Zod, TypeScript Best Practices

### Community 145 - "B004 — Fondasi sinkronisasi server"
Cohesion: 0.33
Nodes (5): B004 — Fondasi sinkronisasi server, Bukti, Implementasi, Koreksi audit dan batas arsitektur 2 Oktober 2026, Review B000–B003

### Community 146 - "Rules"
Cohesion: 0.06
Nodes (27): Architecture review, Business-agnostic libraries, Dependency direction, Transport and domain boundaries, Avoid PostgreSQL-only dialect usage in models; wrap in `models.types`, Detect and avoid duplicate/redundant indexes, Do not query other tables inside `@property`, Guard migration incompatibilities with dialect checks and shared types (+19 more)

### Community 147 - "What You Must Do When Invoked"
Cohesion: 0.08
Nodes (24): For /graphify add and --watch, For /graphify query, For the commit hook and native CLAUDE.md integration, For --update and --cluster-only, /graphify, Honesty Rules, Interpreter guard for subcommands, Part A - Structural extraction for code files (+16 more)

### Community 148 - "graphify reference: extra exports and benchmark"
Cohesion: 0.22
Nodes (8): graphify reference: extra exports and benchmark, Step 6b - Wiki (only if --wiki flag), Step 7 - Neo4j export (only if --neo4j or --neo4j-push flag), Step 7a - FalkorDB export (only if --falkordb or --falkordb-push flag), Step 7b - SVG export (only if --svg flag), Step 7c - GraphML export (only if --graphml flag), Step 7d - MCP server (only if --mcp flag), Step 8 - Token reduction benchmark (only if total_words > 5000)

### Community 150 - "graphify reference: query, path, explain"
Cohesion: 0.33
Nodes (5): For /graphify explain, For /graphify path, graphify reference: query, path, explain, Step 0 — Constrained query expansion (REQUIRED before traversal), Step 1 — Traversal

### Community 151 - "API inventaris B005"
Cohesion: 0.14
Nodes (12): B005 — Master inventaris, Implementasi, Koreksi audit dan refactor 2 Oktober 2026, Migrasi dan verifikasi, Review prasyarat B000–B004, API inventaris B005, Daftar, Endpoint dan hasil (+4 more)

### Community 152 - "graphify reference: add a URL and watch a folder"
Cohesion: 0.50
Nodes (3): For /graphify add, For --watch, graphify reference: add a URL and watch a folder

### Community 153 - "graphify reference: commit hook and native CLAUDE.md integration"
Cohesion: 0.50
Nodes (3): For git commit hook, For native CLAUDE.md integration, graphify reference: commit hook and native CLAUDE.md integration

### Community 154 - "graphify reference: incremental update and cluster-only"
Cohesion: 0.50
Nodes (3): For --cluster-only, For --update (incremental re-extraction), graphify reference: incremental update and cluster-only

### Community 163 - ".agents/skills/caveman-compress/scripts/benchmark.py"
Cohesion: 0.22
Nodes (8): benchmark_pair(), count_tokens(), main(), print_table(), benchmark_pair(), count_tokens(), main(), print_table()

### Community 165 - "Q: Review B000 sampai B004 untuk development B005"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Review B000 sampai B004 untuk development B005, Source Nodes

## Knowledge Gaps
- **849 isolated node(s):** `name`, `version`, `license`, `private`, `type` (+844 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1078 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **49 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `authenticate()` connect `ApiError` to `Review B001/B002`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Why does `Perubahan untuk B003` connect `Review B001/B002` to `ApiError`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **What connects `name`, `version`, `license` to the rest of the system?**
  _849 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `AppDelegate` be split into smaller, more focused modules?**
  _Cohesion score 0.07058823529411765 - nodes in this community are weakly interconnected._
- **Should `.agents/skills/caveman-compress/scripts/validate.py` be split into smaller, more focused modules?**
  _Cohesion score 0.05764411027568922 - nodes in this community are weakly interconnected._
- **Should `.agents/skills/caveman-compress/scripts/cli.py` be split into smaller, more focused modules?**
  _Cohesion score 0.11956521739130435 - nodes in this community are weakly interconnected._
- **Should `my_application.cc` be split into smaller, more focused modules?**
  _Cohesion score 0.09846153846153846 - nodes in this community are weakly interconnected._