# Run from a Linux machine with Ansible (the hub itself, your Kali VM, or WSL).
# Ansible does not run natively on Windows.

.PHONY: deps ping syntax check here hub kave all

deps:            ## install required Ansible collections
	ansible-galaxy collection install -r requirements.yml

ping:            ## can Ansible reach every host?
	ansible servers -m ping

syntax:          ## catch YAML/playbook mistakes without touching any server
	ansible-playbook site.yml --syntax-check

check:           ## dry run with diff: make check HOST=hub
	ansible-playbook site.yml --limit $(or $(HOST),servers) --check --diff

here:            ## apply to the machine you're logged into (run it on the hub itself)
	ansible-playbook site.yml --limit $(shell hostname) --connection local

hub:             ## apply to the hub
	ansible-playbook site.yml --limit hub

kave:            ## apply to Kave
	ansible-playbook site.yml --limit kave

all:             ## apply everything
	ansible-playbook site.yml
