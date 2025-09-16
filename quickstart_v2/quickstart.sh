#!/usr/bin/env bash
set -euo pipefail

# Canonical Nova quickstart shim with versioning
# Delegates to the current implementation (dev-6-1)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/VERSION"
NOVA_QS_VERSION="${NOVA_QS_VERSION:-$( [ -f "$VERSION_FILE" ] && tr -d '\n' < "$VERSION_FILE" || echo '0.0.0-dev' )}"

case "${1:-}" in
  --version|-V)
    echo "nova-quickstart ${NOVA_QS_VERSION}"
    exit 0
    ;;
  --help|-h)
    echo "Nova CI-Rescue Quickstart (canonical)"
    echo "Version: ${NOVA_QS_VERSION}"
    echo
    echo "Usage: $0 [options]"
    echo "(Delegates to quickstart-dev-6-1.sh)"
    echo
    exec "${SCRIPT_DIR}/quickstart-dev-6-0.sh" --help
    ;;
esac

exec "${SCRIPT_DIR}/quickstart-dev-6-1.sh" "$@"


