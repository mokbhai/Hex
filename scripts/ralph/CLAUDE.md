# Ralph Agent Instructions for Hex Voice

You are an autonomous coding agent working on the **Hex Voice** project - a macOS voice-to-text menu bar application built with Tauri + Rust.

## Project Context

**Tech Stack:**
- **Frontend:** React + TypeScript + Vite
- **Backend/UI Framework:** Tauri 2.0
- **Language:** Rust (backend), TypeScript/React (frontend)
- **Styling:** Tailwind CSS
- **State Management:** Zustand
- **Audio:** cpal (Rust), WAV format
- **Transcription:** whisper.cpp or Sherpa-ONNX (via FFI)
- **AI Refinement:** OpenAI API (async-openai crate)
- **Platform:** macOS only

**Project Structure:**
```
src-tauri/
├── Cargo.toml           # Rust dependencies
├── tauri.conf.json      # Tauri configuration
├── src/
│   ├── main.rs          # Entry point
│   ├── lib.rs           # Library exports
│   ├── audio/           # Audio recording module
│   ├── transcription/   # Speech-to-text module
│   ├── clipboard/       # Text injection module
│   ├── hotkey/          # Global hotkey module
│   ├── refinement/      # LLM text refinement module
│   ├── store/           # Settings persistence
│   └── models/          # Data models
src/
├── components/          # React components
├── hooks/               # Custom React hooks
├── stores/              # Zustand stores
├── types/               # TypeScript types
└── utils/               # Utility functions
```

## Your Task

1. **Read the PRD** at `prd.json` (in project root)
2. **Read the progress log** at `progress.txt` - check `## Codebase Patterns` section FIRST
3. **Verify branch** - check you're on the branch from PRD `branchName`. If not, check it out or create from main.
4. **Pick the highest priority user story** where `passes: false`
5. **Implement that single user story** - focus only on this story
6. **Run quality checks** for this project:
   - Rust: `cargo check` in src-tauri directory
   - TypeScript: `npm run typecheck` or `npx tsc --noEmit`
   - Lint: `npm run lint` if configured
   - Tests: `npm test` or `cargo test` as appropriate
7. **Update CLAUDE.md files** if you discover reusable patterns (see below)
8. **If checks pass, commit ALL changes** with conventional commit message:
   - Format: `type(scope): description`
   - Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `style`
   - Example: `feat(audio): add audio device enumeration command`
   - Include Co-Authored-By: `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`
9. **Update the PRD** to set `passes: true` for the completed story
10. **Append progress to `progress.txt`** (see format below)

## Progress Report Format

**APPEND to progress.txt** (never replace, always append):

```markdown
## [Date/Time] - [Story ID] - [Story Title]

**What was implemented:**
- Brief description of changes

**Files changed:**
- List of key files modified/created

**Learnings for future iterations:**
- Patterns discovered (e.g., "Tauri commands must be registered in lib.rs")
- Gotchas encountered (e.g., "cpal requires the stream to live for full recording duration")
- Useful context (e.g., "settings are stored in ~/.hex-app/config.json")

---
```

The learnings section is **critical** - it helps future iterations avoid repeating mistakes.

## Consolidate Patterns

If you discover a **reusable pattern** that future iterations should know, add it to the `## Codebase Patterns` section at the TOP of progress.txt:

```markdown
## Codebase Patterns
- Example: All Tauri commands must be registered in src-tauri/src/lib.rs with #[tauri::command]
- Example: Use async-openai client for all OpenAI API calls
- Example: React components use lucide-react for icons
- Example: Rust error handling uses anyhow::Result and thiserror for custom errors
```

Only add patterns that are **general and reusable**, not story-specific details.

## Update CLAUDE.md Files

Before committing, check if any edited files have learnings worth preserving in nearby CLAUDE.md files:

1. **Identify directories with edited files**
2. **Check for existing CLAUDE.md** in those directories or parent directories
3. **Add valuable learnings** if discovered

**Examples of good CLAUDE.md additions:**
- "When modifying Tauri commands, update both the command function and the tauri.conf.json permissions"
- "This module uses the Manager pattern for state sharing"
- "Tests require the dev server running or cargo test for Rust code"

**Do NOT add:**
- Story-specific implementation details
- Temporary debugging notes
- Information already in progress.txt

## Project-Specific Requirements

### Rust (src-tauri)
- Use `#[tauri::command]` for all exposed commands
- Handle errors gracefully with user-friendly messages
- Use async/await for I/O operations
- Follow Rust naming conventions (snake_case)

### React/TypeScript (src)
- Use functional components with hooks
- Follow React best practices
- Use TypeScript strict mode
- Components should be small and focused

### macOS-Specific
- Request permissions properly (microphone, accessibility, input monitoring)
- Handle macOS-specific APIs (CGEvent for paste, NSWorkspace for app detection)
- Support both light and dark mode
- Follow macOS HIG for UI

## Quality Requirements

- **ALL commits must pass quality checks**
- **Do NOT commit broken code**
- **Keep changes focused and minimal**
- **Follow existing code patterns**
- **Write tests for new functionality**

## Stop Condition

After completing a user story, check if ALL stories have `passes: true`.

If ALL stories are complete and passing, reply with:
```
<promise>COMPLETE</promise>
```

If there are still stories with `passes: false`, end your response normally.

## Important Reminders

- **Work on ONE story per iteration**
- **Commit frequently**
- **Keep CI green**
- **Read Codebase Patterns section in progress.txt before starting**
- **Ask for clarification if a story is ambiguous**
- **Test your changes before committing**

## Troubleshooting Common Issues

If you encounter:
- **Tauri command not found**: Check it's registered in lib.rs and permissions in tauri.conf.json
- **TypeScript errors**: Run `npx tsc --noEmit` for full error output
- **Rust borrow checker issues**: Consider using Arc<Mutex<T>> for shared state
- **Build failures**: Check Rust version and run `cargo clean` if needed
- **Permission errors**: Ensure entitlements are configured in .entitlements file

Now begin your iteration. Read prd.json, pick the highest priority incomplete story, and implement it.
