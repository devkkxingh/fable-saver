---
name: fable-saver
description: Cost-optimized delegation mode for Fable sessions. Fable ($10/$50 per 1M tokens) keeps only high-leverage thinking — architecture, planning, design decisions, final review — and delegates everything token-heavy (codebase exploration, file reading, implementation edits, test runs, mechanical refactors) to Opus subagents ($5/$25, half price) or Haiku for trivial searches ($1/$5). Use when the user wants to reduce Fable costs, invokes /fable-saver, or asks to "save cost" / "run cheap" while keeping Fable's planning quality.
---

# Fable Saver — Delegate Cheap, Think Expensive

You are running as Fable, which costs **2x Opus** ($10/$50 vs $5/$25 per 1M tokens) and **10x Haiku**. Every token you burn reading files, grepping directories, or typing out mechanical edits is money spent on work a cheaper model does equally well. Your job in this mode: **be the architect, not the typist.**

## The core rule

Before any multi-step task, ask: *"Does this step need Fable-level reasoning, or just competent execution?"*

- **Needs Fable (do it yourself):** architecture decisions, system design, planning the approach, resolving ambiguity in requirements, debugging genuinely confusing failures, security-sensitive judgment calls, reviewing/approving subagent work, writing the final summary to the user.
- **Doesn't need Fable (delegate):** finding files, reading/summarizing code, understanding "how does X work in this repo", writing code from a clear spec, mechanical refactors, running tests and reporting results, fixing lint errors, writing boilerplate, updating docs.

## Routing table

| Task type | Route to | How |
|---|---|---|
| "Where is X?" / find files / trace a symbol | **Haiku** | `Agent` tool, `subagent_type: "Explore"`, `model: "haiku"` |
| Understand a subsystem / summarize how code works | **Opus** | `subagent_type: "Explore"`, `model: "opus"` |
| Implement a change from a clear spec | **Opus** | `subagent_type: "general-purpose"`, `model: "opus"` |
| Run tests / build / lint and fix failures | **Opus** | `subagent_type: "general-purpose"`, `model: "opus"` |
| Mechanical refactor across many files | **Opus** (parallel agents, `isolation: "worktree"` if they touch overlapping files) |
| Architecture / plan / design tradeoffs | **Fable (you)** — this is what the user pays you for |
| Review subagent diffs before declaring done | **Fable (you)** — cheap in tokens, high in value |
| Gnarly bug the Opus agent failed on twice | **Fable (you)** — escalate after 2 failed Opus attempts |

## How to delegate well (this is where quality is won or lost)

Subagents start with **zero context** — they can't see your conversation. A lazy delegation prompt produces garbage that you then burn Fable tokens fixing. Write delegation prompts like a tech lead writing a ticket:

1. **State the goal AND the why** — one sentence of intent makes Opus dramatically better.
2. **Give exact file paths** you already know about (from earlier exploration) so the agent doesn't re-search.
3. **Specify the contract:** what to change, what NOT to touch, what "done" looks like (e.g. "tests in `tests/auth/` must pass; run them and include the output").
4. **Demand a structured report back:** "Return: files changed with line ranges, test output, anything you were unsure about." You review the report, not the whole diff, unless something smells off.

**Template:**
```
Context: [1-2 sentences: what the larger task is and why]
Task: [precise change to make]
Files: [known paths; where to start]
Constraints: [don't touch X; match existing style; no new deps]
Done means: [tests pass / builds clean / specific behavior verified]
Report back: files changed + line ranges, verification output, open questions.
```

## Workflow for a typical feature request

1. **Scope (Haiku/Opus):** Fire 1–3 parallel Explore agents (Haiku for simple lookups, Opus for "understand this subsystem") to map the relevant code. You read their *summaries*, never the raw files.
2. **Plan (Fable — you):** Design the approach from the summaries. This is your highest-value output; think properly here.
3. **Implement (Opus):** Delegate implementation with the template above. Independent pieces → parallel agents in one message. Overlapping files → sequential, or `isolation: "worktree"`.
4. **Verify (Opus):** Agent runs tests/build and reports results.
5. **Review (Fable — you):** Read the agents' reports. Spot-check anything suspicious with a targeted Read of just those lines. If wrong, send a *correction* to the same agent via `SendMessage` (it keeps its context — much cheaper than a fresh agent re-learning everything). Escalate to doing it yourself only after 2 failed correction rounds.
6. **Summarize (Fable — you):** Tell the user what happened.

## Hard anti-patterns (these silently burn the savings)

- **Don't read files "just to check" before delegating.** If the subagent needs the file, the subagent reads it. You reading it first = paying twice, at 2x rates.
- **Don't re-do delegated work yourself while an agent runs.** Wait for the result.
- **Don't delegate one-liners.** Spawning an agent has overhead (~fresh context load). If the task is a single Edit to a file you already have in context, just do it.
- **Don't delegate the plan.** Cheap planning produces expensive rework. Planning is *the* thing that must stay on Fable.
- **Don't paste huge code blobs into delegation prompts.** Give paths and let the agent read — your prompt tokens are Fable-priced output.
- **Don't skip the review step.** Opus is very good but the 30-second Fable review of a report is the quality backstop that makes this whole scheme safe.

## Cost intuition (why this works)

A typical feature task might burn 200k tokens of exploration/reading and 100k of implementation, but only ~20k of genuine planning/review. Routed naively, that's ~320k at Fable rates. Routed with this skill: ~20k Fable + ~300k Opus ≈ **~45% total cost reduction with zero quality loss on the parts that matter** — often better quality, because parallel subagents keep your main context clean for thinking.

## When to break the rules

- Tiny tasks (one question, one small edit): just do them — delegation overhead exceeds savings.
- The user explicitly asks Fable to do something directly.
- Deep debugging where context accumulated in *your* conversation is essential — transferring it to a subagent would cost more than it saves.
- Anything security-critical or destructive: your judgment, your hands.
