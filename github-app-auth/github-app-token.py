#!/usr/bin/env python3
import json
import os
import sys
import time

import jwt
import requests
from pathlib import Path

APP_ID = os.environ["GITHUB_APP_ID"]
OWNER = os.environ["GITHUB_APP_OWNER"]
PEM_PATH = os.environ["GITHUB_APP_PEM"]

API = "https://api.github.com"

def make_jwt():
    path = Path(PEM_PATH).expanduser()
    with open(path, "r", encoding="utf-8") as f:
        private_key = f.read()

    now = int(time.time())
    payload = {
        "iat": now - 60,
        "exp": now + 540,   # short-lived JWT
        "iss": APP_ID,
    }
    return jwt.encode(payload, private_key, algorithm="RS256")

def get_installation_id(jwt_token, owner, repo):
    url = f"{API}/repos/{owner}/{repo}/installation"
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {jwt_token}",
        "X-GitHub-Api-Version": "2026-03-10",
    }
    r = requests.get(url, headers=headers, timeout=30)
    r.raise_for_status()
    return r.json()["id"]

def get_installation_token(jwt_token, installation_id, repo_names=None):
    url = f"{API}/app/installations/{installation_id}/access_tokens"
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {jwt_token}",
        "X-GitHub-Api-Version": "2026-03-10",
    }
    body = {}
    if repo_names:
        body["repositories"] = repo_names
    r = requests.post(url, headers=headers, json=body, timeout=30)
    r.raise_for_status()
    return r.json()["token"]

def main():
    if len(sys.argv) < 2:
        print("usage: github-app-token.py REPO [REPO...]", file=sys.stderr)
        sys.exit(2)

    repos = sys.argv[1:]
    first_repo = repos[0]
    jwt_token = make_jwt()
    installation_id = get_installation_id(jwt_token, OWNER, first_repo)
    token = get_installation_token(jwt_token, installation_id, repos)
    print(token)

if __name__ == "__main__":
    main()

