# Graph Report - hidrosense  (2026-09-30)

## Corpus Check
- 201 files · ~91,617 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 52 file(s) not represented in the graph (top: (none) 11, .xcconfig 8, .xml 7)

## Summary
- 478 nodes · 747 edges · 33 communities (21 shown, 12 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 23 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Caveman Compression CLI
- Windows Desktop Flutter Runner
- iOS Flutter App Engine
- Document Format Validation
- Markdown Structure Verification
- Linux Desktop Flutter Runner
- Windows Runner Entrypoint & Windowing
- Caveman Detection & Argument Parsing
- LLM Compression Orchestrator
- Skill Test Harness
- Prompt Builder & Fix Strategy
- Token Benchmarking & Metrics
- File Locking & Path Safety
- HidroSense System Architecture & Lifecycle
- PWA Web Manifest & Metadata
- Package Metadata - Skill Crew
- Package Metadata - Commit
- Package Metadata - Evidence
- Package Metadata - Discover
- Package Metadata - Setup
- Atomic File I/O Utilities
- Flutter Mobile UI & Widget Testing
- Android Flutter Activity Host
- Locking & Timeout Exceptions

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 24 edges
2. `_compress_file_locked()` - 18 edges
3. `_compress_file_locked()` - 18 edges
4. `validate()` - 14 edges
5. `validate()` - 14 edges
6. `MessageHandler` - 12 edges
7. `FlutterWindow` - 10 edges
8. `Create` - 10 edges
9. `WndProc` - 10 edges
10. `detect_file_type()` - 9 edges

## Surprising Connections (you probably didn't know these)
- `Mobile App (Flutter)` --conceptually_related_to--> `YOLO Pest Detection`  [INFERRED]
  README.md → docs/A9_PPL IF_WEEK5.docx.md
- `YOLO Pest Detection` --implements--> `ML Pest Detection Pipeline`  [INFERRED]
  docs/A9_PPL IF_WEEK5.docx.md → README.md
- `Mobile App (Flutter)` --conceptually_related_to--> `Weather Care Recommendation`  [INFERRED]
  README.md → docs/A9_PPL IF_WEEK5.docx.md
- `Mobile App (Flutter)` --conceptually_related_to--> `Inventory Management (Benih & Pupuk)`  [INFERRED]
  README.md → docs/A9_PPL IF_WEEK5.docx.md
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  apps/mobile/windows/runner/main.cpp → apps/mobile/windows/runner/utils.cpp

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Hidroponik Cultivation Lifecycle** — srs_nursery_management, srs_table_capacity_management, srs_growth_monitoring, srs_harvest_sales_tracking [INFERRED 0.95]

## Communities (33 total, 12 thin omitted)

### Community 0 - "Caveman Compression CLI"
Cohesion: 0.06
Nodes (29): main(), backup_dir_for(), build_compress_prompt(), build_fix_prompt(), call_claude(), compress_file(), _compress_file_locked(), file_lock() (+21 more)

### Community 1 - "Windows Desktop Flutter Runner"
Cohesion: 0.05
Nodes (38): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), MessageHandler, OnCreate, OnDestroy, project_, EnableFullDpiSupportIfAvailable() (+30 more)

### Community 2 - "iOS Flutter App Engine"
Cohesion: 0.07
Nodes (11): AppDelegate, SceneDelegate, RunnerTests, AppDelegate, MainFlutterWindow, RunnerTests, Cocoa, Flutter (+3 more)

### Community 3 - "Document Format Validation"
Cohesion: 0.11
Nodes (17): count_bullets(), extract_code_blocks(), extract_fenced_spans(), extract_headings(), extract_indented_code_blocks(), extract_inline_codes(), extract_paths(), extract_urls() (+9 more)

### Community 4 - "Markdown Structure Verification"
Cohesion: 0.12
Nodes (17): count_bullets(), extract_code_blocks(), extract_fenced_spans(), extract_headings(), extract_indented_code_blocks(), extract_inline_codes(), extract_paths(), extract_urls() (+9 more)

### Community 5 - "Linux Desktop Flutter Runner"
Cohesion: 0.10
Nodes (13): main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line(), my_application_new() (+5 more)

