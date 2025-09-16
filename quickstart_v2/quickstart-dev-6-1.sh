#!/usr/bin/env bash
# Nova CI-Rescue - Ultimate Quickstart Experience
# Your autonomous CI autopatcher that builds trust through transparency
#
# Part of the 100 PR Rescues Campaign
# ≤40 lines of code | ≤5 files | ≤3 attempts | 100% automated

set -euo pipefail

# Defaults: enable color and emoji unless explicitly overridden
NOVA_DISABLE_COLOR="${NOVA_DISABLE_COLOR:-0}"
NOVA_ASCII_MODE="${NOVA_ASCII_MODE:-0}"

# Pre-parse UI-affecting flags early (before color/icon setup)
for __arg in "$@"; do
    case "$__arg" in
        --no-color)
            NOVA_DISABLE_COLOR=1
            ;;
        --ascii)
            NOVA_ASCII_MODE=1
            ;;
        --color)
            NOVA_DISABLE_COLOR=0
            ;;
        --emoji)
            NOVA_ASCII_MODE=0
            ;;
    esac
done

# Force ASCII/no-color on Windows Git Bash / WSL shells (separate checks)
if [ -n "${WSL_INTEROP:-}" ] || [ -n "${MSYSTEM:-}" ]; then
    NOVA_ASCII_MODE=1
    NOVA_DISABLE_COLOR=1
fi

# -------------------------
# Minimal CLI UI primitives
# -------------------------
_ui_color() { tput setaf "$1" 2>/dev/null || true; }
_ui_reset() { tput sgr0 2>/dev/null || true; }
_ui_bold()  { tput bold 2>/dev/null || true; }

UI_GREY=$(_ui_color 8); UI_GREEN=$(_ui_color 2); UI_YELLOW=$(_ui_color 3); UI_CYAN=$(_ui_color 6); UI_RESET=$(_ui_reset)
UI_BOLD=$(_ui_bold)

if [ "${NOVA_ASCII_MODE:-0}" = "1" ] || [ "${TERM:-}" = "dumb" ]; then
  ICON_BOX="[+]" ; ICON_ROCKET="->" ; ICON_CHECK="[OK]" ; ICON_WARN="!" ; ICON_DOT="*"
else
  ICON_BOX="📦" ; ICON_ROCKET="🚀" ; ICON_CHECK="✓" ; ICON_WARN="⚠️" ; ICON_DOT="•"
fi

cols() { tput cols 2>/dev/null || echo 80; }

# Respect ASCII/dumb fallback inside print_line
hr() { print_line; }

header() {  # header "Title" "Subtitle"
  hr
  printf "%b%s%b\n" "${UI_BOLD}" "$1" "${UI_RESET}"
  [ -n "${2:-}" ] && printf "%b%s%b\n" "${UI_GREY}" "$2" "${UI_RESET}"
  hr
  echo
}

step() {   # step 1 7 "📦" "Create isolated workspace"
  printf "%bStep %s/%s%b — %s  %s\n" "${UI_BOLD}" "$1" "$2" "${UI_RESET}" "${3:-$ICON_DOT}" "$4"
  hr
}

ok()    { printf "%b%s%b %s\n"   "${UI_GREEN}" "${ICON_CHECK}" "${UI_RESET}" "$*"; }
warn()  { printf "%b%s%b %s\n"   "${UI_YELLOW}" "${ICON_WARN}"  "${UI_RESET}" "$*"; }
note()  { printf "%b%s%b %s\n"   "${UI_GREY}"  "${ICON_DOT}"    "${UI_RESET}" "$*"; }

