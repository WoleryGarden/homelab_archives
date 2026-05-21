#!/usr/bin/env bash
set -euo pipefail

source ~/github_export

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

token="$(GITHUB_APP_OWNER="$owner" ~/venvs/github-app/bin/python ~/github-app-token.py "$repo")"

echo "username=x-access-token"
echo "password=$token"
