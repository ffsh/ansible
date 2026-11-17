---
title: Repository layout
description: Where to find the Ansible playbook, inventory, variables, and roles.
---

| Path | Purpose |
| --- | --- |
| `setup.yml` | Main playbook for gateway, service, and monitoring deployments. |
| `hosts.yml` | Inventory and host groups. |
| `group_vars/` | Shared group configuration and encrypted values. |
| `host_vars/` | Host-specific configuration and encrypted values. |
| `roles/` | Service configuration organized by Ansible role. |

The main play targets the `gateways`, `services`, and `monitoring` groups. See
the repository's [README](https://github.com/ffsh/ansible#readme) for
deployment requirements and operational commands.
