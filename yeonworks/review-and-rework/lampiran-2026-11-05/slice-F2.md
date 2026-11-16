# Slice F2: offline first, BMKG, AI readiness, and the mobile-backend contract

Reviewer: F2. Scope: goals 1, 2, 3 and 6, plus how `apps/mobile` talks to `apps/backend`. Read-only. Nothing in the repo was changed. The probes below live only in the scratch folder.

## Goal verdicts

| Goal | Verdict | Evidence (one sentence) |
|---|---|---|
| 1. Runs locally, offline first | **Not met** | Every feature reads from and writes to the backend over HTTP. The only data on disk is a read-only inventory cache, which you cannot reach offline after a restart because login needs the server (F2-01, F2-02, F2-03). |
| 2. Internet only for BMKG | **Partly** | The app contacts only two hosts: the backend and `api.bmkg.go.id`. BMKG is called directly and its failure stays on the weather page. But every other feature also needs the backend, and the plan itself also names Cloudinary and the internet for sync (F2-09, F2-12). |
| 3. AI model downloaded once | **Not met (not started, consistent with goal 4)** | Nothing exists for a download: no `path_provider`, no model URL, no checksum, no download screen (F2-13). |
| 4. AI not started, not touched | **Met** | `lib/` has no detection screen, placeholder or TFLite code. A grep for `deteksi\|detect\|tflite\|camera\|yolo` in `lib/` finds only `GestureDetector` and one damage label, "Terserang Hama Ulat / Kutu". |
| 6. Model embedded | **Not met (not started)** | `pubspec.yaml` has no TFLite package and no model asset. Android and iOS have no camera permission. Android has no `noCompress` setting for `.tflite` (F2-13). |
| Integration contract (extra) | **Partly** | Field names and string ids and decimals match `API.md`. All 18 domain writes send `Idempotency-Key`. But sales retries make a new key on every try, which creates duplicate sales (F2-04). The sync endpoints and most `expected_version` fields go unused (F2-05, F2-06). |

## Short answers to the dispatch questions

**(a) Where data lives on the phone.** Only the inventory list is on disk: `inventory_cache.db` (`lib/data/services/inventory_cache.dart:24`). It holds one snapshot per (server, user) and is a read cache only (comment at `:17`). Every other feature (stok history, penyemaian, meja tanam, pemindahan, kerusakan, panen, penjualan, akun pegawai, profil, cuaca) keeps its data in Riverpod `StateNotifier` memory only. All of those providers except `connectedTableProvider` and `sessionProvider` are `autoDispose`. That means the data is dropped when you leave the screen (F2-08).

**(b) Does an offline write survive closing the app?** No. Offline, a write fails at once: the `SocketException` or `TimeoutException` reaches the view model, and the form shows "Tidak dapat menghubungi layanan…". The draft is kept only in an in-memory command map (below). Closing the app loses it.

**(c) Is there a queue of pending operations?** No. There are per-screen "uncertain command" slots, all in memory and all with one slot per scope:
- `HarvestCommands.pending` (`panen_viewmodel.dart:58-61`)
- `tableCommandsProvider` (`connected_table_viewmodel.dart:88-90`)
- `inventoryCommandsProvider` (`connected_inventory_viewmodel.dart:20-22`)
- `sowingCommandsProvider`, `seedlingTransferCommandsProvider` (`connected_nursery_viewmodel.dart:13, 60`)
- `damageCommandsProvider` (`damage_viewmodel.dart:44`)

These slots exist so that a manual retry reuses the same `Idempotency-Key` after a lost response. They are not an outbox: there is no persistence, no ordering, no automatic replay and no connectivity trigger.

**(d) Tokens.** Tokens are in memory only (`api_client.dart:45, 55`): "Tokens remain in memory". There is no `flutter_secure_storage` or `shared_preferences` in `pubspec.yaml`. After a restart, `ApiClient` has no token. `AppGate` shows `LoginPage` (`app_gate.dart:32`), and login is an HTTP call. Probe result: `read after restart -> 401 UNAUTHENTICATED`, and `offline login -> user=null error="Tidak dapat menghubungi layanan. Periksa koneksi lalu coba lagi."`.

**(e) Screens with no backend.**
- **Cold start:** every screen is unreachable, because login fails.
- **Mid-session drop, inventory:** shows the cached list with a "cached" label and a "Diperbarui dd/MM HH:mm" stamp (`inventaris_body.dart:192-208`, `connected_inventory_page.dart:120-130`).
- **Mid-session drop, meja tanam:** keeps the list it already loaded while the session lasts. The provider is not `autoDispose`.
- **Mid-session drop, penyemaian, panen, penjualan, kerusakan, pegawai, profil, cuaca:** keep their data only while the screen stays mounted. After a tab switch or a back-navigation, they start empty and show a spinner, then an error (F2-08).
- **The inventory add/edit form** needs `GET /jenis-inventaris` (`connected_inventory_viewmodel.dart:325-332`, not cached), so it cannot open offline.

