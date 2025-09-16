# Repository Guidelines

## Project Structure & Module Organization
The quickstart bundle is a self-contained CLI. `quickstart-cli.sh` is the entry point and should stay in the repo root. Supporting automation and the GitHub-only demo live under `scripts/` (`scripts/nova_quickstart_github.sh`). Keep any auxiliary assets beside the script that consumes them so packaging the folder into a ZIP remains deterministic.

## Build, Test, and Development Commands
Run `bash quickstart-cli.sh --help` to confirm the menu renders and flags are documented. Smoke-test the two main paths with `bash quickstart-cli.sh --local` and `bash quickstart-cli.sh --github` (requires `gh auth login`). For focused debugging of the CI workflow, invoke `bash scripts/nova_quickstart_github.sh --help` or pass `--verbose` to watch each API step.

## Coding Style & Naming Conventions
All scripts must start with `#!/usr/bin/env bash` and `set -euo pipefail`. Use lowercase kebab-case filenames, ALL_CAPS environment variables, and quoted expansions. Group related command-line flags in Bash arrays rather than long string concatenations. Run `shellcheck quickstart-cli.sh scripts/*.sh` before submitting changes, and only add comments when clarifying UX copy, logging decisions, or secret handling.

## Testing Guidelines
There is no automated harness; rely on manual runs. Validate both demos end-to-end, capturing transcripts in `/tmp` for future debugging. When updating installer logic, test with and without `CLOUDSMITH_ENTITLEMENT` (or `CLOUDSMITH_TOKEN`) to confirm fallback paths. Before release, record a macOS and Linux/WSL run and note any deviations in the README or change summary.

## Commit & Pull Request Guidelines
Write imperative commit subjects under 72 characters, e.g., `Tighten Cloudsmith fallback copy`. Bundle related script and doc changes together, and include manual validation notes in the commit body or PR description. Change logs should state: what UX shifted, which commands you ran, and how reviewers can reproduce (point to seeded env vars rather than pasting secrets). Attach screenshots or GIFs when the interactive flow materially changes.

## Using the Quickstart Tool
1. Export `OPENAI_API_KEY` (and optionally `CLOUDSMITH_ENTITLEMENT`) or place them in `~/.nova.env`.
2. From this directory, run `bash quickstart-cli.sh` and choose `1` for the local demo or `2` for the GitHub Actions flow.
3. Follow the prompts; the script creates an isolated venv, installs Nova, seeds a failing calculator repo, and shows Nova fixing it. The GitHub path additionally creates a demo repo, pushes a CI workflow, and streams progress links.
4. After the run, inspect the log referenced in the final output, and reuse the generated demo repo or PR artifacts when presenting Nova to prospects.
