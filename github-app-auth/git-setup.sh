#!/usr/bin/env bash
set -euo pipefail

# Resolve this script's own directory so we register an absolute path to the
# credential helper. Git stores this path in the global config and invokes it
# from arbitrary working directories, so it must be absolute.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

git config --global --unset-all credential.helper || true
git config --global credential.helper "!f() { \"$SCRIPT_DIR/github-gen.sh\"; }; f"
git config --global credential.useHttpPath true
git config --global --get-all credential.helper
