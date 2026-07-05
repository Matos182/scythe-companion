# BASELINE — T0.3 truth commit

Honest before-picture of the repo at `task/T0.2-repo-hygiene` HEAD
(commit `3c217fa`) as seen by the toolchain installed in WSL2 (see
DECISIONS E3). Captured 2026-07-05 by glm-5.2 (IMP) on branch
`task/T0.3-baseline`. **Nothing was fixed** — all failures are
recorded verbatim below per the T0.3 task card. This is the yardstick
against which every subsequent task's gates are measured.

## Environment

| Tool | Version |
|---|---|
| Flutter | 3.44.4 (channel stable, 2026-06-24) |
| Dart | 3.12.2 (stable, 2026-06-09) |
| Node | v22.23.1 (manual tarball at `~/develop/node`) |
| npm | 10.9.8 |
| Android SDK | 36 + build-tools 36 + cmdline-tools 12.0 |
| OpenJDK | 21 (trixie has no JDK 17 package) |
| OS | Debian 13 trixie (WSL2) |

## Flutter client (`lib/`)

### `dart format --set-exit-if-changed .`

Exit 0 — 20 files formatted, 0 changed. **Pass.**

### `flutter pub get`

Exit 0 — dependencies resolved. **Pass.**

Notable output (verbatim, non-fatal warnings):

```
Package wakelock:windows references wakelock_windows:windows as the default
plugin, but the package does not exist, or is not a plugin package.
Ask the maintainers of wakelock to either avoid referencing a default
implementation via `platforms: windows: default_package: wakelock_windows`
or create a plugin named wakelock_windows.
```

(This warning repeats 4× — once per platform context. Root cause:
`wakelock ^0.6.2` is discontinued and its Windows platform glue is
broken. Scheduled for replacement in T0.4 → `wakelock_plus`.)

Pub outdated summary: 1 package discontinued (`wakelock`), 42 packages
have newer versions incompatible with the current `pubspec.yaml`
constraints. Full list captured in the `pub get` stdout above; key
stale deps (per audit A14): `socket_io_client 1.0.2` (current 3.1.6),
`go_router 13.2.0` (current 17.3.0), `flutter_lints 3.0.1` (current
6.0.0), `wakelock 0.6.2` (discontinued).

#### pubspec.lock drift — correction of record

The REV-adhoc hand-off (2026-07-05) flagged ~66 lines of transitive
bumps in `pubspec.lock` from a `pub get` under Flutter 3.44.4, and
asked T0.3 to record it. **Finding on this branch: no drift.**
`pubspec.lock` is 506 lines, `git diff --stat pubspec.lock` is empty
after `pub get`. The drift the REV observed was already committed in
T0.2 (commit `0447a5c`); the lockfile now matches the resolved
dependency set and is stable. Recorded here so the before-picture
stays honest — the ~66-line churn is baked into the T0.2 diff, not
a live drift on T0.3.

### `flutter analyze`

Exit 1 — **59 issues found** (2 errors + 57 info), ran in 1.4s.

#### Errors (2) — pre-existing, audit A11

