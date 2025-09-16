# Getting Started with Nova CI-Rescue Quickstart

This guide walks you through the first run of the quickstart, explains what the
script is doing at each step, and highlights where to look for results. Perfect
for first-time users or teammates onboarding to Nova CI-Rescue.

---

## 1. Prep the essentials

| Requirement | Why it matters | Quick check |
| --- | --- | --- |
| Python ≥3.8 & `pip` | Used to create the demo virtualenv | `python3 --version`, `pip --version` |
| `git` | Needed for committing / pushing demo repos | `git --version` |
| GitHub CLI `gh` | The GitHub demo uses device-flow auth & API calls | `gh --version` |
| OpenAI API key | Nova uses OpenAI to plan & patch | `export OPENAI_API_KEY=sk-…` |
| Cloudsmith entitlement token | Grants read access to Nova’s PyPI index | `export CLOUDSMITH_ENTITLEMENT=…` |

Tips:
- Store secrets in `~/.nova.env` (chmod 600) so the quickstart finds them automatically.
- On macOS, `gh auth login -w -s "repo,workflow"` sets up a device flow in your browser.

---

## 2. First run (local demo)

```bash
cd /path/to/quickstart
bash quickstart-cli.sh --local
```

You’ll see a 7-step flow:
1. Create a temp workspace.
2. Install Nova inside a virtualenv.
3. Seed a broken calculator project.
4. Run pytest (red output expected).
5. Ask Nova to fix the failures.
6. Re-run pytest (green output).
7. Show a summary and next steps.

What to watch for:
- A “Running Nova…” block with the agent loop (planning → patching → testing).
- The final pytest run should show `18 passed`. The script prints the summary with current model, guardrails, and elapsed time.
- Check `/tmp/nova-quickstart-<timestamp>.log` if something fails—the log is scrubbed but keeps full context.

Cleanup (optional):
```bash
bash quickstart-cli.sh --purge --yes      # remove /tmp/nova-quickstart-* dirs
```

---

## 3. GitHub Actions demo

```bash
bash quickstart-cli.sh --github --yes
```

The script creates a throwaway repo under your GitHub account (or the org set via `--use-existing` / `NOVA_DEFAULT_GITHUB_OWNER`). The flow is:

1. Verify `gh` auth and token scopes (`repo`, `workflow`).
2. Create a fresh temp workspace.
3. Install Nova and prerequisites.
4. Scaffold a failing project + CI workflow.
5. Push the repo and configure `OPENAI_API_KEY` secret.
6. Trigger the workflow and stream `gh run watch` inline.
7. Show the final status plus the repo / PR / Actions links.

You’ll see output such as:
```
Workflow run ID: 123456
https://github.com/<you>/nova-demo-YYYY/actions/runs/123456
Waiting for workflow to complete (up to 5 minutes)...
...
✅ Success! Nova fixed the failing tests automatically
```

If you want to reuse an existing empty repo instead of creating a new one:
```bash
bash quickstart-cli.sh --github --use-existing your-account/empty-repo
```

Troubleshooting tips:
- Repo creation errors usually mean you lack org permissions—try without `--org`, or ensure your token has org repo scopes.
- If `gh run watch` exits immediately, install GNU `timeout` (macOS: `brew install coreutils` so `timeout` becomes available).
- A “workflow status: failure” often means the OpenAI key failed validation—re-run with a valid key (`bash quickstart-cli.sh --reset-keys` to remove the bad one).

---

## 4. Recommended sandbox run

To simulate a brand-new machine (no cached keys, no gh login) without touching your real HOME:
```bash
bash quickstart-cli.sh --fresh --github --yes
```
This re-execs the script with a temp HOME, prompts for credentials, and leaves your existing secrets untouched.

---

## 5. Key management cheatsheet

| Command | Description |
| --- | --- |
| `bash quickstart-cli.sh --reset-keys --yes` | Remove cached OpenAI keys from Keychain + `~/.nova.env` |
| `bash quickstart-cli.sh --no-keychain --local` | Force the prompt to skip system keychains |
| `bash quickstart-cli.sh --purge --yes` | Delete `/tmp/nova-quickstart-*` and `nova-demo-*` dirs |

The script masks secrets in logs by default (`setup_logging` pipes through a scrubber).

---

## 6. Summary for new users

1. Set `OPENAI_API_KEY` and `CLOUDSMITH_ENTITLEMENT` (or store in `~/.nova.env`).
2. Run the local demo first (`bash quickstart-cli.sh --local`).
3. Try the GitHub path when you’re ready (`bash quickstart-cli.sh --github`).
4. Use `--fresh` to test the onboarding experience again or to demo without polluting your real HOME.
5. Clean up with `--purge` and rotate keys with `--reset-keys` when finished.

Enjoy shipping green CI with Nova!
