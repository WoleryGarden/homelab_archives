#!/usr/bin/env bash
set -euo pipefail

# Resolve this script's own directory so the tooling works no matter where the
# repo is cloned. All sibling files are referenced relative to SCRIPT_DIR.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

source "$SCRIPT_DIR/github_export"

protocol=""
host=""
path=""

while IFS='=' read -r key value; do
  case "$key" in
    protocol) protocol="$value" ;;
    host) host="$value" ;;
    path) path="$value" ;;
  esac
done

repo_path="${path%.git}"
owner="${repo_path%%/*}"
repo="${repo_path#*/}"

if [[ -z "${owner:-}" || -z "${repo:-}" || "$owner" == "$repo_path" ]]; then
  echo "could not parse owner/repo from path='$path'" >&2
  exit 1
fi

token="$(GITHUB_APP_OWNER="$owner" "$SCRIPT_DIR/.venv/bin/python" "$SCRIPT_DIR/github-app-token.py" "$repo")"

echo "username=x-access-token"
echo "password=$token"