**(f) Sync API use.** None. In `lib/` there are 0 hits for `sync/`, `X-Client-Id`, `client_id` and `cursor` (the only `cursor` hits are `cursorColor`). The app sends `expected_version` only on `PATCH /panen` and `PATCH /penjualan`, where the server requires it (`harvest_draft.dart:60`, `sale_record.dart:246`, `sales_repository.dart:92`).

**(g) Hosts contacted.** I grepped `lib/` for `Uri.parse`, `Uri(`, `http`, `Image.network`, `NetworkImage`, `GoogleFonts`, `launchUrl`, `WebSocket` and `firebase`. The app contacts two hosts:
1. **Backend.** The base URL is `--dart-define=API_BASE_URL`. A debug build falls back to `http://127.0.0.1:3000/api/v1` (`session_viewmodel.dart:31-32`). A release build falls back to an empty `Uri()` (`:35`), which fails with `CONFIGURATION`.
2. **BMKG.** `https://api.bmkg.go.id/publik/prakiraan-cuaca?adm4=…` (`bmkg_weather_service.dart:11, 54`).

`Image.network` appears in `views/widgets/item_image_placeholder.dart:31`, but that widget is never used (its only hit is its own definition). No other host is contacted, and there is no telemetry upload: `AbTestingService` only logs in memory.

**(h) What the backend is for.** In the code as it stands, the backend is the **primary and only data store**: the app is a thin online client. The backend already has sync-server features (receipts, versions, change feed, id reservation), but the app uses only idempotent replay.

### Feature table

| Feature | Read offline | Write offline | Evidence |
|---|---|---|---|
| Login / session | no | no | `api_client.dart:160-180` is HTTP only; tokens are in memory (`:55`). Probe: offline login fails. |
| Inventaris (list) | stale, mid-session only (disk cache) | no | `inventory_repository.dart:14-15` reads the cache; `:136-198` refreshes from the server; `inventory_cache.dart:17` |
| Jenis inventaris (form dropdown) | no | n/a | `connected_inventory_viewmodel.dart:325-332` has no cache |
| Stok (movement, history) | no | no | `inventory_repository.dart:81-125` |
| Penyemaian | in-memory while mounted | no (draft kept in memory only) | `connected_nursery_viewmodel.dart:210-221, 229-320` |
| Meja tanam | in-memory for the session | no (draft kept in memory only) | `connected_table_viewmodel.dart:115-130, 271` (not `autoDispose`) |
| Pemindahan | in-memory while mounted | no (draft kept in memory only) | `nursery_repository.dart:51-90`, `seedling_transfer_sheet.dart:234` |
| Kerusakan | in-memory while mounted | no (draft kept in memory only) | `damage_viewmodel.dart:128-138, 183-260` |
| Panen | in-memory while mounted | no (draft kept in memory only) | `panen_viewmodel.dart:157-181, 381-451` |
| Penjualan | in-memory while mounted | no (the draft is not even kept) | `penjualan_viewmodel.dart:59-109, 111-117` |
| Akun pegawai | in-memory while mounted | no | `employee_repository.dart`, `autoDispose` at `employee_viewmodel.dart:307` |
| Profil | in-memory while mounted | no | `profile_repository.dart`, `autoDispose` at `profile_viewmodel.dart:94` |
| Cuaca | in-memory while mounted (needs internet) | n/a | `weather_viewmodel.dart:29-35, 75-79` |

**How far the app is from "runs locally, no internet needed":** far. It is an online client with one read cache. Offline first needs a new data layer under all seven domain repositories, a persisted session, and an outbox. The view models and screens can stay mostly as they are, because they already talk to repositories and already handle "pending/uncertain" states. My estimate for one developer who knows the code is about **3 to 4 weeks**, sized below.

### The smallest architecture that reaches offline first

