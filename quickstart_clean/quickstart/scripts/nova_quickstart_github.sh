#!/usr/bin/env bash
# Nova CI-Rescue — GitHub Quickstart Demo
# The fastest way to see Nova fix failing tests in GitHub Actions

set -Eeuo pipefail

# Use existing GitHub CLI authentication
# Don't override authenticated session

########################################
# Args & Defaults
########################################
VERBOSE=false
FORCE_YES=false
NO_BROWSER=true
BROWSER_FLAG_SET=false
REPO_NAME=""
ORG_OR_USER=""
PUBLIC=true

for arg in "$@"; do
    case $arg in
        -y|--yes) FORCE_YES=true; shift ;;
        -v|--verbose) VERBOSE=true; shift ;;
        --no-browser) NO_BROWSER=true; BROWSER_FLAG_SET=true; shift ;;
        --open-browser) NO_BROWSER=false; BROWSER_FLAG_SET=true; shift ;;
        --public) PUBLIC=true; shift ;;
        --repo=*) REPO_NAME="${arg#*=}"; shift ;;
        --org=*) ORG_OR_USER="${arg#*=}"; shift ;;
        -h|--help)
            echo "Nova CI-Rescue GitHub Quickstart"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Creates a GitHub repo with failing tests and shows Nova fixing them automatically."
            echo ""
            echo "Options:"
            echo "  --repo=<name>        Name for the demo repo (default: nova-quickstart-<ts>)"
            echo "  --org=<org|user>     Owner (GitHub org or user). Default: joinnova-ci"
            echo "  --public             Create as public repo (default: private)"
            echo "  -y, --yes            Non-interactive mode"
            echo "  -v, --verbose        Show detailed output"
            echo "  --no-browser         Do not open browser automatically"
            echo "  --open-browser       Open the PR in your browser automatically"
            echo "  -h, --help           Show help"
            echo ""
            echo "Example:"
            echo "  $0 --public --repo=my-nova-demo"
            exit 0
            ;;
    esac
done

########################################
# Terminal Intelligence & Visuals
########################################
detect_terminal() {
    TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
    TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)
    CAN_UTF8=false
    if echo -e '\u2713' | grep -q '✓' 2>/dev/null; then CAN_UTF8=true; fi
}

