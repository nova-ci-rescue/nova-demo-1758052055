# Repository Guidelines

## Project Structure & Module Organization
This bundle is self-contained. `quickstart-cli.sh` sits at the root and drives both demos. GitHub automation lives in `scripts/nova_quickstart_github.sh`, while `.github/workflows/nova.yml` is the workflow pushed during the cloud run. Keep demo assets beside their scripts so zipping the directory stays deterministic.

## Build, Test, and Development Commands
Use `bash quickstart-cli.sh --help` to confirm the menu. Smoke-test with `bash quickstart-cli.sh --local` and `--github` (requires `gh auth login`). Include a run of `bash quickstart-cli.sh --fresh --yes --local` periodically to make sure the onboarding path still feels clean. When exercising the GitHub path, provide `--org <owner>` or export `NOVA_DEFAULT_GITHUB_OWNER` to target the right account. For targeted debugging, run `bash scripts/nova_quickstart_github.sh --help` or add `--verbose` to stream every API call.

## Coding Style & Naming Conventions
All Bash files begin with `#!/usr/bin/env bash` and `set -euo pipefail`. Stick to lowercase kebab-case filenames, ALL_CAPS env vars, quoted expansions, and arrays for grouped flags. Run `shellcheck quickstart-cli.sh scripts/*.sh` before shipping.

## Testing Guidelines
No automated harness exists—rely on manual runs. Capture transcripts in `/tmp` for both demos so regressions are easy to diff. When installer behavior changes, test with and without `CLOUDSMITH_ENTITLEMENT` (or `CLOUDSMITH_TOKEN`) to ensure fallbacks work.

## Commit & Pull Request Guidelines
Keep commit subjects imperative and under 72 characters (e.g., `Polish GitHub demo prompts`). Bundle related script and doc edits, and list the validation commands you ran in the commit body or PR description. Add screenshots or GIFs if the terminal flow changes visibly. Point new contributors to `docs/GETTING_STARTED.md` for the walkthrough they can follow end-to-end.

## Security & Secret Handling
Do not commit secrets. Load keys from `~/.nova.env` or exported env vars and let the `scrub` pipeline clean logs. Use `--reset-keys` (optionally with `--yes`) when you need to clear stored credentials, and prefer `--fresh` for sandboxed demos.

## Using the Quickstart Tool
1. Export `OPENAI_API_KEY` (and optionally `CLOUDSMITH_ENTITLEMENT` / `CLOUDSMITH_TOKEN`), or place them in `~/.nova.env`.
2. Run `bash quickstart-cli.sh` and pick `1` for the local calculator rescue or `2` for the GitHub Actions demo (use `--org joinnova-ci` or set `NOVA_DEFAULT_GITHUB_OWNER=joinnova-ci` if you need to create repos in that org).
3. For a truly clean first-run experience use `bash quickstart-cli.sh --fresh --github --yes`; it re-execs under a temp HOME and won’t touch stored keys.
4. Follow the prompts. The script provisions a venv, installs Nova, seeds failing tests, and runs the agent. The GitHub path also creates a demo repo, pushes `.github/workflows/nova.yml`, and links to the run dashboard. Drop a minimal `requirements.txt` (e.g., `echo pytest > requirements.txt`) if you change the scaffold so CI still installs dependencies.
5. Review the log path printed at the end, then reuse the generated repo or artifacts in demos.

## Manual Nova Usage
To run Nova outside the guided flow:
1. `python3 -m venv .venv && source .venv/bin/activate`
2. `pip install nova-ci-rescue pytest`
3. `nova fix --ci "pytest -q"`
This triggers the same constrained agent loop (`≤40 LOC`, `≤5 files`, `≤3 attempts`).