Both in `lib/resources/socket_client.dart`, both caused by the
gitignored `lib/env/env.dart` not existing in the repo (compile-time
server address — the repo doesn't compile after clone):

```
error • Target of URI doesn't exist: '../env/env.dart'. Try creating
       the file referenced by the URI, or try using a URI for a file
       that does exist
       • lib/resources/socket_client.dart:4:8 • uri_does_not_exist

error • Undefined name 'ipaddress2'. Try correcting the name to one
       that is defined, or defining the name
       • lib/resources/socket_client.dart:11:30 • undefined_identifier
```

#### Info (57) — all `deprecated_member_use`

Two deprecation families, all pre-existing (audit A14 era, Flutter
has advanced since the original write):

1. **`MaterialState*` → `WidgetState*`** (deprecated after v3.19.0-0.3.pre)
   — 49 occurrences across `lib/pages/create.dart`, `lib/pages/game.dart`,
   `lib/pages/home.dart`, `lib/pages/join.dart`, `lib/pages/player_add.dart`,
   `lib/pages/simple.dart`, `lib/widgets/turn.dart`,
   `lib/widgets/waiting_lobby.dart`. The full token family appears:
   `MaterialStatePropertyAll`, `MaterialStateProperty`, `MaterialState`.

2. **`value` → `initialValue`** on form fields (deprecated after
   v3.33.0-1.0.pre) — 5 occurrences: `lib/pages/create.dart:91,112,133`,
   `lib/pages/join.dart:104,125`.

(3 additional info items are the `MaterialState`/`MaterialStateProperty`
variants in `player_add.dart` and `turn.dart`/`waiting_lobby.dart` that
round out the 57. Full verbatim listing is in the `flutter analyze`
stdout above; the line:column breakdowns there are the authoritative
record.)

### `flutter test`

Exit 1 — **compilation failure**, 0 passed, 1 failed to load.

The single test file is `test/widget_test.dart` — the stock Flutter
counter template (audit A15). It does not match the app (imports
`MyApp`, expects a counter that doesn't exist). It fails to compile
for two independent reasons:

1. **A11 (blocking compilation):** `lib/resources/socket_client.dart`
   imports the gitignored `lib/env/env.dart` and references the
   undefined `ipaddress2`. Any test that transitively imports the app
   will fail to load until A11 is resolved (scheduled for T3.2 —
   runtime server config + QR flow, which deletes `lib/env/`).

2. **NEW finding (not in audit A15):** `win32 3.1.4` (pulled in
   transitively by the discontinued `wakelock 0.6.2`) is incompatible
   with Dart 3.12.2. The type `UnmodifiableUint8ListView` was removed
   from `dart:typed_data` in a recent Dart revision; `win32 3.1.4`'s
   `guid.dart` still references it at lines 31, 51, 55, 99, so the
   test isolate won't compile even if A11 were fixed.

   Verbatim errors (4 distinct sites, same root cause):
   ```
   ../../.pub-cache/hosted/pub.dev/win32-3.1.4/lib/src/guid.dart:31:9:
   Error: Type 'UnmodifiableUint8ListView' not found.
     final UnmodifiableUint8ListView bytes;
   ../../.pub-cache/hosted/pub.dev/win32-3.1.4/lib/src/guid.dart:51:17:
   Error: Method not found: 'UnmodifiableUint8ListView'.
   ../../.pub-cache/hosted/pub.dev/win32-3.1.4/lib/src/guid.dart:55:31:
   Error: Method not found: 'UnmodifiableUint8ListView'.
   ../../.pub-cache/hosted/pub.dev/win32-3.1.4/lib/src/guid.dart:99:17:
   Error: Method not found: 'UnmodifiableUint8ListView'.
   ```

   This means **`flutter test` cannot pass on the current toolchain
   regardless of the test file's content** until `wakelock` is removed
   or replaced (scheduled for T0.4 → `wakelock_plus`). The
   `wakelock:windows` platform-glue warning in `pub get` (above) is
   the same root cause surfacing earlier in the pipeline. This is a
   baseline blocker for T0.4's GATE-F "passes except pre-existing
   test debt noted in BASELINE" criterion — the test debt is not just
   the counter template, it's also the `win32 3.1.4` / Dart 3.12
   incompatibility. T0.4 should expect `flutter test` to start passing
   only after `wakelock` is replaced and `widget_test.dart` is
   rewritten or deleted.

### Full `flutter test` stdout

```
00:00 +0: loading /home/matos/dev/scythe-companion/test/widget_test.dart
lib/resources/socket_client.dart:4:8: Error: Error when reading
'lib/env/env.dart': No such file or directory
import '../env/env.dart';
       ^
../../.pub-cache/hosted/pub.dev/win32-3.1.4/lib/src/guid.dart:31:9:
Error: Type 'UnmodifiableUint8ListView' not found.
  final UnmodifiableUint8ListView bytes;
        ^^^^^^^^^^^^^^^^^^^^^^^^^
lib/resources/socket_client.dart:11:30: Error: The getter 'ipaddress2'
isn't defined for the type 'SocketClient'.
    socket = i_o.io('http://$ipaddress2:3000', <String, dynamic>{
                             ^^^^^^^^^^\

[... 4 more UnmodifiableUint8ListView errors in guid.dart:51,55,99 ...]

00:00 +0 -1: loading /home/matos/dev/scythe-companion/test/widget_test.dart [E]
  Failed to load "/home/matos/dev/scythe-companion/test/widget_test.dart":
  Compilation failed for testPath=.../test/widget_test.dart
  [... same errors ...]
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/matos/dev/scythe-companion/test/widget_test.dart:
    loading /home/matos/dev/scythe-companion/test/widget_test.dart
```

## Server (`server/`)

### `npm ci`

Exit 0 — 158 packages added, audited 159 packages in 2s. **Pass.**

3 deprecation warnings (all `debug@4.1.1`, low-severity ReDoS
regression — affects versions >=3.2.0 <3.2.7 || >=4 <4.3.1).

`npm audit` reports **20 vulnerabilities** (4 low, 5 moderate, 10
high, 1 critical):

| Package | Range | Severity | Fix |
|---|---|---|---|
| `picomatch` | <=2.3.1 | high | `npm audit fix` |
| `qs` | <=6.14.1 | moderate | `npm audit fix` |
| `send` | <0.19.0 | (via `serve-static` <=1.16.0) | `npm audit fix` |
| `ws` | 7.0.0–7.5.10 | high | `npm audit fix --force` (→ socket.io@4.8.3, breaking) |

The `ws` advisory is the one that matters for Phase 2 — it's pulled
in by `socket.io ^2.5.0` (the server's current major), and the fix is
a breaking upgrade to `socket.io@4.8.3`. T2.0/T2.1 will replace this
entire stack anyway (per D2/D5: in-memory RoomStore, socket.io 4.x
server, Mongoose removed). The vulnerabilities are recorded here as
the baseline; they are not fixed in T0.3.

### `node --check index.js`

Exit 0 — syntax valid. **Pass.**

### Server `package.json` (for the record)

```json
{
  "name": "server",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node ./index.js",
    "dev": "nodemon ./index.js"
  },
  "devDependencies": { "nodemon": "^3.1.0" },
  "dependencies": {
    "express": "^4.18.2",
    "http": "^0.0.1-security",
    "mongodb": "^6.3.0",
    "mongoose": "^8.2.0",
    "socket.io": "^2.5.0"
  }
}
```

No `lint` or `test` scripts exist yet — GATE-S is not applicable
until T2.0 scaffolds them. `mongoose` + `mongodb` are present and
will be removed in T2.1 (D2 — in-memory RoomStore). `socket.io ^2.5.0`
will be upgraded to 4.x in T2.1 (D5).

## Summary — what the baseline tells us

| Gate | Result | Root cause(s) | Scheduled fix |
|---|---|---|---|
| `dart format` | ✅ pass | — | — |
| `flutter pub get` | ✅ pass | `wakelock` discontinued, platform glue broken | T0.4 |
| `flutter analyze` | ❌ 2 errors + 57 info | A11 (`env.dart`); `MaterialState*` + `value` deprecations | A11→T3.2; deprecations→T0.4/T1.4 |
| `flutter test` | ❌ compile fail | A11 + `win32 3.1.4`/Dart 3.12 incompat (via `wakelock`) | T0.4 (wakelock→wakelock_plus) + T3.2 (env.dart) |
| `npm ci` | ✅ pass | 20 vulns (1 critical) | T2.0/T2.1 (stack replacement) |
| `node --check index.js` | ✅ pass | — | — |

**Honest count:** 2 gates green, 4 red. The reds are all pre-existing
debt documented in audit A11/A14/A15 **plus one new finding**: the
`win32 3.1.4` / Dart 3.12.2 incompatibility that makes `flutter test`
uncompilable independent of the test file's content. This is the
before-picture; every subsequent task must not regress it.
