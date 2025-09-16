# Nova CI-Rescue Quickstart

This repo packages the interactive CLI experience we use to demo Nova fixing failing CI tests in minutes. The same bundle powers investor walkthroughs and hands-on trials.

## What’s Inside
- `quickstart-cli.sh` – interactive entrypoint with menus, logging, and secret handling.
- `scripts/nova_quickstart_github.sh` – GitHub Actions demo helper invoked by the CLI or standalone.
- `.github/workflows/nova.yml` – workflow template the GitHub demo pushes to the throwaway repo.
- `AGENTS.md` – contributor guide covering coding style, testing philosophy, and usage tips.
- `archive/` – legacy bundles that should stay untouched unless you are forensically auditing past releases.

## Running the Demo
1. Export `OPENAI_API_KEY` (and `CLOUDSMITH_ENTITLEMENT` / `CLOUDSMITH_TOKEN`) or place them in `~/.nova.env`.
2. `bash quickstart-cli.sh` and choose:
   - `1` for the local calculator rescue (no network writes).
   - `2` for the GitHub Actions flow. Authenticate with `gh auth login` and, if needed, provide `--org <owner>` or `NOVA_DEFAULT_GITHUB_OWNER` so the repo is created under the right account (e.g., `joinnova-ci`).
3. Follow the prompts. The script provisions a temp venv, installs Nova, runs pytest, then shows Nova’s agent loop turning red tests green. The GitHub path also creates a throwaway repo, pushes the workflow, and streams a run link.

Logs land in `/tmp/nova-quickstart-<timestamp>.log` with secrets scrubbed. Delete the temp dirs whenever you’re done.

### Utility Flags
- `--fresh` re-runs the quickstart in a temporary HOME so no saved credentials or gh logins bleed through.
- `--reset-keys` wipes Nova’s stored OpenAI key from macOS Keychain and `~/.nova.env` (requires confirmation unless combined with `--yes`).
- `--purge` removes previous `/tmp/nova-quickstart-*` and `nova-demo-*` workspaces.
- `--no-keychain` forces the script to use dotfile storage only (skips Keychain).
- `--yes` auto-confirms prompts, useful together with cleanup flags or CI runs.


## Non-Interactive Usage
Want to run Nova outside the guided flow?
```
python3 -m venv .venv && source .venv/bin/activate
pip install nova-ci-rescue pytest
nova fix --ci "pytest -q"
```
This triggers the same safety rails (≤40 LOC, ≤5 files, ≤3 attempts).

## Contributing
See `AGENTS.md` for style requirements, manual test expectations, and commit/PR etiquette. When adjusting the GitHub demo, always test with:
```
bash quickstart-cli.sh --local
bash quickstart-cli.sh --github --org <owner>
```
Capture transcripts in `/tmp` for future debugging and leave the legacy artifacts in `archive/` untouched.
