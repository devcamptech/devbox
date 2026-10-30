# Camptech devbox

An isolated Linux VM for working on [Camptech Posventa](https://github.com/devcamptech/camptech), built with
[Lima](https://lima-vm.io). Same tools on every host, and nothing from the host leaks in: no shared folders, no SSH
agent, no host SSH keys. Logins and code live only on the VM's disk.

What's inside: Ubuntu 24.04, Docker (without sudo), Node.js 24, GitHub CLI, Claude Code, Vercel CLI, `psql`.
The host only sees ports **3000** (app) and **54321–54324** (local Supabase API, database, Studio, Mailpit), on
`127.0.0.1`.

## Requirements

- **macOS 13.5+** (Apple Silicon or Intel) or **Linux** with KVM.
- **Lima 2.0+**: `brew install lima` (macOS or Linux with Homebrew), or see
  [Lima's install guide](https://lima-vm.io/docs/installation/).
- About 8 GiB of free RAM and 60 GiB of disk.
- Nothing else on the host using ports 3000 or 54321–54324 (stop any local Supabase first: `npx supabase stop`).

Windows isn't supported.

## Start

On the host:

```bash
limactl start --name=camptech https://raw.githubusercontent.com/devcamptech/devbox/main/camptech.yaml
limactl shell camptech
```

The first start downloads Ubuntu and installs the tools (a few minutes). Then, inside the VM, the quickest way is
to start Claude Code and let it guide you:

```bash
claude             # the first run asks you to log in to Claude
```

Claude Code reads [claude/devbox.md](claude/devbox.md) (installed as `~/.claude/devbox.md`) at the start of every
session: it checks the GitHub, Vercel and Supabase CLI logins and walks you through the missing ones, one at a time,
then through `~/bootstrap.sh`. To do it by hand instead:

```bash
gh auth login --web --git-protocol https && gh auth setup-git
vercel login           # optional: only for the hosted Vercel project
npx supabase login     # optional: only for the hosted Supabase projects
~/bootstrap.sh
```

The bootstrap logs you in to GitHub if needed (open the URL it prints in the host's browser), clones the repo on `preview`, runs
`npm ci`, creates `.env.local`, starts local Supabase with the seed data and fills in its keys. If it says Docker isn't
usable yet, run `exit`, `limactl shell camptech` and `~/bootstrap.sh` again: the docker group applies from the
second login. It can be run again at any time.

Then:

```bash
cd ~/code/camptech
npm run dev        # open http://localhost:3000 on the host: admin@camptech.test / camptech-local
claude             # Claude Code; the first run asks you to log in
```

## Everyday use

| | Command (on the host) |
| --- | --- |
| Open a shell | `limactl shell camptech` |
| Stop / start | `limactl stop camptech` · `limactl start camptech` |
| Status | `limactl list` |
| SSH (for an editor's remote mode) | `ssh -F ~/.lima/camptech/ssh.config lima-camptech` |
| Start over (**deletes the VM's disk: code, logins, local data**) | `limactl delete camptech`, then [Start](#start) again |

Inside the VM, local Supabase keeps running across `npm run dev` restarts; `npx supabase stop` / `start` from
`~/code/camptech`. Push your branches before deleting the VM.

## Changing the devbox

Edit `camptech.yaml` (or `bootstrap.sh`) here and open a PR. Provisioning runs on every boot, so each step must be
safe to repeat. Lima reads the template only when a VM is created: to apply a change to an existing VM, push your
work, `limactl delete camptech` and start it again. The VM fetches `bootstrap.sh` and `claude/devbox.md` from `main` on every boot, so changes to those reach existing VMs at the next start.

Pinned versions: Node.js 24 (latest patch, checked against nodejs.org's SHA-256 list), Claude Code and Vercel CLI
at first install (Claude Code then updates itself), and a dated Ubuntu image checked by digest, with the latest
Ubuntu 24.04 release as fallback once the dated one is removed.

## Security

- No secrets here: this repository is public. Each person logs in on their own VM, through each tool's browser
  login; sessions are never exported or stored in a repository. Revoke a retired host's sessions in GitHub, Vercel
  and Supabase settings, and `limactl delete` it.
- The VM is the isolation boundary: Docker runs without sudo inside it, and nothing on the host is mounted.
- `.env.local` holds only local Supabase values (mode 600). Hosted databases and projects are out of the bootstrap's
  reach; the app repo's `AGENTS.md` sets the rules for them.
