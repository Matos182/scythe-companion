# PLAYTEST-01 — v0.4.x structured game-night test

Purpose: take the v0.4.x release around a real table of Scythe players, run
through the BRIEF release list in order, capture pass/fail per item, and
triage any defects into `orchestra/PROGRESS.md` → Backlog.
Single real run, fills the T4.4 acceptance ("one full real game of Scythe
runs on v0.4.x and the checklist is scored"). Subsequent runs → copy this
file to `PLAYTEST-02.md` and reuse the structure.

## Prereqs (check before starting)

- [ ] Signed APK installed on every test phone. Source:
  https://github.com/Matos182/scythe-companion/releases/latest
  If an older debug build is on the phone, uninstall it first
  (`com.matos.scythe_companion` ≠ old `com.example.*` builds).
- [ ] Server deployed and reachable. `curl https://<server>/healthz` returns
  JSON with `protocolVersion` and zero errors. (See `docs/DEPLOY.md`.)
- [ ] Every player has set the server URL via gear icon → `https://<server>`
  (https, NOT `wss://` — see `docs/DEPLOY.md`).
- [ ] ≥ 2 phones available. Single-phone smoke is possible for steps 1–6
  (install → first connection) by joining twice with two browsers/devices
  on the same Wi-Fi, but pass/pause/resume between real humans needs ≥ 2.
- [ ] Game night recorder: someone keeps this file open and ticks boxes live.
- [ ] Players chose nicknames, factions, and mats BEFORE the room is created
  (creator's nickname seeds the lobby display; everyone else joins and picks).

## Part A — Install, server URL, first connection (can run solo)

A1. **Fresh install runs without crashing** — Open the app on each phone.
     Pass: home menu renders four buttons (Simple Convert / Game Results /
     Create Room / Join Room) and no Android "App keeps stopping" toast.
A2. **App survives a screen rotation** — rotate each phone to landscape
     then back. Pass: UI intact, no analyzer crash dialog.
A3. **Server URL setting persists across app restart** — set URL via gear
     icon, force-stop the app, reopen. Pass: gear icon still shows the
     same URL (verify in settings, not just snackbars).

## Part B — Room lifecycle

B1. **Creator creates a room in < 30 s** — Nickname + faction + mat +
     create. Pass: short room code appears (6 chars,
     alphabet `ABCDEFGHJKMNPQRSTUVWXYZ23456789` — no ambiguous `0/O/1/I`).
B2. **Lobby QR renders and encodes the right URL+code** — phone shows a
     QR. Pass: scanning it from any other device (NOT in our app — phone's
     native camera) shows `scythe://join?server=<urlenc>&room=<code>`.
     If the scan opens in our app: known gap (Backlog, "external
     scythe:// deep-link"). Mark as **PASS-WITH-NOTE**, do not block.
B3. **Joiner scans QR → app prefills server URL and code** — second phone,
     Join Room → Scan QR. Pass: server URL field populated from QR, code
     field populated, scan exits the modal and returns user to Join form.
     Joiner then picks faction/mat/taps Join.
B4. **Joiner can also join by typing the code** — third phone (or as
     backup): Join Room → enter code directly → Join. Pass: same room
     visible with all three players seated.
B5. **Server rejects duplicate faction or mat within a room** — fourth
     phone tries the same faction as phone 1. Pass: server emits a
     readable error ("faction already taken") shown via snackbar
     (humanised per T3.5, not the raw `STATE_FACTION_TAKEN` code).
B6. **Server rejects empty nickname** — join with blank nickname.
     Pass: local form validation blocks the Join button OR server error
     surfaces as snackbar without crashing.

## Part C — Game start, turn order, timer

C1. **Server resolves turn order from mat+faction-wheel, not client input**
     — start the game with 3+ seated. Pass: lobby's hand-typed order has
     no effect on whose turn banner shows up first. Quick test:
     joiners deliberately type nicknames in random order; the actual
     turn order follows Crimea→Saxony→Polania→Albion→Nordic→Rusviet→Togawa
     per `01_AUDIT A8` faction-wheel fixtures.
C2. **Turn banner shows the correct current player** — pass-and-eyes check.
     Pass: banner text and countdown both reference the same player.
C3. **Pass button passes the turn and the next player becomes current**
     — current player taps Pass. Pass: ≥ 1 s later the next seat's
     banner lights up; first player sees a "waiting" state.
C4. **Pass button is hidden/disabled for non-current players** — every
     other player looks at their screen. Pass: no Pass button visible, or
     button visibly disabled. (T3.1 gate on `isMyTurn`.)
C5. **Pause and resume work, countdown survives pause** — current player
     taps Pause when timer reads ≥ 10 s; wait 15 s; tap Resume. Pass:
     timer resumes at the original value (not 15 s lower) and ticks
     again. (T2.2 fixture: "remaining survives pause".)
C6. **Timer is accurate to ±1 s** — observe the countdown on two phones
     for 60 s. Pass: both phones report within 1 s of each other and of
     a wall clock. (Timer is server-authoritative; clients should never
     drift apart.)
C7. **Auto-pass fires when remaining hits 0** — set the timer to 10 s
     (or whatever the in-app minimum is); wait. Pass: turn swaps to the
     next player when the timer reaches 0 without anyone pressing
     anything. (T2.2 fixture: "auto-pass at 0".)

## Part D — Notification on background

D1. **Backgrounded phone gets a "your turn" notification** — current
     player presses Home or locks the screen; wait for next-turn cycle.
     Pass: notification appears on the lockscreen with the player
     nickname + the "your turn" copy (Android 13+ may need
     POST_NOTIFICATIONS accepted on first run — see the system
     permission prompt that fires on first launch in v0.4.x).
D2. **Tapping the notification surfaces the room** — tap the notification.
     Pass: app opens on the game screen (not the home menu). (T3.4 leaves
     the callback intentionally empty; this is a stretch test, mark
     FAIL if it lands elsewhere but it is not a v0.4.x blocker.)

## Part E — Presence + reconnect (the trickiest path)

E1. **Disconnect → pause → reconnect → resume** — wait until it is
     player X's turn; player X force-stops their app or drops Wi-Fi.
     Pass within 30 s:
     (a) other players see player X as "disconnected" badge,
     (b) the server auto-pauses the timer (players see the pause icon),
     (c) when player X reconnects (reopens app, no re-pairing needed —
         playerId is device-saved), the badge goes green,
     (d) the timer resumes,
     (e) it is still X's turn.
E2. **Reconnect keeps the seat and identity** — player X rejoins, looks
     at lobby. Pass: same nickname, faction, mat as before; score-input
     history persists locally if X had any offline entries on their
     device (note for cross-device this is local only — see D4 limit).
E3. **Creator handover when creator disconnects mid-game** — make a
     fresh room with two players A (creator) and B. Wait until A's
     turn; A drops. Pass within 30 s: B becomes creator (UI badge or
     setting change visible to B; Mater note: this is a server-side
     one-way handover — A does NOT get creator back on rejoin, by
     design per T2.3 surprise (2)).
E4. **Background phone rejoin lands in the correct state** — phone
     reconnects after the relaunch from cold (not just from app
     switcher). Pass: lands inside the active game with the correct
     turn / countdown visible.

## Part F — Scoring (offline, works regardless of server)

F1. **Score calculator accepts 7 player rows** — enter 7 entries with
     popularity across the tiers (0, 6, 7, 12, 13, 18 — covers every
     tier boundary). Pass: coins computed match `test/domain/
     score_calculator_test.dart` fixtures exactly. Quick way: run
     `flutter test test/domain/score_calculator_test.dart` separately
     before the playtest and confirm it passes — then trust it
     behaviour-equal to the in-app calc.
F2. **Ties render as "Tie! Alice, Bob (100 each)"** — two players with
     identical coin totals. Pass: results page shows both names and
     no rank-1 winner badge is claimed.

## Part G — Server resilience (visible behaviour, not a fuzz test)

G1. **`/healthz` reachable during the playtest** — periodic curl from
     the recorder's laptop. Pass: returns 200 + JSON every time;
     `rooms` count reflects active rooms.
G2. **Server survives a stuck client** — one phone enters a room and
     gets its connection killed at the OS level (turn off Wi-Fi).
     Wait 5 min. Pass: server still accepts new connections from the
     other phones; no memory leak visible via `docker stats`.
G3. **TTL cleans idle rooms** — at end of night, abandon a test room
     for 3 h, then re-check `rooms` in `/healthz`. Pass: room is gone
     (D2 sweeper is 3 h by default, see `01_BRIEF` D2).

## Part H — Release/CI smoke (read-only checks, recorder runs from a laptop)

H1. **GitHub Actions CI is green on `master`** — open
     https://github.com/Matos182/scythe-companion/actions. Pass: the
     most recent CI run on master shows green ticks for both Flutter
     and server jobs. (Red is not a playtest blocker, but flag.)
H2. **README install steps work end-to-end** — record time taken for
     one new player to install + connect, follow only the README.
     Pass: under 5 min from APK download to "seated in lobby".

## Result template (fill at the end of the night)

```
Date:         <YYYY-MM-DD>
Server:       <URL + healthz response snippet>
Players:      <count, nicknames, devices>
Did full game end naturally?  yes / no
Bugs found during play:       <list — file as PROGRESS Backlog items>
Steps failed:                 <e.g. E1 rejoin took >30 s>
Overall verdict:              SHIP as v0.4.x / BLOCK until <ID> fixed
Recorder:                     <name>
```

## Defect triage (after the playtest)

For every failure recorded above, the CON (next chat) opens a
PROGRESS.md Backlog line with:

- one-sentence symptom,
- affected release-list bullet (A1…H2),
- suspected task ID to fix (most playtest failures will be T3.3 game
  screen, T3.4 notifications, or D4 rejoin — those are the
  highest-risk paths that fake-socket tests cannot reach),
- severity (blocker / major / minor),
- exit criterion (what passing test would close it).

A playtest is **PASS** iff every PART A–H item is "Pass" or
"PASS-WITH-NOTE" (notes are scope for a backlog item, not a fail).
A single blocker → SHIP BLOCKED. Otherwise SHIP AS v0.4.x and
iterate the backlog.

## Why this protocol shape

- Mirrors `orchestra/00_BRIEF.md` lines 70-80 one-to-one (every
  release-list bullet is a part, every sub-assertion a checkbox), so
  passing the protocol means passing the brief.
- Ordered "easy → multiplayer-only" so the first 20 minutes are
  doable solo, and a partial run still produces useful signal.
- D and E are the highest-risk paths (notifications, reconnect) and
  are 35% of the total checks by intent — fake-socket tests can't
  reach them, only a real game can.
- "Result template" is the bridge to PROGRESS Backlog so defect
  triage doesn't get lost between game nights.