1. **Phone SQLite as source of truth** (`sqflite` is already a dependency). One table per server resource. Each table stores the server id, `public_id`, `version`, `payload` JSON, a `local_state` value (`synced`, `pending` or `rejected`), and a local UUID. Repositories read from SQLite only. Size: schema and migration 1 to 2 days; rewriting 7 repositories to read locally 2 to 3 days.
2. **Local apply plus outbox.** A write does three things in one SQLite transaction: it updates the local row, adds an `outbox` row (`op_id = Idempotency-Key`, `X-Client-Id` for creates, method, path, body, `depends_on`), and returns. Derived numbers such as stock balance, table capacity, active plants and stock left to sell can show "pending" until the server confirms them. That avoids copying every server rule into Dart. Size: 3 to 4 days.
3. **Outbox runner.** It starts on connectivity change (`connectivity_plus` must be added), on app resume, and on a timer. It sends operations in order: a parent before its child. After a parent succeeds, it rewrites the child's reference fields (`id_penyemaian`, `id_meja`, `id_pemindahan`, `id_panen`) to the parent's server id. A lost response is retried with the same key. It reads `Retry-After`. It marks 4xx responses as `rejected` and shows them in a "Ditolak server" list. Size: 3 to 4 days.
4. **Pull.** Read `GET /sync/changes` from a persisted cursor. For each change, call `GET /<type>/<id>` and upsert the row, but do not overwrite rows that still have pending outbox entries. On `409 SYNC_CURSOR_RESET`, reload in full from the list endpoints. Size: 2 to 3 days.
5. **Persisted session.** Store the refresh token in `flutter_secure_storage` and cache `SessionUser`. On a cold start, unlock offline with the cached identity, and refresh tokens later. The plan's WBS 2.1.4 already names "aturan sesi luring". Size: 1 to 2 days.
6. **Sync status UI and tests.** A badge with the pending count, a rejected-operations list, and tests. Size: 3 to 5 days.

**What the server already offers:** per-user idempotent receipts with replay, `X-Client-Id` id mapping, `version` on every domain record, `expected_version` conflict checks, a permission-filtered change feed with a cursor, and `POST /sync/operations` to reserve ids. That is a sound base.

**What the server is missing:** see F2-06.

---

## Findings

### F2-01 [GOAL 1] The backend is the only data store; the phone has no source of truth
- Severity: critical
- Status: VERIFIED
- Where: `apps/mobile/lib/data/repositories/*.dart`; `lib/data/services/inventory_cache.dart:17`; `pubspec.yaml:36-41`
- What: All seven domain repositories call `ApiClient` directly for both reads and writes. The plan's model is "SQLite first, then sync" (plan lines 353-355 and 541: "Sistem menyimpan seluruh data … terlebih dahulu pada basis data lokal"). That local store does not exist. The only SQLite use is a read-only snapshot of the inventory list.
- Evidence: `grep -rn "sqflite\|openDatabase" lib` finds only `inventory_cache.dart`. Each repository has a `_api.get` path and no local read path. The table in (a) to (h) above is traced feature by feature.
- Suggested fix: Add a local SQLite layer under the repositories, as in architecture items 1 and 2. Size: 1 to 1.5 weeks of the 3 to 4 week total.

### F2-02 [GOAL 1] Login needs the server and tokens are memory-only, so a restarted phone offline can do nothing
- Severity: critical
- Status: VERIFIED (probe)
- Where: `lib/data/services/api_client.dart:45, 55, 160-180`; `lib/views/pages/app_gate.dart:32`; `lib/viewmodels/session_viewmodel.dart:82-94`
- What: Tokens live in two Dart fields. A process restart, or Android killing the app in the background, means a fresh login, and login is `POST auth/login`. So offline, even the inventory cache cannot be reached: `InventoryRepository` is built only after a session user exists (`connected_inventory_viewmodel.dart:315`). The server also ends a session 7 days after the last refresh (`API.md`, section Autentikasi). A farm that is offline for more than a week has to log in online again.
- Evidence: Probe `f2/offline_probe_test.dart` printed `offline login -> user=null error="Tidak dapat menghubungi layanan. Periksa koneksi lalu coba lagi."` and `read after restart -> 401 UNAUTHENTICATED`.
- Suggested fix: Persist the refresh token and `SessionUser` in secure storage. Allow an offline unlock with the cached identity and refresh tokens on reconnect. Agree on an offline-session window with the backend. Size: 1 to 2 days on the client, plus a policy decision.

### F2-03 [GOAL 1] No outbox: offline writes fail at once and drafts die with the process
- Severity: critical
- Status: VERIFIED
- Where: `panen_viewmodel.dart:58-61, 381-451`; `connected_table_viewmodel.dart:80-90, 175-243`; `connected_inventory_viewmodel.dart:20-22, 189-286`; `connected_nursery_viewmodel.dart:13, 60, 229-320`; `damage_viewmodel.dart:34-45, 183-260`
- What: An offline write throws, and the screen shows an error. The "uncertain command" slots keep the payload and key for a manual retry, but they are plain Dart maps inside a `Provider`. Each slot holds one command per (server, user) scope, and the user can start a second write only after finishing the first. Nothing replays automatically when the connection returns. The plan requires automatic sync within 1 minute of reconnecting (plan line 592) and automatic retry (lines 616, 643).
- Evidence: Each `*CommandsProvider` is `Provider((ref) => <(...), Command>{})`. No file in `lib/` writes these maps to disk. No connectivity package is in `pubspec.yaml`.
- Suggested fix: Replace the slots with a persisted outbox table and a background runner (architecture items 2 and 3). The existing key-reuse logic shows the semantics the runner needs. Size: 1 to 1.5 weeks.

