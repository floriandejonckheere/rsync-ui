# GenAI

## Project

**RSync UI**: Automate file synchronization jobs using rsync in a beautiful web UI

Backend:

- Ruby 4.0
- Ruby on Rails 8.0
- PostgreSQL 18
- Devise (authentication), ActionPolicy (authorization)
- SolidQueue (background jobs)
- SolidCache (caching)
- SolidCable (real-time communication)

Frontend:

- Hotwire, Turbo, Stimulus
- Tailwind CSS
- Basecoat UI (components)

Tooling:

- Docker, Docker Compose
- Herb (ERB)
- GitHub Actions

## Artificial Intelligence

Agents:

- Claude Code, (Codex)
- Junie (JetBrains AI)

Model choice:

- Haiku for quick questions, variable names, general information queries
- Opus for software design and architecture, code review
- Sonnet for code generation, architecture adjustments

## Agent instructions

Whenever I notice something the agent does incorrectly, add to agent instructions.

[CLAUDE.md](../CLAUDE.md) and [AGENTS.md](../AGENTS.md): base instructions and most key conventions

[COMMANDS.md](COMMANDS.md): common and useful commands (e.g. Docker, database)
[ARCHITECTURE.md](ARCHITECTURE.md): file structure, conventions
[docs/STYLE.md](STYLE.md): Ruby and ERB code style conventions
[docs/PATTERNS.md](PATTERNS.md): Common patterns and best practices
[docs/TESTING.md](TESTING.md): Testing setup, conventions, patterns, and CI/CD pipeline
[docs/SECURITY.md](SECURITY.md): Security best practices and authorization patterns
[docs/PERFORMANCE.md](PERFORMANCE.md): Performance optimization tips and background job patterns
[docs/DATABASE.md](DATABASE.md): Database conventions, migrations, and ActiveStorage patterns

## Workflow

Git branches for each feature
Git worktrees for parallel development (multiple agents)
Pull Requests for code review

Project file ([docs/PROJECT.md](PROJECT.md))

1. Add quick description to project file
2. Mature entry in project file, move to section and multiple tasks
3. Write feature document using template
4. Iterate: feature design by Claude, manual review
5. Iterate: software design by Claude, manual review
6. Implementation by Claude, manual and automated review
7. Merge and deploy

## Superpowers

https://github.com/obra/superpowers

An agentic skills framework & software development methodology

1. Brainstorming: Activates before writing code. Refines rough ideas through questions, explores alternatives, presents design in sections for validation. Saves design document.

2. Using git worktrees: Activates after design approval. Creates isolated workspace on new branch, runs project setup, verifies clean test baseline.

3. Writing plans: Activates with approved design. Breaks work into bite-sized tasks (2-5 minutes each). Every task has exact file paths, complete code, verification steps.

4. Subagent-driven development/executing plans: Activates with plan. Dispatches fresh subagent per task with two-stage review (spec compliance, then code quality), or executes in batches with human checkpoints.

5. Test driven development: Activates during implementation. Enforces RED-GREEN-REFACTOR: write failing test, watch it fail, write minimal code, watch it pass, commit. Deletes code written before tests.

6. Requesting code review: Activates between tasks. Reviews against plan, reports issues by severity. Critical issues block progress.

7. Finishing a development branch: Activates when tasks complete. Verifies tests, presents options (merge/PR/keep/discard), cleans up worktree.

8. Systematic debugging: 4-phase root cause process (includes root-cause-tracing, defense-in-depth, condition-based-waiting techniques)

Use it a lot for brainstorming, including UI design and browser previews

Framework decides what to do: spec design and implementation plan, implementation plan only, debugging

Sometimes triggered for small refactors, need to specify "DO NOT use superpowers"

## Findings

### The Good

No vibe coding, therefore, no:
- Massive technical debt
- Unexplainable code
- Unclear/inconsistent architecture
- Inability to debug manually
- Obvious security holes

- Speed on pattern-heavy work (scaffolding on new features)
- Quick feedback on code quality and design
- Consistent code style and quality due to instructions
- Rubber ducky
- Parallel development via git worktrees + multiple agents
- Development velocity, of course
- Design and develop/review remotely

### The Bad

- Session and weekly limits mean planning around them
  - Offline work: reviewing

- Sometimes doesn't read instructions (GPT is worse with this than Claude)

- Not always consistent:
  - Sometimes no comments, sometimes too many comments
  - Instructions not always deterministically followed

- In general:
  - Tends to write tautological tests (mirroring implementation) -> red/green testing
  - Tends to use lots of mocks and stubs in tests

### Takeaways

- Compound interest on good agent instructions
- Choose the right model for the right task
- Know what and how to prompt
- Manage context accordingly
- Pitfall: easy to ship without understanding code 
- "Run test suite and fix any errors" yields pretty good results and makes life easier
