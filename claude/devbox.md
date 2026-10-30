# Camptech devbox

You are running inside the Camptech devbox: an isolated Lima VM (Ubuntu 24.04) from
https://github.com/devcamptech/devbox. It has no browser. The user's browser is on the host, which reaches the VM only on
`127.0.0.1` ports 3000 (app) and 54321–54324 (local Supabase API, database, Studio, Mailpit). Nothing from the host is
mounted. Logins live only on this VM's disk.

## First thing in every session: check the logins

Before other work, check quietly (read-only; don't paste their output, it can contain account details):

| Tool | Check | Logged in when |
| --- | --- | --- |
| GitHub CLI | `gh auth status` | exit code 0 |
| Vercel CLI | `vercel whoami` | prints a username |
| Supabase CLI | `npx --yes supabase projects list -o json` (run from `~`) | exit code 0 |
| Claude Code | — | you are running, so it is |

If all are logged in, say so in one line and continue. If any is missing, guide the user through the missing ones, **one
at a time**, in this order, and check each with its command above before going to the next:

1. `gh auth login --web --git-protocol https`, then `gh auth setup-git`
2. `vercel login`
3. `npx supabase login`

The user runs them, not you: they print a URL (and sometimes a code) to open in the host's browser. Ask them to type
`! <command>` in the prompt. If nothing is printed, it exits at once, or it waits for input that can't be typed (the
`!` prefix has no terminal), ask them to run it in a second terminal on the host instead: `limactl shell camptech`,
then the command. The user may skip a login they don't need (Vercel and Supabase are only for the hosted projects).

- Never ask the user to paste a token, password or key into the chat, and never print one.
- Never write credentials into a file in a repository, private or public, and never export or copy session files
  (`~/.config/gh`, Vercel's `auth.json`, `~/.supabase`) off the VM.
- If `vercel whoami` is the Vercel team's owner, mention once that a non-owner team member is safer inside a VM where
  an agent runs: the owner can deploy production and change its settings.

## Then: the app

- If `~/code/camptech` doesn't exist (or has no `.env.local`), the user runs `~/bootstrap.sh` (clone, `npm ci`,
  `.env.local`, local Supabase). Before that, ask them to confirm the host has no local Supabase running: it uses the
  same ports. If Docker isn't usable yet, they `exit` and `limactl shell camptech` again (the docker group applies
  from the second login).
- For any work on the app, follow `~/code/camptech/AGENTS.md`. Hosted databases and production are read-only for you
  unless the user approves that exact action.

## Changing the devbox

The template, `bootstrap.sh` and this file live in https://github.com/devcamptech/devbox, a **public** repository:
nothing secret goes there. Changes go through a PR. This file is installed as `~/.claude/devbox.md` on every boot and
imported from `~/.claude/CLAUDE.md`; edit the repository, not the installed copy.
