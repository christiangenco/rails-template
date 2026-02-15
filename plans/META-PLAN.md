# Meta-Plan: Orchestrating the Rails Template Build

## Overview

We have 13 sequential phases to implement a complete Rails 8 template. Each phase builds on the previous one (Phase 4 UI helpers → Phase 5 Auth views use `btn`, etc.), so they **cannot be parallelized** — they must run in order.

The tool for execution is `pi` — a coding agent harness that can be invoked non-interactively via `pi -p "prompt"`. Pi has no built-in sub-agent or plan-mode features, but we can orchestrate it via shell scripts and tmux.

## Architecture: Sequential Agent Loop with Supervisor

### Why not parallel?

Every phase depends on the prior phase's output:
- Phase 2 (Tailwind) needs the Rails app from Phase 1
- Phase 5 (Auth) needs UI helpers from Phase 4
- Phase 10 (Posts) needs Auth, Teams, Active Storage from Phases 5-8
- Phase 13 (Polish) touches files from nearly every prior phase

So we run phases **sequentially**, one `pi` invocation per phase.

### Why a supervisor loop?

A single `pi -p` invocation for a big phase might:
- Hit context limits on complex phases (Phase 4 has 307 lines of spec, Phase 5 has 499)
- Fail partway through (a `bundle install` error, a migration conflict)
- Produce code that doesn't pass tests

We need a **supervisor script** that:
1. Invokes `pi` for each phase
2. Checks the result (tests pass? server boots?)
3. If something's broken, re-invokes `pi` with the error context to fix it
4. Commits on success, moves to the next phase

This is the "Ralph Wiggum loop" — a dumb outer loop that keeps poking the agent until the phase is green.

## The Script

### `bin/build-template`

