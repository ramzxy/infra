#!/usr/bin/env bash
# Installs Ansible, then runs this repo on the box itself.
#   sudo bash bootstrap.sh          tools + shell for you, nothing else (shell.yml)
#   sudo bash bootstrap.sh hub      full server setup for that host (site.yml)
# Anything after that goes to ansible-playbook, e.g. --check --diff.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "run as root: sudo bash bootstrap.sh $*" >&2
  exit 1
fi

HOST=""
if [[ $# -gt 0 && "$1" != -* ]]; then
  HOST="$1"
  shift
fi

cd "$(dirname "$0")"
export DEBIAN_FRONTEND=noninteractive

# Current ansible-core from PyPI via pipx, not the distro package: Debian 12 ships 2.14,
# which today's collections no longer support. Same version on every distro this way.
echo "==> installing ansible"
apt-get update -qq
apt-get install -y -qq pipx git curl >/dev/null
export PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin
[[ -x /usr/local/bin/ansible-playbook ]] || pipx install ansible-core >/dev/null
/usr/local/bin/ansible-galaxy collection install -r requirements.yml >/dev/null

if [[ -z "$HOST" ]]; then
  echo "==> tools and shell for ${SUDO_USER:-root}"
  /usr/local/bin/ansible-playbook shell.yml "$@"
  echo
  echo "==> done. Log out and back in (or run: exec zsh) to get the new shell."
  exit 0
fi

echo "==> applying site.yml to '$HOST' (locally)"
/usr/local/bin/ansible-playbook site.yml --limit "$HOST" --connection local "$@"

cat <<EOF

==> done. Before you close this root session:
    open a NEW terminal and check that this works:  ssh $(awk '/^admin_user:/{print $2}' group_vars/all.yml)@<server-ip>
    root login and password login over SSH are now off.
EOF
