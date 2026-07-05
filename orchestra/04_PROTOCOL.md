# 04 — ORCHESTRATION PROTOCOL

## 1. Roles and model routing (hermes-agente)

| Role | Job | Suggested model | Notes |
|---|---|---|---|
| **Conductor (CON)** | Opens/closes phases, closes decision gates with Matos, writes/splits task cards, arbitrates blockers | `claude-fable-5` (or `claude-opus-4-8`) | Chat #1 and every phase boundary |
| **Implementer (IMP)** | Executes exactly one task card | `claude-sonnet-4-6` or MiniMax | Workhorse; pick per task size (large → Sonnet/Opus, small → MiniMax/Haiku ok) |
| **Reviewer (REV)** | Reviews the diff of a finished task against its card | A **different** model than the implementer | Cross-model review catches more; Opus↔MiniMax, Sonnet↔Fable |
| **Scribe (SCR)** | PROGRESS/DECISIONS/CHANGELOG upkeep, doc tasks | `claude-haiku-4-5-20251001` | Cheap and frequent |

Routing rules: 🔴/large tasks and anything touching the timer engine or
reconnect logic → strongest available implementer + mandatory REV pass.
Small/mechanical tasks → cheaper model, REV optional (Matos's diff review
suffices). Matos may substitute models freely; role contract is what matters.

## 2. Boot block — paste at the top of EVERY chat after chat #1

```text
You are one instance in a relay of LLMs improving the repo `scythe-companion`
(working copy: <PASTE REPO PATH>). The repo is the shared memory; this chat is
disposable. Your role for this chat: <CON | IMP | REV | SCR>.
Your task: <TASK ID> from orchestra/03_ROADMAP.md.

Boot sequence, in order, before doing anything else:
1. Read AGENTS.md (repo root).
2. Read orchestra/PROGRESS.md and orchestra/DECISIONS.md.
3. Read your task card in orchestra/03_ROADMAP.md and the sections of
   orchestra/01_AUDIT.md and orchestra/02_ARCHITECTURE.md it references.
4. Confirm prerequisites of your task are ✅ in PROGRESS.md. If not, STOP and
   report instead of starting.
5. State back to Matos, in ≤ 10 lines: your task, your plan, files you will
   touch, and the branch name task/<ID>-<slug>. Wait for his GO.
If you cannot read files from disk, say so and ask Matos to paste them.
```

## 3. Rules of engagement (all roles)

- **R1** Hard constraints C1–C6 in `00_BRIEF.md` bind every chat, always.
- **R2** One task, one branch, one focused diff. Anything else you notice →
  one-line entry in PROGRESS Backlog, then hands off.
- **R3** Don't re-litigate closed decisions (DECISIONS.md). If a task proves a
  decision wrong, stop, write a BLOCKED note explaining why, and hand off to a
  Conductor chat.
- **R4** Never invent library APIs. If unsure of a current package API, check
  its docs/changelog (or ask Matos to) before writing code against it.
- **R5** Acceptance commands are non-negotiable. Red gate = task not done; say
  so plainly. Never weaken a test to pass a gate.
- **R6** Keep chats lean: don't paste whole files back at Matos; reference
  paths + line ranges; show only the diffs that matter.
- **R7** Teach-back is part of the deliverable (see §4) — this project exists
  to refresh Matos's Flutter/Dart. Explain as a mentor: short, concrete,
  tied to the code just written.
- **R8** Reviewer contract: check the diff against the task card's Done-when,
  the architecture doc, and constraints — in that order. Verdict = APPROVE /
  REQUEST CHANGES with file:line specifics. No style nitpicks beyond the
  configured lints.

## 4. Hand-off ritual — every chat ends with these 4 artifacts

1. **Commit(s)** on `task/<ID>-<slug>`, message: `<type>(<scope>): <summary>
   [<ID>]` (conventional commits: feat/fix/refactor/test/chore/docs).
2. **PROGRESS.md update**: task row → ✅ (or 🟥 BLOCKED with reason),
   backlog additions, "Next up" pointer.
3. **Hand-off note** appended to PROGRESS.md under the task:

   ```
   HANDOFF <ID> | <date> | model: <name> | branch: task/<ID>-…
   Did: …            (≤3 lines)
   Gates: F ✅/❌  S ✅/❌ n/a
   Surprises/debt: … (≤2 lines, or "none")
   Next chat needs: …(role + task + anything unusual to read first)
   ```

4. **Teach-back to Matos** (in chat, not committed): 3 bullets — the concepts
   this task exercised, the one mistake the old code made that this fixes, and
   one question for Matos to answer to test himself. Keep it under 15 lines.

## 5. When things go wrong

- Gate fails and the fix is inside task scope → fix it in this chat.
- Fix requires touching another task's territory → 🟥 BLOCKED + hand-off.
- Two models disagree (REV vs IMP) → Conductor chat decides; Matos breaks ties.
- Context window strain (long chat, model confused) → stop, hand off early
  with honest state; a fresh chat with the boot block recovers cheaply.
- Anything requiring credentials, deployment, merging, or force-push → Matos
  does it himself; models produce exact commands + runbooks only.
