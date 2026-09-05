# Copilot project overview

This repository manages the FFSH network infrastructure with Ansible.

## What this repo does

This project provisions Freifunk Südholstein gateways and related services. The automation covers:

- mesh networking with batman-adv
- fastd and WireGuard endpoints
- DHCP, DNS, routing, and IPv6 services
- SSH hardening, service setup, and monitoring
- map and service hosts
- Prometheus and Grafana infrastructure monitoring

## Main files

- README.md: deployment, usage, and vault guidance
- setup.yml: main playbook with gateway, service, and monitoring roles
- hosts.yml: inventory for gateways, services, and monitoring hosts
- group_vars/versions.yml: shared software versions
- group_vars/secrets.yml: shared encrypted vars
- host_vars/: host-specific secret and config values
- roles/: functional deployment modules

## Host groups

- gateways: complete production router deployment
- services: lightweight service-only hosts
- monitoring: Prometheus/Grafana stack

## Typical workflow

```bash
ansible-playbook --vault-id=fastd_key@prompt setup.yml
ansible-playbook --vault-id=fastd_key@prompt setup.yml --limit gateways
ansible-playbook --vault-id=fastd_key@prompt setup.yml --limit services
ansible-playbook --vault-id=fastd_key@prompt setup.yml --check
ansible-lint
```

## When editing this repo

- follow the established role layout in roles/
- prefer templates and handlers over ad-hoc shell logic
- keep host-specific data in host_vars/
- keep shared config in group_vars/
- validate with ansible-lint before broader deployment

## High-level structure

```text
ansible/
├── README.md
├── setup.yml
├── hosts.yml
├── ansible.cfg
├── group_vars/
├── host_vars/
├── roles/
├── .github/
└── ...
```

This is a deployment repository for infrastructure, so changes should be operationally safe, idempotent, and consistent with the existing host inventory and role approach.
