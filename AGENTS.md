# AGENTS.md

## Repository Purpose

This repository contains tools and scripts for tmux workflows. Keep changes focused on practical terminal usage, automation, and maintainable command-line behavior.

## Working Guidelines

- Prefer small, composable tools over broad scripts with hidden side effects.
- Make commands safe to rerun when possible.
- Keep shell behavior explicit: quote variables, handle missing dependencies, and return useful exit codes.
- Avoid assumptions about a user's tmux session, shell, or project layout unless documented.
- Use plain text output by default. Add colors or interactive UI only when it improves terminal readability and can be disabled.

## Project Structure

- Put executable scripts under `bin/` when the repository gains command-line tools.
- Put reusable shell helpers under `lib/` if scripts start sharing logic.
- Put tests under `test/` or `tests/`, matching the test framework chosen for the project.
- Keep generated artifacts, local session data, and temporary files out of Git.

## Verification

- Run the narrowest relevant tests before finishing a change.
- For shell scripts, run `shellcheck` when available.
- For tmux behavior, verify against a real tmux session when the change affects panes, windows, sessions, key bindings, or environment propagation.
- Document any verification that could not be run.

## Git Practices

- Use `main` as the default branch.
- Keep commits scoped to one logical change.
- Do not rewrite or discard user changes unless explicitly asked.
- Prefer clear commit messages that describe the user-visible behavior or maintenance reason.
