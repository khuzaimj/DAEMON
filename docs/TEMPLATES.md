# 4. Templates

### Phase Brief (`docs/phases/Pxx-name.md`, post it, then STOP):

```
# Pxx — <name> · Brief
Goal: <one line>
Tasks: Px.1 ...; Px.2 ... (at most 12, each about one session)
Files and data touched: <paths>
Tests to add: <list>
Acceptance: <observable checks and commands>
Evidence I will attach: <screenshots, replays, test summary>
Assumptions and risks: <at most 3>
Questions for the user: <at most 3, each with a recommended default>
```

### Phase Report (append to the same file, then STOP):

```
# Pxx — <name> · Report
Done: <tasks> · Commits: <n> · Tests: <n passing> · check.ps1: green
Evidence: <paths>
Deviations from the plan: <none, or list>
Known issues: <list>
Playtest: <3 to 6 lines: how to run, what to try>
Ask: accept, or changes?
```

### `docs/STATE.md` (rewrite after every task):

```
Phase: Pxx <name> (approved <date>)   Status: in progress | awaiting accept
Last task: Px.m <summary> (commit <hash>)
Next task: Px.n <summary>
Open questions: <none or list>
Run it: & $env:GODOT --path . -- --room <id>
Known issues: <list>
```

### `docs/DECISIONS.md`:
One line each: `date · Dn · decision · reason`.

### Commits:
`Pn.m: summary`. Tag `pNN-accepted` after each accept.

### Definition of Done (every task):
Code, data and tests written; `tools/check.ps1` green; evidence for gameplay or visual claims; `docs/STATE.md` updated (and `docs/CONTENT.md` for content); committed.