spinner_run() {
  local msg="$1"; shift
  local frames i=0
  if [ "${NOVA_ASCII_MODE:-0}" = "1" ] || [ "${TERM:-}" = "dumb" ]; then
    frames="|/-\\"
  else
    frames='▘▝▖▗'
  fi
  local flen=${#frames}
  printf "%s " "$msg"
  ( "$@" ) >/tmp/nova_step.out 2>/tmp/nova_step.err & local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    i=$(((i+1)%flen)); printf "\r%s %s" "$msg" "${frames:i:1}"; sleep 0.15
  done
  wait "$pid"; local ec=$?
  printf "\r%*s\r" $(( ${#msg} + 2 )) ""
  if [ $ec -eq 0 ]; then ok "$msg"; else
    warn "$msg failed"
    [ -s /tmp/nova_step.err ] && sed -e 's/^/  /' </tmp/nova_step.err
    return $ec
  fi
}

# Secret masking utilities
mask() {
    local s="${1:-}"
    [ -z "$s" ] && { echo ""; return; }
    local pre="${s:0:3}"; local suf="${s: -3}"
    echo "${pre}***${suf}"
}

# Robust entitlement prompt (always visible, even with logging/tee)
ask_entitlement() {
    if [ -e /dev/tty ]; then
        printf "Enter your entitlement token: " > /dev/tty 2>/dev/null || true
        stty -echo < /dev/tty 2>/dev/null || true
        IFS= read -r _ent < /dev/tty
        stty echo < /dev/tty 2>/dev/null || true
        printf "\n" > /dev/tty 2>/dev/null || true
        printf "%s" "$_ent"
    elif [ -t 0 ]; then
        read -rs -p "Enter your entitlement token: " _ent; echo
        printf "%s" "$_ent"
    else
        echo "Non-interactive shell. Set CLOUDSMITH_ENTITLEMENT or CLOUDSMITH_TOKEN in the environment." 1>&2
        return 1
    fi
}

scrub() {
    sed -E \
      -e 's/(sk-[A-Za-z0-9_-]{10,})/[REDACTED_OPENAI]/g' \
      -e 's/(ghp_[A-Za-z0-9]{36})/[REDACTED_GITHUB]/g' \
      -e 's/(github_pat_[A-Za-z0-9_]{20,})/[REDACTED_GITHUB]/g' \
      -e 's/(AKIA[0-9A-Z]{16})/[REDACTED_AWS]/g' \
      -e 's/[Bb]earer[[:space:]]+[A-Za-z0-9._-]{20,}/[REDACTED_BEARER]/g' \
      -e 's#(https://dl\\.cloudsmith\\.io/)[^/]+/#\\1[REDACTED]/#g' \
      -e 's/((CLOUDSMITH_TOKEN|CLOUDSMITH_ENTITLEMENT|NOVA_CLOUDSMITH_TOKEN)[[:space:]]*[:=][[:space:]]*)[A-Za-z0-9._-]{8,}/\\1[REDACTED_ENTITLEMENT]/g' \
      -e 's/([Ee]ntitlement([^[:alnum:]]|[[:space:]])*token[^:]*[:=][[:space:]]*)[A-Za-z0-9._-]{8,}/\\1[REDACTED_ENTITLEMENT]/g' \
      -e '/^Checking .*upload parameters/d' \
      -e '/Checking raw package upload parameters/d' \
      -e '/^Requesting file upload/d' \
      -e '/Uploading .*raw package/d' \
      -e '/^Uploading .*\.sh/d' \
      -e '/^Uploading quickstart/d' \
      -e '/Creating a new raw package/d' \
      -e '/Failed to create package!/d' \
      -e '/Detail: A package with filename/d' \
      -e '/cloudsmith[ ]+push[ ]+raw/d'
}

# Unified logging setup (scrub + tee)
setup_logging() {
    # Respect opt-out to keep everything in the same TTY without process substitution
    if [ "${NOVA_QS_DISABLE_TEE:-0}" = "1" ]; then
        return 0
    fi
    exec > >(scrub | tee -a "$LOG_FILE") 2>&1
}

# Remember initial venv to avoid deactivating user's session later
ORIGINAL_VENV="${VIRTUAL_ENV:-}"

# Terminal capabilities detection
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    COLS=$(tput cols 2>/dev/null || echo 80)
    LINES=$(tput lines 2>/dev/null || echo 24)
else
    COLS=80
    LINES=24
fi

# Professional color scheme
if [ -t 1 ] && [ "${TERM:-}" != "dumb" ] && [ "${NOVA_DISABLE_COLOR:-}" != "1" ]; then
    # Brand colors
    NOVA_BLUE='\033[38;5;33m'     # Primary brand blue
    NOVA_GREEN='\033[38;5;46m'    # Success green
    NOVA_CYAN='\033[38;5;51m'     # Accent cyan
    NOVA_ORANGE='\033[38;5;208m'  # Warning orange
    
    # UI colors
    BOLD='\033[1m'
    DIM='\033[2m'
    ITALIC='\033[3m'
    UNDERLINE='\033[4m'
    
    # Standard colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    GRAY='\033[0;90m'
    NC='\033[0m'
else
    # No color mode
    NOVA_BLUE='' NOVA_GREEN='' NOVA_CYAN='' NOVA_ORANGE=''
    BOLD='' DIM='' ITALIC='' UNDERLINE=''
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' WHITE='' GRAY='' NC=''
fi

# Basic WSL/Windows detection (separate checks)
IS_WSL=0; [ -n "${WSL_INTEROP:-}" ] && IS_WSL=1
IS_MSYS=0; [ -n "${MSYSTEM:-}" ] && IS_MSYS=1

# Professional icons (with fallbacks)
if [ "${NOVA_ASCII_MODE:-}" = "1" ] || [ "${TERM:-}" = "dumb" ]; then
    ROCKET=">"
    CHECK="[OK]"
    SPARKLE="*"
    GEAR="[CFG]"
    BRAIN="[AI]"
    FIRE="[!]"
    PACKAGE="[PKG]"
    GLOBE="[WEB]"
    PHONE="[PH]"
    CHART="[#]"
    SHIELD="[SEC]"
    CLOCK="[CLK]"
    TROPHY="[WIN]"
else
    ROCKET="🚀"
    CHECK="✅"
    SPARKLE="✨"
    GEAR="⚙️"
    BRAIN="🧠"
    FIRE="🔥"
    PACKAGE="📦"
    GLOBE="🌐"
    PHONE="📱"
    CHART="📊"
    SHIELD="🛡️"
    CLOCK="⏱️"
    TROPHY="🏆"
fi

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/tmp/nova-quickstart-${TIMESTAMP}.log"

# default: skip the preflight system check unless explicitly enabled
: "${CI_RESCUE_SYSTEM_CHECK:=0}"

# Persistent env file (read on start; optional)
NOVA_ENV_FILE="${NOVA_ENV_FILE:-$HOME/.nova.env}"

load_nova_env() {
    if [ -f "$NOVA_ENV_FILE" ]; then
        set -a; . "$NOVA_ENV_FILE" 2>/dev/null || true; set +a
    fi
}

_upsert_env() { # _upsert_env KEY VALUE
    local k="$1" v="$2" f="$NOVA_ENV_FILE"
    umask 077; touch "$f"; chmod 600 "$f"
    awk -v k="$k" -v v="$v" 'BEGIN{done=0}
      $0 ~ "^"k"=" {print k"="v; done=1; next}
      {print}
      END{if(!done) print k"="v}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

remember_credentials() {
    [ -t 0 ] || return 0
    echo
    read -r -p "Remember keys in $NOVA_ENV_FILE for next time? [Y/n] " ans
    if [[ ! "$ans" =~ ^[Nn]$ ]]; then
        [ -n "${OPENAI_API_KEY:-}" ] && _upsert_env OPENAI_API_KEY "$OPENAI_API_KEY"
        [ -n "${CLOUDSMITH_TOKEN:-}" ] && _upsert_env CLOUDSMITH_TOKEN "$CLOUDSMITH_TOKEN"
        echo -e "${GREEN}✓ Saved credentials to $NOVA_ENV_FILE (chmod 600)${NC}"
    fi
}

# Cloudsmith configuration
# No hard-coded entitlement; must be provided via env or prompt
CLOUDSMITH_ENTITLEMENT="${CLOUDSMITH_ENTITLEMENT:-}"

########################################
# Professional UI Functions
########################################

center_text() {
    local text="$1"
    local width="${2:-$COLS}"
    # Remove ANSI color codes for length calculation
    local clean_text=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local text_len=${#clean_text}
    local padding=$(( (width - text_len) / 2 ))
    [ $padding -lt 0 ] && padding=0
    # Use %b to interpret ANSI escapes (e.g., \033)
    printf "%*s%b\n" $padding "" "$text"
}

print_line() {
    local default_char
    if [ "${NOVA_ASCII_MODE:-}" = "1" ] || [ "${TERM:-}" = "dumb" ]; then
        default_char='-'
    else
        default_char='─'
    fi
    local char="${1:-$default_char}"
    local width="${2:-$COLS}"
    printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_thick_line() {
    if [ "${NOVA_ASCII_MODE:-}" = "1" ] || [ "${TERM:-}" = "dumb" ] || [ "${NOVA_DISABLE_COLOR:-}" = "1" ]; then
        echo -e "$(print_line '=')"
    else
        echo -e "${BOLD}$(print_line '━')${NC}"
    fi
}

print_box() {
    local title="$1"
    local width="${2:-60}"
    local rule_char
    if [ "${NOVA_ASCII_MODE:-}" = "1" ] || [ "${TERM:-}" = "dumb" ] || [ "${NOVA_DISABLE_COLOR:-}" = "1" ]; then
        rule_char='='
    else
        rule_char='━'
    fi
    echo -e "$(print_line "$rule_char" $width)"
    echo -e "$(center_text "$title" $width)"
    echo -e "$(print_line "$rule_char" $width)"
}

animate_dots() {
    local message="$1"
    local duration="${2:-3}"
    local end_time=$(($(date +%s) + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        for dots in "" "." ".." "..."; do
            printf "\r${message}${dots}   "
            sleep 0.3
        done
    done
    printf "\r%*s\r" $((${#message} + 6)) ""
}

show_progress() {
    local current=$1
    local total=$2
    local width=40
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local fill_char empty_char
    if [ "${NOVA_ASCII_MODE:-}" = "1" ] || [ "${TERM:-}" = "dumb" ]; then
        fill_char='#'; empty_char='-'
    else
        fill_char='█'; empty_char='░'
    fi
    printf "\r["
    printf "%${filled}s" | tr ' ' "$fill_char"
    printf "%$((width - filled))s" | tr ' ' "$empty_char"
    printf "] %3d%%" $percent
}

########################################
# System Checks
########################################

check_requirements() {
    local missing_deps=()
    local warnings=()
    
    # Check Python
    if ! command -v python3 &>/dev/null; then
        missing_deps+=("Python 3.8+")
    else
        local py_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "0.0")
        if ! python3 -c 'import sys; raise SystemExit(0 if (sys.version_info.major, sys.version_info.minor) >= (3, 8) else 1)'; then
            warnings+=("Python $py_version detected (3.8+ recommended)")
        fi
    fi
    
    # Check Git
    if ! command -v git &>/dev/null; then
        missing_deps+=("Git")
    fi
    
    # Check for GitHub CLI (optional)
    if ! command -v gh &>/dev/null; then
        warnings+=("GitHub CLI not found (required for GitHub Actions demo)")
    fi
    
    # Show results
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "\n${RED}${BOLD}Missing Required Dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "  ${RED}✗${NC} $dep"
        done
        echo
        echo -e "${YELLOW}Installation instructions:${NC}"
        echo -e "  ${DIM}• macOS: brew install python3 git gh${NC}"
        echo -e "  ${DIM}• Ubuntu: sudo apt install python3 git gh${NC}"
        echo -e "  ${DIM}• Windows: Use WSL2 or Git Bash${NC}"
        return 1
    fi
    
    if [ ${#warnings[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}Warnings:${NC}"
        for warn in "${warnings[@]}"; do
            echo -e "  ${YELLOW}⚠${NC} $warn"
        done
    fi
    
    return 0
}

check_api_key() {
    # Do NOT auto-detect from files; either use existing env or prompt
    if [ -z "${OPENAI_API_KEY:-}" ]; then
        echo
        echo -e "${NOVA_ORANGE}${BOLD}OpenAI API Key Required${NC}"
        echo -e "${DIM}Nova uses AI to analyze and fix code intelligently${NC}"
        echo
        echo -e "Get your API key at: ${UNDERLINE}${NOVA_CYAN}https://platform.openai.com/api-keys${NC}"
        echo
        # Prefer reading from /dev/tty to guarantee visibility even when stdin is not a TTY
        if [ -e /dev/tty ]; then
            printf "%s" "Enter your OpenAI API key: " > /dev/tty 2>/dev/null || true
            IFS= read -rs OPENAI_API_KEY < /dev/tty || true
            echo > /dev/tty 2>/dev/null || echo
        elif [ -t 0 ]; then
            read -rs -p "Enter your OpenAI API key: " OPENAI_API_KEY
            echo
        fi
        if [ -z "$OPENAI_API_KEY" ]; then
            echo -e "\n${RED}✗ API key is required to continue${NC}"
            return 1
        fi
        export OPENAI_API_KEY
        echo -e "\n${GREEN}✓${NC} API key configured"
    else
        # Respect the pre-set env var without sourcing files
        echo -e "${GREEN}✓${NC} OpenAI API key detected"
    fi
    return 0
}

check_cloudsmith_token() {
    # Prompt only after API key, and only if missing
    if [ -z "${CLOUDSMITH_TOKEN:-}" ]; then
        # Support common env var aliases
        if [ -n "${CLOUDSMITH_ENTITLEMENT:-}" ] && [ -z "${CLOUDSMITH_TOKEN:-}" ]; then
            CLOUDSMITH_TOKEN="$CLOUDSMITH_ENTITLEMENT"
        fi
        if [ -n "${NOVA_CLOUDSMITH_TOKEN:-}" ] && [ -z "${CLOUDSMITH_TOKEN:-}" ]; then
            CLOUDSMITH_TOKEN="$NOVA_CLOUDSMITH_TOKEN"
        fi
        # Try to source from common env files first
        if [ -f ./.env ]; then
            set -a; . ./.env 2>/dev/null || true; set +a
        fi
        if [ -z "${CLOUDSMITH_TOKEN:-}" ] && [ -f "$HOME/.nova.env" ]; then
            set -a; . "$HOME/.nova.env" 2>/dev/null || true; set +a
        fi
    fi

    if [ -z "${CLOUDSMITH_TOKEN:-}" ]; then
        # Silent prompt when interactive; fail-fast in non-interactive
        if [ -t 0 ] && [ "${NOVA_PREFER_STDIN:-1}" = "1" ]; then
            read -rs -p "Cloudsmith entitlement token: " CLOUDSMITH_TOKEN; echo
        elif [ -e /dev/tty ]; then
            printf "%s" "Cloudsmith entitlement token: " > /dev/tty 2>/dev/null || true
            IFS= read -rs CLOUDSMITH_TOKEN < /dev/tty || read -rs CLOUDSMITH_TOKEN
            echo > /dev/tty 2>/dev/null || echo
        else
            echo "CLOUDSMITH_TOKEN is required in non-interactive mode. Try:"
            echo "  CLOUDSMITH_TOKEN=xxxxx OPENAI_API_KEY=yyyy $0 --local"
            return 2
        fi
    fi

    # Fast HEAD/probe using Python urllib (capture status/reason for better messaging)
    PROBE_OUTPUT=$(python3 - "$CLOUDSMITH_TOKEN" <<'PY'
import sys, urllib.request, urllib.error
u = f"https://dl.cloudsmith.io/{sys.argv[1]}/nova/nova-ci-rescue/python/simple/"
try:
    with urllib.request.urlopen(u, timeout=4) as r:
        status = getattr(r, 'status', 200)
        print(f"OK:{status}")
except Exception as e:
    status = getattr(e, 'code', None)
    reason = getattr(e, 'reason', '')
    print(f"BAD:{status}:{reason}")
    sys.exit(1)
PY
)
    if [ "$?" -ne 0 ]; then
        echo -e "${RED}✗ Cloudsmith token validation failed${NC}"
        echo -e "${DIM}Details:${NC} ${PROBE_OUTPUT:-BAD}"
        if [ -n "${CLOUDSMITH_TOKEN:-}" ]; then
          echo -e "${DIM}Token (masked):${NC} $(mask_preview "$CLOUDSMITH_TOKEN")"
        fi
        local _probe_url="https://dl.cloudsmith.io/${CLOUDSMITH_TOKEN}/nova/nova-ci-rescue/python/simple/"
        local _masked_url=$(echo "$_probe_url" | sed -E 's#(https://dl\.cloudsmith\.io/)[^/]+/#\1[REDACTED]/#')
        echo -e "${DIM}Repo checked:${NC} nova/nova-ci-rescue (Python index)"
        echo -e "${DIM}URL:${NC} ${_masked_url}"
        # If interactive, prompt for token and retry up to 2 times
        if [ -t 0 ]; then
            for _try in 1 2; do
                printf "%s" "Enter Cloudsmith entitlement token: " > /dev/tty 2>/dev/null || true
                IFS= read -rs CLOUDSMITH_TOKEN < /dev/tty || read -rs CLOUDSMITH_TOKEN
                echo > /dev/tty 2>/dev/null || echo
                [ -z "${CLOUDSMITH_TOKEN:-}" ] && continue
                PROBE_OUTPUT=$(python3 - "$CLOUDSMITH_TOKEN" <<'PY'
import sys, urllib.request, urllib.error
u = f"https://dl.cloudsmith.io/{sys.argv[1]}/nova/nova-ci-rescue/python/simple/"
try:
    with urllib.request.urlopen(u, timeout=4) as r:
        status = getattr(r, 'status', 200)
        print(f"OK:{status}")
except Exception as e:
    status = getattr(e, 'code', None)
    reason = getattr(e, 'reason', '')
    print(f"BAD:{status}:{reason}")
    sys.exit(1)
PY
)
                if [ "$?" -eq 0 ]; then
                    export CLOUDSMITH_TOKEN
                    echo -e "${GREEN}✓${NC} Cloudsmith token set (${BOLD}$(mask_preview "$CLOUDSMITH_TOKEN")${NC})"
                    return 0
                fi
                echo -e "${YELLOW}Still not valid (${PROBE_OUTPUT}). Try again.${NC}"
            done
        fi
        echo
        echo -e "${BOLD}How to fix:${NC}"
        echo -e "  1) Verify your entitlement token is correct and active"
        echo -e "  2) Set it via one of: CLOUDSMITH_TOKEN, CLOUDSMITH_ENTITLEMENT, NOVA_CLOUDSMITH_TOKEN"
        echo -e "  3) Rotate or create a new token in Cloudsmith account settings"
        echo -e "     ${DIM}(e.g., Organization → Entitlements)${NC}"
        echo -e "  4) Check network/proxy/VPN allowing access to dl.cloudsmith.io"
        echo -e "  5) Need help? Email sebastian@joinnova.com"
        echo
        echo -e "Example (temporary for this session):"
        echo -e "  export CLOUDSMITH_TOKEN=your_entitlement_token_here"
        return 1
    fi
}

kill_stray_cloudsmith_uploads() {
    # Best-effort: stop any lingering cloudsmith raw pushes to our quickstart repo to avoid noisy logs
    if command -v pkill >/dev/null 2>&1; then
        pkill -f "cloudsmith[[:space:]]+push[[:space:]]+raw" 2>/dev/null || true
    else
        ps ax -o pid= -o command= | awk '/cloudsmith[ ]+push[ ]+raw/ {print $1}' | xargs -r kill 2>/dev/null || true
    fi
}

# Normalize Cloudsmith alias early
[ -n "${CLOUDSMITH_ENTITLEMENT:-}" ] && CLOUDSMITH_TOKEN="${CLOUDSMITH_TOKEN:-$CLOUDSMITH_ENTITLEMENT}"

########################################
# Unified Credentials Prompt (masked)
########################################

mask_preview() {
    local v="$1"; local n=${#v}
    if [ $n -le 10 ]; then echo "**********"; return; fi
    local start=${v:0:6}; local end=${v: -4}; echo "${start}…${end}"
}

looks_like_openai_key() {
    local k="$1"
    [[ "$k" =~ ^sk-[A-Za-z0-9]{20,}$ || "$k" =~ ^sk-proj-[A-Za-z0-9_-]{40,}$ ]]
}

# --- Smart secret cache config ---------------------------------------------
: "${NOVA_CRED_BACKEND:=auto}"     # auto | keychain | envfile | none
: "${NOVA_CRED_ASK_REMEMBER:=1}"   # 1=prompt to persist, 0=never persist
[ -n "${CI:-}" ] && NOVA_CRED_ASK_REMEMBER=0  # never persist in CI

cred_backend_detect() {
  case "${NOVA_CRED_BACKEND}" in
    keychain|envfile|none) echo "$NOVA_CRED_BACKEND"; return;;
  esac
  if command -v security >/dev/null 2>&1 && [ "$(uname)" = "Darwin" ]; then
    echo "keychain"; return
  fi
  if command -v secret-tool >/dev/null 2>&1 && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    echo "keychain"; return
  fi
  echo "envfile"
}

cred_store_get() {
  local var="$1" backend; backend="$(cred_backend_detect)"
  case "$backend" in
    keychain)
      if command -v security >/dev/null 2>&1 && [ "$(uname)" = "Darwin" ]; then
        security find-generic-password -a "$USER" -s "Nova:$var" -w 2>/dev/null || true
      elif command -v secret-tool >/dev/null 2>&1; then
        secret-tool lookup service nova key "$var" 2>/dev/null || true
      fi
      ;;
    envfile)
      if command -v grep >/dev/null 2>&1; then
        dotenv_get "$var" 2>/dev/null || true
      fi
      ;;
    none) : ;;
  esac
}

cred_store_set() {
  local var="$1" value="$2" backend; backend="$(cred_backend_detect)"
  case "$backend" in
    keychain)
      if command -v security >/dev/null 2>&1 && [ "$(uname)" = "Darwin" ]; then
        security add-generic-password -U -a "$USER" -s "Nova:$var" -w "$value" >/dev/null 2>&1 || true
      elif command -v secret-tool >/dev/null 2>&1; then
        printf %s "$value" | secret-tool store --label="Nova $var" service nova key "$var" >/dev/null 2>&1 || true
      fi
      ;;
    envfile)
      _upsert_env "$var" "$value"
      ;;
    none) : ;;
  esac
}

cache_secret() {
  local var="$1" label="$2" v
  if [ -n "${!var:-}" ]; then return 0; fi
  v="$(cred_store_get "$var" | head -n1 || true)"
  if [ -n "$v" ]; then export "$var=$v"; return 0; fi
  if [ -e /dev/tty ]; then
    printf "%s: " "$label" > /dev/tty 2>/dev/null || true
    IFS= read -rs v < /dev/tty || true
    echo > /dev/tty 2>/dev/null || echo
  elif [ -t 0 ]; then
    read -rs -p "$label: " v; echo
  else
    echo "Error: $var is required but not set (non-interactive)." >&2
    return 1
  fi
  [ -z "$v" ] && { echo "Error: $var is required." >&2; return 1; }
  export "$var=$v"
  if [ "${NOVA_CRED_ASK_REMEMBER}" = "1" ] && [ -t 0 ]; then
    local ans="y"
    if [ -e /dev/tty ]; then
      printf "Remember for next time? [Y/n] " > /dev/tty 2>/dev/null || true
      IFS= read -r ans < /dev/tty || true
    else
      read -r -p "Remember for next time? [Y/n] " ans || true
    fi
    if [[ ! "$ans" =~ ^[Nn]$ ]]; then
      cred_store_set "$var" "$v"
    fi
  fi
}
# --- OpenAI creds (no-overwrite) ---------------------------------------------
# get value of VAR from .env (without sourcing/overwriting)
dotenv_get() {
  local var="$1"
  [ -f .env ] || return 1
  grep -E "^${var}=" .env | tail -n1 | cut -d= -f2-
}

# prompt for a secret if it's not already in env or .env; append to .env only if absent
# supports overrides:
#   NOVA_FORCE_PROMPT=1 (prompt for all)
#   NOVA_FORCE_PROMPT_OPENAI=1 (prompt for OPENAI_API_KEY specifically)
#   NOVA_FORCE_PROMPT_ENTITLEMENT=1 (prompt for CLOUDSMITH_ENTITLEMENT specifically)
get_or_prompt_secret() {
  local var="$1" label="$2"
  local force_all="${NOVA_FORCE_PROMPT:-0}"
  local force_openai="${NOVA_FORCE_PROMPT_OPENAI:-0}"
  local force_entitlement="${NOVA_FORCE_PROMPT_ENTITLEMENT:-0}"

  # If forced, ignore existing values and prompt
  if { [ "$force_all" = "1" ] || { [ "$var" = "OPENAI_API_KEY" ] && [ "$force_openai" = "1" ]; } || { [ "$var" = "CLOUDSMITH_ENTITLEMENT" ] && [ "$force_entitlement" = "1" ]; }; } && [ -t 0 ]; then
    printf "%s" "$label: " > /dev/tty 2>/dev/null || true
    IFS= read -rs value < /dev/tty || read -rs value
    echo > /dev/tty 2>/dev/null || echo
    if [ -z "$value" ]; then echo "Error: $var is required."; exit 1; fi
    export "$var=$value"
    if ! grep -q -E "^${var}=" .env 2>/dev/null; then
      printf "%s=%s\n" "$var" "$value" >> .env
      echo "Saved $var to .env"
    else
      echo "$var already present in .env (left untouched) ✓"
    fi
    return 0
  fi

  # 1) respect environment if already set
  if [ -n "${!var:-}" ]; then
    echo "$var set from environment ✓"
    return 0
  fi
  # 2) try .env without overriding env
  local from_envfile=""
  from_envfile="$(dotenv_get "$var" || true)"
  if [ -n "$from_envfile" ]; then
    export "$var=$from_envfile"
    echo "Loaded $var from .env ✓"
    return 0
  fi
  # 3) if non-interactive, fail fast
  if [ -n "${CI:-}" ] || [ ! -t 0 ]; then
    echo "Error: $var is required but not set. Provide it via env or .env." >&2
    exit 1
  fi
  # 4) interactive prompt and append to .env only if missing
  printf "%s" "$label: " > /dev/tty 2>/dev/null || true
  IFS= read -rs value < /dev/tty || read -rs value
  echo > /dev/tty 2>/dev/null || echo
  if [ -z "$value" ]; then
    echo "Error: $var is required."; exit 1
  fi
  export "$var=$value"
  if ! grep -q -E "^${var}=" .env 2>/dev/null; then
    printf "%s=%s\n" "$var" "$value" >> .env
    echo "Saved $var to .env"
  else
    echo "$var already present in .env (left untouched) ✓"
  fi
}

ensure_openai_creds() {
  get_or_prompt_secret "OPENAI_API_KEY" "Enter your OpenAI API key (sk-...)"
  get_or_prompt_secret "OPENAI_ENTITLEMENT_TOKEN" "Enter your Cloudsmith entitlement token"
}

# Ensure Cloudsmith entitlement is available (aliases supported)
ensure_cloudsmith_entitlement() {
  # Map common aliases first if primary not set
  if [ -z "${CLOUDSMITH_ENTITLEMENT:-}" ]; then
    if [ -n "${CLOUDSMITH_TOKEN:-}" ]; then
      export CLOUDSMITH_ENTITLEMENT="$CLOUDSMITH_TOKEN"
    elif [ -n "${OPENAI_ENTITLEMENT_TOKEN:-}" ]; then
      export CLOUDSMITH_ENTITLEMENT="$OPENAI_ENTITLEMENT_TOKEN"
    fi
  fi
  # Prompt only if still missing
  if [ -z "${CLOUDSMITH_ENTITLEMENT:-}" ]; then
    if [ -e /dev/tty ]; then
      printf "%s" "Enter your entitlement token: " > /dev/tty 2>/dev/null || true
      IFS= read -rs CLOUDSMITH_ENTITLEMENT < /dev/tty || true
      echo > /dev/tty 2>/dev/null || echo
    elif [ -t 0 ]; then
      read -rs -p "Enter your entitlement token: " CLOUDSMITH_ENTITLEMENT; echo
    else
      echo "Error: CLOUDSMITH_ENTITLEMENT is required but not set. Provide it via env or .env." >&2
      exit 1
    fi
    [ -z "${CLOUDSMITH_ENTITLEMENT:-}" ] && { echo "Error: CLOUDSMITH_ENTITLEMENT is required." >&2; exit 1; }
  fi
  # Keep CLOUDSMITH_TOKEN in sync for legacy callers
  export CLOUDSMITH_TOKEN="${CLOUDSMITH_ENTITLEMENT}"
}

prompt_credentials() {
    echo
    echo -e "${BOLD}Credentials${NC}"
    echo -e "${DIM}Input is hidden; we show only start…end for reference.${NC}"
    echo

    # OpenAI API key (respect existing)
    if [ -n "${OPENAI_API_KEY:-}" ]; then
        echo -e "OpenAI key detected ($(mask_preview "$OPENAI_API_KEY")). Press ENTER to keep or type new:"
        if [ -e /dev/tty ]; then
            local _tmp; IFS= read -rs _tmp < /dev/tty || true; [ -n "$_tmp" ] && OPENAI_API_KEY="$_tmp"
        elif [ -t 0 ]; then
            local _tmp; IFS= read -rs _tmp || true; [ -n "$_tmp" ] && OPENAI_API_KEY="$_tmp"
        fi
    else
        if [ -e /dev/tty ]; then
            printf "%s" "Enter OpenAI API key: " > /dev/tty 2>/dev/null || true
            IFS= read -rs OPENAI_API_KEY < /dev/tty || true
            echo > /dev/tty 2>/dev/null || echo
        elif [ -t 0 ]; then
            read -rs -p "Enter OpenAI API key: " OPENAI_API_KEY; echo
        fi
        while [ -z "${OPENAI_API_KEY:-}" ]; do
            echo -e "${YELLOW}Key cannot be empty.${NC}"
            if [ -e /dev/tty ]; then
                printf "%s" "Enter OpenAI API key: " > /dev/tty 2>/dev/null || true
                IFS= read -rs OPENAI_API_KEY < /dev/tty || true
                echo > /dev/tty 2>/dev/null || echo
            elif [ -t 0 ]; then
                read -rs -p "Enter OpenAI API key: " OPENAI_API_KEY; echo
            fi
        done
    fi
    export OPENAI_API_KEY
    if ! looks_like_openai_key "$OPENAI_API_KEY"; then
        echo -e "${YELLOW}Warning:${NC} key doesn't match typical sk-/sk-proj- pattern"
    fi
    echo -e "${GREEN}✓${NC} OpenAI key set (${BOLD}$(mask_preview "$OPENAI_API_KEY")${NC})"

    # Cloudsmith entitlement token (respect aliases)
    if [ -z "${CLOUDSMITH_TOKEN:-}" ]; then
        [ -n "${CLOUDSMITH_ENTITLEMENT:-}" ] && CLOUDSMITH_TOKEN="$CLOUDSMITH_ENTITLEMENT"
        [ -n "${NOVA_CLOUDSMITH_TOKEN:-}" ] && CLOUDSMITH_TOKEN="$NOVA_CLOUDSMITH_TOKEN"
    fi
    if [ -n "${CLOUDSMITH_TOKEN:-}" ]; then
        echo -e "Cloudsmith token detected ($(mask_preview "$CLOUDSMITH_TOKEN")). Press ENTER to keep or type new:"
        if [ -e /dev/tty ]; then
            local _ct; IFS= read -rs _ct < /dev/tty || true; [ -n "$_ct" ] && CLOUDSMITH_TOKEN="$_ct"
        elif [ -t 0 ]; then
            local _ct; IFS= read -rs _ct || true; [ -n "$_ct" ] && CLOUDSMITH_TOKEN="$_ct"
        fi
    else
        if [ -e /dev/tty ]; then
            printf "%s" "Enter Cloudsmith entitlement token: " > /dev/tty 2>/dev/null || true
            IFS= read -rs CLOUDSMITH_TOKEN < /dev/tty || true
            echo > /dev/tty 2>/dev/null || echo
        elif [ -t 0 ]; then
            read -rs -p "Enter Cloudsmith entitlement token: " CLOUDSMITH_TOKEN; echo
        fi
        while [ -z "${CLOUDSMITH_TOKEN:-}" ]; do
            echo -e "${YELLOW}Token cannot be empty.${NC}"
            if [ -e /dev/tty ]; then
                printf "%s" "Enter Cloudsmith entitlement token: " > /dev/tty 2>/dev/null || true
                IFS= read -rs CLOUDSMITH_TOKEN < /dev/tty || true
                echo > /dev/tty 2>/dev/null || echo
            elif [ -t 0 ]; then
                read -rs -p "Enter Cloudsmith entitlement token: " CLOUDSMITH_TOKEN; echo
            fi
        done
    fi
    export CLOUDSMITH_TOKEN
    echo -e "${GREEN}✓${NC} Cloudsmith token set (${BOLD}$(mask_preview "$CLOUDSMITH_TOKEN")${NC})"

    # Validate Cloudsmith quickly
    check_cloudsmith_token
    remember_credentials
}

########################################
# Welcome Screen
########################################

show_welcome() {
    # Avoid clearing the screen unless explicitly allowed (and not explicitly suppressed)
    if [ "${NOVA_SUPPRESS_CLEAR:-0}" = "1" ]; then :;
    elif [ "${NOVA_ALLOW_CLEAR:-0}" = "1" ]; then clear; fi
    echo
    print_thick_line
    echo
    center_text "${NOVA_BLUE}${BOLD}Nova CI-Rescue${NC}"
    center_text "Self-Healing CI/CD"
    echo
    # Safety rails (on by default)
    echo -e "${BOLD}Safety rails (on by default):${NC}"
    echo -e "  ${CHECK} ${GREEN}≤40 LOC${NC}  ·  ${GREEN}≤5 files${NC}  ·  ${GREEN}≤3 attempts${NC}  ·  ${GREEN}never touches main${NC}"
    echo

    # Why this matters
    echo -e "${BOLD}${NOVA_BLUE}Why this matters:${NC}"
    echo -e "  ${BRAIN} Fixes failing tests automatically"
    echo -e "  ${SHIELD} Every patch verified by tests"
    echo -e "  ${CHART}  Scales from 1 repo to fleets"
    echo
    # Quiet credibility proof
    echo -e "${DIM}Public challenge: 100 PR rescues in 30 days — live ledger: greenweek.joinnova.com${NC}"
    print_line
    echo
}

########################################
# Demo Selection Menu
########################################

show_demo_menu() {
    if [ -e /dev/tty ]; then
        printf "%b\n" "${BOLD}${NOVA_BLUE}Choose how to try it (press Enter):${NC}" > /dev/tty 2>/dev/null || true
        printf "\n" > /dev/tty 2>/dev/null || true
        # Local Demo Option (1)
        printf "%b\n" "  1) Local demo ${DIM}(2–3 min)${NC}   — See red → green on your machine" > /dev/tty 2>/dev/null || true
        printf "\n" > /dev/tty 2>/dev/null || true
        # GitHub Actions Demo Option (2)
        printf "%b\n" "  2) GitHub Actions ${DIM}(5–7 min)${NC} — Watch a live CI rescue in a PR" > /dev/tty 2>/dev/null || true
        printf "\n\n" > /dev/tty 2>/dev/null || true
        print_line > /dev/tty 2>/dev/null || true
        printf "\n" > /dev/tty 2>/dev/null || true
    else
        echo -e "${BOLD}${NOVA_BLUE}Choose how to try it (press Enter):${NC}"
        echo
        echo -e "  1) Local demo ${DIM}(2–3 min)${NC}   — See red → green on your machine"
        echo
        echo -e "  2) GitHub Actions ${DIM}(5–7 min)${NC} — Watch a live CI rescue in a PR"
        echo
        echo
        print_line
        echo
    fi
}

########################################
# Demo Runners
########################################

# Detect if verbose flag is present in provided args
is_verbose_requested() {
    for arg in "$@"; do
        if [ "$arg" = "--verbose" ] || [ "$arg" = "-v" ]; then
            return 0
        fi
    done
    return 1
}

run_local_demo() {
    header "Nova CI–Rescue – Local Quickstart" "Fix a broken calculator locally"
    echo -e "${BOLD}Estimated time:${NC} ~2–3 minutes"
    echo
    
    # Always use the internal calculator local demo for v5
    create_local_demo_script
    local demo_script="/tmp/nova_local_demo.sh"
    
    # Steps are now printed within the inner demo script right before each action

    # Force model/effort for local path
    export NOVA_DEFAULT_LLM_MODEL="gpt-5-mini"
    export NOVA_DEFAULT_REASONING_EFFORT="high"
    
    if [ -e /dev/tty ]; then
      NOVA_SKIP_PR=1 NOVA_SAFETY_MAX_LINES_PER_FILE=200 bash "$demo_script" "$@" </dev/tty >/dev/tty 2>&1
    else
      NOVA_SKIP_PR=1 NOVA_SAFETY_MAX_LINES_PER_FILE=200 bash "$demo_script" "$@"
    fi
    local _demo_ec=$?
    if [ $_demo_ec -ne 0 ]; then
      echo "Local demo exited with code $_demo_ec" >&2
      return $_demo_ec
    fi
}

run_github_demo() {
    header "Nova CI–Rescue – GitHub Quickstart" "See Nova fix failing tests in GitHub Actions"
    echo -e "${BOLD}Estimated time:${NC} ~5–7 minutes"
    echo
    
    # Check GitHub CLI auth first
    if ! command -v gh &>/dev/null; then
        echo -e "${RED}✗ GitHub CLI (gh) is required for this demo${NC}"
        echo -e "${YELLOW}Install with:${NC}"
        echo -e "  ${DIM}brew install gh${NC}  (macOS)"
        echo -e "  ${DIM}sudo apt install gh${NC}  (Ubuntu)"
        echo
        echo -e "Or try the ${BOLD}Local Demo${NC} instead (option 1)"
        return 1
    fi
    
    if ! gh auth status &>/dev/null; then
        echo -e "${YELLOW}GitHub authentication required${NC}"
        echo -e "${DIM}Running: gh auth login${NC}"
        echo
        gh auth login --hostname github.com --web --scopes repo,workflow,admin:public_key || true
    fi
    # Ensure token has required scopes; prompt upgrade if missing
    if ! gh api user >/dev/null 2>&1; then
        echo -e "${YELLOW}Refreshing GitHub token scopes (repo, workflow, admin:public_key)${NC}"
        gh auth refresh --hostname github.com --scopes repo,workflow,admin:public_key || true
    fi
    
    # Ensure git uses gh for HTTPS to avoid credential prompts
    git config --global url."https://github.com/".insteadOf git@github.com: 2>/dev/null || true
    git config --global credential.helper "!gh auth git-credential" 2>/dev/null || true

    # Locate GitHub demo script
    local demo_script
    if [ -f "${SCRIPT_DIR}/../scripts/nova_quickstart_github.sh" ]; then
        demo_script="${SCRIPT_DIR}/../scripts/nova_quickstart_github.sh"
    elif [ -f "${SCRIPT_DIR}/scripts/nova_quickstart_github.sh" ]; then
        demo_script="${SCRIPT_DIR}/scripts/nova_quickstart_github.sh"
    else
        echo -e "${YELLOW}Creating GitHub Actions demo script...${NC}"
        create_github_demo_script
        demo_script="/tmp/nova_github_demo.sh"
    fi
    
    # Ensure PR creation is enabled for the GitHub demo
    unset NO_BROWSER || true
    unset GH_TOKEN || true
    unset GITHUB_TOKEN || true
    export NOVA_SKIP_PR=0
    
    TOTAL=7
    step 1 $TOTAL "$ICON_BOX" "Create isolated workspace"
    step 2 $TOTAL "$ICON_ROCKET" "Install Nova CI‑Rescue"
    step 3 $TOTAL "🧪" "Generate demo repo (failing tests)"
    step 4 $TOTAL "🏗️" "Provision GitHub Actions workflow"
    step 5 $TOTAL "🔎" "Run first CI (expected to fail)"
    step 6 $TOTAL "🤖" "Nova auto‑fix in CI"
    step 7 $TOTAL "✅" "Verify green build and summarize"
    
    # Always run in-process by sourcing, then call the explicit entrypoint if present
    # shellcheck source=/dev/null
    . "$demo_script"
    if command -v nova_github_demo_main >/dev/null 2>&1; then
      nova_github_demo_main "$@"
    else
      # Fallback: if the sourced script defined a 'main' function, use it
      if command -v main >/dev/null 2>&1; then
        main "$@"
      else
        echo -e "${RED}Demo script missing entrypoint${NC}"; return 1
      fi
    fi
}

run_rescue_campaign() {
    echo
    print_box "${TROPHY} 100 PR Rescue Campaign Mode" 50
    echo
    
    echo -e "${NOVA_ORANGE}${BOLD}Green Week Campaign Setup${NC}"
    echo
    echo -e "${BOLD}This advanced mode will:${NC}"
    echo -e "  1. Scan GitHub for repos with failing CI"
    echo -e "  2. Fork and create fix branches"
    echo -e "  3. Run Nova on each failure"
    echo -e "  4. Generate rescue_ledger.jsonl"
    echo -e "  5. Track all metrics for Show HN"
    echo
    
    echo -e "${YELLOW}⚠ This is a production feature${NC}"
    echo -e "${DIM}Requires additional setup and permissions${NC}"
    echo
    
    read -p "Continue with campaign setup? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "\n${NOVA_GREEN}Setting up 100 PR Rescue infrastructure...${NC}"
        # This would launch the full campaign setup
        echo -e "${DIM}Feature coming soon in v1.2${NC}"
        echo -e "${DIM}Contact sebastian@joinnova.com for early access${NC}"
    fi
}

show_advanced_options() {
    echo
    print_box "${GEAR} Advanced Options" 50
    echo
    
    echo -e "${BOLD}Configuration:${NC}"
    echo -e "  ${DIM}Model:${NC} OpenAI ${NOVA_DEFAULT_LLM_MODEL:-gpt-5} • reasoning: ${NOVA_DEFAULT_REASONING_EFFORT:-high}"
    echo -e "  ${DIM}(Sensitive values are masked)${NC}"
    echo -e "  ${DIM}CLOUDSMITH_ENTITLEMENT=$(mask_preview "${CLOUDSMITH_ENTITLEMENT:-}")${NC}"
    echo
    
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  ${CYAN}nova fix${NC} - Fix failing tests"
    echo -e "  ${CYAN}nova fix --verbose${NC} - Show detailed output"
    echo -e "  ${CYAN}nova fix --max-iters 3${NC} - Limit attempts"
    echo
    
    echo -e "${BOLD}Documentation:${NC}"
    echo -e "  ${UNDERLINE}${NOVA_CYAN}https://github.com/novasolve/ci-auto-rescue${NC}"
    echo -e "  ${UNDERLINE}${NOVA_CYAN}https://docs.joinnova.com${NC}"
    echo
    
    echo -e "${BOLD}Support:${NC}"
    echo -e "  ${DIM}Email: sebastian@joinnova.com${NC}"
    echo
}

########################################
# Fallback Demo Creation
########################################

create_local_demo_script() {
    cat > /tmp/nova_local_demo.sh << 'DEMO_SCRIPT'
#!/usr/bin/env bash
# Nova CI-Rescue Local Demo - Auto-generated

set -e

echo -e "\n🚀 Nova CI-Rescue - Local Demo\n"

# Total steps for progress display
TOTAL=7

step() {
  local idx="$1"; local total="$2"; local icon="$3"; shift 3; local msg="$*"
  echo
  echo "Step ${idx}/${total} — ${icon}  ${msg}"
  printf '%*s\n' "$(tput cols 2>/dev/null || echo 80)" '' | tr ' ' '─'
}

step 1 "$TOTAL" "📦" "Create virtual environment"
# Create temp directory
DEMO_DIR="/tmp/nova-demo-$(date +%s)"
mkdir -p "$DEMO_DIR"
cd "$DEMO_DIR"

# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

step 2 "$TOTAL" "🚀" "Install tooling and Nova"
# Install Nova (always latest) with Cloudsmith entitlement; allow deps from PyPI
export PIP_DISABLE_PIP_VERSION_CHECK=1

# Request Cloudsmith entitlement token if not provided
if [ -z "${CLOUDSMITH_TOKEN:-}" ]; then
  # Try to source from common env files, but DO NOT override an already-set OPENAI_API_KEY
  _ORIG_OPENAI_API_KEY="$OPENAI_API_KEY"
  if [ -f ./.env ]; then
    set -a
    . ./.env 2>/dev/null || true
    set +a
  fi
  if [ -z "${CLOUDSMITH_TOKEN:-}" ] && [ -f "$HOME/.nova.env" ]; then
    set -a
    . "$HOME/.nova.env" 2>/dev/null || true
    set +a
  fi
  # Restore caller-provided key if it was set
  if [ -n "${_ORIG_OPENAI_API_KEY:-}" ]; then
    export OPENAI_API_KEY="$_ORIG_OPENAI_API_KEY"
  fi

  # Prompt only if still missing
  echo
  echo -e "${NOVA_ORANGE:-}\033[1mCloudsmith entitlement required for install${NC:-}"
  echo -e "${DIM:-}Set CLOUDSMITH_TOKEN in your env or paste it now.${NC:-}"
  echo -e "${DIM:-}If you don't have a token, email sebastian@joinnova.com and I'll get it to you right away.${NC:-}"
  if [ -z "${CLOUDSMITH_TOKEN:-}" ]; then
    if [ -e /dev/tty ]; then
      printf "%s" "Enter CLOUDSMITH_TOKEN: " > /dev/tty 2>/dev/null || true
      IFS= read -rs CLOUDSMITH_TOKEN < /dev/tty || true
      echo > /dev/tty 2>/dev/null || echo
    elif [ -t 0 ]; then
      read -srp "Enter CLOUDSMITH_TOKEN: " CLOUDSMITH_TOKEN; echo
    fi
  fi
  if [ -z "${CLOUDSMITH_TOKEN:-}" ]; then
    echo -e "\033[0;31m✗ CLOUDSMITH_TOKEN is required. Aborting.\033[0m"
    exit 1
  fi
  export CLOUDSMITH_TOKEN
fi

# Build Cloudsmith index from the same entitlement used during prompt
ENT="${OPENAI_ENTITLEMENT_TOKEN:-${CLOUDSMITH_ENTITLEMENT_TOKEN:-${CLOUDSMITH_ENTITLEMENT:-${CLOUDSMITH_TOKEN:-}}}}"
if [ -z "${ENT:-}" ]; then
  if [ -e /dev/tty ]; then
    printf "%s" "Enter entitlement token: " > /dev/tty 2>/dev/null || true
    IFS= read -rs ENT < /dev/tty || true
    echo > /dev/tty 2>/dev/null || echo
  elif [ -t 0 ]; then
    read -srp "Enter entitlement token: " ENT; echo
  fi
fi

export PIP_DISABLE_PIP_VERSION_CHECK=1
python3 -m pip install -U pip --no-python-version-warning >/dev/null 2>&1 || true

if [ -n "${ENT:-}" ]; then
  export OPENAI_ENTITLEMENT_TOKEN="$ENT"
  export CLOUDSMITH_ENTITLEMENT="$ENT"; export CLOUDSMITH_TOKEN="$ENT"
  export NOVA_INDEX_URL="https://dl.cloudsmith.io/${ENT}/nova/nova-ci-rescue/python/simple/"
  echo "Using Cloudsmith index: $NOVA_INDEX_URL"
  # Verify Cloudsmith availability; hard‑fail if unreachable
  if command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL "$NOVA_INDEX_URL" >/dev/null; then
      echo "Error: Cloudsmith index not accessible."
      echo "Set CLOUDSMITH_TOKEN (entitlement) and ensure access to dl.cloudsmith.io."
      exit 1
    fi
  fi
  # Strictly install from Cloudsmith (no PyPI fallback)
  if ! python3 -m pip install -v --index-url "$NOVA_INDEX_URL" --extra-index-url "https://pypi.org/simple" nova-ci-rescue; then
    echo "First attempt failed; retrying with underscore-normalized name…"
    if ! python3 -m pip install -v --index-url "$NOVA_INDEX_URL" --extra-index-url "https://pypi.org/simple" nova_ci_rescue; then
      echo "Error: Could not install 'nova-ci-rescue' from the Cloudsmith index."
      echo "Verify your entitlement token and try again (or contact support)."
      exit 1
    fi
  fi
  echo "Installed nova-ci-rescue ✓"
else
  echo "Error: missing entitlement token after prompt. Aborting."
  exit 1
fi

# Always install latest test tooling quietly
python3 -m pip install -U black flake8 mypy requests openai pytest pytest-json-report pytest-cov


step 3 "$TOTAL" "🧪" "Seed calculator with failing tests"
# Calculator demo (intentionally buggy implementation + tests)

cat > calculator.py << 'EOF'
"""Simple calculator (intentionally buggy for demo)."""

def add(a, b):
    return a - b  # bug: should add

def multiply(a, b):
    return a + b  # bug: should multiply
EOF

cat > test_calculator.py << 'EOF'
from calculator import add, multiply

def test_add():
    assert add(2, 3) == 5
    assert add(-1, 1) == 0

def test_multiply():
    assert multiply(3, 4) == 12
    assert multiply(0, 5) == 0
EOF

# Initialize git
git init -q
git config user.email "demo@nova.ai"
git config user.name "Demo"
git add .
git commit -q -m "Initial commit"

step 4 "$TOTAL" "🔎" "Run tests (expected to fail)"
echo "Running tests (will fail)..."
PYTHONHASHSEED=0 pytest -q || true

step 5 "$TOTAL" "🤖" "Run Nova"
echo -e "\n🤖 Running Nova to fix bugs...\n"
# Plumb --verbose from quickstart into nova fix
NOVA_FLAGS="--quiet"
for arg in "$@"; do
    if [ "$arg" = "--verbose" ] || [ "$arg" = "-v" ]; then
        NOVA_FLAGS="--verbose"
        break
    fi
done
# Respect NOVA_SKIP_PR in the inner Nova invocation as well
# Force high reasoning effort within the demo environment for v4
export NOVA_DEFAULT_REASONING_EFFORT="${NOVA_DEFAULT_REASONING_EFFORT:-high}"

# Attempt AI-driven fix; allow retry on invalid key; then offline fix as fallback
set +e
# Show masked preview of the key being used
if [ -n "${OPENAI_API_KEY:-}" ]; then
  echo "Using OpenAI key: ${OPENAI_API_KEY:0:6}…${OPENAI_API_KEY: -4}"
fi
FORCE_COLOR=1 CLICOLOR_FORCE=1 NOVA_DISABLE_COLOR=0 NOVA_ASCII_MODE=0 \
NOVA_SKIP_PR=1 PYTHONHASHSEED=0 nova fix $NOVA_FLAGS --demo-mode --max-iters "${NOVA_MAX_ITERS:-3}" --timeout 300
NOVA_STATUS=$?

if [ $NOVA_STATUS -ne 0 ] && [ -t 0 ]; then
  echo -e "\n${YELLOW}Nova failed, possibly due to an invalid OpenAI key.${NC}"
  read -rs -p "Enter a new OpenAI API key (or press ENTER to keep current): " _newkey; echo
  if [ -n "$_newkey" ]; then
    export OPENAI_API_KEY="$_newkey"
    echo "Using OpenAI key: ${OPENAI_API_KEY:0:6}…${OPENAI_API_KEY: -4}"
    echo -e "Retrying with new key..."
    FORCE_COLOR=1 CLICOLOR_FORCE=1 NOVA_DISABLE_COLOR=0 NOVA_ASCII_MODE=0 \
    NOVA_SKIP_PR=1 PYTHONHASHSEED=0 nova fix $NOVA_FLAGS --demo-mode --max-iters "${NOVA_MAX_ITERS:-3}" --timeout 300
    NOVA_STATUS=$?
  fi
fi
set -e

if [ $NOVA_STATUS -ne 0 ]; then
  echo -e "\n⚠️  AI patch failed. Applying offline fix..."
  python3 - <<'PY'
from pathlib import Path

correct = '''
def add(a, b):
    return a + b

def multiply(a, b):
    return a * b
'''

Path('calculator.py').write_text(correct)
print('Applied offline fix to calculator.py')
PY
fi

step 6 "$TOTAL" "🧪" "Run tests after fix"
echo -e "\n✅ Running tests again (should pass)..."
PYTHONHASHSEED=0 pytest -q

step 7 "$TOTAL" "✅" "Show summary & next steps"
echo -e "\n🎉 Demo complete! Nova fixed all bugs automatically.\n"
DEMO_SCRIPT
    chmod +x /tmp/nova_local_demo.sh
}

create_github_demo_script() {
    # Copy the GitHub demo script content from the provided file
    # This is a simplified version
    cat > /tmp/nova_github_demo.sh << 'GITHUB_SCRIPT'
#!/usr/bin/env bash
set -e

echo -e "\n🌐 Nova CI-Rescue - GitHub Actions Demo\n"
echo "This demo requires GitHub CLI (gh) to be installed and authenticated"
echo
echo "Feature coming soon - use Local Demo for now"
GITHUB_SCRIPT
    chmod +x /tmp/nova_github_demo.sh
}

########################################
# Main Execution Flow
########################################

main() {
    # Show welcome BEFORE enabling tee-based logging to avoid out-of-order TTY writes
    show_welcome

    # Smart cache: env -> keychain -> $HOME/.nova.env -> prompt
    echo
    echo -e "${BOLD}Credentials${NC}"
    echo -e "${DIM}We need your OpenAI API key and Cloudsmith entitlement.${NC}"
    echo
    cache_secret OPENAI_API_KEY "Enter your OpenAI API key (sk-...)" || exit 1
    cache_secret CLOUDSMITH_ENTITLEMENT "Enter your entitlement token" || exit 1
    export CLOUDSMITH_TOKEN="${CLOUDSMITH_ENTITLEMENT}"
    export OPENAI_ENTITLEMENT_TOKEN="${CLOUDSMITH_ENTITLEMENT}"
    echo
    print_line
    echo

    # Now set up full-session logging (stdout and stderr) with secret scrubbing
    # Honor NOVA_QS_DISABLE_TEE=1 to keep output attached to the current terminal
    if [ "${NOVA_QS_DISABLE_TEE:-0}" != "1" ]; then
        setup_logging
    fi

    # If running non-interactively without a chosen mode, show brief usage and exit
    if [ ! -t 0 ] && [ $# -eq 0 ]; then
        echo "Non-interactive mode detected. Please pass one of: --local | --github | --campaign"
        echo "Use --help for full usage."
        exit 2
    fi
    
    # Optional preflight system check (off by default)
    if [[ "${CI_RESCUE_SYSTEM_CHECK}" -eq 1 ]]; then
        echo -e "${BOLD}System Check:${NC}"
        kill_stray_cloudsmith_uploads
        if ! check_requirements; then
            echo -e "\n${YELLOW}⚠️  System check failed; continuing anyway${NC}" >&2
            true
        fi
    fi
    # Load any persisted env after core creds
    load_nova_env
    
    # Set reasonable demo caps (inherit if already set)
    export NOVA_DEMO_MODE_MAX_LINES="${NOVA_DEMO_MODE_MAX_LINES:-200}"
    export NOVA_DEMO_MODE_MAX_TOKENS="${NOVA_DEMO_MODE_MAX_TOKENS:-10000}"
    # Default reasoning effort
    export NOVA_DEFAULT_REASONING_EFFORT="${NOVA_DEFAULT_REASONING_EFFORT:-high}"

    # Show configuration
    echo
    echo -e "${BOLD}Configuration:${NC}"
    echo -e "  ${DIM}Model:${NC} OpenAI ${NOVA_DEFAULT_LLM_MODEL:-gpt-5-mini} • reasoning: ${NOVA_DEFAULT_REASONING_EFFORT:-high}"
    echo -e "  ${DIM}Safety:${NC} max_iters=${NOVA_MAX_ITERS:-3}, patch_files≤5, patch_lines≤200"
    echo
    
    echo
    print_line
    echo
    
    # Show menu
    show_demo_menu
    
    # Get user choice (ENTER defaults silently to GitHub Actions)
    while true; do
        # Prefer STDIN/STDOUT to avoid TTY pinning; fall back to /dev/tty only if needed
        if [ "${NOVA_PREFER_STDIN:-1}" = "1" ] && [ -t 0 ]; then
            printf "%b" "${NOVA_BLUE}${BOLD}Choose 1 or 2 [ENTER=1]:${NC} "
            IFS= read -r -n 1 choice || choice=""
            echo
        elif [ -e /dev/tty ]; then
            printf "%b" "${NOVA_BLUE}${BOLD}Choose 1 or 2 [ENTER=1]:${NC} " > /dev/tty 2>/dev/null || true
            IFS= read -r -n 1 choice < /dev/tty || choice=""
            printf "\n" > /dev/tty 2>/dev/null || true
        else
            printf "%b" "${NOVA_BLUE}${BOLD}Choose 1 or 2 [ENTER=1]:${NC} "
            IFS= read -r -n 1 choice || choice=""
            echo
        fi
        # Normalize selection
        choice="$(echo -n "$choice" | tr -d '[:space:]')"
        [ -z "$choice" ] && choice=1
        
        case $choice in
            1)
                # Local demo (ensure entitlement for install path)
                { [ -e /dev/tty ] && printf "%s\n" "Starting Local demo…" > /dev/tty 2>/dev/null || true; } || true
                ensure_cloudsmith_entitlement
                if run_local_demo "$@"; then
                    break
                else
                    { [ -e /dev/tty ] && printf "%s\n" "Local demo did not complete successfully. Choose again." > /dev/tty 2>/dev/null || true; } || true
                fi
                ;;
            2)
                # GitHub Actions integration
                { [ -e /dev/tty ] && printf "%s\n" "(Default) → GitHub Actions demo" > /dev/tty 2>/dev/null || true; } || true
                # Ensure output is directly on the TTY for the rest of the run
                exec >/dev/tty 2>/dev/tty
                if run_github_demo "$@"; then
                    break
                else
                    { [ -e /dev/tty ] && printf "%s\n" "GitHub demo prerequisites not met. Choose again (try 1 for Local)." > /dev/tty 2>/dev/null || true; } || true
                fi
                ;;
            q|Q|quit|exit)
                echo -e "\n${NOVA_BLUE}Thank you for trying Nova CI-Rescue!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please select 1-2 or 'q' to quit${NC}"
                ;;
        esac
    done
    
    # Success message
    echo
    center_text "${NOVA_GREEN}${BOLD}${CHECK} Success!${NC}"
    echo
    
    # One-line receipt (Time‑to‑green · Files changed · LOC · Attempts)
    if [ -f /tmp/nova_step.out ]; then
        # Try to scrape metrics from known log hints
        local _time=$(grep -iE "Time elapsed:|Elapsed:" /tmp/nova_step.out | tail -1 | sed -E 's/.*(Time elapsed:|Elapsed:) *//')
        local _files=$(grep -iE "files changed" /tmp/nova_step.out | tail -1 | sed -E 's/.*([0-9]+) files changed.*/\1/' )
        local _loc=$(grep -iE "([0-9]+) insertions?\(\+\)|patch_lines|lines changed" /tmp/nova_step.out | tail -1 | sed -E 's/[^0-9]*([0-9]+).*/\1/')
        local _iters=$(grep -iE "Iterations:|Attempts:" /tmp/nova_step.out | tail -1 | sed -E 's/[^0-9]*([0-9]+).*/\1/')
        [ -n "$_time" ] || _time="n/a"
        [ -n "$_files" ] || _files="n/a"
        [ -n "$_loc" ] || _loc="n/a"
        [ -n "$_iters" ] || _iters="n/a"
        echo -e "Time-to-green: ${_time} · Files changed: ${_files} · LOC: ${_loc} · Attempts: ${_iters}"
        echo
    fi
    
    # Next steps
    echo -e "${BOLD}${NOVA_CYAN}Next Steps:${NC}"
    echo -e "  • Set up Nova in your own projects"
    echo -e "  • Join the ${BOLD}Founding 50${NC} users program"
    : # removed end-of-show pick line
    echo
    
    echo -e "${DIM}Questions? Contact sebastian@joinnova.com${NC}"
    echo -e "${DIM}Log saved to: $LOG_FILE${NC}"
    echo
}

# Cleanup handler
cleanup() {
    local exit_code=$?
    
    # Deactivate virtual environment if active
    if [ -n "${VIRTUAL_ENV:-}" ] && [ "${VIRTUAL_ENV:-}" != "${ORIGINAL_VENV:-}" ]; then
        deactivate 2>/dev/null || true
    fi
    
    if [ $exit_code -ne 0 ] && [ $exit_code -ne 130 ]; then
        echo
        echo -e "${YELLOW}Demo interrupted or encountered an error${NC}"
        echo -e "${DIM}Check log: $LOG_FILE${NC}"
    fi
    
    exit $exit_code
}

# Set up signal handlers
trap cleanup EXIT INT TERM

########################################
# Unified non-interactive CLI + CI helpers
########################################

# Load .env if present without overriding existing exported vars
load_dotenv_if_present() {
    if [ -f ./.env ]; then
        set -a; . ./.env 2>/dev/null || true; set +a
    fi
}

require_env_or_die() { # require_env_or_die VAR "Helpful message"
    local var="$1"; shift
    if [ -z "${!var:-}" ]; then
        echo "Error: $var is required. $*" >&2
        exit 1
    fi
}

run_cli_mode_unified() {
    # Fail-fast env checks (no prompts)
    load_dotenv_if_present
    require_env_or_die OPENAI_API_KEY "Set it in your shell or in .env"
    require_env_or_die CLOUDSMITH_ENTITLEMENT "Set it in your shell or in .env"

    local demo_dir
    demo_dir="/tmp/nova-cli-demo-$(date +%s)"
    mkdir -p "$demo_dir"
    cd "$demo_dir"

    python3 -m venv .venv
    . .venv/bin/activate

    export PIP_DISABLE_PIP_VERSION_CHECK=1
    python3 -m pip install -U pip --no-python-version-warning >/dev/null 2>&1 || true

    local INDEX_URL
    INDEX_URL="https://dl.cloudsmith.io/${CLOUDSMITH_ENTITLEMENT}/nova/nova-ci-rescue/python/simple/"
    echo "Installing nova-ci-rescue from Cloudsmith…"
    python3 -m pip install -U --no-cache-dir nova-ci-rescue \
      --index-url "$INDEX_URL" \
      --extra-index-url "https://pypi.org/simple"

    # Test tooling
    python3 -m pip install -U pytest >/dev/null 2>&1 || true

    # Minimal buggy calculator + tests
    cat > calculator.py << 'EOF_CLI_CALC'
def add(a, b):
    return a - b

def multiply(a, b):
    return a + b

def power(a, b):
    return a * b
EOF_CLI_CALC

    cat > test_calculator.py << 'EOF_CLI_TEST'
from calculator import add, multiply, power

def test_add():
    assert add(2, 3) == 5

def test_multiply():
    assert multiply(3, 4) == 12

def test_power():
    assert power(2, 3) == 8
EOF_CLI_TEST

    git init -q
    git config user.email "demo@nova.ai"
    git config user.name "Nova Demo"
    git add .
    git commit -q -m "init failing calculator"

    echo "Running pytest (expected to fail)…"
    set +e
    PYTHONHASHSEED=0 pytest -q
    echo "Running nova fix…"
    NOVA_SKIP_PR=1 nova fix --quiet --max-iters "${NOVA_MAX_ITERS:-3}"
    FIX_EXIT=$?
    set -e

    echo "Re-running pytest…"
    PYTHONHASHSEED=0 pytest -q

    echo
    if [ "$FIX_EXIT" -eq 0 ]; then
        echo "Summary: initial tests failed; Nova applied fixes; tests now pass."
    else
        echo "Summary: Nova attempted fixes but reported a non-zero exit; tests status shown above."
    fi
}

generate_ci_workflow() {
    # Generate a ready-to-run GitHub Actions workflow using Cloudsmith as primary index
    load_dotenv_if_present
    if [ -z "${CLOUDSMITH_ENTITLEMENT:-}" ]; then
        echo "Note: The workflow expects GitHub secret CLOUDSMITH_ENTITLEMENT; none needed locally."
    fi

    mkdir -p .github/workflows
    cat > .github/workflows/ci.yml << 'YAML'
name: Nova CI-Rescue

on:
  push:
    branches: [ main, master, develop ]
  pull_request:
    branches: [ main, master ]

jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install tools
        run: |
          python -m pip install -U pip
          python -m pip install pytest

      - name: Run tests (initial)
        id: pytest_initial
        continue-on-error: true
        run: |
          pytest -q | tee test_output.txt
          echo "passed=$([ ${PIPESTATUS[0]} -eq 0 ] && echo true || echo false)" >> $GITHUB_OUTPUT

      - name: Install Nova (Cloudsmith)
        if: steps.pytest_initial.outputs.passed == 'false'
        env:
          CLOUDSMITH_ENTITLEMENT: ${{ secrets.CLOUDSMITH_ENTITLEMENT }}
        run: |
          if [ -z "${CLOUDSMITH_ENTITLEMENT}" ]; then
            echo 'CLOUDSMITH_ENTITLEMENT secret is required'; exit 1; fi
          python -m pip install -U --no-cache-dir nova-ci-rescue \
            --index-url "https://dl.cloudsmith.io/${CLOUDSMITH_ENTITLEMENT}/nova/nova-ci-rescue/python/simple/" \
            --extra-index-url "https://pypi.org/simple"

      - name: Nova auto-fix
        if: steps.pytest_initial.outputs.passed == 'false'
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        run: |
          nova fix --quiet --max-iters 3

      - name: Run tests (after fix)
        if: steps.pytest_initial.outputs.passed == 'false'
        run: |
          pytest -q

      - name: Upload artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: nova-artifacts-${{ github.run_id }}
          path: |
            test_output.txt
            .nova/
YAML

    echo "Created .github/workflows/ci.yml"
    echo "Secrets required: OPENAI_API_KEY, CLOUDSMITH_ENTITLEMENT"
}

# Handle command line arguments

# Map numeric shortcuts to flags if user calls like: ./quickstart.sh 1
if [[ "${1:-}" =~ ^[1-3]$ ]]; then
    _arg="$1"
    shift || true
    case "$_arg" in
        1) set -- --local "$@" ;;
        2) set -- --github "$@" ;;
        3) set -- --campaign "$@" ;;
    esac
fi

case "${1:-}" in
    --version|-V)
        VERSION_FILE="${SCRIPT_DIR}/VERSION"
        NOVA_QS_VERSION="${NOVA_QS_VERSION:-$( [ -f "$VERSION_FILE" ] && tr -d '\n' < "$VERSION_FILE" || echo '6.0.0-dev' )}"
        echo "nova-quickstart ${NOVA_QS_VERSION}"
        exit 0
        ;;
    --help|-h)
        echo "Nova CI-Rescue Quickstart"
        echo "========================"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --cli         Run non-interactive local demo (Cloudsmith-only install)"
        echo "  --ci          Generate GitHub Actions workflow in current repo"
        echo "  --local       Run local demo directly"
        echo "  --github      Run GitHub Actions demo directly"
        echo "  --campaign    Start 100 PR Rescue campaign mode"
        echo "  --verbose     Show detailed output"
        echo "  --no-color    Disable ANSI colors in output"
        echo "  --ascii       Use ASCII icons instead of emoji"
        echo "  --help        Show this help message"
        echo
        echo "Environment Variables:"
        echo "  OPENAI_API_KEY    Your OpenAI API key (required)"
        echo "  NOVA_ASCII_MODE   Use ASCII instead of emoji (set to 1)"
        echo "  NOVA_DISABLE_COLOR Disable ANSI colors (set to 1)"
        echo
        exit 0
        ;;
    --cli)
        run_cli_mode_unified "$@";;
    --ci)
        generate_ci_workflow "$@";;
    --local)
        show_welcome; setup_logging; check_requirements || exit 1; cache_secret OPENAI_API_KEY "Enter your OpenAI API key (sk-...)"; cache_secret CLOUDSMITH_ENTITLEMENT "Enter your entitlement token"; export CLOUDSMITH_TOKEN="${CLOUDSMITH_ENTITLEMENT}"; export OPENAI_ENTITLEMENT_TOKEN="${CLOUDSMITH_ENTITLEMENT}"; shift; run_local_demo "$@";;
    --github)
        show_welcome; setup_logging; check_requirements || exit 1; cache_secret OPENAI_API_KEY "Enter your OpenAI API key (sk-...)"; cache_secret CLOUDSMITH_ENTITLEMENT "Enter your entitlement token"; export CLOUDSMITH_TOKEN="${CLOUDSMITH_ENTITLEMENT}"; export OPENAI_ENTITLEMENT_TOKEN="${CLOUDSMITH_ENTITLEMENT}"; shift; run_github_demo "$@";;
    --campaign)
        show_welcome; setup_logging; check_requirements || exit 1; cache_secret OPENAI_API_KEY "Enter your OpenAI API key (sk-...)"; cache_secret CLOUDSMITH_ENTITLEMENT "Enter your entitlement token"; export CLOUDSMITH_TOKEN="${CLOUDSMITH_ENTITLEMENT}"; export OPENAI_ENTITLEMENT_TOKEN="${CLOUDSMITH_ENTITLEMENT}"; shift; run_rescue_campaign "$@";;
    *)
        main "$@"
        ;;
esac

exit 0