```bash
#!/usr/bin/env bash
set -euo pipefail

PHASES=(01 02 03 04 05 06 07 08 09 10 11 12 13)
MAX_RETRIES=3
PROJECT_DIR="$(pwd)"

log() { echo "$(date '+%H:%M:%S') [META] $*"; }

# ─── Pre-flight ───────────────────────────────────────────────
preflight() {
  log "Pre-flight checks..."

  # Phase 01 creates the git repo, so skip git check for it
  if [ -d ".git" ]; then
    if [ -n "$(git status --porcelain)" ]; then
      log "ERROR: Git working tree is dirty. Commit or stash first."
      exit 1
    fi
  fi

  # Verify pi is available
  if ! command -v pi &>/dev/null; then
    log "ERROR: pi not found. Install with: npm install -g @mariozechner/pi-coding-agent"
    exit 1
  fi

  # Verify Rails is available (needed for Phase 1)
  if ! command -v rails &>/dev/null; then
    log "ERROR: rails not found. Install Ruby and Rails first."
    exit 1
  fi

  log "Pre-flight OK."
}

# ─── Phase gate: verify the phase completed successfully ──────
verify_phase() {
  local phase="$1"
  local errors=""

  # Universal checks (after Phase 1 creates the app)
  if [ "$phase" != "01" ]; then
    # Check that tests pass
    if ! bin/rails test 2>/dev/null; then
      errors+="Tests failed. "
    fi

    # Check that Tailwind builds (after Phase 2)
    if [ "$phase" -ge "02" ] 2>/dev/null; then
      if ! bin/rails tailwindcss:build 2>/dev/null; then
        errors+="Tailwind build failed. "
      fi
    fi
  fi

  # Phase 1: verify the app boots
  if [ "$phase" == "01" ]; then
    if ! bin/rails runner "puts 'OK'" 2>/dev/null; then
      errors+="Rails app won't boot. "
    fi
  fi

  # Check for syntax errors in Ruby files
  local syntax_errors
  syntax_errors=$(find app lib config -name "*.rb" -exec ruby -c {} \; 2>&1 | grep -v "Syntax OK" || true)
  if [ -n "$syntax_errors" ]; then
    errors+="Ruby syntax errors: $syntax_errors "
  fi

  if [ -n "$errors" ]; then
    echo "$errors"
    return 1
  fi
  return 0
}

# ─── Run a single phase ──────────────────────────────────────
run_phase() {
  local phase="$1"
  local plan_file="plans/${phase}-*.md"
  local plan_path
  plan_path=$(ls $plan_file 2>/dev/null | head -1)

  if [ -z "$plan_path" ]; then
    log "ERROR: No plan file found for phase $phase"
    return 1
  fi

  local phase_name
  phase_name=$(basename "$plan_path" .md)
  log "═══════════════════════════════════════════════════"
  log "PHASE $phase: $phase_name"
  log "═══════════════════════════════════════════════════"

  local attempt=0
  local success=false

  while [ $attempt -lt $MAX_RETRIES ]; do
    attempt=$((attempt + 1))
    log "Attempt $attempt/$MAX_RETRIES for phase $phase"

    if [ $attempt -eq 1 ]; then
      # First attempt: implement the phase from scratch
      pi -p \
        --provider anthropic \
        --model claude-sonnet-4-5 \
        --thinking high \
        --no-session \
        --append-system-prompt "You are implementing a Rails 8 template project. Follow the plan EXACTLY. Do not skip steps. Do not leave TODOs or placeholders. Implement everything completely. When done, verify by running the checks described in the plan's Verification section." \
        @"$plan_path" \
        @plans/00-overview.md \
        "Implement Phase $phase completely. Read the plan file carefully and execute every step. The plan file is attached. Create all files, run all commands, and verify everything works."

    else
      # Retry: fix the errors from the previous attempt
      local error_output
      error_output=$(verify_phase "$phase" 2>&1 || true)

      pi -p \
        --provider anthropic \
        --model claude-sonnet-4-5 \
        --thinking high \
        --no-session \
        --append-system-prompt "You are fixing errors from a previous implementation attempt. Focus on the specific errors reported. Do not rewrite everything — make targeted fixes." \
        @"$plan_path" \
        "Phase $phase implementation has errors. Fix them:

ERRORS:
$error_output

Read the relevant files, diagnose the issues, and fix them. Then verify the fixes work."
    fi

    # Check if the phase succeeded
    if verify_phase "$phase"; then
      success=true
      break
    else
      log "Phase $phase verification failed on attempt $attempt"
    fi
  done

  if [ "$success" = true ]; then
    log "✅ Phase $phase PASSED"

    # Commit the work
    git add -A
    git commit -m "Phase $phase: $phase_name

Implemented by pi agent. All verification checks passing."
    return 0
  else
    log "❌ Phase $phase FAILED after $MAX_RETRIES attempts"
    # Commit what we have anyway, tagged as broken
    git add -A
    git commit -m "Phase $phase: $phase_name [BROKEN - needs manual fix]

Failed verification after $MAX_RETRIES attempts."
    return 1
  fi
}

# ─── Main loop ────────────────────────────────────────────────
main() {
  preflight

  # Track where we left off (for resumability)
  local start_phase="${1:-01}"
  local started=false

  for phase in "${PHASES[@]}"; do
    # Skip phases before the start phase
    if [ "$started" = false ]; then
      if [ "$phase" = "$start_phase" ]; then
        started=true
      else
        continue
      fi
    fi

    if ! run_phase "$phase"; then
      log "Stopping at phase $phase due to failure."
      log "Fix manually, commit, then re-run: ./bin/build-template $phase"
      exit 1
    fi
  done

  log "🎉 All phases complete!"
}

main "$@"
```

## Design Decisions Explained

### 1. One `pi -p` per phase (not per step)

Each plan file is self-contained (2-14KB). pi with Claude Sonnet 4.5 and high thinking can handle a full phase in one shot — it has 200K context. Splitting into sub-steps would lose context about how the pieces fit together (e.g., Phase 5's controller needs to reference Phase 5's model, routes, and views).

### 2. `--no-session` for isolation

Each pi invocation starts fresh. We don't want context bleed between phases (Phase 3's Alpine.js setup confusing Phase 5's auth implementation).

### 3. `--thinking high` for complex code generation

These phases involve substantial code generation with interconnected files. High thinking gives the model room to plan before writing.

### 4. The retry loop ("Ralph Wiggum loop")

The outer loop is intentionally dumb:
- Run pi → check if tests pass → if not, tell pi what broke → repeat
- Max 3 retries per phase (most issues are fixable in 1-2 retries)
- On retry, we pass the error output so pi can make targeted fixes instead of rewriting everything