### Community 6 - "Windows Runner Entrypoint & Windowing"
Cohesion: 0.13
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 7 - "Caveman Detection & Argument Parsing"
Cohesion: 0.15
Nodes (6): main(), detect_file_type(), _is_code_line(), _is_json_content(), _is_yaml_content(), should_compress()

### Community 8 - "LLM Compression Orchestrator"
Cohesion: 0.11
Nodes (3): call_claude(), strip_llm_wrapper(), _try_lock_nonblocking()

### Community 9 - "Skill Test Harness"
Cohesion: 0.18
Nodes (6): md, skillFile, skill, md, skillFile, skill

### Community 10 - "Prompt Builder & Fix Strategy"
Cohesion: 0.12
Nodes (9): build_compress_prompt(), build_fix_prompt(), _compress_file_locked(), first_nonblank_line(), _is_smaller_than_body(), mask_code_blocks(), read_source(), restore_code_blocks() (+1 more)

### Community 11 - "Token Benchmarking & Metrics"
Cohesion: 0.22
Nodes (8): benchmark_pair(), count_tokens(), main(), print_table(), benchmark_pair(), count_tokens(), main(), print_table()

### Community 12 - "File Locking & Path Safety"
Cohesion: 0.21
Nodes (7): backup_dir_for(), compress_file(), file_lock(), is_sensitive_path(), lock_path_for(), _state_base_dir(), _unlock()

### Community 13 - "HidroSense System Architecture & Lifecycle"
Cohesion: 0.18
Nodes (12): Mobile App (Flutter), ML Pest Detection Pipeline, HidroSense System, BMKG Weather API Integration, Growth Monitoring (HSS / Umur Tanaman), Harvest & Sales Tracking (Pencatatan Panen), Inventory Management (Benih & Pupuk), NFT Hydroponics Cultivation (+4 more)

### Community 14 - "PWA Web Manifest & Metadata"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 15 - "Package Metadata - Skill Crew"
Cohesion: 0.20
Nodes (9): description, files, license, name, private, scripts, test, type (+1 more)

### Community 16 - "Package Metadata - Commit"
Cohesion: 0.20
Nodes (9): description, files, license, name, private, scripts, test, type (+1 more)

### Community 17 - "Package Metadata - Evidence"
Cohesion: 0.20
Nodes (9): author, description, keywords, license, main, name, scripts, test (+1 more)

### Community 18 - "Package Metadata - Discover"
Cohesion: 0.20
Nodes (9): description, files, license, name, private, scripts, test, type (+1 more)

### Community 19 - "Package Metadata - Setup"
Cohesion: 0.20
Nodes (9): description, files, license, name, private, scripts, test, type (+1 more)

### Community 20 - "Atomic File I/O Utilities"
Cohesion: 0.40
Nodes (3): write_bytes_atomic(), _write_target(), write_text_atomic()

## Knowledge Gaps
- **75 isolated node(s):** `name`, `version`, `license`, `private`, `type` (+70 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 217 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Windows Desktop Flutter Runner` to `Windows Runner Entrypoint & Windowing`?**
  _High betweenness centrality (0.018) - this node is a cross-community bridge._
- **Why does `validate()` connect `Markdown Structure Verification` to `LLM Compression Orchestrator`, `Prompt Builder & Fix Strategy`, `Token Benchmarking & Metrics`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **What connects `name`, `version`, `license` to the rest of the system?**
  _75 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Caveman Compression CLI` be split into smaller, more focused modules?**
  _Cohesion score 0.05687645687645688 - nodes in this community are weakly interconnected._
- **Should `Windows Desktop Flutter Runner` be split into smaller, more focused modules?**
  _Cohesion score 0.05407925407925408 - nodes in this community are weakly interconnected._
- **Should `iOS Flutter App Engine` be split into smaller, more focused modules?**
  _Cohesion score 0.07058823529411765 - nodes in this community are weakly interconnected._
- **Should `Document Format Validation` be split into smaller, more focused modules?**
  _Cohesion score 0.11330049261083744 - nodes in this community are weakly interconnected._