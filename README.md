# fable-saver

**A cost-routing skill for Claude Code that reduces Claude Fable session costs by an estimated 35–56%, with no change to planning or review quality.**

Claude Fable 5 is priced at 2x Claude Opus 4.8 per token. In a typical coding session, however, the majority of tokens are not spent on reasoning — they are spent reading files, searching directories, and writing mechanical edits. fable-saver teaches a Fable session to retain only the work that benefits from Fable-level intelligence (architecture, planning, design decisions, review) and delegate everything else to Opus or Haiku subagents at 50–90% lower per-token cost.

---

## Contents

- [Motivation](#motivation)
- [Architecture](#architecture)
- [Installation](#installation)
- [Usage](#usage)
- [Cost Analysis](#cost-analysis)
- [Design Decisions](#design-decisions)
- [Measuring Your Own Savings](#measuring-your-own-savings)
- [Repository Layout](#repository-layout)
- [Contributing](#contributing)

---

## Motivation

Anthropic API pricing per 1M tokens (mid-2026):

| Model | Input | Output | Blended cost* | Relative to Opus |
|---|---:|---:|---:|---:|
| Claude Fable 5 | $10.00 | $50.00 | $18.00 / 1M | 2.0x |
| Claude Opus 4.8 | $5.00 | $25.00 | $9.00 / 1M | 1.0x |
| Claude Sonnet 4.6 | $3.00 | $15.00 | $5.40 / 1M | 0.6x |
| Claude Haiku 4.5 | $1.00 | $5.00 | $1.80 / 1M | 0.2x |

\* Blended = 80% input / 20% output, a typical ratio for agentic coding sessions.

Token spend in a coding session is heavily skewed toward low-reasoning work. Internal accounting of a representative feature task (see [Cost Analysis](#cost-analysis)) puts roughly 90–95% of tokens in exploration, file reading, implementation, and test execution — categories where Opus 4.8, itself a frontier model, performs equivalently to Fable when given a clear specification. Only the remaining 5–10% (planning, architectural tradeoffs, reviewing results) measurably benefits from Fable.

fable-saver arbitrages this gap.

## Architecture

Claude Code's `Agent` tool accepts a per-agent `model` override. The skill uses this to run a hub-and-spoke topology: the Fable main session acts as coordinator; ephemeral subagents on cheaper models perform the token-heavy work and return structured reports.

```
                 ┌─────────────────────────────────────────────┐
    User ──────► │  FABLE  (main session — coordinator)        │
                 │                                             │
                 │  1. Plan and decompose        (Fable-only)  │
                 │  2. Delegate via Agent tool                 │
                 │  3. Review structured reports (Fable-only)  │
                 │  4. Escalate or summarize     (Fable-only)  │
                 └────────┬──────────────┬──────────────┬──────┘
                          │              │              │
                          ▼              ▼              ▼
                 ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
                 │ OPUS agent   │ │ OPUS agent   │ │ HAIKU agent  │
                 │ implement    │ │ run tests,   │ │ locate files,│
                 │ from spec    │ │ fix failures │ │ trace symbols│
                 └──────────────┘ └──────────────┘ └──────────────┘
                    (parallel, isolated contexts, report back)
```

### Routing policy

| Task class | Model | Rationale |
|---|---|---|
| File location, symbol tracing, simple search | Haiku | Pattern matching; no reasoning required |
| Subsystem comprehension, code summarization | Opus | Strong comprehension at half cost |
| Implementation from a written specification | Opus | Spec quality, not model tier, dominates outcome |
| Test execution, build fixes, lint | Opus | Mechanical, verifiable work |
| Requirements analysis, planning, architecture | Fable | Errors here cascade; highest leverage per token |
| Review of all delegated output | Fable | Quality gate; operates on reports, not raw files |
| Escalated failures (2+ failed Opus attempts) | Fable | Fallback for genuinely hard problems |

### Delegation protocol

Subagents start with no conversational context. The skill enforces a specification template on every delegation — goal and intent, known file paths, constraints, an explicit definition of done, and a required structured report (files changed with line ranges, verification output, open questions). The coordinator reviews reports rather than re-reading source, corrects a failing agent in place via follow-up messages (the agent retains its context), and escalates to direct Fable execution only after two failed correction rounds.

### Failure containment

Three properties keep the cost optimization from degrading quality:

1. **Planning never leaves Fable.** Cheap planning produces expensive rework; this is the one category where the skill refuses to economize.
2. **Every delegated result passes a Fable review** before the task is reported complete.
3. **Small tasks bypass delegation entirely.** Agent spawn overhead (fresh context, file re-reads) exceeds the savings on one-line changes, so the skill executes those directly.

## Installation

Requires [Claude Code](https://claude.com/claude-code). The skill installs at the user level and is available in all projects.

### Option A — Plugin (recommended)

From inside any Claude Code session:

```
/plugin marketplace add devkkxingh/fable-saver
/plugin install fable-saver
```

This is the managed path: the plugin system handles namespacing and updates.

### Option B — Install script

```bash
git clone https://github.com/devkkxingh/fable-saver.git
cd fable-saver
./install.sh
```

### Option C — Manual (single file)

```bash
mkdir -p ~/.claude/skills/fable-saver
curl -fsSL https://raw.githubusercontent.com/devkkxingh/fable-saver/main/skills/fable-saver/SKILL.md \
  -o ~/.claude/skills/fable-saver/SKILL.md
```

After any install method, start a new Claude Code session for the skill to register.

## Usage

Set the session model to Fable (`/model`), then invoke explicitly:

```
/fable-saver refactor the auth module to use JWT refresh tokens
```

The skill also activates implicitly when a request mentions cost reduction, e.g. "add rate limiting to the API and keep the cost down."

On invocation, the session plans the work at Fable level, fans exploration and implementation out to Opus/Haiku agents (in parallel where the work is independent), reviews the returned reports, and delivers a summary.

## Cost Analysis

**Methodology.** The figures below are derived from official Anthropic list pricing using the blended rate of $18.00/1M (Fable), $9.00/1M (Opus), and $1.80/1M (Haiku) at an 80/20 input/output split. Token distributions reflect representative agentic coding sessions; they are workload models, not laboratory benchmarks. Actual savings depend on your task mix — see [Measuring Your Own Savings](#measuring-your-own-savings).

### Scenario 1 — Small bug fix (~80k tokens)

| Phase | Tokens | Routed to |
|---|---:|---|
| Locate and understand the defect | 60k | Opus |
| Diagnose, plan fix, review | 20k | Fable |

All-Fable: **$1.44** — Routed: **$0.90** — **Savings: 37.5%**

### Scenario 2 — Mid-size feature (~320k tokens)

| Phase | Tokens | Routed to |
|---|---:|---|
| Codebase exploration and reading | 200k | Opus |
| Implementation and test runs | 100k | Opus |
| Planning and review | 20k | Fable |

All-Fable: **$5.76** — Routed: **$3.06** — **Savings: 46.9%**

### Scenario 3 — Large refactor (~1M tokens)

| Phase | Tokens | Routed to |
|---|---:|---|
| File discovery and symbol tracing | 200k | Haiku |
| Reading, implementation, verification | 760k | Opus |
| Planning and review | 40k | Fable |

All-Fable: **$18.00** — Routed: **$7.92** — **Savings: 56.0%**

### Summary

| Scenario | All-Fable | Routed | Savings |
|---|---:|---:|---:|
| Small bug fix | $1.44 | $0.90 | 37.5% |
| Mid-size feature | $5.76 | $3.06 | 46.9% |
| Large refactor | $18.00 | $7.92 | 56.0% |

Savings scale with the ratio of exploration-and-implementation tokens to planning tokens. Large codebases, mechanical refactors, and test-heavy work sit at the high end; short conversational exchanges save little, and the skill deliberately does not delegate them.

## Design Decisions

**Why Opus, not Sonnet or Haiku, for implementation?** Opus 4.8 is a frontier-class model; for implementation against a clear specification its output is not meaningfully distinguishable from Fable's, so the quality risk of the 2x-cheaper hop is negligible. Sonnet and Haiku widen the quality gap faster than they widen the savings for non-trivial code changes. Haiku is used only where reasoning is irrelevant (file location, symbol search).

**Why review on Fable instead of trusting the agents?** The review step costs a few thousand Fable tokens and reads structured reports, not raw diffs. It is the mechanism that bounds the blast radius of a bad delegation to one correction round instead of a shipped defect.

**Why correct in place instead of respawning?** A respawned agent pays the full context-acquisition cost again (re-reading files, re-learning the task). A correction message to the existing agent reuses its accumulated context.

**A secondary benefit: context hygiene.** Delegation keeps file dumps and tool output out of the coordinator's context window. The Fable session that does the planning operates on clean summaries, which in practice improves plan quality on large tasks in addition to reducing cost.

## Measuring Your Own Savings

1. Run a representative task on Fable without the skill; record token counts and dollar totals from `/cost`.
2. Run a comparable task with `/fable-saver`; record the same.
3. Compare. Contributions of real before/after numbers (task type, token counts, totals) are welcome — see [Contributing](#contributing).

## Repository Layout

```
fable-saver/
├── .claude-plugin/
│   ├── plugin.json          Plugin manifest
│   └── marketplace.json     Marketplace manifest (enables /plugin install)
├── skills/
│   └── fable-saver/
│       └── SKILL.md         The skill (single file)
├── install.sh               Copies the skill to ~/.claude/skills/
├── README.md
└── LICENSE                  MIT
```

## Contributing

Issues and pull requests are welcome. The highest-value contributions:

- Measured before/after `/cost` data from real sessions (task type, token counts, dollar totals)
- Routing-policy adjustments for task classes the skill misroutes
- Reports of cases requiring escalation from Opus to Fable, with context

## License

MIT — see [LICENSE](LICENSE).