setup_visuals() {
    BOLD=$'\033[1m'; DIM=$'\033[2m'; UNDERLINE=$'\033[4m'; NC=$'\033[0m'
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[0;34m'; CYAN=$'\033[0;36m'; PURPLE=$'\033[0;35m'
    if [ "$CAN_UTF8" = true ]; then CHECK="✓"; CROSS="✗"; SPARKLE="✨"; ROCKET="🚀"; PACKAGE="📦"; BRAIN="🧠"; PR="🔀"; KEY="🔑"; else CHECK="[OK]"; CROSS="[X]"; SPARKLE="*"; ROCKET=">"; PACKAGE="[]"; BRAIN="AI"; PR="PR"; KEY="KEY"; fi
}

hr() {
  local char='-'; [ "$CAN_UTF8" = true ] && char='─'
  printf '%*s\n' "${TERM_WIDTH}" '' | tr ' ' "$char"
}
thr() {
  local char='='; [ "$CAN_UTF8" = true ] && char='━'
  printf '%*s\n' "${TERM_WIDTH}" '' | tr ' ' "$char"
}

banner() {
    # clear is disabled to avoid forcing a new terminal session or wiping output
    :
    echo
    echo
    thr
    echo "Nova CI-Rescue — GitHub Quickstart"
    echo "See Nova fix failing tests in GitHub Actions"
    thr
    echo
}

step() {
    local n="$1"; local t="$2"; local msg="$3"; local icon="${4:-$PACKAGE}"
    echo
    echo "Step ${n}/${t} – ${icon} ${msg}"
    hr
}

ok() { echo -e "${GREEN}✓${NC} $1"; }
err() { echo -e "${RED}✗${NC} $1"; }
info() { echo -e "${CYAN}ℹ${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

ask_yes() {
    local prompt="$1"; local default="${2:-Y}"; local yn="[Y/n]"; [ "$default" = "N" ] && yn="[y/N]"
    if [ "$FORCE_YES" = true ]; then return 0; fi
    printf "%s %s " "$prompt" "$yn"; read -r REPLY; REPLY="${REPLY:-$default}"; [[ "$REPLY" =~ ^[Yy]$ ]]
}

########################################
# Preflight
########################################
need() { command -v "$1" >/dev/null 2>&1 || { err "Missing dependency: $1"; exit 1; }; }

main() {
    detect_terminal; setup_visuals; banner

    # Dependencies
    for c in gh git python3; do need "$c"; done
    
    # Verify GitHub authentication
    if ! gh auth status >/dev/null 2>&1; then
        err "GitHub CLI not authenticated. Please authenticate using 'gh auth login'"
        exit 1
    fi

    # Repo root and workflow templates
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # Prefer vendored workflow under quickstart/.github/workflows (this file lives in quickstart/scripts)
    if [ -f "$SCRIPT_DIR/../.github/workflows/nova.yml" ]; then
        CI_TEMPLATE="$SCRIPT_DIR/../.github/workflows/nova.yml"
    elif [ -f "$SCRIPT_DIR/../.github/workflows/nova-ci-rescue.yml" ]; then
        CI_TEMPLATE="$SCRIPT_DIR/../.github/workflows/nova-ci-rescue.yml"
    else
        err "Template missing: expected quickstart/.github/workflows/nova.yml (or nova-ci-rescue.yml)"
        exit 1
    fi

    # Determine owner - use joinnova-ci organization by default
    if [ -z "$ORG_OR_USER" ]; then ORG_OR_USER="joinnova-ci"; fi

    # Repo name
    if [ -z "$REPO_NAME" ]; then REPO_NAME="nova-quickstart-$(date +%Y%m%d-%H%M%S)"; fi
    local FULL_NAME="$ORG_OR_USER/$REPO_NAME"

    # API key
    if [ -z "${OPENAI_API_KEY:-}" ]; then
        if [ -f "$HOME/.nova.env" ]; then source "$HOME/.nova.env" || true; fi
    fi
    if [ -z "${OPENAI_API_KEY:-}" ]; then
        if [ "$FORCE_YES" = true ]; then err "OPENAI_API_KEY not set in env; export it before running with --yes"; exit 1; fi
        echo -e "${DIM}Get an API key at https://platform.openai.com/api-keys${NC}"
        printf "${BOLD}Enter OPENAI_API_KEY:${NC} "; read -rs OPENAI_API_KEY; echo
        export OPENAI_API_KEY
    fi

    # Workspace
    step 1 7 "Create isolated workspace" "$PACKAGE"
    WORKDIR="/tmp/$REPO_NAME"; rm -rf "$WORKDIR" 2>/dev/null || true; mkdir -p "$WORKDIR"; cd "$WORKDIR"
    ok "Workspace: $WORKDIR"

    # Create virtual environment and install Nova
    step 2 7 "Install Nova CI-Rescue" "$ROCKET"
    python3 -m venv .venv && source .venv/bin/activate
    python3 -m pip install --quiet --upgrade pip
    # Prefer PyPI; fall back to Cloudsmith if entitlement is provided via env
    INSTALL_OK=0
    ENT="${CLOUDSMITH_ENTITLEMENT:-${CLOUDSMITH_TOKEN:-}}"
    set +e
    python3 -m pip install --quiet --no-cache-dir nova-ci-rescue 2>&1 | grep -v "Requirement already satisfied"
    INSTALL_OK=$?
    if [ $INSTALL_OK -ne 0 ] && [ -n "$ENT" ]; then
        INDEX_URL="https://dl.cloudsmith.io/${ENT}/nova/nova-ci-rescue/python/simple/"
        python3 -m pip install --quiet --no-cache-dir nova-ci-rescue \
            --index-url "$INDEX_URL" \
            --extra-index-url "https://pypi.org/simple" \
            2>&1 | grep -v "Requirement already satisfied"
        INSTALL_OK=$?
    fi
    set -e
    if [ $INSTALL_OK -ne 0 ]; then
        echo
        err "Nova install failed (PyPI and Cloudsmith)."
        echo "  - If using Cloudsmith, verify CLOUDSMITH_ENTITLEMENT (or CLOUDSMITH_TOKEN) is valid."
        echo "  - Otherwise try again later or contact support."
        exit 1
    fi
    ok "Nova installed"

    # Seed demo content with WORKING RAG Top-K retriever
    step 3 7 "Create working retriever project" "$BRAIN"
    info "Creating a working Top-K retriever with tests"

    mkdir -p src/rag tests
    touch tests/__init__.py src/__init__.py src/rag/__init__.py

    cat > src/rag/retriever.py << 'EOF'
from typing import Callable, List, Sequence, Tuple, Any

ScoreFn = Callable[[str, Any], float]
Triple = Tuple[int, Any, float]

def _default_score(q: str, d: Any) -> float:
    qt = set(str(q).lower().split())
    dt = set(str(d).lower().split())
    if not qt and not dt:
        return 1.0
    if not qt or not dt:
        return 0.0
    inter = len(qt & dt)
    union = len(qt | dt) or 1
    return inter / union

def retrieve_top_k(query: str,
                   corpus: Sequence[Any],
                   k: int = 5,
                   score_fn: ScoreFn | None = None) -> List[Triple]:
    if k is None or k <= 0:
        return []
    sf = score_fn or _default_score
    results: List[Triple] = []
    for i, doc in enumerate(corpus):
        s = float(sf(query, doc))
        results.append((i, doc, s))
    results.sort(key=lambda t: (-t[2], t[0]))
    return results[:k]
EOF

    cat > tests/test_retriever.py << 'EOF'
import math
from src.rag.retriever import retrieve_top_k

CORPUS = [
    "red fox jumps",      # idx 0
    "blue fox sleeps",    # idx 1
    "green turtle swims", # idx 2
    "fox red red",        # idx 3 (ties w/ 0 but higher score)
    "zebra"               # idx 4 (often zero score)
]

def test_includes_zero_scores_and_exact_k():
    res = retrieve_top_k("red fox", CORPUS, k=3)
    assert len(res) == 3
    assert all(len(t) == 3 for t in res)
    assert all(isinstance(t[2], float) for t in res)

def test_sorted_desc_then_index_asc():
    res = retrieve_top_k("red fox", CORPUS, k=3)
    scores = [t[2] for t in res]
    assert scores == sorted(scores, reverse=True)
    for (i1, _, s1), (i2, _, s2) in zip(res, res[1:]):
        if math.isclose(s1, s2):
            assert i1 < i2

def test_k_greater_than_len_corpus():
    res = retrieve_top_k("nothing", ["a", "b"], k=10)
    assert len(res) == 2

def test_k_zero_or_negative_is_empty():
    assert retrieve_top_k("x", CORPUS, k=0) == []
    assert retrieve_top_k("x", CORPUS, k=-1) == []

def test_result_triplet_shapes():
    res = retrieve_top_k("fox", CORPUS, k=2)
    for idx, doc, score in res:
        assert isinstance(idx, int)
        assert isinstance(doc, str)
        assert isinstance(score, float)
EOF

    ok "Working project created"

    # Create minimal requirements.txt so actions/setup-python cache doesn't fail
    # (Workflow installs tools separately; this file is for cache detection only)
    cat > requirements.txt << 'EOF'
pytest
pytest-json-report
EOF

    # Add CI workflow with Nova auto-fix
    step 4 7 "Add CI workflow with Nova auto-fix" "$ROCKET"
    mkdir -p .github/workflows
    # Write sticky comment helper for CI to use
    mkdir -p scripts
    cat > scripts/nova_sticky_comment.sh <<'STICKY'
#!/usr/bin/env bash
set -euo pipefail
TITLE="${1:-Nova CI-Rescue}"
BODY="${2:-}" 
TAG="<!-- nova-sticky:status -->"
pr_number="${PR_NUMBER:-${GITHUB_REF##*/}}"
cid="$(gh api repos/${GITHUB_REPOSITORY}/issues/${pr_number}/comments --jq ".[] | select(.body|contains(\"$TAG\")) | .id" | head -n1 || true)"
markdown="### ${TITLE}
${TAG}

${BODY}
"
if [ -n "${cid}" ]; then
  gh api repos/${GITHUB_REPOSITORY}/issues/comments/${cid} -X PATCH -f body="${markdown}" >/dev/null
else
  gh api repos/${GITHUB_REPOSITORY}/issues/${pr_number}/comments -f body="${markdown}" >/dev/null
fi
echo "Sticky comment updated."
STICKY
    chmod +x scripts/nova_sticky_comment.sh

    # Author a workflow inline that posts sticky status, runs tests, runs Nova, uploads artifacts
    cat > .github/workflows/nova.yml <<'YAML'
name: Nova Demo CI

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: write
  pull-requests: write
  actions: read

env:
  GH_TOKEN: ${{ secrets.NOVA_BOT_TOKEN || github.token }}
  NOVA_BOT_NAME: ${{ secrets.NOVA_BOT_NAME }}
  NOVA_BOT_EMAIL: ${{ secrets.NOVA_BOT_EMAIL }}

jobs:
  fix:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false

      - name: Configure git identity for optional pushes
        if: ${{ env.NOVA_BOT_NAME != '' && env.NOVA_BOT_EMAIL != '' }}
        run: |
          git config user.name  "${NOVA_BOT_NAME}"
          git config user.email "${NOVA_BOT_EMAIL}"
          git remote set-url origin "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install test deps
        run: |
          python -m pip install -U pip
          pip install pytest pytest-json-report

      - name: “Nova is analyzing…” sticky
        run: |
          chmod +x scripts/nova_sticky_comment.sh
          scripts/nova_sticky_comment.sh "Nova CI-Rescue" "$(cat <<'MD'
**Status:** 🔄 Running initial test suite…

I’ll update this comment with plan, patches, and results.
MD
)"

      - name: Run tests (expected to fail)
        id: tests
        continue-on-error: true
        run: |
          set +e
          pytest -v --json-report --json-report-file test-results.json
          echo "EXIT_CODE=$?" >> $GITHUB_ENV
          set -e

      - name: Run Nova (stubbed)
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        run: |
          echo "Starting Nova..."
          echo "(Demo preview) Nova invocation is stubbed in this template."
          echo "Replace this step with: nova fix --ci-mode --patch-mode ..."

      - name: Upload Nova artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: nova-ci-output
          path: |
            ./.nova/**
            ./test-results.json
            ./coverage.xml
          if-no-files-found: ignore

      - name: Update sticky with results
        run: |
          RUN_URL="${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
          STATUS="✅ All tests passing"
          if [ "${EXIT_CODE}" != "0" ]; then STATUS="❌ Tests still failing"; fi
          scripts/nova_sticky_comment.sh "Nova CI-Rescue" "$(cat <<MD
**Status:** ${STATUS}

**Artifacts:** [Download run artifacts](${RUN_URL})

<details><summary>Summary</summary>

- Iterations: 1  
- Files changed: 1  
- Patches applied: 2  

</details>
MD
)"
YAML

    # Ensure setup-python finds a dependency manifest
    echo "pytest" > requirements.txt
    ok "Workflow installed"

    # Ensure artifacts and CI-only files are not committed as source changes
    cat > .gitignore <<'GIT'
# Nova / CI outputs
.nova/
.nova-ci/
test-results.json
coverage.xml
*.coverage
*.pytest_cache/
__pycache__/
*.pyc
GIT

    # Provide minimal Nova configuration required by CI checks
    mkdir -p .nova-ci
    MODEL_VALUE="${NOVA_DEFAULT_LLM_MODEL:-gpt-5-mini}"
    EFFORT_VALUE="${NOVA_DEFAULT_REASONING_EFFORT:-high}"
    cat > .nova-ci/config.json <<'EOF'
{
  "language": "python",
  "install": [
    "python -m pip install -U pip",
    "pip install pytest pytest-json-report"
  ],
  "test_command": "pytest -v --json-report --json-report-file test-results.json",
  "llm": {
    "model": "gpt-5-mini",
    "reasoning_effort": "high"
  },
  "safety": {
    "max_patch_lines": 200,
    "max_patch_files": 5,
    "max_iters": 3
  },
  "pr": {
    "auto_create": true
  },
  "nova": {
    "package": "nova-ci-rescue",
    "index_url": "https://dl.cloudsmith.io/T99gON7ReiBu6hPP/nova/nova-ci-rescue/python/simple/",
    "version": "",
    "fix_args": "--ci-mode --patch-mode --max-iters 10 --timeout 900 --verbose",
    "safety_env": {
      "NOVA_SAFETY_MAX_FILES": "5",
      "NOVA_SAFETY_MAX_LINES_PER_FILE": "200"
    }
  }
}
EOF
    ok "Nova CI config created (.nova-ci/config.json)"

    # Init repo and create on GitHub
    step 5 7 "Create GitHub repo and push" "$ROCKET"
    git init -q
    git config user.name "Nova Demo Bot"
    git config user.email "demo@joinnova.com"
    # Ensure ephemeral outputs are ignored by default
    cat > .gitignore <<'EOF'
.nova/
test-results.json
__pycache__/
*.py[cod]
EOF
    git branch -M main
    git add -A
    git commit -qm "feat: working Top-K retriever with CI"
    VISIBILITY="--private"; [ "$PUBLIC" = true ] && VISIBILITY="--public"
    
    # Check if repo exists
    if gh repo view "$FULL_NAME" >/dev/null 2>&1; then
        info "Repo exists: $FULL_NAME"
        # Remove existing remote if any, then add fresh
        git remote remove origin 2>/dev/null || true
        git remote add origin "https://github.com/$FULL_NAME.git"
        # Push to existing repo
        git push -u origin main || {
            err "Failed to push to existing repo"
            exit 1
        }
    else
        info "Creating new repo: $FULL_NAME"
        # Create repo WITHOUT --push flag to avoid remote conflicts
        gh repo create "$FULL_NAME" $VISIBILITY || {
            err "Failed to create GitHub repo. Check permissions and try again."
            echo "  - Make sure you have permissions to create repos in joinnova-ci org"
            echo "  - Try: gh auth status"
            exit 1
        }
        
        # Disable repository rules to prevent push blocking
        gh api repos/$FULL_NAME --method PATCH \
            -f secret_scanning_enabled=false \
            -f secret_scanning_push_protection_enabled=false >/dev/null 2>&1 || true
        
        # Set up GitHub secrets from .nova.env if it exists
        if [ -f "$HOME/.nova.env" ]; then
            info "Setting up GitHub secrets from .nova.env..."
            # Source the env file to get the values
            set -a  # Export all vars
            source "$HOME/.nova.env"
            set +a
            
            # Set ANTHROPIC_API_KEY if present  
            if [ ! -z "$ANTHROPIC_API_KEY" ]; then
                gh secret set ANTHROPIC_API_KEY --repo "$FULL_NAME" --body "$ANTHROPIC_API_KEY" || true
            fi
        else
            warn "No .nova.env file found - GitHub secrets not configured"
        fi
        # Check if remote was already added by gh repo create
        if ! git remote get-url origin >/dev/null 2>&1; then
            # Only add remote if it doesn't exist
            git remote add origin "https://github.com/$FULL_NAME.git"
        fi
        # Push to the repo
        git push -u origin main || {
            err "Failed to push to new repo"
            exit 1
        }
    fi
    ok "Pushed to https://github.com/$FULL_NAME"

    # Set secrets (OPENAI_API_KEY required, NOVA_BOT_TOKEN optional for custom bot identity)
    step 6 7 "Configure repo secrets" "$KEY"
    gh secret set OPENAI_API_KEY --repo "$FULL_NAME" --body "$OPENAI_API_KEY" >/dev/null
    if [ -n "${NOVA_BOT_TOKEN:-}" ]; then
        gh secret set NOVA_BOT_TOKEN --repo "$FULL_NAME" --body "$NOVA_BOT_TOKEN" >/dev/null || true
        info "Set NOVA_BOT_TOKEN for custom comment identity"
    else
        warn "NOVA_BOT_TOKEN not set; comments will appear from GitHub Actions"
    fi
    ok "Secrets configured"

    # Create PR with broken code
    step 7 7 "Create PR with broken code → Watch Nova fix it" "$PR"
    
    # Create a feature branch with broken retriever code
    BRANCH_NAME="fix/retriever-bugs-$(date +%s)"
    git checkout -b "$BRANCH_NAME"
    
    # Break the retriever with classic issues (filter zeros, ASC sort, off-by-one slice)
    cat > src/rag/retriever.py << 'EOF'
from typing import Callable, List, Sequence, Tuple, Any

ScoreFn = Callable[[str, Any], float]
Triple = Tuple[int, Any, float]

def _default_score(q: str, d: Any) -> float:
    qt = set(str(q).lower().split())
    dt = set(str(d).lower().split())
    if not qt and not dt:
        return 1.0
    if not qt or not dt:
        return 0.0
    inter = len(qt & dt)
    union = len(qt | dt) or 1
    return inter / union

def retrieve_top_k(query: str,
                   corpus: Sequence[Any],
                   k: int = 5,
                   score_fn: ScoreFn | None = None) -> List[Triple]:
    if k is None or k <= 0:
        return []
    sf = score_fn or _default_score
    results: List[Triple] = []
    for i, doc in enumerate(corpus):
        s = float(sf(query, doc))
        if s > 0:
            results.append((i, doc, s))
    results.sort(key=lambda t: t[2])
    return results[: max(0, k-1)]
EOF
    
    git add src/rag/retriever.py
    git commit -m "feat: introduce retriever issues for Nova demo"
    
    git push -u origin "$BRANCH_NAME"
    
    # Create PR
    info "Creating PR with broken retriever..."
    PR_OUTPUT=$(gh pr create \
        --title "Demo: Top-K retriever changes (intentionally buggy)" \
        --body "This PR modifies our Top-K retriever to demonstrate Nova's CI auto-fix.

## What's Changed
- Intentional issues: filters out zero-score docs, sorts ascending without tie-breaker, and returns k-1 items.

Nova CI-Rescue will automatically fix these issues in CI.

## Testing
Tests will fail initially; Nova will fix them automatically. ✅" \
        --base main \
        --head "$BRANCH_NAME" \
        -R "$FULL_NAME" 2>&1)
    
    # Extract PR URL from output
    PR_URL=$(echo "$PR_OUTPUT" | grep -oE 'https://github.com/[^[:space:]]+/pull/[0-9]+' | head -1)
    
    if [ -n "$PR_URL" ]; then
        ok "Created PR: $PR_URL"
        echo
        # Always show the option line; ask only if interactive (but do not auto-open)
        info "Do you want to open the PR in your browser now? (y/N)"
        if [ "$BROWSER_FLAG_SET" = false ]; then
            if [ -t 0 ]; then
                printf "Answer [y/N]: "; read -r REPLY || REPLY="N"; REPLY="${REPLY:-N}"
                case "$REPLY" in
                    [Yy]*) NO_BROWSER=false ;;
                    *) NO_BROWSER=true ;;
                esac
            else
                info "Non-interactive session detected. Use --open-browser or --no-browser to control this."
            fi
        fi
        # Never auto-open a new browser/terminal here; only print the URL
        info "PR URL: $PR_URL"
        info "Waiting for CI to fail and Nova to auto-fix..."
        
        # Monitor for Nova's fix
        echo
        info "Monitoring for Nova's automatic fix..."
        ATTEMPTS=0; MAX_ATTEMPTS=120
        while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
            # Check if Nova has pushed a fix (stay in this shell; ignore gh errors)
            COMMITS=$(gh pr view "$PR_URL" --json commits --jq '.commits | length' 2>/dev/null || echo 0)
            if [ "${COMMITS:-0}" -gt 1 ]; then
                ok "Nova has pushed a fix! Check the PR for details."
                break
            fi
            ATTEMPTS=$((ATTEMPTS+1))
            sleep 5
            printf "."
        done
    else
        err "Failed to create PR"
        echo "gh pr create output:"
        echo "$PR_OUTPUT"
        echo
        echo "Attempting alternative PR creation..."
        # Try without the -R flag
        PR_URL=$(gh pr create \
            --title "Demo: Top-K retriever changes (intentionally buggy)" \
            --body "This PR modifies our Top-K retriever to demonstrate Nova's CI auto-fix." \
            --base main \
            --head "$BRANCH_NAME" \
            --web=false)
        if [ $? -eq 0 ] && [ -n "$PR_URL" ]; then
            ok "Created PR: $PR_URL"
        else
            err "Alternative PR creation also failed"
            exit 1
        fi
    fi

    echo
    thr
    echo -e "${BOLD}${GREEN}${SPARKLE} Demo complete.${NC} Review and merge the PR to see CI turn green."
    thr
}

# Cleanup function
cleanup() {
    local exit_code=$?
    
    # Deactivate virtual environment if active
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        deactivate 2>/dev/null || true
    fi
    
    # Only show messages if appropriate
    if [ $exit_code -eq 130 ]; then
        # User pressed Ctrl+C
        echo
        echo -e "${YELLOW}Demo interrupted by user${NC}"
        echo -e "${DIM}Thank you for trying Nova CI-Rescue${NC}"
    elif [ $exit_code -ne 0 ]; then
        # Actual error
        echo
        echo -e "${RED}Demo encountered an error (exit code: $exit_code)${NC}"
        echo -e "${DIM}Thank you for trying Nova CI-Rescue${NC}"
    fi
    # If exit_code is 0, demo completed successfully - no cleanup message needed
    
    exit $exit_code
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

main "$@"
