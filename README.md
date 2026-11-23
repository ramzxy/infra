# infra

Ansible for my machines. Debian 12 / Ubuntu 24.04 (Kali and WSL work too).

| Mode | Command | Sets up |
|---|---|---|
| **Shell only** | `sudo bash bootstrap.sh` | CLI tools, zsh, prompt, tmux, git config for you. Nothing else on the box changes. |
| **Full server** | `sudo bash bootstrap.sh hub` | All of the above plus user, SSH keys and hardening, firewall, Tailscale, Docker, host extras. |

`bootstrap.sh` installs Ansible first. After that, re-run with `make shell` or `make here`.

## Shell only

```bash
git clone https://github.com/ramzxy/infra.git && cd infra   # or scp the folder over
sudo bash bootstrap.sh
exec zsh
```

Works as a normal user (via sudo) or as root. On WSL, keep the repo on the Linux side, not under `/mnt/c`, or Ansible ignores `ansible.cfg`.

## Full server

Fresh VPS, from Windows:

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@SERVER "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
scp -r D:\Ramsy\infra root@SERVER:/root/
ssh root@SERVER
```

```bash
cd /root/infra && TS_AUTHKEY=tskey-auth-... bash bootstrap.sh hub
```

- The Tailscale key is optional (one-off key from the admin console); without it, run `sudo tailscale up` afterwards.
- Before closing the root session, check `ssh ilia@SERVER` from a new terminal. Root and password login are off after the run.
- Then move the repo home: `sudo mv /root/infra ~ && sudo chown -R ilia: ~/infra`.

On the hub afterwards:

```bash
cd ~/infra && git pull
make here       # apply
make syntax     # catch typos, changes nothing
ansible-playbook site.yml --limit hub --connection local --check --diff   # dry run
```

## Where things live

| Change | Where |
|---|---|
| CLI tools, AI CLIs | `cli_tools`, `ai_tools` in `group_vars/all.yml` (mise; `mise up` upgrades) |
| apt packages | `shell_packages` (every run), `base_packages` (servers) |
| User, SSH keys | `admin_user`, `admin_ssh_keys` |
| Public SSH on/off | `ssh_public` (then `ansible_host: hub` in `inventory/hosts.yml`) |
| Pentest toolkit | `pentest_enabled: true` in `host_vars/hub.yml` |
| Prompt theme | `roles/shell/files/theme.omp.json` |
| zsh, tmux, git config | `roles/shell/templates/` |
| Personal, unmanaged tweaks | `~/.zshrc.local` on the machine |

Files that say "Managed by Ansible" get overwritten on the next run.

Full-run order (`site.yml`): base, users, firewall, tailscale, cli, shell; then docker + hub (+ pentest) on the hub, egress on Kave; ssh hardening last.

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

`history -i` shows timestamps.

## Kave

1. Put its IP in `inventory/hosts.yml`, copy the repo over, `bash bootstrap.sh kave`.
2. Tailscale admin console → Machines → kave → Edit route settings → enable **Use as exit node**.
3. On Kali/laptop: `tailscale set --exit-node=kave`, then `egress-check`.
4. Set reverse DNS for Kave's IP to `scanner.ramsy.eu` in its provider panel.

## Tailscale admin console

- Disable key expiry for `hub` and `kave`, or they drop off the tailnet after 180 days.
- Before a rented box (RunPod GPU) joins, tag the servers and restrict what it can reach. By default every device reaches every port.
