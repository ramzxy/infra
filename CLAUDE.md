# infra: context for Claude Code

Ansible repo that builds Ilia's servers. Ilia runs Ramsy (security testing consultancy) and is new to Ansible: explain changes in plain terms and keep the repo simple.

## The setup

| Machine | What it is | Notes |
|---|---|---|
| `hub` | Contabo VPS (8 vCPU, 24 GB, NVMe), public IP 109.123.254.174 | Main always-on box, general purpose: shell + CLI tools, Docker stacks, AI coding CLIs. Pentest toolkit is opt-in (`pentest_enabled`), off by default. |
| `kave` | Small VPS | Egress only: Tailscale exit node. The IP clients see and allowlist. Holds no data or keys. Reverse DNS should be `scanner.ramsy.eu`. |
| Kali VM | On Ilia's Windows PC at home | Main pentest workstation (Burp, GUI tools). Runs an internal dashboard that could move to the hub. |
| Laptop | Mobile workstation | |
| GPU | RunPod, rented by the hour | For local LLMs; joins the tailnet when running. |

All machines join one Tailscale network. Public SSH gets closed once Tailscale works (`ssh_public: false`).

## Decisions already made (don't relitigate unless asked)

- **Ansible, not Terraform.** Servers are long-lived boxes bought by hand; the work is configuring them.
- **The hub is a general hub**, not a pentest box. Pentest tools only via `pentest_enabled: true`.
- **CLI tools come from mise** (`cli_tools` in group_vars → `~/.config/mise/config.toml`), not apt, so they're current on Debian 12 too. apt is for system basics.
- **Shell mirrors Ilia's Windows PowerShell setup**: oh-my-posh with the same theme (`roles/shell/files/theme.omp.json`, plus user@host over SSH), PSReadLine palette in zsh-syntax-highlighting, fzf colours, zoxide, tmux with tpm + tmux-sensible + opensessions.
- **Ansible itself** is installed by `bootstrap.sh` from PyPI via pipx into `/usr/local/bin`, because Debian 12's packaged ansible-core 2.14 is too old for current collections.
- **Scan egress:** Kali/laptop use `tailscale set --exit-node=kave` and run `egress-check` before scanning. Client contracts list Kave's IP as the source IP.
- **Docker** publishes ports on 127.0.0.1 by default (`/etc/docker/daemon.json`), because Docker bypasses ufw. Expose services with `tailscale serve`, never to the internet.
- **Backups:** restic from the hub to a HostBrr storage box (different provider on purpose).

## How to work in this repo

- The control node must be Linux: the hub itself (`make here`), Kali, or WSL (repo on the Linux filesystem, not `/mnt/*`).
- `make syntax`, then `make check HOST=hub`, then apply. On a fresh box: `sudo bash bootstrap.sh hub`.
- Most edits belong in `group_vars/all.yml`. Per-host bits in `host_vars/`.
- Keep `ansible-lint` clean and roles idempotent (second run reports no changes). Read-only probe tasks need `check_mode: false` so dry runs work.
- Templates are Jinja: `{#` starts a Jinja comment, so avoid it in shell/zsh templates (`${#arr}` too; write `$#arr`).
- Keep zsh precmd hooks lean: each one runs on every Enter, and the hub's shared CPU makes them spiky. direnv was dropped for this (use `[env]` in a mise.toml); zsh-autosuggestions runs with `ZSH_AUTOSUGGEST_MANUAL_REBIND`.
- Never commit secrets. Tailscale keys come from `TS_AUTHKEY`; use ansible-vault or sops for anything else.
- Never lock Ilia out: the `ssh` role runs last, and `base` refuses to run without a real key in `admin_ssh_keys`.
- Target distros: Ubuntu 24.04 and Debian 12.

## Open TODOs

1. Bootstrap the hub; then `ssh_public: false`, `ansible_host: hub`, rerun. Disable Tailscale key expiry for hub/kave.
2. Tailscale ACLs with tags before RunPod or other third-party boxes join.
3. restic backup role (hub → HostBrr storage box, nightly, with a restore test).
4. First compose stacks in `/srv/stacks` (e.g. the dashboard from the Kali VM, Uptime Kuma with Telegram alerts).
5. Kave: fill its IP and `egress_ip`, bootstrap, approve exit node, set rDNS.
6. If the hub ever scans: proxychains over `ssh -D kave` only covers TCP connect scans. SYN/raw-socket tools (nmap -sS, masscan, naabu) would leave via the hub's own IP. Route them through Kave properly (e.g. a Tailscale sidecar container with `--exit-node=kave`) first.
