#!/usr/bin/env bash
# Quickstart init dispatcher
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/VERSION"
DEFAULT_SCRIPT="$SCRIPT_DIR/quickstart-dev-6-1.sh"

if [ -f "$VERSION_FILE" ]; then
  QS_VERSION="$(cat "$VERSION_FILE" | tr -d '\r' | tr -d ' ')"
else
  QS_VERSION="dev"
fi

case "${QS_VERSION}" in
  6.1.*)
    TARGET="$SCRIPT_DIR/quickstart-dev-6-1.sh"
    ;;
  *)
    TARGET="$DEFAULT_SCRIPT"
    ;;
esac

exec "$TARGET" "$@"
