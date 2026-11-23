#!/usr/bin/env bash
# Turn a fresh Debian/Ubuntu box into a managed server, running Ansible on the box itself.
#   scp -r infra root@SERVER:/root/
#   ssh root@SERVER
#   cd /root/infra && TS_AUTHKEY=tskey-... bash bootstrap.sh hub
set -euo pipefail

HOST="${1:-}"
if [[ -z "$HOST" ]]; then
  echo "usage: sudo bash bootstrap.sh <hub|kave> [extra ansible-playbook args]" >&2
  exit 1
fi
if [[ $EUID -ne 0 ]]; then
  echo "run as root (sudo bash bootstrap.sh $HOST)" >&2
  exit 1
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

echo "==> applying site.yml to '$HOST' (locally)"
/usr/local/bin/ansible-playbook site.yml --limit "$HOST" --connection local "${@:2}"

cat <<EOF

==> done. Before you close this root session:
    open a NEW terminal and check that this works:  ssh $(awk '/^admin_user:/{print $2}' group_vars/all.yml)@<server-ip>
    root login and password login over SSH are now off.
EOF
