Nova CI‑Rescue — CLI Quickstart (Investor Demo)

Nova fixes failing tests automatically, under strict safety rails, and shows its work.
This bundle lets you try Nova in two ways:

Local demo (2–3 min): run on a toy repo entirely on your machine (no pushes, no PRs).

GitHub Actions demo (5–7 min): create a PR in a throwaway repo and watch Nova rescue CI.

What’s in this folder
CLI QUICKSTART/
├─ quickstart-cli.sh # Main entrypoint (interactive; also supports flags)
├─ scripts/
│ └─ nova_quickstart_github.sh # Minimal GH demo helper
└─ .github/
└─ workflows/
└─ nova.yml # Ready-to-use GitHub Actions workflow

quickstart-cli.sh handles UI, secret prompting/masking, logging, and running either demo mode. Logs are scrubbed to redact tokens and saved under /tmp/nova-quickstart-<timestamp>.log. If you opt in, the script can remember your keys in Keychain or ~/.nova.env (chmod 600).

quickstart-dev-6-0

Prerequisites

macOS or Linux

bash, git, and python3 (3.8+ recommended)

An OpenAI API key and a Cloudsmith entitlement token (read‑only)

You’ll be prompted securely at runtime; nothing is persisted unless you confirm. Secrets echoed in logs are masked (e.g., sk-xxxx…yyyy).

quickstart-dev-6-0

Quick start (one‑liner download + Local demo)

Replace <DROPBOX_DIRECT_URL> with your share link (use dl=1 to force direct download).

TMP_DIR="$(mktemp -d)"; cd "$TMP_DIR"
curl -L "<DROPBOX_DIRECT_URL>" -o cli_quickstart.zip
unzip -q cli_quickstart.zip
bash "CLI QUICKSTART/quickstart-cli.sh" --local

What happens:

A temp venv is created under /tmp/…, Nova is installed, and a small broken calculator project is seeded.

Tests fail red → Nova runs an agent loop → diffs are applied → tests go green.

Nothing is pushed to any remote; this path never opens a PR.

Safety rails (on by default): ≤40 LOC, ≤5 files, ≤3 attempts, never touches main.

quickstart-dev-6-0

GitHub Actions demo (optional)

Ensure you’re authenticated with gh auth login.

In a throwaway repo, add these secrets:

# From that repo directory:

gh secret set OPENAI_API_KEY # paste your OpenAI key
gh secret set CLOUDSMITH_ENTITLEMENT # paste your Cloudsmith entitlement

Copy .github/workflows/nova.yml from this bundle into your repo and push.
The workflow runs tests, installs Nova only if tests fail, attempts a fix, then re‑runs tests. It requires the two secrets above.

quickstart-dev-6-0

Or generate a workflow from the script:

bash "CLI QUICKSTART/quickstart-cli.sh" --ci

Non‑interactive CLI mode (for demos and CI boxes)

# Uses Cloudsmith for Nova install; requires env set ahead of time

OPENAI_API_KEY=... CLOUDSMITH_ENTITLEMENT=... \
bash "CLI QUICKSTART/quickstart-cli.sh" --cli

This path fails fast on missing env (no prompts) and prints a concise before/after test summary.

quickstart-dev-6-0

Configuration & flags

--local Run the local demo directly

--github Run the GitHub Actions demo directly

--ci   Generate a GH Actions workflow in the current repo

--cli   Non‑interactive local demo (Cloudsmith install path)

--verbose More detailed output

--no-color / --ascii Force TTY‑safe output

The script prints config (model, reasoning effort) and masks sensitive values. Logs are scrubbed (scrub), and credentials can be optionally cached (keychain or ~/.nova.env).

quickstart-dev-6-0

Cleanup

Local demo assets live in /tmp and can be removed anytime:

rm -rf /tmp/nova-demo-_ /tmp/nova-cli-demo-_ 2>/dev/null || true

Keep or delete logs in /tmp/nova-quickstart-\*.log. Venvs are temporary and not global.

quickstart-dev-6-0

Troubleshooting

“Nova failed, possibly due to an invalid OpenAI key.”
The demo will prompt once to retry with a new key. If the agent still fails, an offline patch is auto‑applied so the demo completes (you’ll still see tests go green).

quickstart-dev-6-0

GH CLI complains about default repo.
Run: gh repo set-default <owner>/<repo> or pass -R owner/repo to gh commands.

Security notes

Logs are piped through a secret scrubber; common token patterns (OpenAI, GitHub, AWS, Bearer, Cloudsmith entitlement strings) are redacted.

quickstart-dev-6-0

Credential caching is opt‑in. If you accept, the script stores to macOS Keychain (or ~/.nova.env with mode 600) and will not overwrite existing env vars silently.

quickstart-dev-6-0

Support

Questions or issues? sebastian@joinnova.com

Thanks for trying Nova CI‑Rescue!

(Optional) Direct download command you can share
TMP_DIR="$(mktemp -d)"; cd "$TMP_DIR"; \
curl -L "<DROPBOX_DIRECT_URL>" -o nova_cli_quickstart.zip; \
unzip -q nova_cli_quickstart.zip; \
bash "CLI QUICKSTART/quickstart-cli.sh"