### F2-04 [GOAL 1, integration] Sales retries make a new Idempotency-Key, so a lost response creates a duplicate sale
- Severity: high
- Status: VERIFIED (probe fails on current code)
- Where: `lib/viewmodels/penjualan_viewmodel.dart:112, 133, 155`; `lib/viewmodels/catat_penjualan_viewmodel.dart:204-211`
- What: `createSale`, `updateSale` and `updateSaleHeader` each call `generateUuidV4()` on every attempt. If the server commits and the response is lost, the next tap on "Simpan" sends a new key. The server then writes a second sale. Money and harvest stock are counted twice. `API.md` ("Pakai lagi nilai yang sama saat mengirim ulang") and every other feature reuse the key.
- Evidence: Probe `f2/sale_retry_probe_test.dart` ran two `createSale` calls after a dropped first response. It printed `keys sent: [2ab6a147-…, 1b546cd8-…]`, and the `expect(keys[0], keys[1])` check failed.
- Suggested fix: Keep a `SaleCommand` (draft plus key plus uncertain flag) per scope, as `HarvestCommand` does. Reuse it while the draft is unchanged. Size: 3 to 4 hours, including a regression test that is a copy of the probe.

### F2-05 [GOAL 1, integration] The sync contract is unused: no change feed, no X-Client-Id, and most PATCHes are last-write-wins
- Severity: high
- Status: VERIFIED
- Where: all of `lib/`; `lib/data/models/nursery_record.dart:66-102`; `table_repository.dart:103-133`; `nursery_repository.dart:121-142`; `damage_repository.dart:49-108`; `inventory_repository.dart:47-75`
- What: The app never calls `GET /sync/changes` or `POST /sync/operations` and never sends `X-Client-Id`. `PATCH` on meja tanam, penyemaian, pemindahan, kerusakan and inventaris omits `expected_version`. When two phones edit the same record, the second write silently overwrites the first. `SowingRecord` does not even parse `version`, so it could not send one. Other devices see changes only through a full list reload.
- Evidence: A grep for `sync/|X-Client-Id|client_id` in `lib` finds 0 matches. A grep for `expected_version` finds only `harvest_draft.dart:60`, `sale_record.dart:246` and `sales_repository.dart:92`. `TableRecord`, `DamageRecord`, `TransferRecord` and `InventoryRecord` all parse `version`, but no caller sends it back.
- Suggested fix: Send `expected_version` from the record the user is editing, and handle `409 VERSION_CONFLICT` the way harvest does. Parse `version` in `SowingRecord`. The feed and `X-Client-Id` belong to the outbox work. Size: 1 day for `expected_version` across 5 features; the feed is in architecture item 4.

### F2-06 [GOAL 1] Server gaps that block a real offline client
- Severity: high
- Status: VERIFIED (read from code), with timings estimated
- Where: `apps/backend/src/features/sync/changes.ts:41-56`; `apps/backend/src/app.ts:85`; `apps/backend/src/features/sync/operations.ts:9-15`; `apps/backend/API.md` (sections Sinkronisasi and Autentikasi)
- What: The backend supports replay and conflict detection, but five gaps remain for an offline client:
  1. The change feed returns only `resource_type`, `domain_id`, `public_id` and `version`. The client must make one `GET` per changed record.
  2. Every `/api/` request counts against **120 requests per minute per IP**. All phones on the farm Wi-Fi share one public IP. A queue of 150 operations plus their re-reads cannot finish in the plan's "under 1 minute" (plan line 592).
  3. A child body can reference its parent only by the server's numeric id (`id_penyemaian`, `id_meja`, `id_pemindahan`, `id_panen`). An offline chain (sow, transfer, damage, harvest, sell) must be sent strictly one after another, with each child's body rewritten after its parent succeeds. There is no way to reference a parent by `client_id` or `public_id`.
  4. There is no batch endpoint. `POST /sync/operations` only reserves ids.
  5. Sessions end 7 days after the last refresh, and 30 days at most after login. An offline period of more than 7 days logs every phone out.

  Employees and profile are outside the feed and have no receipts (`panduan` line 244). That is acceptable only if account management stays online-only. The team should say so in writing.
