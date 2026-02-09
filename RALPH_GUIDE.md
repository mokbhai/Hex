# Ralph Loop - Hex Voice Autonomous Development

This directory contains the **Ralph Loop** setup for autonomous AI-driven development of Hex Voice.

## What is Ralph Loop?

Ralph is an autonomous AI agent loop that runs Claude Code repeatedly until all PRD items are complete. Each iteration is a fresh instance with clean context. Memory persists via:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and context)
- `prd.json` (task completion status)

## Quick Start

```bash
# Run Ralph with default 50 iterations
./scripts/ralph/ralph.sh

# Run with custom iteration count
./scripts/ralph/ralph.sh 100
```

## Key Files

| File | Purpose |
|------|---------|
| `scripts/ralph/ralph.sh` | The bash loop that spawns fresh AI instances |
| `scripts/ralph/CLAUDE.md` | Prompt template for Claude Code |
| `prd.json` | User stories with `passes` status (the task list) |
| `progress.txt` | Append-only learnings for future iterations |

## How It Works

Each iteration:

1. Reads `prd.json` to find the highest priority incomplete story
2. Reads `progress.txt` to understand codebase patterns
3. Implements that single story
4. Runs quality checks (`cargo check`, `npm run typecheck`, tests)
5. Commits changes if checks pass
6. Updates `prd.json` to mark story as `passes: true`
7. Appends learnings to `progress.txt`
8. Repeats until all stories pass or max iterations reached

## Status

Run this to see current progress:

```bash
# See which stories are done
cat prd.json | jq '.userStories[] | {id, title, passes}'

# See learnings from previous iterations
cat progress.txt

# Check git history
git log --oneline -10
```

## Customize

Edit `scripts/ralph/CLAUDE.md` to add:
- Project-specific quality check commands
- Codebase conventions
- Common gotchas for your stack

## Archive

Previous runs are automatically archived to `.ralph-archive/YYYY-MM-DD-feature-name/` when switching features.

## References

- [Original Ralph repository](https://github.com/snarktank/ralph)
- [What is Ralph Loop](https://medium.com/@tentenco/what-is-ralph-loop-a-new-era-of-autonomous-coding-96a4bb3e2ac8)
- [Geoffrey Huntley's Ralph pattern](https://www.aihero.dev/getting-started-with-ralph)
