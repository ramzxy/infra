# infra

Turns a fresh Debian 12 / Ubuntu 24.04 VPS into one of your servers, the same way every time.

| Host | Role |
|---|---|
| `hub`  | Main always-on box: your shell and CLI tools, Docker stacks, AI coding CLIs. Pentest toolkit optional. |
| `kave` | Egress only: Tailscale exit node, the IP clients see during tests. Holds nothing. |

## Ansible in two minutes

You describe the end state in YAML, Ansible makes the server match it. Running it twice changes nothing the second time.

- `inventory/hosts.yml`: which servers exist and how to reach them.
- `group_vars/all.yml`: **the file you edit**. Your user, SSH keys, packages, tool list.
- `host_vars/<host>.yml`: per-server overrides (e.g. pentest toolkit on/off).
- `roles/<name>/`: one job each (`base`, `users`, `shell`...). `tasks/main.yml` is the list of steps, `templates/` are files with `{{ variables }}` filled in.
- `site.yml`: which roles run on which hosts, in order.

## What a run does

1. **base**: hostname, updates, apt packages, timezone, automatic security updates
2. **users**: your user with zsh, sudo and exactly the SSH keys in `admin_ssh_keys`
3. **firewall**: ufw denies everything in except Tailscale (and public SSH while `ssh_public: true`)
4. **tailscale**: installs it, logs in if you pass `TS_AUTHKEY`
5. **cli**: [mise](https://mise.jdx.dev) installs the toolset in `cli_tools` (eza, bat, fzf, zoxide, lazygit, neovim, node, go...) plus Claude Code, Codex, Gemini CLI, opencode
6. **shell**: zsh set up like your Windows PowerShell (same oh-my-posh prompt and colours, inline history suggestions, Tab menu, Up/Down prefix search, fzf, zoxide), tmux with tpm + tmux-sensible + opensessions, git with delta
7. **hub only**: Docker (published ports bind to localhost), `/srv/stacks`; pentest toolkit if `pentest_enabled: true`
8. **kave only**: IP forwarding + exit node
9. **ssh** (last): keys only, no root login, no passwords

## First run on a fresh server

1. **Your key** is already in `admin_ssh_keys` (from `~/.ssh/id_ed25519.pub` on the Windows PC). Add the laptop's and Kali's keys there too.
2. **Tailscale auth key** (optional, recommended): admin console → Settings → Keys → Generate auth key. One-off, not reusable.
3. **Let your key log in as root once** (asks for the Contabo root password, which you type):
   ```powershell
   type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@109.123.254.174 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
   ```
4. **Copy the repo over and run it:**
   ```powershell
   scp -r D:\Ramsy\infra root@109.123.254.174:/root/
   ssh root@109.123.254.174
   ```
   ```bash
   cd /root/infra && TS_AUTHKEY=tskey-auth-... bash bootstrap.sh hub
   ```
   Use `bash bootstrap.sh`, not `./bootstrap.sh`: copying from Windows drops the executable bit.
   A one-off auth key is worthless once used, so it doesn't matter that it lands in root's shell history.
5. **Before closing the root session**, open a new terminal and check `ssh ilia@109.123.254.174` works.
   If anything goes wrong, Contabo's VNC console still gets you in as root with the root password.
6. **Move the repo to your home** so the hub can manage itself: `sudo mv /root/infra ~ && sudo chown -R ilia: ~/infra`.

## Day to day

Ansible doesn't run on Windows. The easiest place to run it is the hub itself:

```bash
cd ~/infra
make syntax        # catch typos, touches nothing
make check HOST=hub   # dry run with diff
make here          # apply to this machine
make kave          # apply to Kave over SSH
```

Change something → edit the YAML → `make here`. Don't hand-edit managed files on the server (they say "Managed by Ansible" at the top); the next run overwrites them. Personal shell tweaks go in `~/.zshrc.local`.

From WSL or Kali instead: keep the repo on the Linux filesystem (not `/mnt/c` or a shared folder), or Ansible ignores `ansible.cfg` because the folder is world-writable. Run `make deps` once.

## Common edits (all in `group_vars/all.yml`)

- **Add a CLI tool**: one line in `cli_tools`, e.g. `zellij: latest`. Browse what exists: `mise registry`. Upgrade everything: `mise up`.
- **Try a tool without keeping it**: `mise exec ruby -- ruby -v`.
- **Pentest toolkit on the hub**: `pentest_enabled: true` in `host_vars/hub.yml`. Adds nmap, nuclei, ffuf etc., SecLists, `/srv/engagements`, `egress-check` and `eng`.
- **SSH only over Tailscale**: once `ssh ilia@hub` works over the tailnet, set `ssh_public: false`, set `ansible_host: hub` in `inventory/hosts.yml`, run `make here`.

## Shell cheatsheet

| Keys / command | Does |
|---|---|
| Up / Down | history entries starting with what you've typed |
| → (end of line) | accept the grey suggestion |
| Tab | completion menu, arrow through it |
| Ctrl+R / Ctrl+T / Alt+C | fzf: history / files / cd into a folder |
| `cd part-of-dir` (or `z`), `cdi` (or `zi`) | normal cd, plus jumping to a folder you've visited (zoxide) |
| `ls`, `ll`, `lt`, `tree` | eza listing, long, tree |
| `cat`, `vim`, `top` | bat, neovim, btop |
| `df`, `du`, `dig`, `diff a b` | duf, dust, doggo, delta; add a flag the new tool doesn't know and you get the classic one |
| `rg`, `fd`, `sd`, `xh` | grep, find, sed, curl replacements (different flags, so they keep their own names) |
| `\cat`, `command df` | the original tool, skipping the swap |
| `lg`, `lzd` | lazygit, lazydocker |
| `yazi` | file manager |
| `tldr tar` | short examples for a command |
| `mkcd dir`, `..`, `...` | same as on Windows |
| tmux `prefix o s` | opensessions sidebar |
| tmux `prefix P` | save the whole pane to `~/tmux-<session>-<time>.log` |
| tmux `prefix I` / `U` | install / update tmux plugins |

`history -i` shows timestamps, so the history doubles as a record of what you ran and when.

## Kave

1. Put its IP in `inventory/hosts.yml`, copy the repo over, `bash bootstrap.sh kave`.
2. Tailscale admin console → Machines → kave → Edit route settings → enable **Use as exit node**.
3. On Kali/laptop: `tailscale set --exit-node=kave`, then `egress-check`.
4. Set reverse DNS for Kave's IP to `scanner.ramsy.eu` in its provider panel.

## Things to set in the Tailscale admin console

- **Disable key expiry** for `hub` and `kave`. Otherwise they drop off the tailnet after 180 days, and once `ssh_public: false` that means VNC console only.
- **Access controls**: by default every device on the tailnet can reach every port on the hub. Before a rented box (RunPod GPU) joins, tag the servers and limit what that box can reach.
