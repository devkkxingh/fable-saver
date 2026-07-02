# 💸 fable-saver

**Cut your Claude Fable costs ~40–50% without losing its brain.**

A [Claude Code](https://claude.com/claude-code) skill that turns a Fable session into a smart cost router: Fable keeps the work only Fable is good at (architecture, planning, design decisions, review), and delegates everything token-heavy (codebase exploration, file reading, implementation, test runs) to **Opus subagents at half the price** — or Haiku at a tenth.

## Why this exists

Anthropic pricing per 1M tokens (as of mid-2026):

| Model | Input | Output | Relative cost |
|---|---|---|---|
| **Claude Fable 5** | $10.00 | $50.00 | 2x Opus, 10x Haiku |
| Claude Opus 4.8 | $5.00 | $25.00 | 1x |
| Claude Sonnet 4.6 | $3.00 | $15.00 | 0.6x |
| Claude Haiku 4.5 | $1.00 | $5.00 | 0.2x |

Here's the thing about a typical coding session: **most of the tokens aren't spent thinking.** They're spent reading files, grepping directories, and typing out edits — work where Opus is just as good as Fable. Only a small slice (planning, architecture, judgment calls) actually benefits from Fable-level intelligence.

Paying Fable rates for `grep` is like hiring a principal engineer to rename variables.

## How it works

Claude Code's `Agent` tool supports a per-agent `model` override. This skill teaches your Fable main session to route work by value:

```
                    ┌──────────────────────────────┐
   You ───────────► │  FABLE (main session)        │
                    │  plan · architect · review   │
                    └──────┬───────────┬───────────┘
                           │ delegate  │ delegate
                           ▼           ▼
                  ┌────────────┐  ┌────────────┐
                  │ OPUS agents│  │HAIKU agents│
                  │ implement  │  │ find files │
                  │ run tests  │  │ quick grep │
                  │ read code  │  └────────────┘
                  └────────────┘
```

| Task | Routed to |
|---|---|
| "Where is X?" / find files / trace symbols | Haiku |
| Understand a subsystem, summarize code | Opus |
| Implement a change from a clear spec | Opus |
| Run tests / build / fix lint | Opus |
| Architecture, planning, design tradeoffs | **Fable** |
| Reviewing subagent work before "done" | **Fable** |
| Escalated bugs (after 2 failed Opus attempts) | **Fable** |

The skill isn't just a routing table — it includes the parts that make delegation actually work:

- **A delegation prompt template.** Subagents start with zero context; a lazy handoff produces garbage you then pay Fable rates to fix. The template forces goal + file paths + constraints + "done means X" into every delegation.
- **A mandatory Fable review step** — the quality backstop. Fable reads the agent's *report* (cheap), not the raw files.
- **Correction over respawn.** A wrong result gets a correction sent to the *same* agent (it keeps its context) instead of a fresh agent re-learning everything.
- **Anti-patterns that silently burn the savings** — the big one: *never read files "just to check" before delegating.* That's paying twice, at 2x rates.

## Install

```bash
git clone https://github.com/YOUR_USERNAME/fable-saver.git
cd fable-saver && ./install.sh
```

Or manually — it's a single file:

```bash
mkdir -p ~/.claude/skills/fable-saver
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/fable-saver/main/skills/fable-saver/SKILL.md \
  -o ~/.claude/skills/fable-saver/SKILL.md
```

Installs at the **user level**, so it works in every project. Start a new Claude Code session after installing.

## Usage

Set your session model to Fable (`/model`), then:

```
/fable-saver refactor the auth module to use JWT refresh tokens
```

Or just mention cost and it triggers on its own:

> "add rate limiting to the API, and save cost where you can"

Fable will plan the work itself, fan the grunt work out to Opus/Haiku agents, review their reports, and hand you the summary.

## Cost model 📊

> These are **worked estimates from official pricing**, not lab benchmarks — real savings depend on your task mix. See "Measure your own savings" below.

Typical mid-size feature task (~320k total tokens):

| Phase | Tokens | Naive (all Fable) | With fable-saver | Routed to |
|---|---|---|---|---|
| Explore / read codebase | ~200k | Fable rates | Opus/Haiku rates | agents |
| Implementation + tests | ~100k | Fable rates | Opus rates | agents |
| Planning + review | ~20k | Fable rates | Fable rates | **Fable** |

Assuming a typical ~80/20 input/output token split:

- **All-Fable:** ≈ $5.76
- **fable-saver:** ≈ $3.06
- **Savings: ~47%** — while the planning and review quality stays 100% Fable.

The bigger the exploration-to-planning ratio (large codebases, mechanical refactors, test-heavy work), the bigger the savings. Small conversational tasks save little — and the skill knows this: it explicitly *doesn't* delegate one-liners, because agent spawn overhead would exceed the savings.

### Measure your own savings

1. Run a representative task normally on Fable, note the numbers from `/cost`.
2. Run a similar task with `/fable-saver`, compare.
3. PRs with real before/after numbers are very welcome — see below.

## Quality: what you give up

Honestly? Very little, and the skill is designed so the answer is "nothing that matters":

- Planning, architecture, and design **never leave Fable**. Cheap planning produces expensive rework — that's the one place the skill refuses to save.
- Every delegated result passes a Fable review before the task is called done.
- Opus 4.8 is itself a frontier model — for "implement this clearly-specified change," the quality difference vs Fable is negligible.
- Bonus: your Fable context stays clean of file dumps, which often makes the *planning* better, not worse.

## Repo layout

```
fable-saver/
├── skills/fable-saver/SKILL.md   ← the skill (single file)
├── install.sh                    ← copies it to ~/.claude/skills/
├── README.md
└── LICENSE
```

## Contributing

Issues and PRs welcome. Especially valuable:

- Real before/after `/cost` numbers from your sessions (task type + token counts + $ totals)
- Routing-table tweaks for task types the skill misroutes
- Reports of cases where an Opus agent needed Fable escalation

## License

MIT