- Evidence: `changes.ts:57-64` builds the response with ids only. `app.ts:85` calls `consumeLimit(db, \`ip:${request.ip}\`, 120, 60000, …)`. `operations.ts:11` sets `operation_type: z.literal('sync.reserve-id')`. In `API.md`: "kirim induk lebih dulu … karena anak merujuk ID server milik induk".
- Suggested fix:
  - Add record payloads to the feed (an `include=data` option), or add a bulk `GET` by ids.
  - Raise the rate limit for authenticated users, or key it by user.
  - Accept `public_id` (or client UUID) references in child bodies.
  - Optionally add a batch operations endpoint.
  - Decide the offline-session window.

  Size: 3 to 5 days on the backend.

### F2-07 [GOAL 1/2] A release build can reach only an HTTPS backend set at build time; a farm-laptop server over LAN is rejected
- Severity: high
- Status: VERIFIED (probe)
- Where: `lib/data/services/api_client.dart:78-92`; `lib/viewmodels/session_viewmodel.dart:8-36, 46`; `apps/backend/src/app.ts:82-84`; `android/app/src/debug/AndroidManifest.xml:2`
- What: `allowInsecureLocalhost` equals `kDebugMode`. A release APK refuses `http://192.168.x.x`, and the production backend refuses HTTP with `426 HTTPS_REQUIRED`. Cleartext traffic is allowed only in the debug manifest. The base URL is fixed when the APK is built: `resolveApiBaseUri` takes a `customAddress`, but nothing ever passes one. A release build without `API_BASE_URL` returns `Uri()` and fails every login with `CONFIGURATION`. So today the release app can work only with a cloud or TLS-fronted backend. That decides the deployment question in F2-12 without anyone having chosen it.
- Evidence: Probe printed `release LAN http -> 0 CONFIGURATION: Alamat layanan belum dikonfigurasi dengan benar.` A grep for `resolveApiBaseUri` finds one caller, with no argument.
- Suggested fix: Once the team picks a deployment model, either keep HTTPS-only (cloud) or support a LAN server. A LAN server needs a local TLS certificate, or a scoped `network_security_config` cleartext exception plus `NODE_ENV` handling. Add a settings field for the server address in either case. Size: half a day to 1 day after the decision.

### F2-08 [GOAL 1] Data already loaded is thrown away on a tab switch, so offline navigation turns into error screens even mid-session
- Severity: medium
- Status: VERIFIED (traced)
- Where: `lib/views/pages/main_page.dart:79-84, 115`; `autoDispose` at `connected_nursery_viewmodel.dart:323`, `penjualan_viewmodel.dart:291`, `panen_viewmodel.dart:455`, `damage_viewmodel.dart:348`, `employee_viewmodel.dart:307`, `profile_viewmodel.dart:94`, `weather_viewmodel.dart:76`
- What: `MainPage` builds only `pages[_selectedIndex]`, and the view models are `autoDispose`. Leaving penyemaian or penjualan disposes them. Coming back makes a fresh view model with an empty list, which calls the server, and offline that shows an error. Inventory survives only because `MainPage` itself watches `connectedInventoryProvider` (`:75-77`) and the data is on disk.
- Evidence: `pages[_selectedIndex]` at `main_page.dart:115`. No `IndexedStack` and no `keepAlive`.
- Suggested fix: The local store (F2-01) fixes this in passing. Until then, keep the tab view models alive (`IndexedStack` or `ref.keepAlive()`). Size: 1 to 2 hours as a stopgap.

### F2-09 [GOAL 2] The weather page needs a backend login, and it keeps no last good forecast
- Severity: medium
- Status: VERIFIED
- Where: `lib/views/components/cuaca_body.dart:16-23`; `lib/views/components/dashboard_body.dart:329`; `lib/viewmodels/weather_viewmodel.dart:29-79`; `apps/backend/src/common/permissions.ts:10`
- What: The app calls BMKG directly, so the backend is not in the data path for weather. That part is good. But the page is reachable only through a session that has `cuaca:read`, and only the backend issues that permission. If the backend is down while the internet works, weather is unreachable too.

  The forecast lives only in an `autoDispose` provider. Leaving the page drops it, and reopening it offline shows "Data cuaca belum dapat dimuat". Keeping the last good forecast with its "Diperbarui" stamp would not break the plan's rule against weather history (plan line 540: "tidak menyimpan data cuaca sebagai riwayat historis"), because it is one snapshot, not a history.

  Two more points. The service builds a specific message (timeout, HTTP status, bad JSON, wrong location), but the view model drops it and always shows one generic text (`weather_viewmodel.dart:56-62`). And the plan's "memperbarui data cuaca … secara berkala" (Operations 3) is not done: the app fetches on page open and on manual refresh only.
