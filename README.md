# Nova CI-Rescue Quickstart

Jump in to see Nova turning red CI green in minutes. This repo packages the guided CLI experience we use for investor demos and onboarding.

## Repo structure
- `quickstart-cli.sh` – the interactive entrypoint described below.
- `scripts/` – light helper scripts used during demos.
- `.github/workflows/` – sample workflow the GitHub demo pushes to the throwaway repo.
- `AGENTS.md` – contributor guide covering coding style, testing expectations, security notes.
- `archive/` – legacy quickstart bundles kept for reference (don’t modify).

## Prerequisites
- macOS or Linux shell
- `python3`, `pip`, `git`, `gh`
- OpenAI API key (set `OPENAI_API_KEY` or store in `~/.nova.env`)
- Cloudsmith entitlement token (set `CLOUDSMITH_ENTITLEMENT` or similar)

Optional but useful:
- `coreutils` on macOS (`brew install coreutils`) to provide `timeout` for watching GitHub Actions runs.

## Running demos
```bash
bash quickstart-cli.sh            # interactive menu
bash quickstart-cli.sh --local    # direct local demo (calculator rescue)
bash quickstart-cli.sh --github   # direct GitHub Actions demo
```

The script provisions a virtual environment, installs Nova, runs pytest, and shows Nova’s agent loop turning red tests green. In GitHub mode it pushes a throwaway repo, installs the workflow, sets secrets, and streams the Action run inline.

Logs are scrubbed by default and saved as `/tmp/nova-quickstart-<timestamp>.log`. Use `--purge` to clean up `/tmp` afterwards if desired.

## Useful flags
| Flag | Description |
| --- | --- |
| `--fresh` | Re-run in a sandbox HOME (no saved keys, blank gh login); nothing persists. |
| `--reset-keys` | Remove cached keys (Keychain + `~/.nova.env`). Use `--yes` to skip confirmation. |
| `--purge` | Delete prior `/tmp/nova-*` demo workspaces. |
| `--no-keychain` | Skip Keychain; use dotfile storage only. |
| `--yes` | Assume “yes” for prompts (handy with reset/purge). |
| `--use-existing OWNER/REPO` | Run GitHub demo against an existing empty repo you own. |
| `--org <owner>` / `NOVA_DEFAULT_GITHUB_OWNER=<owner>` | Default owner/org for repo creation. |

## Non-interactive Nova usage
```
python3 -m venv .venv && source .venv/bin/activate
pip install nova-ci-rescue pytest
nova fix --ci "pytest -q"
```
This mirrors the demo: Nova plans, patches ≤40 LOC / ≤5 files, and re-runs tests until green or safety limits hit.

## Contributing & validation
1. Adjust code.
2. Run both demos:
   ```bash
   bash quickstart-cli.sh --local
   bash quickstart-cli.sh --github --yes  # requires gh auth login -w -s "repo,workflow"
   ```
3. Capture transcripts in `/tmp` for future debugging.
4. See `AGENTS.md` for style and PR guidelines.

Questions? Reach out at `sebastian@joinnova.com`.