### 5. Git commit per phase

Each successful phase gets its own commit. This gives us:
- Clean rollback points if later phases break earlier work
- A readable git history showing the template being built
- Easy diffing to see exactly what each phase added

### 6. Resumability

The script accepts a starting phase number:
```bash
./bin/build-template       # Start from Phase 01
./bin/build-template 05    # Resume from Phase 05
```

If a phase fails after max retries, you fix it manually, commit, and re-run from that phase.

### 7. Phase-specific verification

The `verify_phase` function runs:
- `bin/rails test` — catches model/controller errors
- `bin/rails tailwindcss:build` — catches CSS config issues
- `ruby -c` syntax check on all Ruby files — catches obvious parse errors
- `bin/rails runner "puts 'OK'"` — catches boot failures (bad initializers, missing gems)

### 8. Context provided to each pi invocation

Each invocation gets:
- The specific phase plan file (`@plans/05-authentication.md`)
- The overview file (`@plans/00-overview.md`) for high-level context
- An append to the system prompt with behavioral instructions

We do NOT pass all 13 plan files — that would waste context. Each phase plan is self-contained and references what it expects from prior phases.

## What Could Go Wrong (and Mitigations)

| Risk | Mitigation |
|------|-----------|
| Phase 1's `rails new` creates files outside our directory | Plan says `cd ~/projects` first; we run from the project dir |
| `bundle install` fails on native gems | Pre-install build dependencies; the retry loop will catch this |
| Phase 4 (UI Helpers) is huge (307 lines) | Sonnet 4.5 with high thinking handles this; if needed, we could split the plan |
| Phase 5 references Team model from Phase 6 | Plan notes this — stub it or create a skeleton; pi should follow the plan |
| pi produces code that passes tests but is wrong | Tests are our safety net; we should add more tests per-phase in the plans |
| A later phase breaks an earlier phase's code | Git commits let us diff; the retry loop's test suite catches regressions |

## Alternative Approaches Considered

### Parallel agents per phase (rejected)
Phases are sequential. No parallelism possible.

### Parallel agents within a phase (rejected)
Too complex to coordinate. A single pi instance writing all files for a phase avoids merge conflicts and ordering issues.

### Interactive pi sessions (rejected)
`pi -p` (print mode) is deterministic and scriptable. Interactive mode would require human babysitting.

### One giant pi session for all 13 phases (rejected)
Would exceed context limits. The plans total 3,826 lines / ~105KB of spec. With generated code, we'd blow past 200K tokens easily.

### tmux-based pi sessions (considered but unnecessary)
We could run `pi` in a tmux session and monitor it, but `pi -p` already blocks until done and returns output. tmux adds complexity without benefit here since we're running sequentially.

## Running It

```bash
# From the project root (which is currently empty except for plans/)
chmod +x bin/build-template
./bin/build-template
```

To watch progress:
```bash
# The script logs timestamps and phase info to stdout
./bin/build-template 2>&1 | tee build.log
```

To resume after a failure:
```bash
# Fix the issue manually, then:
git add -A && git commit -m "Manual fix for phase XX"
./bin/build-template XX
```

## Expected Timeline

| Phase | Est. Time | Complexity |
|-------|-----------|-----------|
| 01 Scaffold | 2-3 min | Low — mostly shell commands |
| 02 Tailwind | 1-2 min | Low — config files |
| 03 Alpine + Turbo | 2-3 min | Medium — JS files |
| 04 UI Helpers | 5-8 min | High — lots of Ruby helpers, views |
| 05 Authentication | 5-8 min | High — models, controllers, views, mailer |
| 06 Teams | 4-6 min | High — models, controllers, views |
| 07 Profile | 3-4 min | Medium — CRUD + email flow |
| 08 Active Storage | 2-3 min | Low — mostly install commands |
| 09 Background Jobs | 2-3 min | Low — config + one job |
| 10 Posts | 3-5 min | Medium — standard CRUD |
| 11 Landing Page | 3-5 min | Medium — views + Article PORO |
| 12 Kamal | 2-3 min | Low — config files |
| 13 Polish | 3-5 min | Medium — error pages, admin, seeds |
| **Total** | **~40-60 min** | |

Plus retry time if phases fail. Realistic wall clock: **1-2 hours**.
