# GitHub App Git authentication

These four files together set up **Git authentication to GitHub via a GitHub App**.
Every Git HTTPS operation transparently obtains a fresh, short-lived, repo-scoped
installation token from the GitHub App.

## Why this approach (the actual goal)

This is **not** about PAT security. The constraints that drove this design are:

- **`git` (e.g. `git push`) cannot use a PAT in this setup at all.** A plain
  personal access token is not a usable credential here, so something else has to
  supply the password to Git.
- **Deploy keys are per-repository.** A single deploy key cannot be reused across
  multiple repositories — and here we need to authenticate against several repos
  (e.g. all the game-server repos under `AndrewSav`).
- **The owner-level repo key cannot be kept on this machine** for security reasons.

A GitHub App solves all three: the App is installed once across many repos, and it
mints **short-lived, per-repo installation tokens on demand** from a single private
key — no per-repo deploy keys, and no long-lived owner credential stored locally.

## Files

### `github_export`
Config/secrets, sourced by the other scripts. Sets three env vars:

- `GITHUB_APP_ID` = `3214500` — the GitHub App's ID
- `GITHUB_APP_OWNER` = `AndrewSav`
- `GITHUB_APP_PEM` = `~/github.pem` — path to the App's private key

> The `.pem` is the real secret. Keep it protected (`chmod 600 ~/github.pem`) and
> never commit it.

### `github-app-token.py`
Mints a short-lived GitHub App **installation access token**:

1. Reads the `.pem` private key and builds a signed **JWT** (valid ~9 min) using the App ID.
2. Looks up the App's *installation ID* for the target repo
   (`GET /repos/{owner}/{repo}/installation`).
3. Exchanges the JWT for an installation token, optionally scoped to specific repos
   (`POST /app/installations/{id}/access_tokens`).
4. Prints the token to stdout.

Usage: `github-app-token.py REPO [REPO...]`

### `github-gen.sh`
A **Git credential helper** wrapper. Git invokes it with `protocol/host/path` on stdin:

1. Sources `~/github_export`.
2. Parses `owner/repo` out of the requested path.
3. Calls `github-app-token.py` (via the dedicated venv at `~/venvs/github-app/`) to
   get a token for that repo.
4. Outputs `username=x-access-token` and `password=<token>` — the format Git expects
   from a credential helper.

### `git-setup.sh`
One-time installer. Configures global Git to use the helper:

- Clears any existing `credential.helper`.
- Registers `~/github-gen.sh` as the credential helper.
- Sets `credential.useHttpPath true` so Git passes the full repo path (needed so the
  helper can scope the token per-repo).

## How they work together

```
git push  ──▶  git-setup.sh (already configured the helper globally)
                     │
                     ▼
              github-gen.sh   ◀── sources github_export (App ID/owner/pem)
                     │ parses owner/repo, calls ↓
                     ▼
            github-app-token.py  ──▶  GitHub API: JWT → installation token
                     │
                     ▼
        returns username=x-access-token + short-lived password to Git
```

## venv setup

`github-gen.sh` calls a Python interpreter at a fixed path:
`~/venvs/github-app/bin/python`. Create that virtualenv and install the
dependencies the script needs (`PyJWT` and `requests`; `cryptography` is required
for `PyJWT` to sign with RS256):

```bash
# Create the virtualenv at the exact path github-gen.sh expects
python3 -m venv ~/venvs/github-app

# Upgrade pip, then install dependencies
~/venvs/github-app/bin/pip install --upgrade pip
~/venvs/github-app/bin/pip install PyJWT cryptography requests
```

Verify it works:

```bash
# Imports should succeed with no output
~/venvs/github-app/bin/python -c "import jwt, requests, cryptography; print('ok')"

# End-to-end: should print a token (ghs_...)
source ~/github_export
~/venvs/github-app/bin/python ~/github-app-token.py some-repo
```

> If you place the scripts somewhere other than `~`, update the `~/...` paths in
> `git-setup.sh`, `github-gen.sh`, and `github_export` accordingly. Make the shell
> scripts executable: `chmod +x ~/github-gen.sh ~/git-setup.sh`.

## Installation order

1. Put `github_export`, `github-app-token.py`, `github-gen.sh`, `git-setup.sh`, and
   `github.pem` in your home directory.
2. Create the venv (see above).
3. Run `~/git-setup.sh` once to register the credential helper globally.
4. `git push` / `git pull` over HTTPS now authenticate automatically.
