# Copilot repository guidance

This repository contains the Ansible automation for provisioning and maintaining the Freifunk Südholstein network stack.

## Project purpose

- Deploy and configure FFSH gateway hosts
- Provision service-only hosts and mesh infrastructure
- Manage routing, DHCP, DNS, fastd, batman-adv, SSH, monitoring, and web services
- Keep per-host values and secrets separate from shared configuration
- Support repeatable, idempotent deployments across multiple network nodes

## Repository layout

- README.md: project overview, setup requirements, and common commands
- setup.yml: main playbook entry point for gateway, service, and monitoring deployments
- hosts.yml: inventory and host groups
- ansible.cfg: Ansible configuration
- group_vars/versions.yml: shared software versions and pinned versions
- group_vars/secrets.yml: shared encrypted values
- host_vars/: host-specific inventory values and encrypted secrets
- roles/: role-based service configuration, one role per feature area

## Deployment model

The main playbook targets three groups:

- gateways: full router/gateway stack
- services: minimal service-host deployment
- monitoring: Grafana, Prometheus, and blackbox exporter stack

The playbook uses serial deployment by default, and it checks OS compatibility before continuing.

## Role conventions

Most roles in roles/ follow this structure:

- tasks/main.yml
- handlers/main.yml
- templates/*.j2
- files/
- defaults/main.yml
- vars/

When working in this repository:

- keep changes Ansible-native and idempotent
- prefer templates for generated config files
- use handlers for service restarts or reloads
- keep host-specific config under host_vars/
- keep shared defaults in group_vars/ and role defaults
- respect the existing role naming and role tags in setup.yml

## Important workflow patterns

### Common commands

```bash
ansible-playbook --vault-id=fastd_key@prompt setup.yml
ansible-playbook --vault-id=fastd_key@prompt setup.yml --limit gateways
ansible-playbook --vault-id=fastd_key@prompt setup.yml --limit services
ansible-playbook --vault-id=fastd_key@prompt setup.yml --limit monitoring
ansible-playbook --vault-id=fastd_key@prompt setup.yml --check
ansible-lint
```

### Secrets and vaults

- use ansible-vault for encrypted values
- do not hardcode secrets in templates or task files
- align secret naming with existing host_vars and group_vars patterns
- follow the guidance in README.md for vault access and per-host credentials

### Adding or changing roles

- create or modify the role under roles/<name>/
- implement logic in tasks/main.yml
- add handler logic if a restart is needed
- add templates for generated configuration files
- update setup.yml to include the role and tag it appropriately
- validate with ansible-lint and targeted playbook checks

## Key files to reference first

- README.md
- setup.yml
- hosts.yml
- group_vars/versions.yml
- roles/

## Guidance for AI assistance

When making changes in this repo:

- treat the project as infrastructure automation, not a generic app codebase
- prefer minimal, safe, idempotent modifications
- preserve the deployment model and role structure already used by the repo
- validate YAML and Ansible conventions before claiming a change is complete
- be careful with host-specific variables and secrets when adding new nodes or services

This repository is optimized around repeatable network provisioning across gateway hosts, so changes should be consistent with the existing structure and operational patterns.
