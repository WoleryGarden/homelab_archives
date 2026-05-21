# GitHub App Git authentication

These files set up **Git authentication to GitHub via a GitHub App**. Once
configured, every Git HTTPS operation (`clone`, `pull`, `push`) transparently
obtains a fresh, short-lived, repo-scoped installation token from the App — no
SSH keys and no Personal Access Tokens involved.

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

This folder is **self-contained**: each script resolves its own location, so you
can clone this repo to any path and the tooling still works. There is no need to
copy files into your home directory.

### `github_export`
Config, sourced by the other scripts. Edit the three values for your own App:

- `GITHUB_APP_ID` — the GitHub App's ID
- `GITHUB_APP_OWNER` — the account/org that owns the repos (used as a default;
  `github-gen.sh` overrides it per request)
- `GITHUB_APP_PEM` — path to the App's private key (a leading `~` is expanded)

> The `.pem` is the real secret. Keep it **outside** this repo, protect it
> (`chmod 600`), and never commit it. (`.gitignore` here also ignores `*.pem`.)

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

1. Sources `github_export` from its own directory.
2. Parses `owner/repo` out of the requested path.
3. Calls `github-app-token.py` (via the local venv at `.venv/`) to get a token for
   that repo.
4. Outputs `username=x-access-token` and `password=<token>` — the format Git expects
   from a credential helper.

### `git-setup.sh`
One-time installer. Configures global Git to use the helper:

- Clears any existing `credential.helper`.
- Registers this folder's `github-gen.sh` (by absolute path) as the credential helper.
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

---

# Walkthrough: clone a private repo without SSH or a PAT

This is the full path from nothing to `git clone`-ing a private repo using only a
GitHub App. Steps 1–2 are one-time on GitHub; steps 3–6 are one-time on the machine;
step 7 is what you do from then on.

## 1. Create a GitHub App

1. Go to **GitHub → Settings → Developer settings → GitHub Apps → New GitHub App**
   (for an org, use the org's settings instead of your personal settings).
2. Fill in:
   - **GitHub App name**: anything unique (e.g. `myname-git-auth`).
   - **Homepage URL**: anything (e.g. your repo URL); it is not used.
   - **Webhook**: **uncheck "Active"** — no webhook is needed.
3. Under **Permissions → Repository permissions**, set:
   - **Contents**: **Read and write** (read-only is enough for clone/pull; read &
     write is needed to `git push`).
   - **Metadata**: **Read-only** (this is mandatory and usually auto-selected).
4. Under **Where can this GitHub App be installed?**, choose **Only on this account**.
5. Click **Create GitHub App**.
6. On the App's page, note the **App ID** (shown near the top). You'll put this in
   `github_export`.

## 2. Generate the private key and install the App

1. Still on the App's page, scroll to **Private keys → Generate a private key**.
   A `.pem` file downloads — this is the secret the scripts sign JWTs with.
2. In the left sidebar of the App, click **Install App**, pick your account/org, and
   choose **Only select repositories** → select the **private repo(s)** you want to
   clone and work with. Click **Install**.
   - The App only has access to the repos you select here. You can come back and add
     more repos to the installation later.

## 3. Get this tooling onto the machine

```bash
# Clone this repo anywhere — the scripts work from any path.
git clone https://github.com/AndrewSav/homelab_archives.git
cd homelab_archives/github-app-auth
```

## 4. Place the private key and edit the config

```bash
# Move the downloaded key somewhere safe outside the repo, and lock it down.
mv ~/Downloads/your-app.*.private-key.pem ~/github.pem
chmod 600 ~/github.pem
```

Edit `github_export` and set the three values:

```bash
export GITHUB_APP_ID="123456"           # the App ID from step 1
export GITHUB_APP_OWNER="your-account"  # account/org that owns the private repo
export GITHUB_APP_PEM="~/github.pem"     # where you put the .pem
```

## 5. Create the virtualenv

`github-gen.sh` runs the token script via a venv it expects at `.venv/` next to the
scripts. Create it and install the dependencies (`PyJWT` and `requests`;
`cryptography` is required for `PyJWT` to sign with RS256):

```bash
# Run from inside this github-app-auth folder.
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install PyJWT cryptography requests
```

> On Debian/Ubuntu, `python3 -m venv` may fail with *"ensurepip is not available"*.
> Install the venv package matching your `python3` version, then retry — e.g.
> `sudo apt install python3-venv` (or the versioned `python3.11-venv`). The version
> in the message is just whatever `python3` points to on your system.

The scripts already have the executable bit set in the repo, so no `chmod` is needed
after cloning.

Verify the token flow works end-to-end (use the **name** of the private repo, not
the full `owner/repo`):

```bash
# Imports should succeed with no output
.venv/bin/python -c "import jwt, requests, cryptography; print('ok')"

# Should print a token (ghs_...)
source ./github_export
.venv/bin/python ./github-app-token.py your-private-repo
```

If that prints a `ghs_...` token, the App, key, and installation are all wired up
correctly. (A `404` here usually means the App isn't installed on that repo, or the
owner/repo name is wrong; a `401` usually means a bad/old `.pem` or App ID.)

## 6. Register the credential helper (one-time)

```bash
./git-setup.sh
```

This points global Git at `github-gen.sh` (by absolute path) and enables
`credential.useHttpPath` so the helper sees which repo each request is for. The
script ends by printing the configured helper; you should see a line like this
(with your own clone path):

```
!f() { "/home/andrewsav/homelab_archives/github-app-auth/github-gen.sh"; }; f
```

## 7. Clone and use the private repo

From now on, just use HTTPS URLs — Git calls the helper automatically and the token
is minted on the fly:

```bash
git clone https://github.com/your-account/your-private-repo.git
cd your-private-repo
# edit...
git pull
git push
```

No username/password prompt, no SSH key, no PAT. Each operation gets a fresh
short-lived token scoped to just that repo.

> To add more private repos later, re-run **step 2's install** and add them to the
> App's installation (and use the matching `owner` in the clone URL). No changes to
> these scripts are needed.

## Troubleshooting

- **Git prompts for a username/password** → the helper isn't registered or isn't
  executable. Re-run `git-setup.sh` and confirm `git config --global --get-all
  credential.helper` shows this folder's `github-gen.sh`. (The exec bit is committed,
  but if it got lost, `chmod +x github-gen.sh git-setup.sh github-app-token.py`.)
- **`could not parse owner/repo from path=...`** → the URL wasn't a normal
  `https://github.com/owner/repo.git`, or `credential.useHttpPath` is off. `git-setup.sh`
  sets it; verify with `git config --global credential.useHttpPath`.
- **`404` from the token script** → the App isn't installed on that repo (step 2), or
  `GITHUB_APP_OWNER`/repo name is wrong.
- **`401` from the token script** → wrong `GITHUB_APP_ID`, or the `.pem` doesn't match
  the App / was revoked. Generate a fresh key (step 2) if unsure.
