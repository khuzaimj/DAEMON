---
name: daemon-phase-protocol
description: Runs the DAEMON confirm-then-build workflow. Use when starting, continuing or finishing a phase or task of the DAEMON game, writing a Phase Brief or Phase Report, or updating docs/STATE.md.
---

# DAEMON phase protocol

## Goal
Keep work spec-first and approval-gated while spending few tokens.

## Instructions
1. Read docs/STATE.md and the active docs/phases file. Nothing else unless a task needs it.
2. New phase: write the Phase Brief (docs/TEMPLATES.md) to docs/phases/Pxx-name.md, post it, STOP until the user says "go".
3. Approved phase: one task at a time. After each task run `tools/check.ps1`. If red, fix first. Then commit `Pn.m: summary` and update docs/STATE.md.
4. Phase done: run `tools/check.ps1 -Full`, write the Phase Report with evidence paths, STOP until the user says "accept", then tag `pNN-accepted`.
5. Undecided question: ask one question with a recommended default.

## Constraints
- Never expand or cut scope; split tasks instead.
- Reports under 15 lines, no pasted code.
- Never start the next phase without "go".