The launcher will present a menu (press 1 for Local demo, 2 for GitHub demo).

quickstart-dev-6-0

Short email you can send

Subject: Nova CI‑Rescue — 2‑minute local demo (zip inside)

Body (paste):

I’ve attached a tiny quickstart for Nova CI‑Rescue. It shows Nova taking 18 failing tests → green with strict safety rails (≤40 LOC, ≤5 files, ≤3 attempts; never touches main).

Try it (Local demo):

TMP_DIR="$(mktemp -d)"; cd "$TMP_DIR"
curl -L "<DROPBOX_DIRECT_URL>" -o cli_quickstart.zip
unzip -q cli_quickstart.zip
bash "CLI QUICKSTART/quickstart-cli.sh" --local

You’ll be prompted for an OpenAI key and a Cloudsmith entitlement token. Nothing is pushed; the run stays local and logs mask secrets.

Optional: copy .github/workflows/nova.yml into a test repo and add two secrets (OPENAI_API_KEY, CLOUDSMITH_ENTITLEMENT) to watch Nova rescue CI on a PR.

Questions welcome—happy to jump on a call.

About sharing your own keys

For a 2‑investor demo it’s fine to ask them to paste their own OpenAI key (best) or give them a time‑boxed, read‑only Cloudsmith entitlement you can revoke. Avoid embedding secrets in the script or one‑liners. If you must provide an OpenAI key, use a separate “demo” project key with a hard spend cap and plan to rotate it after the demos.

If you want me to tailor the README with your exact Dropbox URL and org/repo names in the GH examples, say the word and I’ll drop in the final strings.

# Quickstart scripts

This directory contains the canonical quickstart experiences and the archived historical versions.

## Canonical scripts

- `quickstart-dev-6-0.sh` — Unified entrypoint with `--cli` and `--ci`
- `quickstart-dev-5-2.sh` — Previous interactive quickstart (legacy)
- `quickstart_prod_v1_0.sh` — Minimal production onboarding (non-interactive friendly)

## Supporting scripts

- `scripts/nova_quickstart_local.sh` — Local demo helper
- `scripts/nova_quickstart_github.sh` — GitHub Actions demo helper

## Archived scripts

All previous versions (e.g., `quickstart_v*.sh`, older CI helpers) are preserved under `quickstart/_archive/` for reference.

## Active workflows

- Generated by `quickstart-dev-6-0.sh --ci` → `.github/workflows/ci.yml` using Cloudsmith as the primary index

## Notes

- Add new quickstarts under `quickstart/` and move superseded versions into `quickstart/_archive/`.
- Avoid duplicating workflows; prefer updating the canonical ones above.

---

## One-minute Quickstart (CLI)

Prereqs: Python 3.8+, `python3 -m venv`

1. Export credentials or add them to a `.env` in your repo root:

```
export OPENAI_API_KEY=sk-...
export CLOUDSMITH_ENTITLEMENT=your-cloudsmith-entitlement-token
```

2. Run the unified CLI demo (non-interactive, Cloudsmith-only):

```
./quickstart/quickstart-dev-6-0.sh --cli
```

What it does:

- Creates a small calculator project with failing tests
- Installs `nova-ci-rescue` from Cloudsmith only (PyPI used only for deps)
- Runs tests → runs `nova fix` → reruns tests and prints a concise summary

Troubleshooting:

- "Error: CLOUDSMITH_ENTITLEMENT is required" → export `CLOUDSMITH_ENTITLEMENT` or add to `.env`
- "Could not install nova-ci-rescue" → verify the index URL pattern and your entitlement token

---

## Add CI in one commit (GitHub Actions)

Secrets required in your GitHub repo:

- `OPENAI_API_KEY`
- `CLOUDSMITH_ENTITLEMENT`

Steps:

```
./quickstart/quickstart-dev-6-0.sh --ci
git add .github/workflows/ci.yml
git commit -m "Add Nova CI-Rescue workflow"
git push
```

What the workflow does:

- Installs `nova-ci-rescue` with Cloudsmith as primary index
- Runs tests; on failure runs `nova fix`; reruns tests
- Uploads `.nova/` and test output artifacts

---

## Troubleshooting

- Missing `CLOUDSMITH_ENTITLEMENT`:
  - Add to GitHub Secrets (for CI) and/or export in shell or `.env` (for CLI)
- Bad index URL / 404:
  - Ensure the URL pattern matches: `https://dl.cloudsmith.io/${CLOUDSMITH_ENTITLEMENT}/nova/nova-ci-rescue/python/simple/`
- Missing secrets in CI:
  - Add `OPENAI_API_KEY` and `CLOUDSMITH_ENTITLEMENT` in GitHub → Settings → Secrets → Actions

---

## Comms / Escalation

If blocked or no visible progress, post a status update tagging `@murtaza` in the Linear issue and update `STATUS.md` at the repository root.
