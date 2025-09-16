#!/usr/bin/env bash
set -euo pipefail

# Test wrapper for the "official" quickstart script hosted externally

# Default to the provided Dropbox URL (convert to direct download)
QUICKSTART_URL_DEFAULT="https://www.dropbox.com/scl/fi/zktgp7wqx8woy11jhkuue/quickstart_v5.3_official.sh?rlkey=k7tqqd5hm39obnly2x1d3b00b&st=mguq4f6w&dl=1"
QUICKSTART_URL="${QUICKSTART_URL:-$QUICKSTART_URL_DEFAULT}"

mask() { local v="$1"; local n=${#v}; if [ $n -le 10 ]; then echo "**********"; else echo "${v:0:6}…${v: -4}"; fi; }

echo "Nova Quickstart – Official Script Tester"
echo "----------------------------------------"
echo "Source URL: ${QUICKSTART_URL}"
echo

# Prompt for creds if missing (hidden input)
if [ -z "${OPENAI_API_KEY:-}" ]; then
  if [ -e /dev/tty ]; then
    printf "%s" "Enter OPENAI_API_KEY: " > /dev/tty 2>/dev/null || true
    IFS= read -rs OPENAI_API_KEY < /dev/tty || true
    echo > /dev/tty 2>/dev/null || echo
  else
    read -rs -p "Enter OPENAI_API_KEY: " OPENAI_API_KEY; echo
  fi
fi
if [ -z "${CLOUDSMITH_TOKEN:-}" ]; then
  if [ -e /dev/tty ]; then
    printf "%s" "Enter CLOUDSMITH_TOKEN: " > /dev/tty 2>/dev/null || true
    IFS= read -rs CLOUDSMITH_TOKEN < /dev/tty || true
    echo > /dev/tty 2>/dev/null || echo
  else
    read -rs -p "Enter CLOUDSMITH_TOKEN: " CLOUDSMITH_TOKEN; echo
  fi
fi

echo "Using OPENAI_API_KEY: $(mask "$OPENAI_API_KEY")"
echo "Using CLOUDSMITH_TOKEN: $(mask "$CLOUDSMITH_TOKEN")"

TMP_FILE="/tmp/quickstart_official_$$.sh"
echo "Downloading official quickstart to ${TMP_FILE}…"
curl -fsSLo "$TMP_FILE" "$QUICKSTART_URL"
chmod +x "$TMP_FILE"

echo
echo "Running official quickstart (local path, verbose)…"
export OPENAI_API_KEY CLOUDSMITH_TOKEN
"$TMP_FILE" --local --verbose || true

echo
echo "Done. Log (if any) lives under /tmp/nova-quickstart-*.log"