- Evidence: Failure is isolated: only `CuacaBody` and `CuacaPage` watch `weatherViewModelProvider`, and the dashboard does not fetch weather. Timeouts are handled (20 s, `bmkg_weather_service.dart:57`), as are non-200 responses (`:64-68`), non-JSON bodies (`:70-81`) and a location mismatch (`:83-90`). One malformed slot rejects the whole forecast (`:281-289`).
- Suggested fix: Persist one last-good `WeatherData` snapshot with its time and label it "terakhir diperbarui". Pass `BmkgWeatherException.message` through to the screen. Decide whether weather should be open without the `cuaca:read` gate when the user is offline from the backend. Size: half a day.

### F2-10 [GOAL 1/2] The plan describes three different deployment models; the code has silently chosen "cloud"
- Severity: medium
- Status: VERIFIED (plan text quoted by line)
- Where: `hidrosense-plan-docs/Hidrosense Plan Document.md` lines 105, 295, 346, 353-357, 376, 386-388, 417, 541, 592, 604-608, 616, 620
- What: Different sections of the plan describe different models:
  - **Software Interfaces (353-357):** SQLite on the phone, Turso as "basis data pusat untuk sinkronisasi", a backend "untuk integrasi API BMKG dan proses bisnis lainnya", and Cloudinary for images. That describes a cloud sync hub, with BMKG called through the backend.
  - **Operations (375-377):** login is required before any feature, and data syncs "ke server pusat secara otomatis ketika perangkat terhubung ke internet". That is also a cloud hub. It also implies that login must work offline, which today it does not.
  - **Constraints (105, 295, 417) and Hardware (346):** "Sistem membutuhkan koneksi internet untuk sinkronisasi data dan integrasi API BMKG". That contradicts goal 2's "internet only for BMKG". Cloudinary (357, 388, 1108) is another internet dependency.
  - **Design Constraints and Availability (604-608, 620):** all eight domain features must work offline, sync automatically, and offer 24-hour recording. That is offline first.

  What each reading implies:
  - **Cloud reading** (serverless backend with Turso; the owner's decision): the backend never runs on the phone or the farm. The phone is the source of truth and syncs over the internet. Goal 2 then really means "works without internet; internet is needed for sync, BMKG and images". The current HTTPS-only client fits this reading (F2-07).
  - **"Runs locally" reading** (goal 1 taken literally): the backend runs on a laptop or mini PC on the farm LAN with the file database (`DATABASE_URL=file:` is supported). Phones sync over Wi-Fi without internet. Turso and serverless go unused at runtime. The client would need LAN or cleartext support (F2-07), and the server would run with `NODE_ENV` not equal to `production`, or behind TLS.
  - **Phone-only reading:** the Node backend cannot run on the phone. This reading would remove the server, so a petani and a pegawai on separate phones could never share data.
- Evidence: Line references above. `docs/panduan-menjalankan-backend.md` sections 8 and 9 support both the local-file and serverless setups.
- Suggested fix: The owner should write down one sentence that names the host, for example "sync hub = serverless + Turso; internet needed for sync, BMKG, Cloudinary". Then align goal 2 and the Constraints sections with it. Size: 1 hour of decision; the code follows.

### F2-11 [GOAL 2] The plan says the backend integrates BMKG; the app calls BMKG directly
- Severity: low
- Status: VERIFIED
- Where: plan line 356; `apps/backend/API.md` (last line); `lib/data/services/bmkg_weather_service.dart:10-37`
- What: The plan lists the backend as the BMKG integrator. `API.md` says the opposite: "Cuaca BMKG berjalan di aplikasi mobile, bukan di backend". The direct call is the better fit for "internet only for BMKG". The BMKG location (`adm4`) can be set only at build time with `--dart-define=BMKG_ADM4` (`:30-33`, README line 64). A second farm needs a new APK.
- Evidence: Quoted above. The BMKG integration document named in the dispatch, `apps/mobile/docs/bmkg-weather-integration.md`, was deleted in commit `a6c9bf3`. I read it through `git show a6c9bf3^:…`. It still says "Tidak ada penyimpanan riwayat cuaca", which matches the code.
- Suggested fix: Update the plan's Software Interfaces line. Optionally make `adm4` a setting. Size: 1 hour for the document; half a day for the setting.

### F2-12 [GOAL 3/6] AI readiness: none of the packaging exists, and "download once" conflicts with "embedded"
- Severity: medium (planning risk, not a defect, because goal 4 says do not start)
- Status: VERIFIED for the inventory; SUSPECTED for the sizes
- Where: `apps/mobile/pubspec.yaml:30-66`; `android/app/build.gradle.kts:9-23`; `android/app/src/main/AndroidManifest.xml:2`; `ios/Runner/Info.plist`; `apps/mobile/assets/` (18 PNGs, 6.1 MB); `ml/` (file names only: `train.py`, `evaluate.py`, `export_tflite.py`, `requirements.txt`, `venv/`)
- What: The app has no detection screen and no placeholder, which is consistent with goal 4. Embedding a model needs:
  - a TFLite runtime package such as `tflite_flutter`
  - `image_picker` or `camera`
  - an `assets/models/` entry in `pubspec.yaml`
  - Android: `CAMERA` permission, an `androidResources { noCompress += "tflite" }` setting, and possibly a higher `minSdk` than `flutter.minSdkVersion` (SUSPECTED; it depends on the plugin version)
  - iOS: `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`

  "Download once" (goal 3) also needs `path_provider`, a hosting URL, a checksum or version file, a first-run download screen, and a resume-on-failure path. That is a second internet dependency besides BMKG. Goals 3 and 6 pull in different directions: a model embedded in the APK needs no download, because installing the APK is the one download.
- Evidence: `pubspec.yaml` dependencies are only `cupertino_icons`, `flutter_riverpod`, `intl`, `http`, `sqflite` and `path`. No `.tflite` file exists under `apps/mobile`.

  Sizes (SUSPECTED): the plan's baseline is YOLO11n (plan line 669), which has about 2.6 M parameters. The TFLite file would be about 10 MB in float32, about 5 MB in float16, and about 3 MB in int8. The TFLite native libraries add about 2 to 4 MB per ABI. The debug APK on disk is 94.7 MB (`build/app/outputs/flutter-apk/app-debug.apk`), but debug builds are not representative. A release split-per-ABI APK of this app is likely about 15 to 20 MB, so an embedded fp16 model adds roughly 30 to 50 percent. That is well inside store limits.
- Suggested fix: Decide "embed in APK" (simplest, and offline from day one) or "download on first run" (smaller APK, needs internet once, and goal 2 must allow it). Write the decision into the plan's Software Interfaces section. Size: none now; 1 to 2 days of packaging when AI work starts.

### F2-13 [integration] Inventory deactivation makes a new key on every tap
- Severity: low
- Status: VERIFIED
- Where: `lib/data/repositories/inventory_repository.dart:77-80`; `lib/viewmodels/connected_inventory_viewmodel.dart:300-305`
- What: `deactivateItem` always sends `generateUuidV4()`. A retry after a lost response sends a new key against a record that is already inactive. The effect is the same, but the user may see a confusing error instead of a replay. It is also the only domain write that cannot be safely put in a queue as written.
- Evidence: Line 79: `headers: {'Idempotency-Key': generateUuidV4()}`. The function has no `idempotencyKey` parameter.
- Suggested fix: Accept a key parameter and keep it in a small command, as the other writes do. Size: 1 hour.

### F2-14 [integration] Conflict and rate-limit codes are not acted on
- Severity: low
- Status: VERIFIED
- Where: `lib/viewmodels/penjualan_viewmodel.dart:111-160`; `lib/data/services/api_client.dart:123-134`; `lib/viewmodels/connected_table_viewmodel.dart:153-161`; `lib/data/models/table_record.dart`
- What: Three codes or fields are handled only as text, or not at all:
  - `409 SALE_VERSION_CONFLICT` shows as plain text, with no refresh and no conflict state. Harvest does handle its own conflict (`panen_viewmodel.dart:434-438`).
  - On `429`, the app shows its own message but ignores `Retry-After`.
  - The app ignores `saldo_valid` on tables. `refreshTable` then hits `409 TABLE_BALANCE_INVALID` on `GET /meja-tanam/:id` (`apps/backend/src/features/tables/store.ts:46`), and after a harvest that appears only as a generic warning.

  No code branches on `422`, but the app treats every 4xx as a definite rejection, which is correct.
- Evidence: A grep for `.code ==` in `lib` finds `USERNAME_TAKEN`, `ACCOUNT_DEACTIVATED`, `VALIDATION_ERROR`, `HARVEST_VERSION_CONFLICT`, `DAMAGE_EXCEEDS_ACTIVE`, `DAMAGE_RESTORE_EXCEEDS_TABLE_CAPACITY` and `SESSION_CHANGED`. Every one of them exists in the backend (grep of `ApiError(` codes).
- Suggested fix: Refresh and lock the sales form on `SALE_VERSION_CONFLICT`, as harvest does. Make the outbox read `Retry-After`. Show `saldo_valid: false` tables as "perlu koreksi". Size: half a day.

### F2-15 [integration] Lenient parsers hide contract drift
- Severity: low
- Status: VERIFIED
- Where: `lib/features/accounts/data/models/employee_model.dart:27-40`; `lib/data/models/nursery_record.dart:75-99`
- What: `EmployeeModel.fromJson` replaces missing fields with `''`, `1` and `'pegawai'`, and accepts `id` or `noTelepon` aliases that the backend never sends. `SowingRecord` accepts `consumed_materials` and `materials`, which the backend never emits; it sends only `stok_konsumsi` (`apps/backend/src/features/nursery/store.ts:75`). `SowingRecord` also defaults a missing `status_penyemaian` to `'aktif'`. The other models validate strictly, so these two hide drift that the rest of the app would catch.
- Evidence: A grep of the backend for `consumed_materials` finds 0 files. `accounts/store.ts:11-15` always emits `id_user`, `role` and `status_aktif`.
- Suggested fix: Make both parsers strict, as `SaleRecord` and `TableRecord` are. Size: 1 to 2 hours.

### F2-16 [integration] Sales totals are summed as `double`
- Severity: low
- Status: VERIFIED
- Where: `lib/data/models/sale_record.dart:30-39, 98-101, 130`; `lib/viewmodels/penjualan_viewmodel.dart:241-249, 275-277, 345-359`
- What: The app sends and receives the wire values as strings, which is correct. But it parses `harga_per_kg` and `total_harga` to `double` and sums revenue in `double`. With real rupiah values the error is far below one cent, so this is display-only. It is still the one place where `API.md`'s "decimals as strings" rule turns into floating-point arithmetic.
- Evidence: `_amount` at `sale_record.dart:30` returns `double`. `totalPendapatanBulanIniProvider` folds with `0.0`.
- Suggested fix: Sum minor units in `BigInt`, as harvest weights already do (`HarvestWeight`). Size: 1 to 2 hours.

### F2-17 [GOAL 1] A network blip during token refresh logs the user out
- Severity: low
- Status: VERIFIED (traced)
- Where: `lib/data/services/api_client.dart:182-203`
- What: `_rotate` catches every error, including timeouts, and clears the session. A `401` followed by a dropped refresh request sends the user back to the login screen, and offline that is a dead end (F2-02). The comment explains why: refresh tokens are single-use. That reasoning holds, but together with F2-02 it makes a weak network cost more.
- Evidence: Lines 195-201: `catch (_) { … clearSession(); onSessionExpired?.call(); rethrow; }`.
- Suggested fix: Once the refresh token is persisted (F2-02), keep the cached identity when a timeout happens and retry the rotation, rather than logging the user out. Size: covered by F2-02.

---

## Met and fine

- **Idempotency-Key on every domain write.** All 18 domain `POST`/`PATCH` calls in `lib/data/repositories` send `Idempotency-Key`. The 5 account calls (`employees`, `profile`) send none, which matches `API.md`: "Endpoint ini tidak memakai Idempotency-Key".
- **Retries reuse the key** for meja tanam, inventaris (item and opening stock, with separate keys), penyemaian, pemindahan, kerusakan, catatan batch and panen. Each keeps a command object (`TableCommand`, `InventorySaveCommand`, `SowingCommand`, `SeedlingTransferCommand`, `DamageCommand`, `HarvestCommand`) that is reused while the payload stays the same. The app also refuses a different payload while a result is uncertain.
- **Ids and decimals.** Ids are strings validated against `^[1-9][0-9]*$`. Decimals are sent and compared as strings (`HarvestWeight.wire`, `quantityWire`, `priceWire`). Field names in all 11 models match the backend; spot-checked `stok_konsumsi`, `sisa_benih`, `siap_pindah`, `usia_hari`, `tanaman_aktif`, `kapasitas_tersedia`, `estimasi_panen`, `berat_layak`, `total_harga`, `nama_role` and `reversal_of`.
- **Response checks.** Write responses are checked against the request (target id, version increment, echoed fields). Paging is checked for completeness and duplicates.
- **Inventory cache.** It is keyed by server and user, written in one transaction, and labelled "cached" with its time in the UI.
- **BMKG.** The app calls BMKG directly with no backend in the path. A failure stays on the weather page. Timeouts, non-200 responses, non-JSON bodies and location mismatches are all handled. No weather history is stored, as the plan requires.
- **Hosts.** The app contacts only the backend and BMKG.
- **Release security.** A release build refuses plain HTTP and redirects (`followRedirects = false`).
- **Analyzer.** `flutter analyze`: "No issues found!" (re-run).

## Probes run (scratch only)

- `…/review2/f2/sale_retry_probe_test.dart` fails on the current code: the two keys differ (F2-04).
- `…/review2/f2/offline_probe_test.dart` covers offline login, a read after restart, a release-mode LAN backend, and the repository-level key default (F2-02, F2-07).
- Both were run with `flutter test <absolute path>` from `apps/mobile`.

## Count by severity

critical 3 (F2-01, F2-02, F2-03) · high 4 (F2-04, F2-05, F2-06, F2-07) · medium 4 (F2-08, F2-09, F2-10, F2-12) · low 6 (F2-11, F2-13, F2-14, F2-15, F2-16, F2-17). Total 17.
