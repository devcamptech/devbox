#!/usr/bin/env bash
# Sets up the Camptech app inside the devbox VM: GitHub login, clone, npm ci, .env.local, local Supabase.
# Safe to run again: each step is skipped when already done. Never touches a hosted database or project.
#
#   ~/bootstrap.sh
#
# Overrides: CAMPTECH_REPO (default devcamptech/camptech), CAMPTECH_DIR (default ~/code/camptech),
# CAMPTECH_BRANCH (default preview).
set -euo pipefail

REPO="${CAMPTECH_REPO:-devcamptech/camptech}"
DIR="${CAMPTECH_DIR:-$HOME/code/camptech}"
BRANCH="${CAMPTECH_BRANCH:-preview}"
export PATH="$HOME/.npm-global/bin:$PATH"

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# Sets KEY=value in .env.local without printing the value.
set_env() {
  local key="$1" value="$2" tmp
  tmp="$(umask 077 && mktemp .env.local.XXXXXX)"
  awk -v k="$key" -v v="$value" 'BEGIN { FS = OFS = "=" }
    $1 == k { print k "=" v; found = 1; next } { print }
    END { if (!found) print k "=" v }' .env.local > "$tmp"
  mv "$tmp" .env.local
  chmod 600 .env.local
}

step "Docker"
if ! docker info >/dev/null 2>&1; then
  echo "Docker is not usable by $USER yet: the docker group applies from the next login."
  echo "Run 'exit', then 'limactl shell camptech' and ~/bootstrap.sh again."
  exit 1
fi
echo "ok"

step "GitHub login"
if gh auth status >/dev/null 2>&1; then
  echo "already logged in as $(gh api user --jq .login)"
else
  echo "Open the URL it prints in the host's browser and enter the code."
  gh auth login --hostname github.com --git-protocol https --web
fi
gh auth setup-git

step "Clone $REPO"
if [ -d "$DIR/.git" ]; then
  echo "already at $DIR"
else
  mkdir -p "$(dirname "$DIR")"
  gh repo clone "$REPO" "$DIR" -- --branch "$BRANCH"
fi
cd "$DIR"

step "Git identity (this repository only)"
# The GitHub noreply address always matches the account, which Vercel needs to accept a deployed commit.
if [ -z "$(git config --local user.email || true)" ]; then
  login="$(gh api user --jq .login)"
  git config --local user.name "$(gh api user --jq '.name // .login')"
  git config --local user.email "$(gh api user --jq .id)+$login@users.noreply.github.com"
fi
echo "$(git config user.name) <$(git config user.email)>"

step "npm ci"
npm ci

step ".env.local"
if [ ! -f .env.local ]; then
  (umask 077 && cp .env.example .env.local)
  set_env POSTGRES_URL "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
  set_env ANTHROPIC_API_KEY ""
  echo "created from .env.example"
else
  echo "already there; only the local Supabase values are refreshed below"
fi
chmod 600 .env.local

step "Local Supabase"
echo "The host must not run another local Supabase: it uses the same ports (54321-54324)."
if ! npx supabase status >/dev/null 2>&1; then
  npx supabase start
fi
status_env="$(npx supabase status -o env)"
get() { sed -n "s/^$1=\"\{0,1\}\([^\"]*\)\"\{0,1\}$/\1/p" <<<"$status_env" | head -n1; }
api_url="$(get API_URL)"
publishable="$(get PUBLISHABLE_KEY)"; publishable="${publishable:-$(get ANON_KEY)}"
secret="$(get SECRET_KEY)"; secret="${secret:-$(get SERVICE_ROLE_KEY)}"
[ -n "$api_url" ] && [ -n "$publishable" ] && [ -n "$secret" ] || {
  echo "Could not read the local Supabase keys from 'npx supabase status -o env'."; exit 1; }
set_env NEXT_PUBLIC_SUPABASE_URL "$api_url"
set_env NEXT_PUBLIC_SUPABASE_ANON_KEY "$publishable"
set_env SUPABASE_SERVICE_ROLE_KEY "$secret"
echo "NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY set (values not shown)"

step "Done"
cat <<EOF
Next:
  cd $DIR
  npm run dev            # then open http://localhost:3000 on the host
                         # admin@camptech.test / camptech-local
  claude                 # first run asks you to log in

Optional logins, only for the hosted projects (read the repo's AGENTS.md first):
  npx supabase login
  vercel login
EOF
